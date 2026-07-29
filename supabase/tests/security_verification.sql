-- ═══════════════════════════════════════════════════════════════
-- DALALI — Post-fix security verification (run in Supabase SQL
-- Editor or `psql` against the project AFTER pushing migrations
-- 035–039). Each section states the EXPECTED result.
--
-- These checks simulate API callers by setting the JWT claims
-- PostgREST would set, then downgrading the role. Run as the
-- postgres role. Do NOT run inside a transaction you intend to
-- keep — wrap in BEGIN/ROLLBACK for a clean pass:
--   BEGIN;
--   \i security_verification.sql
--   ROLLBACK;
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. Privilege escalation (035) ─────────────────────────────
-- EXPECT: every statement raises "Clients cannot modify admin
-- flags" (or badges/role). If any UPDATE succeeds, 035 is NOT
-- applied correctly.

-- Simulate a non-admin authenticated user:
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
-- (use a real non-admin user id for a live check)
-- SELECT set_config('request.jwt.claim.sub', '<user-uuid>', true);

-- The attacker statement from the audit:
UPDATE users SET is_admin = true WHERE id = auth.uid();            -- EXPECT ERROR
UPDATE users SET admin_role = 'superAdmin' WHERE id = auth.uid();  -- EXPECT ERROR
UPDATE users SET role = 'agent' WHERE id = auth.uid();             -- EXPECT ERROR
UPDATE users SET verification_status = 'verified' WHERE id = auth.uid(); -- EXPECT ERROR
UPDATE users SET subscription_tier = 3 WHERE id = auth.uid();      -- EXPECT ERROR

-- Benign self-edit must still work:
UPDATE users SET full_name = full_name WHERE id = auth.uid();      -- EXPECT OK

RESET ROLE;

-- ─── 2. Money RPC EXECUTE lockdown (038) ───────────────────────
-- EXPECT: "permission denied for function ..." for every call.
SET LOCAL ROLE authenticated;
SELECT public.wallet_credit_pending(gen_random_uuid(), 1000);      -- EXPECT ERROR
SELECT public.wallet_settle_pending(gen_random_uuid(), 1000);      -- EXPECT ERROR
SELECT public.platform_wallet_credit_pending(1000);                -- EXPECT ERROR
SELECT public.settle_dpo_payment(gen_random_uuid(), 't', 'm', NULL, 1, 1); -- EXPECT ERROR
RESET ROLE;

-- ─── 3. Legacy tables RLS (037) ────────────────────────────────
-- EXPECT: 0 rows / permission denied for anon + authenticated.
SET LOCAL ROLE anon;
SELECT count(*) FROM commissions;      -- EXPECT permission denied or 0 rows with policies hiding
SELECT count(*) FROM gateway_logs;     -- EXPECT same
SELECT count(*) FROM refunds;          -- EXPECT same
INSERT INTO refunds (reason) VALUES ('probe');  -- EXPECT permission denied
RESET ROLE;

-- ─── 4. Account-deletion FK behavior (036) ─────────────────────
-- EXPECT: constraint delete rules are SET NULL / CASCADE, not NO ACTION.
SELECT conrelid::regclass AS table_name, conname, confdeltype
FROM pg_constraint
WHERE conname IN (
  'properties_listing_creator_id_fkey',   -- n (SET NULL)
  'inquiries_landlord_id_fkey',           -- c (CASCADE)
  'fraud_reports_reporter_id_fkey',       -- n
  'disputes_reporter_id_fkey',            -- n
  'tenancies_agent_id_fkey',              -- n
  'admin_logs_admin_id_fkey'              -- n
)
ORDER BY conrelid::regclass::text;
-- confdeltype legend: a=NO ACTION, c=CASCADE, n=SET NULL.
-- EXPECT: no 'a' values in the result.

-- ─── 5. Settlement cron registered (038) ───────────────────────
-- EXPECT: one row, jobname 'scheduled-settlement-daily'.
SELECT jobid, jobname, schedule, active FROM cron.job
WHERE jobname = 'scheduled-settlement-daily';

-- ─── 6. properties bucket policies (039) ───────────────────────
-- EXPECT: 4 policies on storage.objects for bucket 'properties'
-- (public read, owner upload/update/delete).
SELECT policyname, cmd FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname LIKE 'Property images%'
ORDER BY policyname;
