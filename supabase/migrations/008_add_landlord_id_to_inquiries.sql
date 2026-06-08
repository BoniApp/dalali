-- Migration: Add landlord_id to inquiries for efficient filtering

ALTER TABLE inquiries
ADD COLUMN IF NOT EXISTS landlord_id UUID REFERENCES users(id);

-- Backfill existing inquiries from properties table
UPDATE inquiries
SET landlord_id = (
  SELECT landlord_id FROM properties WHERE properties.id = inquiries.property_id
)
WHERE landlord_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_inquiries_landlord ON inquiries(landlord_id);
