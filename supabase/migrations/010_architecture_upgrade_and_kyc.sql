-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — Phase 5: Architecture Upgrade + KYC Module
--
-- Changes:
--   1. Property Registry (duplicate prevention)
--   2. Deals (tenancy lifecycle tracking)
--   3. Agency Fees (fixed 20,000 TZS)
--   4. Earnings (agency fee ledger)
--   5. Property Claims (ownership disputes)
--   6. KYC Sessions (identity verification)
--   7. ID Documents (captured documents)
--   8. Verification Results (external API responses)
--   9. KYC Audit Logs (compliance trail)
--   10. Updates to users + properties tables
--
-- Run in Supabase SQL Editor after 009_notifications_table.sql
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- PART A: ARCHITECTURE UPGRADE TABLES
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. PROPERTY REGISTRY ─────────────────────────────────────
-- Canonical record of every physical property.

CREATE TABLE IF NOT EXISTS property_registry (
  registry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_hash TEXT UNIQUE NOT NULL,
  latitude NUMERIC NOT NULL,
  longitude NUMERIC NOT NULL,
  landlord_phone TEXT NOT NULL,
  landlord_name TEXT NOT NULL,
  property_type TEXT NOT NULL CHECK (property_type IN ('apartment','house','villa','bedsitter','office','shop','room','selfContainedRoom','plot','frame')),
  rooms INTEGER NOT NULL DEFAULT 0,
  address TEXT NOT NULL,
  verification_status TEXT NOT NULL DEFAULT 'unverified' CHECK (verification_status IN ('unverified','pending','verified','rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

ALTER TABLE property_registry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Registry public read"
  ON property_registry FOR SELECT USING (true);

CREATE POLICY "Registry admin write"
  ON property_registry FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_registry_hash ON property_registry(property_hash);
CREATE INDEX IF NOT EXISTS idx_registry_phone ON property_registry(landlord_phone);

-- ─── 2. PROPERTY CLAIMS ───────────────────────────────────────
-- Ownership claims when duplicates are detected.

CREATE TABLE IF NOT EXISTS property_claims (
  claim_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES property_registry(registry_id),
  claimant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  claimant_role TEXT NOT NULL,
  reason TEXT NOT NULL,
  evidence_urls TEXT[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_by UUID REFERENCES users(id),
  review_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ
);

ALTER TABLE property_claims ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Claims read own"
  ON property_claims FOR SELECT USING (claimant_id = auth.uid());

CREATE POLICY "Claims read admin"
  ON property_claims FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "Claims insert own"
  ON property_claims FOR INSERT WITH CHECK (claimant_id = auth.uid());

CREATE POLICY "Claims update admin"
  ON property_claims FOR UPDATE USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_claims_property ON property_claims(property_id);
CREATE INDEX IF NOT EXISTS idx_claims_claimant ON property_claims(claimant_id);
CREATE INDEX IF NOT EXISTS idx_claims_status ON property_claims(status);

-- ─── 3. DEALS ─────────────────────────────────────────────────
-- Tracks the lifecycle from property match to confirmed tenancy.

CREATE TABLE IF NOT EXISTS deals (
  deal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL,
  listing_creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  seeker_id UUID REFERENCES users(id) ON DELETE SET NULL,
  landlord_phone TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'matched' CHECK (status IN ('matched','viewingScheduled','viewingCompleted','negotiating','tenancyConfirmed','agencyFeePending','agencyFeePaid','closed')),
  viewing_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at TIMESTAMPTZ,
  tenant_confirmed BOOLEAN NOT NULL DEFAULT false,
  landlord_confirmed BOOLEAN NOT NULL DEFAULT false,
  tenant_confirmed_at TIMESTAMPTZ,
  landlord_confirmed_at TIMESTAMPTZ
);

ALTER TABLE deals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Deals read participants"
  ON deals FOR SELECT USING (listing_creator_id = auth.uid() OR seeker_id = auth.uid());

CREATE POLICY "Deals insert"
  ON deals FOR INSERT WITH CHECK (true);

CREATE POLICY "Deals update participants"
  ON deals FOR UPDATE USING (listing_creator_id = auth.uid() OR seeker_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_deals_creator ON deals(listing_creator_id);
CREATE INDEX IF NOT EXISTS idx_deals_property ON deals(property_id);
CREATE INDEX IF NOT EXISTS idx_deals_status ON deals(status);

-- ─── 4. AGENCY FEES ───────────────────────────────────────────
-- Fixed 20,000 TZS fee per confirmed tenancy.

CREATE TABLE IF NOT EXISTS agency_fees (
  fee_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id UUID NOT NULL REFERENCES deals(deal_id),
  property_id UUID NOT NULL,
  listing_creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL DEFAULT 20000,
  currency TEXT NOT NULL DEFAULT 'TZS',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','paid','cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  approved_by UUID REFERENCES users(id),
  payout_reference TEXT
);

ALTER TABLE agency_fees ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Fees read own"
  ON agency_fees FOR SELECT USING (listing_creator_id = auth.uid());

CREATE POLICY "Fees read admin"
  ON agency_fees FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "Fees update admin"
  ON agency_fees FOR UPDATE USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_agency_fees_creator ON agency_fees(listing_creator_id);
CREATE INDEX IF NOT EXISTS idx_agency_fees_status ON agency_fees(status);

-- ─── 5. EARNINGS ──────────────────────────────────────────────
-- Earnings ledger for agency fee tracking.

CREATE TABLE IF NOT EXISTS earnings (
  entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  deal_id UUID,
  property_id UUID,
  property_title TEXT,
  type TEXT NOT NULL DEFAULT 'agencyFee' CHECK (type IN ('agencyFee','bonus','adjustment')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','available','withdrawn','cancelled')),
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'TZS',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  available_at TIMESTAMPTZ,
  withdrawn_at TIMESTAMPTZ,
  withdrawal_id UUID
);

ALTER TABLE earnings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Earnings read own"
  ON earnings FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Earnings read admin"
  ON earnings FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "Earnings insert system"
  ON earnings FOR INSERT WITH CHECK (true);

CREATE POLICY "Earnings update admin"
  ON earnings FOR UPDATE USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_earnings_user ON earnings(user_id);
CREATE INDEX IF NOT EXISTS idx_earnings_status ON earnings(status);

-- ═══════════════════════════════════════════════════════════════
-- PART B: KYC MODULE TABLES
-- ═══════════════════════════════════════════════════════════════

-- ─── 6. KYC SESSIONS ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS kyc_sessions (
  session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'unverified' CHECK (status IN ('unverified','inProgress','pendingReview','verified','rejected','expired')),
  tier TEXT NOT NULL DEFAULT 'tier0' CHECK (tier IN ('tier0','tier1','tier2','tier2Plus')),
  selected_document_type TEXT CHECK (selected_document_type IN ('nidaId','passport','driversLicense','zanId','votersId')),
  consent_version TEXT,
  consent_timestamp TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ,
  verified_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  rejection_reason TEXT,
  correlation_id TEXT,
  device_fingerprint TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  UNIQUE(user_id)
);

ALTER TABLE kyc_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "KYC read own"
  ON kyc_sessions FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "KYC insert own"
  ON kyc_sessions FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "KYC update own"
  ON kyc_sessions FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "KYC read admin"
  ON kyc_sessions FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "KYC update admin"
  ON kyc_sessions FOR UPDATE USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_kyc_user ON kyc_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_status ON kyc_sessions(status);

-- ─── 7. ID DOCUMENTS ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS id_documents (
  document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL CHECK (document_type IN ('nidaId','passport','driversLicense','zanId','votersId')),
  front_image_url TEXT,
  back_image_url TEXT,
  extracted_full_name TEXT,
  extracted_document_number TEXT,
  extracted_date_of_birth TIMESTAMPTZ,
  extracted_expiry_date TIMESTAMPTZ,
  extracted_nationality TEXT,
  ocr_confidence NUMERIC DEFAULT 0,
  mrz_valid BOOLEAN DEFAULT false,
  checksum_valid BOOLEAN DEFAULT false,
  captured_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE id_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ID docs read own"
  ON id_documents FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "ID docs insert own"
  ON id_documents FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "ID docs read admin"
  ON id_documents FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_id_docs_user ON id_documents(user_id);

-- ─── 8. VERIFICATION RESULTS ──────────────────────────────────

CREATE TABLE IF NOT EXISTS verification_results (
  result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES kyc_sessions(session_id) ON DELETE CASCADE,
  source TEXT NOT NULL,
  outcome TEXT NOT NULL CHECK (outcome IN ('match','mismatch','notFound','deceased','error','timeout')),
  match_score NUMERIC,
  matched_name TEXT,
  matched_date_of_birth TEXT,
  api_response_code TEXT,
  api_response_body TEXT,
  assessed_risk TEXT CHECK (assessed_risk IN ('low','medium','high','critical')),
  flags TEXT[] DEFAULT '{}',
  checked_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE verification_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Verification results read own"
  ON verification_results FOR SELECT USING (
    EXISTS (SELECT 1 FROM kyc_sessions WHERE session_id = verification_results.session_id AND user_id = auth.uid())
  );

CREATE POLICY "Verification results read admin"
  ON verification_results FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE INDEX IF NOT EXISTS idx_ver_results_session ON verification_results(session_id);

-- ─── 9. KYC AUDIT LOGS ────────────────────────────────────────
-- Immutable compliance trail. 7-year retention per AML Act 2006.

CREATE TABLE IF NOT EXISTS kyc_audit_logs (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES kyc_sessions(session_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  ip_address TEXT,
  device_hash TEXT,
  correlation_id TEXT,
  metadata JSONB,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE kyc_audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Audit logs read own"
  ON kyc_audit_logs FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Audit logs read admin"
  ON kyc_audit_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "Audit logs insert system"
  ON kyc_audit_logs FOR INSERT WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_audit_user ON kyc_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_session ON kyc_audit_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON kyc_audit_logs(timestamp DESC);

-- ═══════════════════════════════════════════════════════════════
-- PART C: EXISTING TABLE UPDATES
-- ═══════════════════════════════════════════════════════════════

-- ─── UPDATE: users table ──────────────────────────────────────
-- Add trust badges + earnings tracking

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_verified_agent BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_verified_property BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_verified_listing_creator BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS total_earnings NUMERIC NOT NULL DEFAULT 0;

-- ─── UPDATE: properties table ─────────────────────────────────
-- Add listing ownership + registry linkage

ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS listing_creator_id UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS listing_creator_role TEXT,
  ADD COLUMN IF NOT EXISTS registry_id UUID REFERENCES property_registry(registry_id),
  ADD COLUMN IF NOT EXISTS agency_fee_eligible BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tenancy_confirmed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS listing_status TEXT NOT NULL DEFAULT 'draft' CHECK (listing_status IN ('draft','active','viewing','negotiating','tenancyConfirmed','closed'));

CREATE INDEX IF NOT EXISTS idx_properties_registry ON properties(registry_id);
CREATE INDEX IF NOT EXISTS idx_properties_creator ON properties(listing_creator_id);
CREATE INDEX IF NOT EXISTS idx_properties_listing_status ON properties(listing_status);

-- ═══════════════════════════════════════════════════════════════
-- PART D: ANTI-TAMPER TRIGGERS
-- ═══════════════════════════════════════════════════════════════

-- Clients cannot modify computed/controlled fields on properties.

CREATE OR REPLACE FUNCTION prevent_property_tamper()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_approved IS DISTINCT FROM OLD.is_approved AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify is_approved';
  END IF;

  IF NEW.view_count IS DISTINCT FROM OLD.view_count AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify view_count';
  END IF;

  IF NEW.inquiry_count IS DISTINCT FROM OLD.inquiry_count AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify inquiry_count';
  END IF;

  IF NEW.rating IS DISTINCT FROM OLD.rating AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify rating';
  END IF;

  IF NEW.review_count IS DISTINCT FROM OLD.review_count AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify review_count';
  END IF;

  IF NEW.safety_score IS DISTINCT FROM OLD.safety_score AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify safety_score';
  END IF;

  IF NEW.incident_count IS DISTINCT FROM OLD.incident_count AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Clients cannot modify incident_count';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_property_tamper ON properties;

CREATE TRIGGER trg_prevent_property_tamper
  BEFORE UPDATE ON properties
  FOR EACH ROW EXECUTE FUNCTION prevent_property_tamper();
