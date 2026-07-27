-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 033: pg_cron wiring for tenancy lifecycle jobs
--
-- Schedules the two 029 cron edge functions (deployed with
-- --no-verify-jwt, self-gated on CRON_SECRET):
--   process-tenancy-expiry         daily 03:17 UTC (06:17 EAT)
--   send-tenancy-expiry-reminders  daily 06:43 UTC (09:43 EAT)
-- using pg_cron for scheduling and pg_net for the HTTP call.
--
-- SECRET HANDLING: the CRON_SECRET bearer is NOT stored in this
-- file (secrets never go to git). It is read at call time from the
-- database setting app.cron_secret, applied once manually:
--   ALTER DATABASE postgres SET app.cron_secret = '<function secret value>';
-- (Supabase SQL Editor or psql; pg_cron workers open a fresh
-- connection per job, so they pick it up.) Until it is set, the
-- wrapper logs a WARNING and skips the call — jobs exist but inert.
--
-- invoke_edge_function() is EXECUTE-revoked from API roles: it is
-- plumbing for pg_cron (jobs run as the scheduling role), not a
-- client RPC — left callable, anyone could fire the jobs with the
-- secret attached. It is NOT in exposed schemas for PostgREST RPC
-- semantics only via this REVOKE; keep the REVOKE if re-created.
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.invoke_edge_function(p_function_name TEXT)
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_secret TEXT := current_setting('app.cron_secret', true);
BEGIN
  IF v_secret IS NULL OR v_secret = '' THEN
    RAISE WARNING 'app.cron_secret not set — skipping call to %', p_function_name;
    RETURN;
  END IF;

  PERFORM net.http_post(
    url := 'https://wnfeeyvanzesfdxvnkvf.supabase.co/functions/v1/' || p_function_name,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
END;
$$ LANGUAGE plpgsql;

REVOKE EXECUTE ON FUNCTION public.invoke_edge_function(TEXT) FROM PUBLIC, anon, authenticated;

-- Idempotent (re)scheduling: drop same-named jobs first.
DO $$
BEGIN
  PERFORM cron.unschedule('process-tenancy-expiry-daily');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  PERFORM cron.unschedule('send-tenancy-expiry-reminders-daily');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'process-tenancy-expiry-daily',
  '17 3 * * *',
  $$SELECT public.invoke_edge_function('process-tenancy-expiry')$$
);

SELECT cron.schedule(
  'send-tenancy-expiry-reminders-daily',
  '43 6 * * *',
  $$SELECT public.invoke_edge_function('send-tenancy-expiry-reminders')$$
);
