-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 029: Property Lifecycle Management
--
-- Closes spec gap G10 (LISTING_WORKFLOW_SPEC.md: "terminated tenancy
-- unreachable, no early-exit flow") and extends the tenancy pipeline
-- (019/020/021/025) past "active" into notice → renewal|move-out →
-- inspection → deposit settlement → relist.
--
-- Deliberately additive:
--   - properties.status (available/occupied/pending/unlisted) is
--     UNTOUCHED — it gates the public feed everywhere. Turnover
--     detail (notice period / inspection / maintenance / available
--     again / archived) is layered on the existing, already-unused-
--     for-this listing_status column instead.
--   - tenancies.status keeps its existing values and guard shape;
--     'renewed' is added as a fourth terminal state alongside
--     completed/terminated so the timeline can tell "lease ended,
--     tenant renewed" apart from "lease ended, tenant left".
--   - Renewal creates a NEW tenancies row (back-linked via
--     renewed_from_tenancy_id) rather than mutating a closed one —
--     reuses setup_new_tenancy() (020) for rent-schedule seeding and
--     avoids fighting the terminal-state immutability guard.
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. PROPERTY LIFECYCLE STATES (listing_status) ──────────────

ALTER TABLE properties DROP CONSTRAINT IF EXISTS properties_listing_status_check;
ALTER TABLE properties ADD CONSTRAINT properties_listing_status_check
  CHECK (listing_status IN (
    'draft','active','viewing','negotiating','tenancyConfirmed','closed',
    'noticePeriod','inspection','maintenanceInProgress','availableAgain','archived'
  ));

-- ─── 2. TENANCIES: notice / renewal / agent linkage ─────────────

ALTER TABLE tenancies
  ADD COLUMN IF NOT EXISTS agent_id UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS termination_reason TEXT,
  ADD COLUMN IF NOT EXISTS notice_given_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notice_by TEXT CHECK (notice_by IN ('tenant','landlord')),
  ADD COLUMN IF NOT EXISTS planned_move_out_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS renewal_requested_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS renewed_from_tenancy_id UUID REFERENCES tenancies(id),
  ADD COLUMN IF NOT EXISTS expiry_reminder_sent_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_tenancies_agent ON tenancies(agent_id);
CREATE INDEX IF NOT EXISTS idx_tenancies_renewed_from ON tenancies(renewed_from_tenancy_id);
-- Backs the expiry-reminder / process-expiry edge function scans.
CREATE INDEX IF NOT EXISTS idx_tenancies_active_move_out
  ON tenancies(expected_move_out_date) WHERE status = 'active';

ALTER TABLE tenancies DROP CONSTRAINT IF EXISTS tenancies_status_check;
ALTER TABLE tenancies ADD CONSTRAINT tenancies_status_check
  CHECK (status IN ('upcoming','active','completed','terminated','renewed'));

CREATE OR REPLACE FUNCTION public.tenancy_guard()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.application_id IS DISTINCT FROM OLD.application_id
     OR NEW.property_id IS DISTINCT FROM OLD.property_id
     OR NEW.tenant_id IS DISTINCT FROM OLD.tenant_id
     OR NEW.landlord_id IS DISTINCT FROM OLD.landlord_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Tenancy identity fields are immutable';
  END IF;

  -- Closed tenancies are terminal.
  IF OLD.status IN ('completed','terminated','renewed') THEN
    RAISE EXCEPTION 'Tenancy is closed';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status = 'upcoming' AND NEW.status IN ('active','terminated'))
      OR (OLD.status = 'active' AND NEW.status IN ('completed','terminated','renewed'))
    ) THEN
      RAISE EXCEPTION 'Invalid tenancy transition: % -> %', OLD.status, NEW.status;
    END IF;
    IF NEW.status = 'active' THEN
      NEW.activated_at := NOW();
    ELSE
      NEW.completed_at := NOW();
    END IF;
  ELSE
    NEW.activated_at := OLD.activated_at;
    NEW.completed_at := OLD.completed_at;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Property reconciliation: 'renewed' behaves like 'completed' — the
-- old unit is vacated by that lease record even though a fresh
-- tenancies row (created by create-renewal-record) keeps the tenant
-- in place and the property occupied, so this UPDATE is immediately
-- superseded within the same edge-function transaction. Written
-- explicitly (not folded into the completed/terminated branch) so
-- that intent stays legible if the two ever diverge.
CREATE OR REPLACE FUNCTION public.handle_tenancy_status_change()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'active' THEN
    UPDATE properties SET status = 'occupied' WHERE id = NEW.property_id;
  ELSIF NEW.status IN ('completed','terminated','renewed') THEN
    UPDATE properties SET status = 'unlisted' WHERE id = NEW.property_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- setup_new_tenancy (020) seeds a move checklist + 12 rent rows for
-- every new tenancy. A renewal isn't a move — skip the checklist,
-- keep the rent schedule (new lease term, new due dates).
CREATE OR REPLACE FUNCTION public.setup_new_tenancy()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.renewed_from_tenancy_id IS NULL THEN
    INSERT INTO move_checklists (user_id, tenancy_id, items)
    VALUES (
      NEW.tenant_id,
      NEW.id,
      '[
        {"id":"c1","title":"Confirm move-in date with landlord","completed":false,"completedAt":null},
        {"id":"c2","title":"Pay deposit and first month rent","completed":false,"completedAt":null},
        {"id":"c3","title":"Arrange transport or movers","completed":false,"completedAt":null},
        {"id":"c4","title":"Pack and label belongings","completed":false,"completedAt":null},
        {"id":"c5","title":"Transfer utilities (water & electricity)","completed":false,"completedAt":null},
        {"id":"c6","title":"Inspect new home and report issues","completed":false,"completedAt":null},
        {"id":"c7","title":"Handover walkthrough with landlord","completed":false,"completedAt":null},
        {"id":"c8","title":"Return old keys and update address","completed":false,"completedAt":null}
      ]'::jsonb
    );
  END IF;

  IF NEW.move_in_date IS NOT NULL THEN
    FOR i IN 0..11 LOOP
      INSERT INTO rent_schedules (tenancy_id, tenant_id, landlord_id, property_title, due_date, amount)
      VALUES (
        NEW.id,
        NEW.tenant_id,
        NEW.landlord_id,
        NEW.property_title,
        NEW.move_in_date + make_interval(months => i),
        NEW.rent_amount
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Best-effort agent attribution: when a tenancy is created off an
-- approved application, copy the property's listing_creator_id onto
-- tenancies.agent_id if that user is an agent. Passive — does not
-- touch the separate (and separately broken, spec gaps G3/G4) deals
-- pipeline.
CREATE OR REPLACE FUNCTION public.attach_tenancy_agent()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  SELECT p.listing_creator_id INTO NEW.agent_id
  FROM properties p
  JOIN users u ON u.id = p.listing_creator_id
  WHERE p.id = NEW.property_id AND u.role = 'agent';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_attach_tenancy_agent ON tenancies;
CREATE TRIGGER trg_attach_tenancy_agent
  BEFORE INSERT ON tenancies
  FOR EACH ROW EXECUTE FUNCTION attach_tenancy_agent();

-- ─── 3. MAINTENANCE REQUESTS: turnover linkage ──────────────────

ALTER TABLE maintenance_requests
  ADD COLUMN IF NOT EXISTS tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cost NUMERIC DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_maintenance_tenancy ON maintenance_requests(tenancy_id);

-- Turnover repairs (no active tenant to file them) are landlord-
-- initiated. Tenant-filed requests keep using the existing INSERT
-- policy (025).
DROP POLICY IF EXISTS "Maintenance insert landlord" ON maintenance_requests;
CREATE POLICY "Maintenance insert landlord" ON maintenance_requests FOR INSERT
  WITH CHECK (auth.uid() = landlord_id AND status = 'open');

-- ─── 4. INSPECTIONS ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
  landlord_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inspector_id UUID REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','completed')),
  scheduled_date TIMESTAMPTZ,
  condition_before TEXT,
  condition_after TEXT,
  damage_cost NUMERIC DEFAULT 0,
  photos JSONB NOT NULL DEFAULT '[]',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Inspections read participants" ON inspections;
CREATE POLICY "Inspections read participants" ON inspections FOR SELECT
  USING (
    auth.uid() = landlord_id
    OR auth.uid() = (SELECT tenant_id FROM tenancies WHERE id = inspections.tenancy_id)
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

DROP POLICY IF EXISTS "Inspections insert landlord" ON inspections;
CREATE POLICY "Inspections insert landlord" ON inspections FOR INSERT
  WITH CHECK (auth.uid() = landlord_id);

DROP POLICY IF EXISTS "Inspections update landlord" ON inspections;
CREATE POLICY "Inspections update landlord" ON inspections FOR UPDATE
  USING (auth.uid() = landlord_id);

CREATE INDEX IF NOT EXISTS idx_inspections_property ON inspections(property_id);
CREATE INDEX IF NOT EXISTS idx_inspections_tenancy ON inspections(tenancy_id);
CREATE INDEX IF NOT EXISTS idx_inspections_landlord ON inspections(landlord_id);
CREATE INDEX IF NOT EXISTS idx_inspections_status ON inspections(status);

-- Guard: identity fields immutable; scheduled -> completed only,
-- terminal after; completed_at server-stamped.
CREATE OR REPLACE FUNCTION public.inspection_guard()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.property_id IS DISTINCT FROM OLD.property_id
     OR NEW.tenancy_id IS DISTINCT FROM OLD.tenancy_id
     OR NEW.landlord_id IS DISTINCT FROM OLD.landlord_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Inspection identity fields are immutable';
  END IF;

  IF OLD.status = 'completed' THEN
    RAISE EXCEPTION 'Inspection is already completed';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status <> 'completed' THEN
      RAISE EXCEPTION 'Invalid inspection transition: % -> %', OLD.status, NEW.status;
    END IF;
    NEW.completed_at := NOW();
  ELSE
    NEW.completed_at := OLD.completed_at;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inspection_guard ON inspections;
CREATE TRIGGER trg_inspection_guard
  BEFORE UPDATE ON inspections
  FOR EACH ROW EXECUTE FUNCTION inspection_guard();

-- ─── 5. DEPOSIT TRANSACTIONS ─────────────────────────────────────
-- Record-keeping only: no money moves through Dalali here (deposits
-- are held directly between tenant and landlord, same as rent). The
-- refund_amount is server-checked to equal amount - deductions so
-- the numbers on screen can't drift from each other.

CREATE TABLE IF NOT EXISTS deposit_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  landlord_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL DEFAULT 0,
  deductions NUMERIC NOT NULL DEFAULT 0,
  refund_amount NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','settled','disputed')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  settled_at TIMESTAMPTZ
);

ALTER TABLE deposit_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Deposits read participants" ON deposit_transactions;
CREATE POLICY "Deposits read participants" ON deposit_transactions FOR SELECT
  USING (
    auth.uid() = tenant_id
    OR auth.uid() = landlord_id
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

DROP POLICY IF EXISTS "Deposits insert landlord" ON deposit_transactions;
CREATE POLICY "Deposits insert landlord" ON deposit_transactions FOR INSERT
  WITH CHECK (auth.uid() = landlord_id AND status = 'pending');

DROP POLICY IF EXISTS "Deposits update landlord" ON deposit_transactions;
CREATE POLICY "Deposits update landlord" ON deposit_transactions FOR UPDATE
  USING (auth.uid() = landlord_id);

CREATE INDEX IF NOT EXISTS idx_deposits_tenancy ON deposit_transactions(tenancy_id);
CREATE INDEX IF NOT EXISTS idx_deposits_tenant ON deposit_transactions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_deposits_landlord ON deposit_transactions(landlord_id);

CREATE OR REPLACE FUNCTION public.deposit_transaction_guard()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tenancy_id IS DISTINCT FROM OLD.tenancy_id
     OR NEW.tenant_id IS DISTINCT FROM OLD.tenant_id
     OR NEW.landlord_id IS DISTINCT FROM OLD.landlord_id
     OR NEW.amount IS DISTINCT FROM OLD.amount
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Deposit transaction terms are immutable';
  END IF;

  IF OLD.status <> 'pending' THEN
    RAISE EXCEPTION 'Deposit transaction is already resolved';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status NOT IN ('settled','disputed') THEN
      RAISE EXCEPTION 'Invalid deposit transition: % -> %', OLD.status, NEW.status;
    END IF;
    IF NEW.status = 'settled' AND NEW.refund_amount IS DISTINCT FROM (NEW.amount - NEW.deductions) THEN
      RAISE EXCEPTION 'refund_amount must equal amount - deductions';
    END IF;
    NEW.settled_at := NOW();
  ELSE
    NEW.settled_at := OLD.settled_at;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_deposit_transaction_guard ON deposit_transactions;
CREATE TRIGGER trg_deposit_transaction_guard
  BEFORE UPDATE ON deposit_transactions
  FOR EACH ROW EXECUTE FUNCTION deposit_transaction_guard();

-- ─── 6. NOTIFICATIONS: new lifecycle event types ────────────────

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'inquiry','appointment','propertyApproved','propertyRejected',
    'tenancyApplication','tenancyApproved','maintenanceUpdate','rentDue',
    'paymentReceived','withdrawalProcessed','system',
    'tenancyExpiring','noticeGiven','renewalRequested',
    'inspectionScheduled','depositSettled'
  ));

-- ─── 7. LIFECYCLE RPCs ───────────────────────────────────────────
-- Bundle a status change with its notification atomically, same
-- shape as handle_application_resolution() (019) — client calls
-- .rpc(), never writes these fields directly.

CREATE OR REPLACE FUNCTION public.give_tenancy_notice(
  p_tenancy_id UUID,
  p_given_by TEXT,
  p_planned_move_out_date TIMESTAMPTZ,
  p_reason TEXT DEFAULT NULL
)
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenancy tenancies%ROWTYPE;
  v_recipient UUID;
BEGIN
  SELECT * INTO v_tenancy FROM tenancies WHERE id = p_tenancy_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tenancy not found';
  END IF;
  IF v_tenancy.status <> 'active' THEN
    RAISE EXCEPTION 'Notice can only be given on an active tenancy';
  END IF;
  IF auth.uid() <> v_tenancy.tenant_id AND auth.uid() <> v_tenancy.landlord_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_given_by NOT IN ('tenant','landlord') THEN
    RAISE EXCEPTION 'given_by must be tenant or landlord';
  END IF;

  UPDATE tenancies SET
    notice_given_at = NOW(),
    notice_by = p_given_by,
    planned_move_out_date = p_planned_move_out_date,
    termination_reason = p_reason
  WHERE id = p_tenancy_id;

  UPDATE properties SET listing_status = 'noticePeriod' WHERE id = v_tenancy.property_id;

  v_recipient := CASE WHEN p_given_by = 'tenant' THEN v_tenancy.landlord_id ELSE v_tenancy.tenant_id END;
  INSERT INTO notifications (user_id, type, title, body, target_id, target_collection)
  VALUES (
    v_recipient,
    'noticeGiven',
    'Move-Out Notice Given',
    (CASE WHEN p_given_by = 'tenant' THEN v_tenancy.tenant_name ELSE v_tenancy.landlord_name END)
      || ' gave notice for ' || v_tenancy.property_title,
    p_tenancy_id::text,
    'tenancies'
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.request_tenancy_renewal(
  p_tenancy_id UUID,
  p_requested_by TEXT
)
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenancy tenancies%ROWTYPE;
  v_recipient UUID;
BEGIN
  SELECT * INTO v_tenancy FROM tenancies WHERE id = p_tenancy_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tenancy not found';
  END IF;
  IF v_tenancy.status <> 'active' THEN
    RAISE EXCEPTION 'Renewal can only be requested on an active tenancy';
  END IF;
  IF auth.uid() <> v_tenancy.tenant_id AND auth.uid() <> v_tenancy.landlord_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_requested_by NOT IN ('tenant','landlord') THEN
    RAISE EXCEPTION 'requested_by must be tenant or landlord';
  END IF;

  UPDATE tenancies SET renewal_requested_at = NOW() WHERE id = p_tenancy_id;

  v_recipient := CASE WHEN p_requested_by = 'tenant' THEN v_tenancy.landlord_id ELSE v_tenancy.tenant_id END;
  INSERT INTO notifications (user_id, type, title, body, target_id, target_collection)
  VALUES (
    v_recipient,
    'renewalRequested',
    'Renewal Requested',
    (CASE WHEN p_requested_by = 'tenant' THEN v_tenancy.tenant_name ELSE v_tenancy.landlord_name END)
      || ' requested to renew the tenancy for ' || v_tenancy.property_title,
    p_tenancy_id::text,
    'tenancies'
  );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.give_tenancy_notice TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_tenancy_renewal TO authenticated;

-- ─── 8. REALTIME PUBLICATION ─────────────────────────────────────

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE inspections;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE deposit_transactions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
