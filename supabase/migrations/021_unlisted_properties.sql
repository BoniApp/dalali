-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 021: Unlisted Properties (No Auto-Relist)
--
-- Bug: handle_tenancy_status_change() (019) flipped a property back
-- to status='available' when its tenancy completed or terminated, so
-- a just-vacated house silently re-entered the public feed.
--
-- Relisting is now an explicit landlord decision: tenancy end parks
-- the property at 'unlisted' (out of every feed, which filters
-- status='available'), and the landlord relists from the dashboard,
-- which sets status back to 'available'.
--
-- 1. Widen the properties.status CHECK with 'unlisted'.
-- 2. Rework handle_tenancy_status_change() accordingly (the trigger
--    itself is untouched — it calls the function by name).
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE properties DROP CONSTRAINT IF EXISTS properties_status_check;
ALTER TABLE properties ADD CONSTRAINT properties_status_check
  CHECK (status IN ('available','occupied','pending','unlisted'));

CREATE OR REPLACE FUNCTION public.handle_tenancy_status_change()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'active' THEN
    UPDATE properties SET status = 'occupied' WHERE id = NEW.property_id;
  ELSIF NEW.status IN ('completed','terminated') THEN
    -- No auto-relist: the property leaves the market until the
    -- landlord explicitly relists it (status back to 'available').
    UPDATE properties SET status = 'unlisted' WHERE id = NEW.property_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

