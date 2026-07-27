-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — 030: Rental Confirmations ("Mark as Rented")
--
-- Direct rented-mark path alongside the tenancy-application flow
-- (019): a landlord or agent who received rent payment offline marks
-- their available listing as rented and picks the seeker; the seeker
-- confirms (listing drops to 'occupied' + a real tenancy is created)
-- or disputes (listing stays available). The marker can cancel a
-- pending mark.
--
-- Follows the established shape: state machine enforced by a guard
-- trigger, ALL writes via SECURITY DEFINER RPCs that bundle side
-- effects + notifications atomically (like 029's lifecycle RPCs),
-- RLS for reads only, realtime publication for client streams.
--   rental_confirmations: pending → confirmed | disputed | cancelled (terminal)
--
-- The seeker picker pool is the union of agency-fee payers
-- (property_access, 022) and tenancy applicants (019) — served by
-- list_rentable_seekers() because users RLS only exposes one's own
-- row, so the client cannot join seeker names/phones itself.
--
-- Also repairs the notifications_type_check constraint: 029's
-- re-creation accidentally dropped 'message'/'broadcast' (017).
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. RENTAL CONFIRMATIONS ────────────────────────────────────

CREATE TABLE IF NOT EXISTS rental_confirmations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  property_title TEXT DEFAULT '',
  seeker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  seeker_name TEXT DEFAULT '',
  seeker_phone TEXT DEFAULT '',
  marked_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  marked_by_name TEXT DEFAULT '',
  marked_by_role TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','confirmed','disputed','cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

ALTER TABLE rental_confirmations ENABLE ROW LEVEL SECURITY;

-- Reads only; writes go exclusively through the RPCs below (no client
-- INSERT/UPDATE/DELETE policies). The properties subquery is safe
-- because properties are publicly readable.
DROP POLICY IF EXISTS "Rental confirmations read participants" ON rental_confirmations;
CREATE POLICY "Rental confirmations read participants" ON rental_confirmations FOR SELECT
  USING (
    auth.uid() = seeker_id
    OR auth.uid() = marked_by
    OR EXISTS (
      SELECT 1 FROM properties p
      WHERE p.id = property_id
        AND (p.landlord_id = auth.uid() OR p.listing_creator_id = auth.uid())
    )
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

-- One open mark per listing; resolved rows are the audit trail.
DROP INDEX IF EXISTS uniq_pending_rental_confirmation;
CREATE UNIQUE INDEX uniq_pending_rental_confirmation
  ON rental_confirmations(property_id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_rental_confirmations_seeker ON rental_confirmations(seeker_id);
CREATE INDEX IF NOT EXISTS idx_rental_confirmations_marker ON rental_confirmations(marked_by);
CREATE INDEX IF NOT EXISTS idx_rental_confirmations_property ON rental_confirmations(property_id);
CREATE INDEX IF NOT EXISTS idx_rental_confirmations_status ON rental_confirmations(status);

-- ─── 2. GUARD TRIGGER ───────────────────────────────────────────
-- pending → confirmed | disputed | cancelled, then terminal.
-- Identity/denormalized fields immutable; resolved_at server-stamped.

CREATE OR REPLACE FUNCTION public.rental_confirmation_guard()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.property_id IS DISTINCT FROM OLD.property_id
     OR NEW.property_title IS DISTINCT FROM OLD.property_title
     OR NEW.seeker_id IS DISTINCT FROM OLD.seeker_id
     OR NEW.seeker_name IS DISTINCT FROM OLD.seeker_name
     OR NEW.seeker_phone IS DISTINCT FROM OLD.seeker_phone
     OR NEW.marked_by IS DISTINCT FROM OLD.marked_by
     OR NEW.marked_by_name IS DISTINCT FROM OLD.marked_by_name
     OR NEW.marked_by_role IS DISTINCT FROM OLD.marked_by_role
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Rental confirmation identity fields are immutable';
  END IF;

  IF OLD.status <> 'pending' THEN
    RAISE EXCEPTION 'Rental confirmation is already resolved';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status NOT IN ('confirmed','disputed','cancelled') THEN
      RAISE EXCEPTION 'Invalid rental confirmation transition: % -> %', OLD.status, NEW.status;
    END IF;
    NEW.resolved_at := NOW();
  ELSE
    NEW.resolved_at := OLD.resolved_at;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_rental_confirmation_guard ON rental_confirmations;
CREATE TRIGGER trg_rental_confirmation_guard
  BEFORE UPDATE ON rental_confirmations
  FOR EACH ROW EXECUTE FUNCTION rental_confirmation_guard();

-- ─── 3. NOTIFICATIONS: rental confirmation types ────────────────
-- Restores 'message'/'broadcast' (017), which 029's re-creation of
-- this constraint accidentally dropped, and adds the three new types.

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'inquiry','appointment','propertyApproved','propertyRejected',
    'tenancyApplication','tenancyApproved','maintenanceUpdate','rentDue',
    'paymentReceived','withdrawalProcessed','system',
    'message','broadcast',
    'tenancyExpiring','noticeGiven','renewalRequested',
    'inspectionScheduled','depositSettled',
    'rentalMarked','rentalConfirmed','rentalDisputed'
  ));

-- ─── 4. RPCs ────────────────────────────────────────────────────

-- Seeker picker for the mark sheet: agency-fee payers (property_access)
-- ∪ tenancy applicants, with names/phones resolved server-side.
CREATE OR REPLACE FUNCTION public.list_rentable_seekers(p_property_id UUID)
RETURNS TABLE(user_id UUID, full_name TEXT, phone TEXT, source TEXT)
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prop properties%ROWTYPE;
BEGIN
  SELECT * INTO v_prop FROM properties WHERE id = p_property_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Property not found';
  END IF;
  IF auth.uid() <> v_prop.landlord_id AND auth.uid() <> v_prop.listing_creator_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_prop.status <> 'available' THEN
    RAISE EXCEPTION 'Property is not available';
  END IF;

  RETURN QUERY
  WITH eligible AS (
    SELECT pa.tenant_id AS uid, 'paid'::text AS src
    FROM property_access pa
    WHERE pa.property_id = p_property_id AND pa.paid = true
    UNION
    SELECT ta.tenant_id, 'applied'::text
    FROM tenancy_applications ta
    WHERE ta.property_id = p_property_id AND ta.status IN ('pending','approved')
  ),
  combined AS (
    SELECT e.uid, string_agg(DISTINCT e.src, '+' ORDER BY e.src) AS source
    FROM eligible e
    GROUP BY e.uid
  )
  SELECT u.id, u.full_name, u.phone, c.source
  FROM combined c
  JOIN users u ON u.id = c.uid
  WHERE NOT EXISTS (
    SELECT 1 FROM rental_confirmations rc
    WHERE rc.property_id = p_property_id
      AND rc.seeker_id = c.uid
      AND rc.status = 'pending'
  )
  ORDER BY u.full_name;
END;
$$ LANGUAGE plpgsql;

-- Landlord/agent marks their available listing as rented by a seeker.
-- The listing STAYS in the feed until the seeker confirms.
CREATE OR REPLACE FUNCTION public.mark_listing_rented(p_property_id UUID, p_seeker_id UUID)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prop properties%ROWTYPE;
  v_seeker users%ROWTYPE;
  v_marker users%ROWTYPE;
  v_id UUID;
BEGIN
  SELECT * INTO v_prop FROM properties WHERE id = p_property_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Property not found';
  END IF;
  IF auth.uid() <> v_prop.landlord_id AND auth.uid() <> v_prop.listing_creator_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_prop.status <> 'available' THEN
    RAISE EXCEPTION 'Property is not available';
  END IF;

  -- Seeker must be in the eligible pool (paid the agency fee or applied).
  IF NOT EXISTS (
    SELECT 1 FROM property_access pa
    WHERE pa.property_id = p_property_id AND pa.tenant_id = p_seeker_id AND pa.paid = true
  ) AND NOT EXISTS (
    SELECT 1 FROM tenancy_applications ta
    WHERE ta.property_id = p_property_id AND ta.tenant_id = p_seeker_id
      AND ta.status IN ('pending','approved')
  ) THEN
    RAISE EXCEPTION 'Seeker is not eligible for this listing';
  END IF;

  SELECT * INTO v_seeker FROM users WHERE id = p_seeker_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Seeker not found';
  END IF;
  SELECT * INTO v_marker FROM users WHERE id = auth.uid();

  -- A duplicate open mark is rejected by uniq_pending_rental_confirmation.
  INSERT INTO rental_confirmations (
    property_id, property_title, seeker_id, seeker_name, seeker_phone,
    marked_by, marked_by_name, marked_by_role
  ) VALUES (
    p_property_id, v_prop.title, p_seeker_id, v_seeker.full_name, v_seeker.phone,
    auth.uid(), v_marker.full_name, v_marker.role
  ) RETURNING id INTO v_id;

  INSERT INTO notifications (user_id, type, title, body, target_id, target_collection)
  VALUES (
    p_seeker_id,
    'rentalMarked',
    'Did you rent this home?',
    COALESCE(NULLIF(v_marker.full_name, ''), 'The landlord')
      || ' marked ' || v_prop.title || ' as rented by you. Please confirm.',
    v_id::text,
    'rental_confirmations'
  );

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Seeker confirms (listing drops to 'occupied' + tenancy created) or
-- disputes (property untouched). All side effects in one transaction.
CREATE OR REPLACE FUNCTION public.respond_rental_confirmation(p_confirmation_id UUID, p_confirm BOOLEAN)
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rc rental_confirmations%ROWTYPE;
  v_prop properties%ROWTYPE;
BEGIN
  SELECT * INTO v_rc FROM rental_confirmations WHERE id = p_confirmation_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Confirmation not found';
  END IF;
  IF auth.uid() <> v_rc.seeker_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_rc.status <> 'pending' THEN
    RAISE EXCEPTION 'Confirmation is already resolved';
  END IF;

  IF p_confirm THEN
    -- Atomic double-booking guard, same shape as 019's
    -- handle_application_resolution(): aborts the whole transaction
    -- if the listing was taken off the market meanwhile.
    UPDATE properties
    SET status = 'occupied',
        listing_status = 'tenancyConfirmed',
        tenancy_confirmed = true
    WHERE id = v_rc.property_id AND status = 'available';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Property is no longer available';
    END IF;

    SELECT * INTO v_prop FROM properties WHERE id = v_rc.property_id;

    UPDATE rental_confirmations SET status = 'confirmed' WHERE id = p_confirmation_id;

    -- Mirrors the application-approval tenancy (019): move-in +14d,
    -- move-out +374d, deposit 2x rent. setup_new_tenancy (020/029)
    -- seeds the move checklist + rent schedule; attach_tenancy_agent
    -- (029) attributes an agent listing creator.
    INSERT INTO tenancies (
      property_id, property_title, property_location,
      tenant_id, tenant_name, landlord_id, landlord_name,
      move_in_date, expected_move_out_date, rent_amount, deposit_amount
    ) VALUES (
      v_rc.property_id, v_prop.title, v_prop.location,
      v_rc.seeker_id, v_rc.seeker_name, v_prop.landlord_id, v_prop.landlord_name,
      NOW() + INTERVAL '14 days', NOW() + INTERVAL '374 days',
      v_prop.rent_price, v_prop.rent_price * 2
    );

    INSERT INTO notifications (user_id, type, title, body, target_id, target_collection)
    VALUES (
      v_rc.marked_by,
      'rentalConfirmed',
      'Rental Confirmed',
      v_rc.seeker_name || ' confirmed renting ' || v_rc.property_title
        || '. The listing is now off the market.',
      p_confirmation_id::text,
      'rental_confirmations'
    );
  ELSE
    UPDATE rental_confirmations SET status = 'disputed' WHERE id = p_confirmation_id;

    INSERT INTO notifications (user_id, type, title, body, target_id, target_collection)
    VALUES (
      v_rc.marked_by,
      'rentalDisputed',
      'Rental Disputed',
      v_rc.seeker_name || ' says they did not rent ' || v_rc.property_title
        || '. The listing stays available.',
      p_confirmation_id::text,
      'rental_confirmations'
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Marker (or the property's landlord) withdraws a pending mark.
CREATE OR REPLACE FUNCTION public.cancel_rental_confirmation(p_confirmation_id UUID)
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rc rental_confirmations%ROWTYPE;
BEGIN
  SELECT * INTO v_rc FROM rental_confirmations WHERE id = p_confirmation_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Confirmation not found';
  END IF;
  IF auth.uid() <> v_rc.marked_by AND NOT EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = v_rc.property_id AND p.landlord_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_rc.status <> 'pending' THEN
    RAISE EXCEPTION 'Confirmation is already resolved';
  END IF;

  UPDATE rental_confirmations SET status = 'cancelled' WHERE id = p_confirmation_id;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.list_rentable_seekers TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_listing_rented TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_rental_confirmation TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_rental_confirmation TO authenticated;

-- ─── 5. REALTIME PUBLICATION ─────────────────────────────────────

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE rental_confirmations;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
