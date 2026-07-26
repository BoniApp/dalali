-- ═══════════════════════════════════════════════════════════════
-- DALALI — id-documents storage bucket (KYC capture fix)
--
-- document_capture_screen.dart previously never called the camera —
-- it faked a 2-second delay and a hardcoded '/mock/captured_id.jpg'
-- path, so no ID photo was ever actually captured or stored. This
-- adds a real, PRIVATE bucket (unlike the public properties/avatars
-- buckets — identity documents must not be publicly readable by URL)
-- for the front-camera capture to upload into. Owner can upload/read
-- their own folder (<uid>/...); admins can read all for manual
-- review. There's no client UPDATE/DELETE policy — a re-capture
-- uploads a new file, it doesn't overwrite the audit trail.
-- ═══════════════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public)
VALUES ('id-documents', 'id-documents', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "ID documents owner upload" ON storage.objects;
CREATE POLICY "ID documents owner upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'id-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "ID documents owner read" ON storage.objects;
CREATE POLICY "ID documents owner read"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'id-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "ID documents admin read" ON storage.objects;
CREATE POLICY "ID documents admin read"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'id-documents'
    AND EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );
