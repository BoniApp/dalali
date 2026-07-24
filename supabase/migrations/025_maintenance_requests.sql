-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 025: Maintenance Requests
--
-- The maintenance feature was client-complete but had no table —
-- streams returned nothing and writes were no-ops. Tenants file
-- requests from the tenancy detail screen; landlords move them
-- open → inProgress → resolved (resolved is terminal). Guard
-- trigger freezes parties/details and stamps resolved_at.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS maintenance_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tenant_name TEXT NOT NULL DEFAULT '',
  landlord_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  property_title TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'general'
    CHECK (category IN ('plumbing','electrical','security','general','appliance','structural')),
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','inProgress','resolved')),
  photos JSONB NOT NULL DEFAULT '[]',
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE maintenance_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Maintenance read participants" ON maintenance_requests;
CREATE POLICY "Maintenance read participants" ON maintenance_requests FOR SELECT
  USING (
    auth.uid() = tenant_id
    OR auth.uid() = landlord_id
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- Tenants file their own requests only (always open).
DROP POLICY IF EXISTS "Maintenance insert tenant" ON maintenance_requests;
CREATE POLICY "Maintenance insert tenant" ON maintenance_requests FOR INSERT
  WITH CHECK (auth.uid() = tenant_id AND status = 'open');

-- Only the landlord moves the request through its lifecycle.
DROP POLICY IF EXISTS "Maintenance update landlord" ON maintenance_requests;
CREATE POLICY "Maintenance update landlord" ON maintenance_requests FOR UPDATE
  USING (auth.uid() = landlord_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_tenant ON maintenance_requests(tenant_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_landlord ON maintenance_requests(landlord_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_property ON maintenance_requests(property_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_status ON maintenance_requests(status);

-- Guard: parties/details immutable; open → inProgress|resolved,
-- inProgress → resolved; resolved terminal; resolved_at stamped.
CREATE OR REPLACE FUNCTION public.maintenance_request_guard()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id
     OR NEW.tenant_name IS DISTINCT FROM OLD.tenant_name
     OR NEW.landlord_id IS DISTINCT FROM OLD.landlord_id
     OR NEW.property_id IS DISTINCT FROM OLD.property_id
     OR NEW.property_title IS DISTINCT FROM OLD.property_title
     OR NEW.category IS DISTINCT FROM OLD.category
     OR NEW.description IS DISTINCT FROM OLD.description
     OR NEW.photos IS DISTINCT FROM OLD.photos
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Maintenance request details are immutable';
  END IF;

  IF OLD.status = 'resolved' THEN
    RAISE EXCEPTION 'Maintenance request is already resolved';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status = 'resolved' THEN
      NEW.resolved_at := NOW();
    ELSIF NEW.status = 'inProgress' AND OLD.status = 'open' THEN
      NEW.resolved_at := NULL;
    ELSE
      RAISE EXCEPTION 'Invalid maintenance transition: % -> %', OLD.status, NEW.status;
    END IF;
  ELSE
    NEW.resolved_at := OLD.resolved_at;
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_maintenance_guard ON maintenance_requests;
CREATE TRIGGER trg_maintenance_guard
  BEFORE UPDATE ON maintenance_requests
  FOR EACH ROW EXECUTE FUNCTION maintenance_request_guard();

-- Live updates for the tenancy detail screen (023 skips missing
-- tables, so the table joins the publication here where it exists).
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE maintenance_requests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
