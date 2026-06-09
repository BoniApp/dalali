-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — Phase 2: Core Data (Properties, Favorites, Appointments, Inquiries)
--
-- Run in Supabase SQL Editor after 001_initial_schema.sql
-- ═══════════════════════════════════════════════════════════════

-- ─── PROPERTIES ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  location TEXT NOT NULL,
  latitude NUMERIC DEFAULT 0,
  longitude NUMERIC DEFAULT 0,
  rent_price NUMERIC NOT NULL DEFAULT 0,
  bedrooms INTEGER DEFAULT 0,
  bathrooms INTEGER DEFAULT 0,
  property_type TEXT DEFAULT 'apartment' CHECK (property_type IN ('apartment','house','villa','bedsitter','office','shop')),
  is_furnished BOOLEAN DEFAULT false,
  has_water BOOLEAN DEFAULT false,
  has_parking BOOLEAN DEFAULT false,
  has_security BOOLEAN DEFAULT false,
  shared_compound BOOLEAN DEFAULT false,
  has_borehole BOOLEAN DEFAULT false,
  images TEXT[] DEFAULT '{}',
  video_url TEXT,
  status TEXT DEFAULT 'available' CHECK (status IN ('available','occupied','pending')),
  listing_type TEXT DEFAULT 'basic' CHECK (listing_type IN ('basic','featured')),
  source_type TEXT DEFAULT 'landlordListing' CHECK (source_type IN ('landlordListing','userMoveListing','agentListing')),
  landlord_id UUID REFERENCES users(id) ON DELETE CASCADE,
  landlord_name TEXT DEFAULT '',
  landlord_phone TEXT DEFAULT '',
  is_landlord_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  view_count INTEGER DEFAULT 0,
  inquiry_count INTEGER DEFAULT 0,
  is_approved BOOLEAN DEFAULT true,
  rating NUMERIC DEFAULT 0,
  review_count INTEGER DEFAULT 0,
  is_boosted BOOLEAN DEFAULT false,
  boost_expires_at TIMESTAMPTZ,
  tags TEXT[] DEFAULT '{}',
  utilities JSONB DEFAULT '{"water":"shared","electricity":"shared","internet":"notAvailable","wasteCollection":"shared","security":"notIncluded"}',
  safety_score NUMERIC DEFAULT 80,
  incident_count INTEGER DEFAULT 0,
  rent_amount NUMERIC DEFAULT 0,
  payment_options TEXT[] DEFAULT ARRAY['monthly'],
  minimum_accepted_term TEXT,
  deposit_required BOOLEAN DEFAULT false,
  deposit_amount NUMERIC DEFAULT 0,
  has_electricity BOOLEAN DEFAULT true,
  has_internet BOOLEAN DEFAULT false,
  has_gym BOOLEAN DEFAULT false,
  has_swimming_pool BOOLEAN DEFAULT false,
  has_balcony BOOLEAN DEFAULT false,
  has_garden BOOLEAN DEFAULT false,
  has_backup_generator BOOLEAN DEFAULT false,
  has_cctv BOOLEAN DEFAULT false,
  has_elevator BOOLEAN DEFAULT false,
  pet_friendly BOOLEAN DEFAULT false,
  has_air_conditioning BOOLEAN DEFAULT false,
  has_fitted_kitchen BOOLEAN DEFAULT false
);

ALTER TABLE properties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Properties public read" ON properties FOR SELECT USING (true);
CREATE POLICY "Landlords can create properties" ON properties FOR INSERT
  WITH CHECK (auth.uid() = landlord_id AND EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('landlord','agent')
  ));
CREATE POLICY "Landlords can update own" ON properties FOR UPDATE
  USING (auth.uid() = landlord_id);
CREATE POLICY "Landlords/admins can delete" ON properties FOR DELETE
  USING (auth.uid() = landlord_id OR EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
  ));

-- Index for common queries
CREATE INDEX IF NOT EXISTS idx_properties_status ON properties(status);
CREATE INDEX IF NOT EXISTS idx_properties_approved ON properties(is_approved);
CREATE INDEX IF NOT EXISTS idx_properties_landlord ON properties(landlord_id);
CREATE INDEX IF NOT EXISTS idx_properties_created ON properties(created_at DESC);

-- ─── FAVORITES ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, property_id)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own favorites" ON favorites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can add favorites" ON favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove own favorites" ON favorites FOR DELETE USING (auth.uid() = user_id);

-- ─── APPOINTMENTS ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  property_title TEXT DEFAULT '',
  seeker_id UUID REFERENCES users(id) ON DELETE CASCADE,
  seeker_name TEXT DEFAULT '',
  seeker_phone TEXT DEFAULT '',
  landlord_id UUID REFERENCES users(id) ON DELETE CASCADE,
  scheduled_date TIMESTAMPTZ,
  notes TEXT DEFAULT '',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','confirmed','completed','cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read involved appointments" ON appointments FOR SELECT
  USING (auth.uid() = seeker_id OR auth.uid() = landlord_id);
CREATE POLICY "Seekers can create appointments" ON appointments FOR INSERT
  WITH CHECK (auth.uid() = seeker_id);
CREATE POLICY "Involved parties can update" ON appointments FOR UPDATE
  USING (auth.uid() = seeker_id OR auth.uid() = landlord_id);

CREATE INDEX IF NOT EXISTS idx_appointments_seeker ON appointments(seeker_id);
CREATE INDEX IF NOT EXISTS idx_appointments_landlord ON appointments(landlord_id);

-- ─── INQUIRIES ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  property_title TEXT DEFAULT '',
  seeker_id UUID REFERENCES users(id) ON DELETE CASCADE,
  seeker_name TEXT DEFAULT '',
  seeker_phone TEXT DEFAULT '',
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  is_read BOOLEAN DEFAULT false
);

ALTER TABLE inquiries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read related inquiries" ON inquiries FOR SELECT
  USING (auth.uid() = seeker_id OR auth.uid() = (
    SELECT landlord_id FROM properties WHERE properties.id = inquiries.property_id
  ));
CREATE POLICY "Seekers can send inquiries" ON inquiries FOR INSERT
  WITH CHECK (auth.uid() = seeker_id);
CREATE POLICY "Landlords can mark read" ON inquiries FOR UPDATE
  USING (auth.uid() = (
    SELECT landlord_id FROM properties WHERE properties.id = inquiries.property_id
  ));

CREATE INDEX IF NOT EXISTS idx_inquiries_property ON inquiries(property_id);
CREATE INDEX IF NOT EXISTS idx_inquiries_seeker ON inquiries(seeker_id);
