-- ═══════════════════════════════════════════════════════════════
-- DALALI — 037: Lock down legacy payment tables
--
-- commissions, gateway_logs and refunds (created by 001 in the
-- Selcom era, unused since the DPO migration in 022) had RLS
-- DISABLED and no policies. On any project where these tables
-- exist with default grants, that leaves them fully readable and
-- writable by anyone holding the public anon key.
--
-- Verified 2026-07-29: the tables currently return 404 via
-- PostgREST on the production project (not exposed / possibly
-- absent). This migration is therefore written to be correct in
-- BOTH worlds: it only touches tables that exist.
--
-- End state wherever the tables exist:
--   • RLS enabled
--   • clients (anon/authenticated): no access at all
--   • admins: read-only (refund/audit visibility)
--   • service role (edge functions): full access (bypasses RLS)
-- ═══════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'commissions') THEN
    EXECUTE 'ALTER TABLE commissions ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Server-only commissions" ON commissions';
    EXECUTE 'CREATE POLICY "Server-only commissions" ON commissions FOR ALL USING (false)';
    EXECUTE 'DROP POLICY IF EXISTS "Admins read commissions" ON commissions';
    EXECUTE 'CREATE POLICY "Admins read commissions" ON commissions FOR SELECT
               USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true))';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'gateway_logs') THEN
    EXECUTE 'ALTER TABLE gateway_logs ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Server-only gateway_logs" ON gateway_logs';
    EXECUTE 'CREATE POLICY "Server-only gateway_logs" ON gateway_logs FOR ALL USING (false)';
    EXECUTE 'DROP POLICY IF EXISTS "Admins read gateway_logs" ON gateway_logs';
    EXECUTE 'CREATE POLICY "Admins read gateway_logs" ON gateway_logs FOR SELECT
               USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true))';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'refunds') THEN
    EXECUTE 'ALTER TABLE refunds ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Server-only refunds" ON refunds';
    EXECUTE 'CREATE POLICY "Server-only refunds" ON refunds FOR ALL USING (false)';
    EXECUTE 'DROP POLICY IF EXISTS "Admins read refunds" ON refunds';
    EXECUTE 'CREATE POLICY "Admins read refunds" ON refunds FOR SELECT
               USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true))';
  END IF;
END;
$$;
