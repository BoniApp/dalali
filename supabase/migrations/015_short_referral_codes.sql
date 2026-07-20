-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — Phase 15: Short referral codes
--
-- Referral codes are now exactly 5 characters (unambiguous
-- alphabet, no 0/O/1/I) instead of up to 8 name letters + a 4-char
-- suffix. Replaces handle_new_influencer() from
-- 013_auto_influencer_signup.sql; the trigger itself is unchanged
-- (it references the function by name). Existing long codes are
-- left as-is — only newly minted codes use the short format.
-- Run after 014_avatars_storage_policies.sql
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_influencer()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
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

  -- Mint a unique 5-char referral code (unambiguous alphabet, no
  -- 0/O/1/I). ~33.6M combinations; collisions retried. Same format
  -- as the generate-referral-code edge function.
  FOR v_attempt IN 1..12 LOOP
    v_code := (
      SELECT string_agg(
        substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', floor(random() * 32 + 1)::int, 1),
        ''
      )
      FROM generate_series(1, 5)
    );
    EXIT WHEN NOT EXISTS (SELECT 1 FROM influencers WHERE referral_code = v_code);
  END LOOP;

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
