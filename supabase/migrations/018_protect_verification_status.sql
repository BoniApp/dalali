-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — Phase 18: Protect user verification fields
--
-- The users UPDATE policy ("Users can update own profile",
-- 001_initial_schema.sql) has no column restrictions, so any
-- client could self-set verification_status='verified' and bypass
-- the withdrawal gate (016) and trust badges. Mirrors the
-- prevent_influencer_tamper pattern: only admins and the service
-- role (edge functions such as process-kyc-verification) may
-- change these fields.
-- Run after 017_chat.sql
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.prevent_user_verification_tamper()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_privileged BOOLEAN;
BEGIN
  -- Service role (edge functions) and admins may change anything.
  v_privileged :=
    COALESCE(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true);

  IF v_privileged THEN
    RETURN NEW;
  END IF;

  IF NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
    RAISE EXCEPTION 'Clients cannot modify verification_status';
  END IF;

  IF NEW.is_verified_landlord IS DISTINCT FROM OLD.is_verified_landlord
     OR NEW.is_verified_agent IS DISTINCT FROM OLD.is_verified_agent
     OR NEW.is_verified_listing_creator IS DISTINCT FROM OLD.is_verified_listing_creator THEN
    RAISE EXCEPTION 'Clients cannot modify verification badges';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_user_verification_tamper ON users;

CREATE TRIGGER trg_prevent_user_verification_tamper
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION prevent_user_verification_tamper();
