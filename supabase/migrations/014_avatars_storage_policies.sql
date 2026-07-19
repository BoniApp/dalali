-- ═══════════════════════════════════════════════════════════════
-- DALALI STORAGE — Phase 14: avatars bucket RLS policies
--
-- Profile picture uploads (StorageService.uploadProfileImage) were
-- rejected by storage RLS (403) because the avatars bucket had no
-- INSERT policy. Policies are scoped to the user's own folder
-- (<uid>/...) so clients can manage only their own avatar; reads
-- stay public (bucket is public). Run after 013_auto_influencer_signup.sql
-- ═══════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Avatars public read" ON storage.objects;
CREATE POLICY "Avatars public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Avatars owner upload" ON storage.objects;
CREATE POLICY "Avatars owner upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Needed for upsert re-uploads (replacing an existing avatar).
DROP POLICY IF EXISTS "Avatars owner update" ON storage.objects;
CREATE POLICY "Avatars owner update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Avatars owner delete" ON storage.objects;
CREATE POLICY "Avatars owner delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
