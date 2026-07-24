-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 024: FCM Push Tokens
--
-- Firebase Cloud Messaging device tokens, synced by FcmService on
-- login/refresh and cleared on logout. Sending is server-side only
-- (send-notification edge function; service account in secrets).
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS device_platform TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_token_update TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;
