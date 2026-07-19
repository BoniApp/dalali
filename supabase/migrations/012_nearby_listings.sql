-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — Phase 12: "Listings Near Me" (PostGIS geo search)
--
-- Adds a generated geography column + spatial index on properties,
-- and the properties_nearby RPC powering the Near Me map screen.
-- Run after 011_influencer_partnership.sql
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS postgis;

-- Location text columns written by the client; ensure they exist so the
-- RPC below is portable across environments.
ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS street TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS district TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS ward TEXT DEFAULT '';

-- ─── GENERATED GEOGRAPHY COLUMN + SPATIAL INDEX ───────────────

ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS geo geography(Point, 4326)
  GENERATED ALWAYS AS (
    ST_SetSRID(
      ST_MakePoint(longitude::double precision, latitude::double precision),
      4326
    )::geography
  ) STORED;

CREATE INDEX IF NOT EXISTS properties_geo_idx ON properties USING GIST(geo);

-- ─── NEARBY LISTINGS RPC ──────────────────────────────────────
-- SECURITY INVOKER (default): properties SELECT is public under RLS.
-- Visibility filter matches the app feed (DataService.getProperties):
-- status='available' AND is_approved=true.

CREATE OR REPLACE FUNCTION public.properties_nearby(
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer,
  p_min_price numeric DEFAULT NULL,
  p_max_price numeric DEFAULT NULL,
  p_bedrooms integer DEFAULT NULL,
  p_property_type text DEFAULT NULL,
  p_premium_only boolean DEFAULT false,
  p_verified_only boolean DEFAULT false,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  location text,
  street text,
  district text,
  ward text,
  latitude numeric,
  longitude numeric,
  rent_price numeric,
  bedrooms integer,
  bathrooms integer,
  property_type text,
  is_furnished boolean,
  has_water boolean,
  has_parking boolean,
  has_security boolean,
  shared_compound boolean,
  has_borehole boolean,
  has_electricity boolean,
  has_internet boolean,
  has_gym boolean,
  has_swimming_pool boolean,
  has_balcony boolean,
  has_garden boolean,
  has_backup_generator boolean,
  has_cctv boolean,
  has_elevator boolean,
  pet_friendly boolean,
  has_air_conditioning boolean,
  has_fitted_kitchen boolean,
  images text[],
  video_url text,
  status text,
  listing_type text,
  source_type text,
  landlord_id uuid,
  landlord_name text,
  landlord_phone text,
  is_landlord_verified boolean,
  listing_creator_id uuid,
  listing_creator_role text,
  registry_id uuid,
  agency_fee_eligible boolean,
  tenancy_confirmed boolean,
  listing_status text,
  created_at timestamptz,
  updated_at timestamptz,
  view_count integer,
  inquiry_count integer,
  is_approved boolean,
  rating numeric,
  review_count integer,
  is_boosted boolean,
  boost_expires_at timestamptz,
  tags text[],
  utilities jsonb,
  safety_score numeric,
  incident_count integer,
  rent_amount numeric,
  payment_options text[],
  minimum_accepted_term text,
  deposit_required boolean,
  deposit_amount numeric,
  distance_meters double precision
)
LANGUAGE sql STABLE
AS $$
  SELECT
    p.id,
    p.title,
    p.description,
    p.location,
    p.street,
    p.district,
    p.ward,
    p.latitude,
    p.longitude,
    p.rent_price,
    p.bedrooms,
    p.bathrooms,
    p.property_type,
    p.is_furnished,
    p.has_water,
    p.has_parking,
    p.has_security,
    p.shared_compound,
    p.has_borehole,
    p.has_electricity,
    p.has_internet,
    p.has_gym,
    p.has_swimming_pool,
    p.has_balcony,
    p.has_garden,
    p.has_backup_generator,
    p.has_cctv,
    p.has_elevator,
    p.pet_friendly,
    p.has_air_conditioning,
    p.has_fitted_kitchen,
    p.images,
    p.video_url,
    p.status,
    p.listing_type,
    p.source_type,
    p.landlord_id,
    p.landlord_name,
    p.landlord_phone,
    p.is_landlord_verified,
    p.listing_creator_id,
    p.listing_creator_role,
    p.registry_id,
    p.agency_fee_eligible,
    p.tenancy_confirmed,
    p.listing_status,
    p.created_at,
    p.updated_at,
    p.view_count,
    p.inquiry_count,
    p.is_approved,
    p.rating,
    p.review_count,
    p.is_boosted,
    p.boost_expires_at,
    p.tags,
    p.utilities,
    p.safety_score,
    p.incident_count,
    p.rent_amount,
    p.payment_options,
    p.minimum_accepted_term,
    p.deposit_required,
    p.deposit_amount,
    ST_Distance(
      p.geo,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    ) AS distance_meters
  FROM properties p
  WHERE p.status = 'available'
    AND p.is_approved = true
    AND p.latitude <> 0
    AND p.longitude <> 0
    AND ST_DWithin(
      p.geo,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_m
    )
    AND (p_min_price IS NULL OR p.rent_price >= p_min_price)
    AND (p_max_price IS NULL OR p.rent_price <= p_max_price)
    AND (p_bedrooms IS NULL OR p.bedrooms >= p_bedrooms)
    AND (p_property_type IS NULL OR p.property_type = p_property_type)
    AND (NOT p_premium_only OR p.listing_type = 'featured')
    AND (NOT p_verified_only OR p.is_landlord_verified = true)
  ORDER BY distance_meters ASC,
           (p.listing_type = 'featured') DESC,
           p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;
