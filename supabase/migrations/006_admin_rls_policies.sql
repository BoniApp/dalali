-- ═══════════════════════════════════════════════════════════════
-- DALALI ADMIN RLS POLICIES — Phase 6: Fix missing admin permissions
--
-- Run this in the Supabase SQL Editor:
--   https://supabase.com/dashboard/project/_/sql
--
-- Fixes:
--   1. properties: admins couldn't approve/reject listings (no UPDATE policy)
--   2. withdrawals: admins couldn't process payouts (UPDATE blocked by server-only policy)
--   3. users: RLS is currently OFF (infinite recursion bug), so admin checks work
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. PROPERTIES — Admin can approve/reject/update any listing ─

DROP POLICY IF EXISTS "Admins can update any property" ON properties;
CREATE POLICY "Admins can update any property"
  ON properties FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- ─── 2. WITHDRAWALS — Admin can approve/reject (bypass server-only lock) ─

DROP POLICY IF EXISTS "Admins can update withdrawals" ON withdrawals;
CREATE POLICY "Admins can update withdrawals"
  ON withdrawals FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- ─── 3. WALLETS — Admin can read all wallets (for support/debug) ─

DROP POLICY IF EXISTS "Admins can read all wallets" ON wallets;
CREATE POLICY "Admins can read all wallets"
  ON wallets FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- ─── 4. TRANSACTIONS — Admin can read all transactions ─

DROP POLICY IF EXISTS "Admins can read all transactions" ON transactions;
CREATE POLICY "Admins can read all transactions"
  ON transactions FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- ═══════════════════════════════════════════════════════════════
-- VERIFY: List all policies after running
-- ═══════════════════════════════════════════════════════════════
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename IN ('properties', 'withdrawals', 'wallets', 'transactions', 'users', 'fraud_reports', 'disputes')
-- ORDER BY tablename, policyname;
