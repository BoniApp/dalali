-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 019: Tenancy Applications & Tenancies
--
-- Closes gap G1 of LISTING_WORKFLOW_SPEC.md: tenancy applications
-- ("reservation requests") and tenancies were client-only state with
-- stubbed persistence. This migration gives both a real table, RLS,
-- and moves ALL approval/activation side effects into server-side
-- triggers so the workflow graph stays consistent regardless of
-- which client commits the status change.
--
-- State machines enforced here:
--   tenancy_applications: pending → approved | rejected   (terminal)
--   tenancies:            upcoming → active → completed | terminated (terminal)
--
-- Note: 'withdrawn'/'expired' application states and the reservation
-- hold/TTL concept are intentionally deferred to the reservations
-- migration (spec §3.2 / gap G5). Sibling auto-reject on approval
-- is gap G6 — hook point marked in handle_application_resolution().
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. TENANCY APPLICATIONS ────────────────────────────────────

CREATE TABLE IF NOT EXISTS tenancy_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  property_title TEXT DEFAULT '',
  tenant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tenant_name TEXT DEFAULT '',
  tenant_phone TEXT DEFAULT '',
  landlord_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  landlord_name TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

ALTER TABLE tenancy_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Applications read participants" ON tenancy_applications;
CREATE POLICY "Applications read participants" ON tenancy_applications FOR SELECT
  USING (
    auth.uid() = tenant_id
    OR auth.uid() = landlord_id
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- Seekers apply for themselves; landlord_id must match the property's
-- actual landlord so applications cannot be spoofed onto another owner.
DROP POLICY IF EXISTS "Seekers can apply" ON tenancy_applications;
CREATE POLICY "Seekers can apply" ON tenancy_applications FOR INSERT
  WITH CHECK (
    auth.uid() = tenant_id
    AND landlord_id = (SELECT landlord_id FROM properties WHERE id = property_id)
  );

-- Only the landlord resolves an application. Transition legality,
-- field immutability, and resolved_at stamping are enforced by the
-- guard trigger below (RLS alone cannot restrict columns/transitions).
DROP POLICY IF EXISTS "Landlords can resolve" ON tenancy_applications;
CREATE POLICY "Landlords can resolve" ON tenancy_applications FOR UPDATE
  USING (auth.uid() = landlord_id);

-- No client DELETE: resolved applications are the audit trail.

-- One open application per seeker per property (gap G7). 'approved'
-- stays covered so the winning tenant cannot double-book; a rejected
-- row drops out of the index, allowing a fresh application.
DROP INDEX IF EXISTS uniq_open_application;
CREATE UNIQUE INDEX uniq_open_application
  ON tenancy_applications(property_id, tenant_id)
  WHERE status IN ('pending','approved');

CREATE INDEX IF NOT EXISTS idx_applications_tenant ON tenancy_applications(tenant_id);
CREATE INDEX IF NOT EXISTS idx_applications_landlord ON tenancy_applications(landlord_id);
CREATE INDEX IF NOT EXISTS idx_applications_property ON tenancy_applications(property_id);
CREATE INDEX IF NOT EXISTS idx_applications_status ON tenancy_applications(status);

-- ─── 2. TENANCIES ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS tenancies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID REFERENCES tenancy_applications(id) ON DELETE SET NULL,
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  property_title TEXT DEFAULT '',
  property_location TEXT DEFAULT '',
  tenant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tenant_name TEXT DEFAULT '',
  landlord_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  landlord_name TEXT DEFAULT '',
  move_in_date TIMESTAMPTZ,
  expected_move_out_date TIMESTAMPTZ,
  rent_amount NUMERIC DEFAULT 0,
  deposit_amount NUMERIC DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming','active','completed','terminated')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  activated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

ALTER TABLE tenancies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tenancies read participants" ON tenancies;
CREATE POLICY "Tenancies read participants" ON tenancies FOR SELECT
  USING (
    auth.uid() = tenant_id
    OR auth.uid() = landlord_id
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- No client INSERT: tenancies are created only by the
-- handle_application_resolution() trigger (SECURITY DEFINER).

-- Only the landlord advances the tenancy lifecycle; the guard trigger
-- restricts updates to legal status transitions.
DROP POLICY IF EXISTS "Landlords can advance tenancy" ON tenancies;
CREATE POLICY "Landlords can advance tenancy" ON tenancies FOR UPDATE
  USING (auth.uid() = landlord_id);

CREATE INDEX IF NOT EXISTS idx_tenancies_tenant ON tenancies(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenancies_landlord ON tenancies(landlord_id);
CREATE INDEX IF NOT EXISTS idx_tenancies_property ON tenancies(property_id);
CREATE INDEX IF NOT EXISTS idx_tenancies_status ON tenancies(status);

-- ─── 3. APPLICATION GUARD (BEFORE UPDATE) ───────────────────────
-- Enforces the state machine: pending → approved | rejected, then
-- terminal. Identity/denormalized fields are immutable; resolved_at
-- is stamped server-side so clients cannot fabricate it.

CREATE OR REPLACE FUNCTION public.tenancy_application_guard()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.property_id IS DISTINCT FROM OLD.property_id
     OR NEW.tenant_id IS DISTINCT FROM OLD.tenant_id
     OR NEW.landlord_id IS DISTINCT FROM OLD.landlord_id
     OR NEW.property_title IS DISTINCT FROM OLD.property_title
     OR NEW.tenant_name IS DISTINCT FROM OLD.tenant_name
     OR NEW.tenant_phone IS DISTINCT FROM OLD.tenant_phone
     OR NEW.landlord_name IS DISTINCT FROM OLD.landlord_name
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Applications are immutable except status/notes';
  END IF;

  -- Resolved applications are terminal (spec §4 dead end).
  IF OLD.status <> 'pending' THEN
    RAISE EXCEPTION 'Application is already resolved';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status NOT IN ('approved','rejected') THEN
      RAISE EXCEPTION 'Invalid application transition: % -> %', OLD.status, NEW.status;
    END IF;
    NEW.resolved_at := NOW();
  ELSE
    NEW.resolved_at := OLD.resolved_at;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tenancy_application_guard ON tenancy_applications;
CREATE TRIGGER trg_tenancy_application_guard
  BEFORE UPDATE ON tenancy_applications
  FOR EACH ROW EXECUTE FUNCTION tenancy_application_guard();

-- ─── 4. APPLICATION SIDE EFFECTS ────────────────────────────────
-- INSERT → notify landlord (replaces the client-side notifyUser call).
-- approval → create tenancy + reserve property + notify tenant,
--            atomically; rejected → notify tenant.

CREATE OR REPLACE FUNCTION public.handle_new_tenancy_application()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, body, target_id, target_collection)
  VALUES (
    NEW.landlord_id,
    'tenancyApplication',
    'New Tenancy Application',
    COALESCE(NULLIF(NEW.tenant_name, ''), 'A seeker') || ' applied for ' || NEW.property_title,
    NEW.id::text,
    'tenancy_applications'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_new_tenancy_application ON tenancy_applications;
CREATE TRIGGER trg_new_tenancy_application
  AFTER INSERT ON tenancy_applications
  FOR EACH ROW EXECUTE FUNCTION handle_new_tenancy_application();

CREATE OR REPLACE FUNCTION public.handle_application_resolution()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prop properties%ROWTYPE;
BEGIN
  IF NEW.status = 'approved' THEN
    -- Reserve the property atomically; aborts the whole transaction
    -- (application stays pending, no tenancy created) if another deal
    -- already took the listing off the market.
    UPDATE properties
    SET status = 'pending'
    WHERE id = NEW.property_id AND status = 'available';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Property is no longer available';
    END IF;

    SELECT * INTO v_prop FROM properties WHERE id = NEW.property_id;

    -- Mirrors the former client-side construction: move-in +14 days,
    -- move-out +374 days, deposit = 2x rent (old app_state.dart:678-681).
    INSERT INTO tenancies (
      application_id, property_id, property_title, property_location,
      tenant_id, tenant_name, landlord_id, landlord_name,
      move_in_date, expected_move_out_date, rent_amount, deposit_amount
    ) VALUES (
      NEW.id, NEW.property_id, NEW.property_title, v_prop.location,
      NEW.tenant_id, NEW.tenant_name, NEW.landlord_id, NEW.landlord_name,
      NOW() + INTERVAL '14 days', NOW() + INTERVAL '374 days',
      v_prop.rent_price, v_prop.rent_price * 2
    );

    INSERT INTO notifications (user_id, type, title, body, target_id, target_collection)
    VALUES (
      NEW.tenant_id,
      'tenancyApproved',
      'Application Approved',
      'Your application for ' || NEW.property_title || ' was approved!',
      NEW.id::text,
      'tenancy_applications'
    );

    -- G6 hook point: auto-reject sibling pending applications for this
    -- property + notify them. Deferred to the reservations migration.
  ELSIF NEW.status = 'rejected' THEN
    INSERT INTO notifications (user_id, type, title, body, target_id, target_collection)
    VALUES (
      NEW.tenant_id,
      'system',
      'Application Rejected',
      'Your application for ' || NEW.property_title || ' was not approved.',
      NEW.id::text,
      'tenancy_applications'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_application_resolution ON tenancy_applications;
CREATE TRIGGER trg_application_resolution
  AFTER UPDATE OF status ON tenancy_applications
  FOR EACH ROW EXECUTE FUNCTION handle_application_resolution();

-- ─── 5. TENANCY GUARD + PROPERTY RECONCILIATION ─────────────────
-- upcoming → active → completed | terminated; upcoming → terminated
-- is allowed as the early-exit path (spec §4). Timestamps are
-- server-stamped; property status is reconciled by trigger so the
-- listing feed can never drift from tenancy reality.

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
  IF OLD.status IN ('completed','terminated') THEN
    RAISE EXCEPTION 'Tenancy is closed';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status = 'upcoming' AND NEW.status IN ('active','terminated'))
      OR (OLD.status = 'active' AND NEW.status IN ('completed','terminated'))
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

DROP TRIGGER IF EXISTS trg_tenancy_guard ON tenancies;
CREATE TRIGGER trg_tenancy_guard
  BEFORE UPDATE ON tenancies
  FOR EACH ROW EXECUTE FUNCTION tenancy_guard();

CREATE OR REPLACE FUNCTION public.handle_tenancy_status_change()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'active' THEN
    UPDATE properties SET status = 'occupied' WHERE id = NEW.property_id;
  ELSIF NEW.status IN ('completed','terminated') THEN
    -- Listing returns to the feed (status='available'). The
    -- reservations work (G5) may refine listing_status here later.
    UPDATE properties SET status = 'available' WHERE id = NEW.property_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tenancy_status_change ON tenancies;
CREATE TRIGGER trg_tenancy_status_change
  AFTER UPDATE OF status ON tenancies
  FOR EACH ROW EXECUTE FUNCTION handle_tenancy_status_change();
