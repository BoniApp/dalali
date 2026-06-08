-- ═══════════════════════════════════════════════════════════════
-- DALALI STORAGE BUCKETS — Phase 5: Property & Avatar Images
--
-- ⚠️ IMPORTANT: This SQL ONLY creates bucket records.
--    You MUST also create buckets via the Supabase Dashboard UI
--    (steps below) because the SQL Editor cannot modify
--    storage.objects policies (owned by supabase_storage_admin).
--
-- Run this in the Supabase SQL Editor:
--   https://supabase.com/dashboard/project/_/sql
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. CREATE BUCKET RECORDS ──────────────────────────────────
-- This inserts into storage.buckets so Supabase knows about them.
-- If buckets already exist via UI, this is a no-op.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('properties', 'properties', true, 5242880, ARRAY['image/jpeg','image/png','image/webp']),
  ('avatars',    'avatars',    true, 2097152, ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ═══════════════════════════════════════════════════════════════
-- MANUAL STEPS (Required — do these in the Dashboard UI):
-- ═══════════════════════════════════════════════════════════════
--
-- Step 1: Open Supabase Dashboard
--   → https://supabase.com/dashboard/project/wnfeeyvanzesfdxvnkvf/storage
--
-- Step 2: Create bucket "properties"
--   → Click "New bucket"
--   → Name: properties
--   → Toggle "Public bucket" ON
--   → Click "Save"
--
-- Step 3: Create bucket "avatars"
--   → Click "New bucket"
--   → Name: avatars
--   → Toggle "Public bucket" ON
--   → Click "Save"
--
-- Step 4: Add policies for "properties" bucket
--   → Click "properties" → "Policies" tab
--   → Click "New policy" → "Get started quickly"
--   → Select "Allow access to JPG, PNG and GIF" template
--   → OR manually add these 3 policies:
--
--     Policy 1: SELECT (Public read)
--       Name: Public read
--       Allowed operation: SELECT
--       Target roles: anon, authenticated
--       Policy definition: true
--
--     Policy 2: INSERT (Authenticated upload)
--       Name: Authenticated upload
--       Allowed operation: INSERT
--       Target roles: authenticated
--       Policy definition: auth.uid() IS NOT NULL
--
--     Policy 3: DELETE (Owner or admin)
--       Name: Owner or admin can delete
--       Allowed operation: DELETE
--       Target roles: authenticated
--       Policy definition: auth.uid() = owner OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.is_admin = true)
--
-- Step 5: Repeat Step 4 for "avatars" bucket
--
-- ─── Alternative: Supabase CLI ─────────────────────────────────
-- If you have the Supabase CLI installed, run:
--   supabase storage create properties --public
--   supabase storage create avatars --public
--
-- Then apply bucket-level policies via SQL (works via CLI):
--   supabase db push
-- ═══════════════════════════════════════════════════════════════
