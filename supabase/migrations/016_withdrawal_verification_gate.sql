-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — Phase 16: Withdrawal verification gate
--
-- Withdrawal requests are direct client inserts into
-- public.withdrawals, so enforcement must live in the database:
-- a user may only request a withdrawal when their account is
-- verified (users.verification_status = 'verified', set by the
-- KYC flow). Processing functions only UPDATE existing rows, so
-- the gate applies to INSERT only.
-- Run after 015_short_referral_codes.sql
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.enforce_withdrawal_verification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
BEGIN
  SELECT verification_status INTO v_status
  FROM public.users
  WHERE id = NEW.user_id;

  IF v_status IS DISTINCT FROM 'verified' THEN
    RAISE EXCEPTION 'Account verification required before making withdrawals';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_withdrawal_verification ON withdrawals;

CREATE TRIGGER trg_withdrawal_verification
  BEFORE INSERT ON withdrawals
  FOR EACH ROW
  EXECUTE FUNCTION enforce_withdrawal_verification();
