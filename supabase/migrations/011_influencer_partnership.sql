-- ═══════════════════════════════════════════════════════════════
-- 011: INFLUENCER PARTNERSHIP SYSTEM
-- ═══════════════════════════════════════════════════════════════
-- Adds the `influencer` role, application/approval flow, referral
-- tracking, commission conversion ledger, campaigns, and fraud logs.
--
-- Money movement reuses the existing tables (003_wallet_system.sql):
--   wallets / transactions / withdrawals
-- Commission entries reuse `earnings` with type 'referralCommission'.
--
-- Run after 010_architecture_upgrade_and_kyc.sql.

-- ═══════════════════════════════════════════════════════════════
-- PART A: ALTER EXISTING OBJECTS
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. users.role: allow 'influencer' ────────────────────────

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check
  CHECK (role IN ('seeker', 'landlord', 'agent', 'influencer'));

-- Signup trigger: accept 'influencer' in the role whitelist.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_role TEXT;
BEGIN
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'seeker');

  IF user_role NOT IN ('seeker', 'landlord', 'agent', 'influencer') THEN
    user_role := 'seeker';
  END IF;

  INSERT INTO public.users (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    user_role
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── 2. earnings.type: allow 'referralCommission' ─────────────

ALTER TABLE earnings DROP CONSTRAINT IF EXISTS earnings_type_check;
ALTER TABLE earnings ADD CONSTRAINT earnings_type_check
  CHECK (type IN ('agencyFee', 'bonus', 'adjustment', 'referralCommission'));

-- ─── 3. system_settings: influencer commission config ─────────

ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS influencer_agency_fee_pct NUMERIC DEFAULT 0.10;
ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS influencer_premium_pct NUMERIC DEFAULT 0.20;
ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS influencer_registration_bonus NUMERIC DEFAULT 0;
ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS influencer_program_enabled BOOLEAN DEFAULT true;

-- ═══════════════════════════════════════════════════════════════
-- PART B: NEW TABLES
-- ═══════════════════════════════════════════════════════════════

-- ─── 4. INFLUENCERS ───────────────────────────────────────────
-- Profile + denormalized stats for an approved influencer.
-- Money lives in `wallets` (keyed by the same user_id).

CREATE TABLE IF NOT EXISTS influencers (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  referral_code TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended')),
  tiktok_url TEXT,
  instagram_url TEXT,
  youtube_url TEXT,
  followers_count INTEGER DEFAULT 0,
  content_niche TEXT,
  audience_location TEXT,
  total_clicks INTEGER NOT NULL DEFAULT 0,
  total_registrations INTEGER NOT NULL DEFAULT 0,
  total_conversions INTEGER NOT NULL DEFAULT 0,
  total_earnings NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  activated_at TIMESTAMPTZ
);

ALTER TABLE influencers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Influencers read own" ON influencers;
CREATE POLICY "Influencers read own"
  ON influencers FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Influencers read admin" ON influencers;
CREATE POLICY "Influencers read admin"
  ON influencers FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- Owner may edit social/profile fields; status, referral_code and the
-- counters are protected by the prevent_influencer_tamper trigger.
DROP POLICY IF EXISTS "Influencers update own profile" ON influencers;
CREATE POLICY "Influencers update own profile"
  ON influencers FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Influencers update admin" ON influencers;
CREATE POLICY "Influencers update admin"
  ON influencers FOR UPDATE USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_influencers_status ON influencers(status);

-- ─── 5. INFLUENCER APPLICATIONS ───────────────────────────────

CREATE TABLE IF NOT EXISTS influencer_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  tiktok_url TEXT,
  instagram_url TEXT,
  youtube_url TEXT,
  followers_count INTEGER DEFAULT 0,
  content_niche TEXT,
  audience_location TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE influencer_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Applications insert own" ON influencer_applications;
CREATE POLICY "Applications insert own"
  ON influencer_applications FOR INSERT
  WITH CHECK (auth.uid() = user_id AND status = 'pending');

DROP POLICY IF EXISTS "Applications read own" ON influencer_applications;
CREATE POLICY "Applications read own"
  ON influencer_applications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Applications read admin" ON influencer_applications;
CREATE POLICY "Applications read admin"
  ON influencer_applications FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

DROP POLICY IF EXISTS "Applications update admin" ON influencer_applications;
CREATE POLICY "Applications update admin"
  ON influencer_applications FOR UPDATE USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_influencer_applications_status ON influencer_applications(status);

-- ─── 6. REFERRAL LINKS ────────────────────────────────────────
-- One default link per influencer; more per campaign later.

CREATE TABLE IF NOT EXISTS referral_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  influencer_id UUID NOT NULL REFERENCES influencers(user_id) ON DELETE CASCADE,
  campaign_id UUID,
  code TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE referral_links ENABLE ROW LEVEL SECURITY;

-- Codes are public by design (shared on social media): any
-- authenticated user may look up an ACTIVE code (registration flow).
DROP POLICY IF EXISTS "Referral links public read active" ON referral_links;
CREATE POLICY "Referral links public read active"
  ON referral_links FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Referral links read own" ON referral_links;
CREATE POLICY "Referral links read own"
  ON referral_links FOR SELECT USING (auth.uid() = influencer_id);

DROP POLICY IF EXISTS "Referral links read admin" ON referral_links;
CREATE POLICY "Referral links read admin"
  ON referral_links FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_referral_links_influencer ON referral_links(influencer_id);
CREATE INDEX IF NOT EXISTS idx_referral_links_campaign ON referral_links(campaign_id);

-- ─── 7. REFERRAL CLICKS ───────────────────────────────────────
-- A row per code use. v1 source = 'registration'; deeplink/web later.

CREATE TABLE IF NOT EXISTS referral_clicks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id UUID REFERENCES referral_links(id) ON DELETE SET NULL,
  code TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'registration',
  ip TEXT,
  user_agent TEXT,
  referred_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE referral_clicks ENABLE ROW LEVEL SECURITY;

-- Registration flow: a signed-in user attributes themselves to a code.
DROP POLICY IF EXISTS "Clicks insert own attribution" ON referral_clicks;
CREATE POLICY "Clicks insert own attribution"
  ON referral_clicks FOR INSERT
  WITH CHECK (
    referred_user_id = auth.uid()
    AND code IN (SELECT code FROM referral_links WHERE is_active = true)
  );

DROP POLICY IF EXISTS "Clicks read own influencer" ON referral_clicks;
CREATE POLICY "Clicks read own influencer"
  ON referral_clicks FOR SELECT USING (
    link_id IN (SELECT id FROM referral_links WHERE influencer_id = auth.uid())
  );

DROP POLICY IF EXISTS "Clicks read admin" ON referral_clicks;
CREATE POLICY "Clicks read admin"
  ON referral_clicks FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_referral_clicks_code ON referral_clicks(code);
CREATE INDEX IF NOT EXISTS idx_referral_clicks_link ON referral_clicks(link_id);
CREATE INDEX IF NOT EXISTS idx_referral_clicks_referred ON referral_clicks(referred_user_id);

-- ─── 8. REFERRAL CONVERSIONS ──────────────────────────────────
-- Meaningful attributed events. Money rows carry commission_amount;
-- the matching ledger row lives in `earnings` (earnings_entry_id).
-- transaction_id / earnings_entry_id intentionally have no FK:
-- the transactions table has two historic variants (see 001 vs 003).

CREATE TABLE IF NOT EXISTS referral_conversions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  influencer_id UUID NOT NULL REFERENCES influencers(user_id) ON DELETE CASCADE,
  link_id UUID REFERENCES referral_links(id) ON DELETE SET NULL,
  referred_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  transaction_id UUID,
  earnings_entry_id UUID,
  conversion_type TEXT NOT NULL CHECK (conversion_type IN
    ('registration', 'agency_fee_payment', 'premium_payment', 'deal_closed')),
  commission_amount NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (referred_user_id, conversion_type)
);

ALTER TABLE referral_conversions ENABLE ROW LEVEL SECURITY;

-- Registration attribution: the referred user creates their own
-- 'registration' conversion, never for themselves, never with money.
DROP POLICY IF EXISTS "Conversions insert own registration" ON referral_conversions;
CREATE POLICY "Conversions insert own registration"
  ON referral_conversions FOR INSERT
  WITH CHECK (
    conversion_type = 'registration'
    AND referred_user_id = auth.uid()
    AND influencer_id <> auth.uid()
    AND commission_amount = 0
    AND status = 'pending'
  );

DROP POLICY IF EXISTS "Conversions read own" ON referral_conversions;
CREATE POLICY "Conversions read own"
  ON referral_conversions FOR SELECT USING (auth.uid() = influencer_id);

DROP POLICY IF EXISTS "Conversions read admin" ON referral_conversions;
CREATE POLICY "Conversions read admin"
  ON referral_conversions FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- No client UPDATE/DELETE policies: mutations are server-only
-- (service role bypasses RLS).

CREATE INDEX IF NOT EXISTS idx_referral_conversions_influencer ON referral_conversions(influencer_id);
CREATE INDEX IF NOT EXISTS idx_referral_conversions_transaction ON referral_conversions(transaction_id);

-- ─── 9. CAMPAIGNS ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  budget NUMERIC DEFAULT 0,
  start_date DATE,
  end_date DATE,
  target_audience TEXT DEFAULT '',
  commission_rules JSONB,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'paused', 'ended')),
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Campaigns read active" ON campaigns;
CREATE POLICY "Campaigns read active"
  ON campaigns FOR SELECT USING (status = 'active');

DROP POLICY IF EXISTS "Campaigns read admin" ON campaigns;
CREATE POLICY "Campaigns read admin"
  ON campaigns FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

DROP POLICY IF EXISTS "Campaigns write admin" ON campaigns;
CREATE POLICY "Campaigns write admin"
  ON campaigns FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_dates ON campaigns(start_date, end_date);

-- ─── 10. CAMPAIGN PARTICIPANTS ────────────────────────────────

CREATE TABLE IF NOT EXISTS campaign_participants (
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  influencer_id UUID NOT NULL REFERENCES influencers(user_id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'joined' CHECK (status IN ('joined', 'removed')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (campaign_id, influencer_id)
);

ALTER TABLE campaign_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participants join own" ON campaign_participants;
CREATE POLICY "Participants join own"
  ON campaign_participants FOR INSERT
  WITH CHECK (
    influencer_id = auth.uid()
    AND EXISTS (SELECT 1 FROM influencers WHERE user_id = auth.uid() AND status = 'active')
    AND EXISTS (SELECT 1 FROM campaigns WHERE id = campaign_id AND status = 'active')
  );

DROP POLICY IF EXISTS "Participants read own" ON campaign_participants;
CREATE POLICY "Participants read own"
  ON campaign_participants FOR SELECT USING (auth.uid() = influencer_id);

DROP POLICY IF EXISTS "Participants read admin" ON campaign_participants;
CREATE POLICY "Participants read admin"
  ON campaign_participants FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- ─── 11. FRAUD LOGS ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fraud_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  influencer_id UUID REFERENCES influencers(user_id) ON DELETE SET NULL,
  referred_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'low' CHECK (severity IN ('low', 'medium', 'high')),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE fraud_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Fraud logs admin read" ON fraud_logs;
CREATE POLICY "Fraud logs admin read"
  ON fraud_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- Inserts are server-only (service role bypasses RLS).

CREATE INDEX IF NOT EXISTS idx_fraud_logs_influencer ON fraud_logs(influencer_id);

-- ═══════════════════════════════════════════════════════════════
-- PART C: ANTI-TAMPER TRIGGER
-- ═══════════════════════════════════════════════════════════════
-- Mirrors prevent_property_tamper() (010). Clients (including the
-- influencer themselves) cannot modify status, referral_code, or the
-- counters. Admins and the service role (edge functions) may.

CREATE OR REPLACE FUNCTION prevent_influencer_tamper()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify influencer status';
  END IF;

  IF NEW.referral_code IS DISTINCT FROM OLD.referral_code AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify referral_code';
  END IF;

  IF NEW.total_clicks IS DISTINCT FROM OLD.total_clicks
     OR NEW.total_registrations IS DISTINCT FROM OLD.total_registrations
     OR NEW.total_conversions IS DISTINCT FROM OLD.total_conversions
     OR NEW.total_earnings IS DISTINCT FROM OLD.total_earnings THEN
    RAISE EXCEPTION 'Clients cannot modify influencer counters';
  END IF;

  IF NEW.activated_at IS DISTINCT FROM OLD.activated_at AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify activated_at';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_influencer_tamper ON influencers;

CREATE TRIGGER trg_prevent_influencer_tamper
  BEFORE UPDATE ON influencers
  FOR EACH ROW EXECUTE FUNCTION prevent_influencer_tamper();

-- ═══════════════════════════════════════════════════════════════
-- PART D: AI-READY INFLUENCER MATCHING
-- ═══════════════════════════════════════════════════════════════
-- Heuristic scoring (0-100): niche match 40, location match 20,
-- followers up to 20, historical conversion rate up to 20.
-- Swap this body for a real model call later; keep the signature.

CREATE OR REPLACE FUNCTION match_influencers_for_campaign(p_campaign_id UUID)
RETURNS TABLE (
  influencer_id UUID,
  full_name TEXT,
  referral_code TEXT,
  followers_count INTEGER,
  content_niche TEXT,
  audience_location TEXT,
  total_conversions INTEGER,
  score NUMERIC
) AS $$
DECLARE
  v_target TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true) THEN
    RAISE EXCEPTION 'Admin only';
  END IF;

  SELECT target_audience INTO v_target FROM campaigns WHERE id = p_campaign_id;

  RETURN QUERY
  SELECT
    i.user_id,
    u.full_name,
    i.referral_code,
    i.followers_count,
    i.content_niche,
    i.audience_location,
    i.total_conversions,
    ROUND(
      (CASE WHEN i.content_niche IS NOT NULL AND v_target ILIKE '%' || i.content_niche || '%' THEN 40 ELSE 0 END)
      + (CASE WHEN i.audience_location IS NOT NULL AND v_target ILIKE '%' || i.audience_location || '%' THEN 20 ELSE 0 END)
      + LEAST(COALESCE(i.followers_count, 0) / 1000.0, 20)
      + (COALESCE(i.total_conversions, 0)::NUMERIC / GREATEST(COALESCE(i.total_registrations, 0), 1)) * 20
    , 1) AS score
  FROM influencers i
  
  JOIN users u ON u.id = i.user_id
  WHERE i.status = 'active'
  ORDER BY score DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
