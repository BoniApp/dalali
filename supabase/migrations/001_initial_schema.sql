-- ═══════════════════════════════════════════════════════════════
-- DALALI INITIAL SCHEMA — Phase 1: Users + Auth
--
-- Run this in the Supabase SQL Editor:
--   https://supabase.com/dashboard/project/_/sql
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. USERS TABLE ───────────────────────────────────────────
-- Mirrors Firebase Auth + Firestore users collection

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL DEFAULT '',
  phone TEXT DEFAULT '',
  role TEXT NOT NULL DEFAULT 'seeker' CHECK (role IN ('seeker','landlord','agent')),
  is_admin BOOLEAN DEFAULT false,
  admin_role TEXT DEFAULT NULL CHECK (admin_role IN ('superAdmin','financeAdmin','listingsModerator','supportAgent','fraudAnalyst')),
  is_approved BOOLEAN DEFAULT false,
  is_verified_landlord BOOLEAN DEFAULT false,
  is_phone_verified BOOLEAN DEFAULT false,
  verification_status TEXT DEFAULT 'unverified' CHECK (verification_status IN ('unverified','pending','verified')),
  profile_image TEXT,
  national_id TEXT,
  agent_license TEXT,
  subscription_tier INTEGER DEFAULT 0,
  total_reward_points INTEGER DEFAULT 0,
  move_mode TEXT DEFAULT 'none' CHECK (move_mode IN ('none','planning','active')),
  active_move_listing_id TEXT,
  saved_searches TEXT[] DEFAULT '{}',
  preferred_locations TEXT[] DEFAULT '{}',
  preferences_theme TEXT DEFAULT 'system',
  preferences_language TEXT DEFAULT 'en',
  last_active TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- RLS: Users can read/update their own profile
CREATE POLICY "Users can read own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- RLS: Admins can read all users
CREATE POLICY "Admins can read all users"
  ON users FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = true)
  );

CREATE POLICY "Admins can update all users"
  ON users FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = true)
  );

-- ─── 2. AUTO-CREATE PROFILE ON SIGNUP ───────────────────────
-- When a user signs up via Supabase Auth, automatically create
-- their row in the users table.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    'seeker'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists (idempotent)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── 3. ENABLE EMAIL AUTH ───────────────────────────────────
-- (Do this in the Supabase Dashboard UI too:)
-- Authentication → Providers → Email → Enable "Confirm email"

-- ─── 4. SYSTEM SETTINGS ─────────────────────────────────────
-- Global app configuration (replaces Firestore systemSettings doc)

CREATE TABLE IF NOT EXISTS system_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  agency_fee NUMERIC DEFAULT 20000,
  agent_share NUMERIC DEFAULT 0.60,
  platform_share NUMERIC DEFAULT 0.40,
  settlement_delay_hours INTEGER DEFAULT 48,
  min_withdrawal NUMERIC DEFAULT 5000,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default settings
INSERT INTO system_settings (id, agency_fee, agent_share, platform_share, settlement_delay_hours, min_withdrawal)
VALUES ('default', 20000, 0.60, 0.40, 48, 5000)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "System settings public read"
  ON system_settings FOR SELECT
  USING (true);

CREATE POLICY "Admins can update system settings"
  ON system_settings FOR ALL
  USING (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = true)
  );

-- ─── 5. ADMIN LOGS (Audit Trail) ────────────────────────────

CREATE TABLE IF NOT EXISTS admin_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES users(id),
  action TEXT NOT NULL,
  target_table TEXT,
  target_id TEXT,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read admin logs"
  ON admin_logs FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = true)
  );

CREATE POLICY "Admins can create admin logs"
  ON admin_logs FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = true)
  );
