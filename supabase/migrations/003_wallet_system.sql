-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — Phase 3: Wallet, Transactions & Withdrawals
--
-- Run in Supabase SQL Editor after 002_core_data.sql
-- ═══════════════════════════════════════════════════════════════

-- ─── WALLETS ──────────────────────────────────────────────────
-- One wallet per user. Server-only mutations via Edge Functions.

CREATE TABLE IF NOT EXISTS wallets (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  available_balance NUMERIC DEFAULT 0 CHECK (available_balance >= 0),
  pending_balance NUMERIC DEFAULT 0 CHECK (pending_balance >= 0),
  locked_balance NUMERIC DEFAULT 0 CHECK (locked_balance >= 0),
  total_earned NUMERIC DEFAULT 0,
  total_withdrawn NUMERIC DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own wallet" ON wallets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Server-only wallet mutations" ON wallets FOR ALL USING (false);
CREATE POLICY "Admins read all wallets" ON wallets FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
);

-- ─── TRANSACTIONS ─────────────────────────────────────────────
-- Append-only financial ledger.

CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('agencyFee','revenueShare','withdrawal','refund','adminAdjustment')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','processing','locked','available','completed','failed','reversed')),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  currency TEXT DEFAULT 'TZS',
  payer_id UUID REFERENCES users(id),
  payee_id UUID REFERENCES users(id),
  property_id UUID REFERENCES properties(id),
  property_title TEXT,
  payment_method TEXT DEFAULT 'selcom',
  idempotency_key TEXT UNIQUE,
  selcom_transaction_id TEXT,
  split JSONB,
  failure_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  settled_at TIMESTAMPTZ,
  reversed_at TIMESTAMPTZ
);

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own transactions" ON transactions FOR SELECT
  USING (auth.uid() = payer_id OR auth.uid() = payee_id);
CREATE POLICY "Users can create payment intent" ON transactions FOR INSERT
  WITH CHECK (auth.uid() = payer_id AND status = 'pending');
CREATE POLICY "Server-only transaction updates" ON transactions FOR UPDATE USING (false);
CREATE POLICY "Admins read all transactions" ON transactions FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
);

CREATE INDEX IF NOT EXISTS idx_transactions_payer ON transactions(payer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_payee ON transactions(payee_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_idempotency ON transactions(idempotency_key);

-- ─── WITHDRAWALS ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS withdrawals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  phone TEXT NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('mpesa','airtelMoney','tigoPesa','haloPesa','bankTransfer')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','processing','completed','failed')),
  selcom_payout_id TEXT,
  failure_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

ALTER TABLE withdrawals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own withdrawals" ON withdrawals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can request withdrawal" ON withdrawals FOR INSERT
  WITH CHECK (auth.uid() = user_id AND status = 'pending');
CREATE POLICY "Server-only withdrawal updates" ON withdrawals FOR UPDATE USING (false);
CREATE POLICY "Admins read all withdrawals" ON withdrawals FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
);

CREATE INDEX IF NOT EXISTS idx_withdrawals_user ON withdrawals(user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON withdrawals(status);

-- ─── WEBHOOK PROCESSED (Idempotency) ──────────────────────────

CREATE TABLE IF NOT EXISTS webhook_processed (
  order_id TEXT PRIMARY KEY,
  status TEXT NOT NULL,
  event_type TEXT,
  processed_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE webhook_processed ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Server-only webhook processed" ON webhook_processed FOR ALL USING (false);

-- ─── FRAUD REPORTS ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fraud_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id),
  reporter_name TEXT,
  type TEXT NOT NULL,
  description TEXT,
  evidence_urls TEXT[] DEFAULT '{}',
  status TEXT DEFAULT 'open' CHECK (status IN ('open','investigating','resolved','dismissed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES users(id)
);

ALTER TABLE fraud_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can submit fraud reports" ON fraud_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Users can read own reports" ON fraud_reports FOR SELECT
  USING (auth.uid() = reporter_id);
CREATE POLICY "Admins manage fraud reports" ON fraud_reports FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
);

-- ─── DISPUTES ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id),
  respondent_id UUID REFERENCES users(id),
  property_id UUID REFERENCES properties(id),
  type TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','mediating','resolved','escalated')),
  resolution TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Involved parties can read disputes" ON disputes FOR SELECT
  USING (auth.uid() = reporter_id OR auth.uid() = respondent_id);
CREATE POLICY "Users can create disputes" ON disputes FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Admins manage disputes" ON disputes FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
);
