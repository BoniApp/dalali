-- ═══════════════════════════════════════════════════════════════
-- DALALI — 036: Fix account deletion (FK NO ACTION blockers)
--
-- delete-account de-links the transactions ledger and then calls
-- auth.admin.deleteUser; the users row cascades from auth.users
-- (031). But several foreign keys into users(id) were created with
-- no ON DELETE action (NO ACTION), so deleting any user who has
-- one of these rows raised an FK violation and the whole deletion
-- failed — landlords, listing-creating agents/seekers, anyone
-- involved in a dispute/fraud report, reviewers, campaign owners.
--
-- Fix: re-create those FKs with the right delete behavior —
--   SET NULL  for audit/attribution columns (the record must
--             survive the user: financial + moderation trail)
--   CASCADE   for records that are meaningless without the user
--             (a landlord's inquiries)
--
-- transactions.payer_id/payee_id stay NO ACTION on purpose: the
-- ledger must never silently lose its parties — delete-account
-- explicitly nulls them after its obligation checks.
-- ═══════════════════════════════════════════════════════════════

-- ─── properties.listing_creator_id ─────────────────────────────
-- An agent/seeker-created listing belongs to the landlord; the
-- listing survives, the creator attribution is anonymized.
ALTER TABLE properties
  DROP CONSTRAINT IF EXISTS properties_listing_creator_id_fkey;
ALTER TABLE properties
  ADD CONSTRAINT properties_listing_creator_id_fkey
  FOREIGN KEY (listing_creator_id) REFERENCES users(id) ON DELETE SET NULL;

-- ─── inquiries.landlord_id ─────────────────────────────────────
ALTER TABLE inquiries
  DROP CONSTRAINT IF EXISTS inquiries_landlord_id_fkey;
ALTER TABLE inquiries
  ADD CONSTRAINT inquiries_landlord_id_fkey
  FOREIGN KEY (landlord_id) REFERENCES users(id) ON DELETE CASCADE;

-- ─── fraud_reports.reporter_id / resolved_by ───────────────────
ALTER TABLE fraud_reports
  DROP CONSTRAINT IF EXISTS fraud_reports_reporter_id_fkey;
ALTER TABLE fraud_reports
  ADD CONSTRAINT fraud_reports_reporter_id_fkey
  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE fraud_reports
  DROP CONSTRAINT IF EXISTS fraud_reports_resolved_by_fkey;
ALTER TABLE fraud_reports
  ADD CONSTRAINT fraud_reports_resolved_by_fkey
  FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL;

-- ─── disputes.reporter_id / respondent_id ──────────────────────
ALTER TABLE disputes
  DROP CONSTRAINT IF EXISTS disputes_reporter_id_fkey;
ALTER TABLE disputes
  ADD CONSTRAINT disputes_reporter_id_fkey
  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE disputes
  DROP CONSTRAINT IF EXISTS disputes_respondent_id_fkey;
ALTER TABLE disputes
  ADD CONSTRAINT disputes_respondent_id_fkey
  FOREIGN KEY (respondent_id) REFERENCES users(id) ON DELETE SET NULL;

-- ─── property_claims.reviewed_by ───────────────────────────────
ALTER TABLE property_claims
  DROP CONSTRAINT IF EXISTS property_claims_reviewed_by_fkey;
ALTER TABLE property_claims
  ADD CONSTRAINT property_claims_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL;

-- ─── agency_fees.approved_by ───────────────────────────────────
ALTER TABLE agency_fees
  DROP CONSTRAINT IF EXISTS agency_fees_approved_by_fkey;
ALTER TABLE agency_fees
  ADD CONSTRAINT agency_fees_approved_by_fkey
  FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL;

-- ─── influencer_applications.reviewed_by ───────────────────────
ALTER TABLE influencer_applications
  DROP CONSTRAINT IF EXISTS influencer_applications_reviewed_by_fkey;
ALTER TABLE influencer_applications
  ADD CONSTRAINT influencer_applications_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL;

-- ─── campaigns.created_by ──────────────────────────────────────
ALTER TABLE campaigns
  DROP CONSTRAINT IF EXISTS campaigns_created_by_fkey;
ALTER TABLE campaigns
  ADD CONSTRAINT campaigns_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

-- ─── tenancies.agent_id ────────────────────────────────────────
ALTER TABLE tenancies
  DROP CONSTRAINT IF EXISTS tenancies_agent_id_fkey;
ALTER TABLE tenancies
  ADD CONSTRAINT tenancies_agent_id_fkey
  FOREIGN KEY (agent_id) REFERENCES users(id) ON DELETE SET NULL;

-- ─── inspections.inspector_id ──────────────────────────────────
ALTER TABLE inspections
  DROP CONSTRAINT IF EXISTS inspections_inspector_id_fkey;
ALTER TABLE inspections
  ADD CONSTRAINT inspections_inspector_id_fkey
  FOREIGN KEY (inspector_id) REFERENCES users(id) ON DELETE SET NULL;

-- ─── admin_logs.admin_id ───────────────────────────────────────
-- Audit trail survives the admin's departure, anonymized.
ALTER TABLE admin_logs
  DROP CONSTRAINT IF EXISTS admin_logs_admin_id_fkey;
ALTER TABLE admin_logs
  ADD CONSTRAINT admin_logs_admin_id_fkey
  FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL;

-- ─── transactions.property_id (fresh-install parity) ───────────
-- On projects built from the repaired 001 the ledger's property FK
-- is deferred (properties is created in 002). Add it here where
-- missing; on long-lived projects it already exists (003) and this
-- is a no-op.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'transactions_property_id_fkey'
  ) THEN
    ALTER TABLE transactions
      ADD CONSTRAINT transactions_property_id_fkey
      FOREIGN KEY (property_id) REFERENCES properties(id);
  END IF;
END;
$$;
