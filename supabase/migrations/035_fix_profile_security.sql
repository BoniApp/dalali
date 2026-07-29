-- ═══════════════════════════════════════════════════════════════
-- DALALI — 035: Fix profile security (admin privilege escalation)
--
-- The users UPDATE policy ("Users can update own profile",
-- 031_initial_schema.sql) has no column restrictions, and the
-- tamper trigger (018, extended by 026 for `role`) never guarded
-- the admin flags — any authenticated user could run
--   UPDATE users SET is_admin = true WHERE id = auth.uid();
-- and gain full admin: every is_admin RLS policy, the admin
-- dashboard, and the admin-JWT path into process-withdrawal.
--
-- This migration extends prevent_user_verification_tamper so
-- non-privileged clients can no longer modify:
--   is_admin, admin_role           (platform access control)
--   subscription_tier              (paid entitlement)
--   total_reward_points            (rewards ledger)
-- plus the fields already guarded by 018/026 (role,
-- verification_status, verification badges).
--
-- Money columns on OTHER tables need no trigger here:
--   wallets.*        — client writes blocked by RLS ("Server-only
--                      wallet mutations" USING (false), 003)
--   payments.status  — same ("Server-only payment writes", 022)
--   transactions.*   — server-only updates (003)
--   commissions/gateway_logs/refunds — locked down in 037.
-- The withdrawal gate (016) and all edge functions run as
-- service_role / admin and keep working.
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.prevent_user_verification_tamper()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_privileged BOOLEAN;
BEGIN
  -- Service role (edge functions) and existing admins may change
  -- anything. The EXISTS reads the STORED row (pre-update state),
  -- so a user cannot escalate is_admin within this same statement
  -- and pass the check.
  v_privileged :=
    COALESCE(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true);

  IF v_privileged THEN
    RETURN NEW;
  END IF;

  -- Platform access control: admin flags are server/admin only.
  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin
     OR NEW.admin_role IS DISTINCT FROM OLD.admin_role THEN
    RAISE EXCEPTION 'Clients cannot modify admin flags';
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

  -- Paid entitlement and rewards ledger are server/admin only.
  IF NEW.subscription_tier IS DISTINCT FROM OLD.subscription_tier THEN
    RAISE EXCEPTION 'Clients cannot modify subscription_tier';
  END IF;

  IF NEW.total_reward_points IS DISTINCT FROM OLD.total_reward_points THEN
    RAISE EXCEPTION 'Clients cannot modify total_reward_points';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- The trigger (trg_prevent_user_verification_tamper, 018) already
-- exists and calls this function by name — CREATE OR REPLACE is
-- sufficient, no trigger re-creation needed.
