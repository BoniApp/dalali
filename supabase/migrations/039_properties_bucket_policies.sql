-- ═══════════════════════════════════════════════════════════════
-- DALALI — 039: properties bucket storage policies (scripted)
--
-- The 'properties' bucket was created by 005 with its policies
-- documented as MANUAL dashboard steps — unverifiable, drift-prone,
-- and the documented INSERT policy was `auth.uid() IS NOT NULL`
-- with no folder scoping: any authenticated user could upload into
-- any property's folder.
--
-- This migration scripts the policies in SQL (same pattern as 014
-- avatars / 028 id-documents). Layout is '<property_id>/<file>'
-- (StorageService.uploadPropertyImage), so write access is scoped
-- to the listing's owner: the landlord or the listing creator.
-- Reads stay public — the bucket is public by design (listing
-- images render in the feed without signed URLs).
-- ═══════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Property images public read" ON storage.objects;
CREATE POLICY "Property images public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'properties');

DROP POLICY IF EXISTS "Property images owner upload" ON storage.objects;
CREATE POLICY "Property images owner upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'properties'
    AND EXISTS (
      SELECT 1 FROM properties p
      WHERE p.id::text = (storage.foldername(name))[1]
        AND (p.landlord_id = auth.uid() OR p.listing_creator_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Property images owner update" ON storage.objects;
CREATE POLICY "Property images owner update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'properties'
    AND EXISTS (
      SELECT 1 FROM properties p
      WHERE p.id::text = (storage.foldername(name))[1]
        AND (p.landlord_id = auth.uid() OR p.listing_creator_id = auth.uid())
    )
  )
  WITH CHECK (
    bucket_id = 'properties'
    AND EXISTS (
      SELECT 1 FROM properties p
      WHERE p.id::text = (storage.foldername(name))[1]
        AND (p.landlord_id = auth.uid() OR p.listing_creator_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Property images owner delete" ON storage.objects;
CREATE POLICY "Property images owner delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'properties'
    AND (
      EXISTS (
        SELECT 1 FROM properties p
        WHERE p.id::text = (storage.foldername(name))[1]
          AND (p.landlord_id = auth.uid() OR p.listing_creator_id = auth.uid())
      )
      OR EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = true)
    )
  );
