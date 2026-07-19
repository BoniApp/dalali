-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — Phase 13: Influencer self-signup
--
-- When a user registers with role='influencer' (register screen
-- "I am a: Influencer"), instantly create their influencers row +
-- referral code + default referral link + wallet, with no admin
-- approval step. The application/approval flow (edge function
-- generate-referral-code) still works for users who apply later —
-- it reuses the existing code for users who already have one.
-- Run after 012_nearby_listings.sql
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_influencer()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
  v_base TEXT;
  v_attempt INT;
BEGIN
  -- Only act on a transition INTO the influencer role, once per user.
  IF NEW.role <> 'influencer' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.role = 'influencer' THEN
    RETURN NEW;
  END IF;
  IF EXISTS (SELECT 1 FROM influencers WHERE user_id = NEW.id) THEN
    RETURN NEW;
  END IF;

  -- Mint a unique referral code. Same format as the edge function:
  -- up to 8 letters from the user's name + 4-char random suffix
  -- (unambiguous alphabet, no 0/O/1/I).
  v_base := UPPER(REGEXP_REPLACE(COALESCE(NEW.full_name, ''), '[^a-zA-Z]', '', 'g'));
  v_base := LEFT(COALESCE(NULLIF(v_base, ''), 'DALALI'), 8);

  FOR v_attempt IN 1..6 LOOP
    v_code := v_base || (
      SELECT string_agg(
        substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', floor(random() * 32 + 1)::int, 1),
        ''
      )
      FROM generate_series(1, 4)
    );
    EXIT WHEN NOT EXISTS (SELECT 1 FROM influencers WHERE referral_code = v_code);
    v_code := NULL;
  END LOOP;

  -- Fallback: longer random suffix if all 6 attempts collided.
  IF v_code IS NULL THEN
    v_code := v_base || (
      SELECT string_agg(
        substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', floor(random() * 32 + 1)::int, 1),
        ''
      )
      FROM generate_series(1, 8)
    );
  END IF;

  -- INSERT only: trg_prevent_influencer_tamper is BEFORE UPDATE and
  -- does not fire here.
  INSERT INTO influencers (user_id, referral_code, status, activated_at)
  VALUES (NEW.id, v_code, 'active', NOW())
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO referral_links (influencer_id, code, is_active)
  VALUES (NEW.id, v_code, true)
  ON CONFLICT (code) DO NOTHING;

  -- Wallet for commission payouts (keep existing balances if present).
  INSERT INTO wallets (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO notifications (user_id, type, title, body)
  VALUES (
    NEW.id,
    'system',
    'Karibu to the Influencer Program',
    'Your referral code is ' || v_code || '. Share it to start earning commissions.'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_on_user_becomes_influencer ON users;

CREATE TRIGGER trg_on_user_becomes_influencer
  AFTER INSERT OR UPDATE OF role ON users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_influencer();
