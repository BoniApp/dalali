-- ═══════════════════════════════════════════════════════════════
-- DALALI — 040: Property-deletion FK parity (account deletion gap)
--
-- Follow-up to 036. Live verification after the 036 push found two
-- remaining NO ACTION foreign keys into properties(id):
--   transactions.property_id — the financial ledger
--   disputes.property_id     — dispute records
--
-- A landlord's account deletion cascades their properties
-- (properties.landlord_id ON DELETE CASCADE, 002); with these FKs
-- strict, deleting any property that has ledger rows or disputes
-- raised an FK violation and the whole account deletion failed —
-- i.e. landlords with paid agency fees still could not delete
-- their accounts.
--
-- Both columns are nullable; switch to ON DELETE SET NULL so the
-- ledger and dispute records survive (anonymized link) while the
-- property row is removed. transactions.payer_id/payee_id stay
-- NO ACTION on purpose (delete-account de-links them explicitly).
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE transactions
  DROP CONSTRAINT IF EXISTS transactions_property_id_fkey;
ALTER TABLE transactions
  ADD CONSTRAINT transactions_property_id_fkey
  FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;

ALTER TABLE disputes
  DROP CONSTRAINT IF EXISTS disputes_property_id_fkey;
ALTER TABLE disputes
  ADD CONSTRAINT disputes_property_id_fkey
  FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
