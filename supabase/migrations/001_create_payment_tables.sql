-- ═══════════════════════════════════════════════════════════════
-- DALALI — 001: Payment tables (REPAIRED 2026-07 for fresh installs)
--
-- Historical note. This file predates 003's wallet schema. Its
-- original definitions of `wallets`/`transactions` used text ids
-- and a single `balance` column and — because every later CREATE
-- is `IF NOT EXISTS` — a FRESH `supabase db push` installed the
-- wrong shape: users was only created in 031, so 001's FKs into
-- users(id) failed outright, and 003's real schema never landed.
-- The production DB (built from the original manual run order) has
-- the 003 shape; 027's RPCs depend on it.
--
-- Repair (keeps prod and fresh installs converging on ONE schema):
--   1. Bootstrap `users` here (031's definition, IF NOT EXISTS) so
--      migrations 001–030 can reference it; 031 no-ops later.
--   2. `wallets`/`transactions` are created DIRECTLY in the 003
--      shape — 003's CREATE no-ops and its RLS/policies/indexes
--      apply unchanged.
--   3. Legacy Selcom-era tables (payment_gateways, commissions,
--      gateway_logs, refunds) are kept for historical parity but
--      WITHOUT their type-mismatched FKs (text → uuid users.id).
--      payment_gateways is dropped by 022; the rest are locked by
--      037. The transactions→properties FK is added by 036 (after
--      properties exists) where missing.
-- ═══════════════════════════════════════════════════════════════

-- ─── 0. USERS BOOTSTRAP (mirrors 031_initial_schema.sql) ───────
-- IF NOT EXISTS: whichever of 001/031 runs first creates it.

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

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- ─── 1. WALLETS (003 schema — one wallet per user) ─────────────

CREATE TABLE IF NOT EXISTS wallets (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  available_balance NUMERIC DEFAULT 0 CHECK (available_balance >= 0),
  pending_balance NUMERIC DEFAULT 0 CHECK (pending_balance >= 0),
  locked_balance NUMERIC DEFAULT 0 CHECK (locked_balance >= 0),
  total_earned NUMERIC DEFAULT 0,
  total_withdrawn NUMERIC DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 2. TRANSACTIONS (003 schema — append-only ledger) ─────────
-- property_id has no FK here: properties is created in 002. 036
-- adds the constraint where missing.

CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('agencyFee','revenueShare','withdrawal','refund','adminAdjustment')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','processing','locked','available','completed','failed','reversed')),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  currency TEXT DEFAULT 'TZS',
  payer_id UUID REFERENCES users(id),
  payee_id UUID REFERENCES users(id),
  property_id UUID,
  property_title TEXT,
  payment_method TEXT DEFAULT 'selcom',
  idempotency_key TEXT UNIQUE,
  selcom_transaction_id TEXT,
  split JSONB,
  failure_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  settled_at TIMESTAMPTZ,
  reversed_at TIMESTAMPTZ
);

-- ─── 3. LEGACY TABLES (unused since the DPO migration, 022) ────

-- payment_gateways: provider-switching config from the Selcom era.
-- Dropped by 022_dpo_payments.sql; created here only for parity
-- with projects that applied the original 001.
CREATE TABLE IF NOT EXISTS payment_gateways (
  id text PRIMARY KEY,
  provider_name text NOT NULL,
  environment text NOT NULL DEFAULT 'production',
  enabled boolean NOT NULL DEFAULT false,
  config jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- gateway_logs: raw gateway callbacks for auditing
CREATE TABLE IF NOT EXISTS gateway_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id text,
  payload jsonb,
  status text,
  created_at timestamptz DEFAULT now()
);

-- commissions: legacy agent commission allocations (no live writer)
CREATE TABLE IF NOT EXISTS commissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id text,
  transaction_id text,
  percentage numeric NOT NULL DEFAULT 0,
  amount numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  paid_at timestamptz
);

-- refunds (legacy; no live flow writes here)
CREATE TABLE IF NOT EXISTS refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id text,
  reason text,
  amount numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'requested',
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- ─── 4. INDEXES ─────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_wallets_user ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_commissions_agent ON commissions(agent_id);
