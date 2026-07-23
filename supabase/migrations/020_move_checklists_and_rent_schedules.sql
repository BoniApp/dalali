-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 020: Move Checklists & Rent Schedules
--
-- Completes the tenancy-management chain (My Tenancies → Tenancy
-- Details → Checklist → Rent): both features had models and UI but
-- no tables — checklists never loaded, the rent tab was always
-- empty, and "Pay" was a no-op.
--
-- A tenancies AFTER INSERT trigger seeds both: the tenant gets a
-- default move checklist and 12 monthly rent schedule rows (lease
-- = move_in_date → expected_move_out_date, ~374 days) the moment an
-- application is approved (see 019).
--
-- State machine: rent_schedules.status pending → paid (terminal),
-- 'overdue' is reserved (client computes overdue from due_date).
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. MOVE CHECKLISTS ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS move_checklists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
  move_id UUID, -- reserved for move-engine linkage
  items JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenancy_id, user_id)
);

ALTER TABLE move_checklists ENABLE ROW LEVEL SECURITY;

-- The checklist is the tenant's personal move plan: owner read/write
-- of items only. Rows are created by the setup_new_tenancy() trigger.
DROP POLICY IF EXISTS "Checklists read owner" ON move_checklists;
CREATE POLICY "Checklists read owner" ON move_checklists FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Checklists update owner" ON move_checklists;
CREATE POLICY "Checklists update owner" ON move_checklists FOR UPDATE
  USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_checklists_user ON move_checklists(user_id);
CREATE INDEX IF NOT EXISTS idx_checklists_tenancy ON move_checklists(tenancy_id);

-- ─── 2. RENT SCHEDULES ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS rent_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  landlord_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  property_title TEXT DEFAULT '',
  due_date TIMESTAMPTZ NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','overdue')),
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE rent_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Rent schedules read participants" ON rent_schedules;
CREATE POLICY "Rent schedules read participants" ON rent_schedules FOR SELECT
  USING (
    auth.uid() = tenant_id
    OR auth.uid() = landlord_id
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- Either party may mark a schedule paid (tenant after paying, landlord
-- confirming cash received). The guard trigger below restricts updates
-- to that single transition. Rows are created by the trigger only.
DROP POLICY IF EXISTS "Rent schedules mark paid" ON rent_schedules;
CREATE POLICY "Rent schedules mark paid" ON rent_schedules FOR UPDATE
  USING (auth.uid() = tenant_id OR auth.uid() = landlord_id);

CREATE INDEX IF NOT EXISTS idx_rent_schedules_tenancy ON rent_schedules(tenancy_id);
CREATE INDEX IF NOT EXISTS idx_rent_schedules_tenant ON rent_schedules(tenant_id);
CREATE INDEX IF NOT EXISTS idx_rent_schedules_landlord ON rent_schedules(landlord_id);
CREATE INDEX IF NOT EXISTS idx_rent_schedules_due ON rent_schedules(due_date);

-- Guard: pending/overdue → paid only; paid rows are terminal; schedule
-- terms (tenancy, parties, due date, amount) are immutable; paid_at is
-- server-stamped.
CREATE OR REPLACE FUNCTION public.rent_schedule_guard()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tenancy_id IS DISTINCT FROM OLD.tenancy_id
     OR NEW.tenant_id IS DISTINCT FROM OLD.tenant_id
     OR NEW.landlord_id IS DISTINCT FROM OLD.landlord_id
     OR NEW.property_title IS DISTINCT FROM OLD.property_title
     OR NEW.due_date IS DISTINCT FROM OLD.due_date
     OR NEW.amount IS DISTINCT FROM OLD.amount
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Rent schedule terms are immutable';
  END IF;

  IF OLD.status = 'paid' THEN
    RAISE EXCEPTION 'Rent schedule is already paid';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status <> 'paid' THEN
      RAISE EXCEPTION 'Invalid rent schedule transition: % -> %', OLD.status, NEW.status;
    END IF;
    NEW.paid_at := NOW();
  ELSE
    NEW.paid_at := OLD.paid_at;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_rent_schedule_guard ON rent_schedules;
CREATE TRIGGER trg_rent_schedule_guard
  BEFORE UPDATE ON rent_schedules
  FOR EACH ROW EXECUTE FUNCTION rent_schedule_guard();

-- ─── 3. TENANCY SETUP TRIGGER ───────────────────────────────────
-- Seed the checklist + 12 monthly rent rows for every new tenancy
-- (tenancies are created by 019's approval trigger).

CREATE OR REPLACE FUNCTION public.setup_new_tenancy()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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

DROP TRIGGER IF EXISTS trg_setup_new_tenancy ON tenancies;
CREATE TRIGGER trg_setup_new_tenancy
  AFTER INSERT ON tenancies
  FOR EACH ROW EXECUTE FUNCTION setup_new_tenancy();
