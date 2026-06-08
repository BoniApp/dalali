-- Migration: Add admin_name and admin_role columns to admin_logs
-- Fixes PostgREST PGRST204 error when logging admin actions

ALTER TABLE admin_logs
ADD COLUMN IF NOT EXISTS admin_name TEXT,
ADD COLUMN IF NOT EXISTS admin_role TEXT;
