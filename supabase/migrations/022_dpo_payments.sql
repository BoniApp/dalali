-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 022: DPO Pay Payments & Property Access
--
-- DPO Pay is now the ONLY payment gateway (Selcom removed). The
-- agency-fee collection flow: create-dpo-token inserts a pending
-- `payments` row and mints the DPO token; verify-dpo-payment /
-- dpo-callback settle it (VerifyToken) server-side and unlock the
-- listing's contact details via `property_access`.
--
-- Both tables are service-role write only — clients read their own
-- rows; money movement lands in the existing `transactions` ledger
-- (see _shared/dpo_settlement.ts), which keeps the 60/40 creator
-- split and influencer commissions unchanged.
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. PAYMENTS ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES users(id) ON DELETE SET NULL,   -- listing creator (earns the split)
  landlord_id UUID REFERENCES users(id) ON DELETE SET NULL,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'TZS',
  dpo_token TEXT UNIQUE,
  dpo_transaction_id TEXT,
  payment_method TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','paid','failed','cancelled','expired')),
  receipt_number TEXT NOT NULL UNIQUE
    DEFAULT 'RCPT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Payments read participants" ON payments;
CREATE POLICY "Payments read participants" ON payments FOR SELECT
  USING (
    auth.uid() = tenant_id
    OR auth.uid() = landlord_id
    OR auth.uid() = agent_id
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- Rows are created and settled by edge functions only (service role).
DROP POLICY IF EXISTS "Server-only payment writes" ON payments;
CREATE POLICY "Server-only payment writes" ON payments FOR ALL USING (false);

CREATE INDEX IF NOT EXISTS idx_payments_tenant ON payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_property ON payments(property_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_token ON payments(dpo_token);
-- One open (pending) payment attempt per tenant per property.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_open_payment
  ON payments(tenant_id, property_id) WHERE status = 'pending';

CREATE OR REPLACE FUNCTION public.touch_payments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_payments_touch ON payments;
CREATE TRIGGER trg_payments_touch
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION touch_payments_updated_at();

-- ─── 2. PROPERTY ACCESS ─────────────────────────────────────────
-- Grants contact unlock (phone/WhatsApp/call/chat) once the agency
-- fee is paid. expires_at is reserved (null = no expiry).

CREATE TABLE IF NOT EXISTS property_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  payment_id UUID REFERENCES payments(id) ON DELETE SET NULL,
  paid BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(property_id, tenant_id)
);

ALTER TABLE property_access ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Access read participants" ON property_access;
CREATE POLICY "Access read participants" ON property_access FOR SELECT
  USING (
    auth.uid() = tenant_id
    OR EXISTS (SELECT 1 FROM properties p WHERE p.id = property_id AND p.landlord_id = auth.uid())
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

DROP POLICY IF EXISTS "Server-only access writes" ON property_access;
CREATE POLICY "Server-only access writes" ON property_access FOR ALL USING (false);

CREATE INDEX IF NOT EXISTS idx_property_access_tenant ON property_access(tenant_id);
CREATE INDEX IF NOT EXISTS idx_property_access_property ON property_access(property_id);

-- ─── 3. LEGACY GATEWAY CONFIG ───────────────────────────────────
-- Provider-switching config from the Selcom era; DPO is configured
-- purely via function secrets now.
DROP TABLE IF EXISTS payment_gateways;
