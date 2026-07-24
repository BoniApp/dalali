
-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 023: Realtime Publication for App Stream
--
-- AppState/DPO/influencer screens stream these tables via Supabase
-- Realtime (.stream / onPostgresChanges). Only conversations and
-- messages were ever added to the supabase_realtime publication
-- (017) — every other stream silently delivered the initial fetch
-- but no live events. This publishes all streamed tables; the DO
-- block is idempotent (duplicate_object is swallowed).
--
-- Also adds the created_at index backing the notifications stream's
-- descending order.
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'notifications',
    'properties',
    'favorites',
    'appointments',
    'inquiries',
    'tenancy_applications',
    'tenancies',
    'maintenance_requests',
    'rent_schedules',
    'move_checklists',
    'deals',
    'agency_fees',
    'earnings',
    'payments',
    'property_access',
    'wallets',
    'withdrawals',
    'referral_conversions',
    'referral_clicks',
    'influencers',
    'property_claims',
    'conversations',
    'messages'
  ] LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    EXCEPTION WHEN duplicate_object THEN
      -- already published
      NULL;
    END;
  END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);
