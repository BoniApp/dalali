-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 034: Cron secret store (private.app_settings)
--
-- Reworks the 033 secret channel. The GUC approach
-- (ALTER DATABASE/ROLE ... SET app.cron_secret) fails on hosted
-- Supabase — PG15+ parameter privileges: "permission denied to set
-- parameter" for every role available to us. Instead the bearer is
-- stored in a table in the NON-PostgREST-exposed `private` schema:
-- unreachable by anon/authenticated (no schema grants, not in
-- db-schema), readable only by the SECURITY DEFINER
-- invoke_edge_function() wrapper (owner) when pg_cron fires it.
--
-- The secret VALUE is still not in git — it is inserted out-of-band:
--   INSERT INTO private.app_settings (key, value)
--   VALUES ('cron_secret', '<function secret value>')
--   ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
-- Until that row exists, the wrapper logs a WARNING and skips.
-- ═══════════════════════════════════════════════════════════════

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Wrapper now reads the bearer from private.app_settings instead of
-- the (unsettable) app.cron_secret GUC. EXECUTE stays revoked from
-- API roles (restated: CREATE OR REPLACE preserves grants, but keep
-- this line authoritative).
CREATE OR REPLACE FUNCTION public.invoke_edge_function(p_function_name TEXT)
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_secret TEXT;
BEGIN
  SELECT value INTO v_secret FROM private.app_settings WHERE key = 'cron_secret';
  IF v_secret IS NULL OR v_secret = '' THEN
    RAISE WARNING 'cron_secret missing from private.app_settings — skipping call to %', p_function_name;
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
