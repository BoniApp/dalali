-- ═══════════════════════════════════════════════════════════════
-- DALALI — 038: Wire scheduled-settlement + revoke money RPCs
--
-- 1. scheduled-settlement (moves agent/influencer balances
--    pending → available after the settlement hold) had NO pg_cron
--    job — 033 only scheduled the two tenancy functions — so
--    earnings never became withdrawable. Schedule it daily via the
--    same invoke_edge_function plumbing (CRON_SECRET bearer from
--    private.app_settings, 034).
--
-- 2. settlement_log: one row per run (settled counts, failures,
--    error details) so ops can see the job is alive and the edge
--    function can alert on failures.
--
-- 3. The wallet/settlement RPCs (027) were executable by the
--    anon/authenticated roles (Supabase grants EXECUTE on public
--    functions by default). RLS currently blocks any harm — they
--    are SECURITY INVOKER and every money table is server-write —
--    but these functions are server plumbing and should never be
--    client-callable. Revoke EXECUTE, mirroring 033's
--    invoke_edge_function treatment. The service role is
--    unaffected (it bypasses permission checks as superuser-class
--    role) — edge functions keep working.
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. Settlement run log ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS settlement_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  settled INTEGER NOT NULL DEFAULT 0,
  referral_settled INTEGER NOT NULL DEFAULT 0,
  failures INTEGER NOT NULL DEFAULT 0,
  details JSONB DEFAULT '{}'::jsonb
);

ALTER TABLE settlement_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins read settlement log" ON settlement_log;
CREATE POLICY "Admins read settlement log" ON settlement_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true));

DROP POLICY IF EXISTS "Server-only settlement log writes" ON settlement_log;
CREATE POLICY "Server-only settlement log writes" ON settlement_log FOR ALL USING (false);

-- ─── 2. Daily settlement schedule (02:29 UTC / 05:29 EAT) ─────

DO $$
BEGIN
  PERFORM cron.unschedule('scheduled-settlement-daily');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'scheduled-settlement-daily',
  '29 2 * * *',
  $$SELECT public.invoke_edge_function('scheduled-settlement')$$
);

-- ─── 3. Revoke client EXECUTE on money RPCs ───────────────────

REVOKE EXECUTE ON FUNCTION public.wallet_credit(uuid, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.wallet_debit(uuid, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.wallet_credit_pending(uuid, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.wallet_settle_pending(uuid, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.platform_wallet_credit_pending(numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.platform_wallet_settle_pending(numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.settle_dpo_payment(uuid, text, text, uuid, numeric, numeric) FROM PUBLIC, anon, authenticated;
