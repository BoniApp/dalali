-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 026: Lock User Role After Signup
--
-- A user picks ONE role at registration — it must not change
-- afterwards through the client. The users UPDATE policy ("Users
-- can update own profile") has no column restrictions, so anyone
-- could self-promote (seeker → landlord/agent) and skip the
-- verification model. Extends 018's prevent_user_verification_tamper
-- to also guard `role`: only admins (updateUserRole, verifyLandlord)
-- and the service role (edge functions, e.g. generate-referral-code
-- flipping approved influencers) may change it. Re-setting the SAME
-- role value is a no-op and always allowed (the register flow does
-- this right after the handle_new_user trigger).
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

  -- Role is picked once at signup; afterwards admin/server only.
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Clients cannot modify role';
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

-- Trigger already exists from 018 and points at this function by
-- name — CREATE OR REPLACE is enough.
