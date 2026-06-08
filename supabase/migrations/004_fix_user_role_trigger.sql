-- Fix: Trigger now reads role from user metadata, defaults to 'seeker'
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- Read role from metadata, default to 'seeker'
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'seeker');
  
  -- Validate role is allowed
  IF user_role NOT IN ('seeker', 'landlord', 'agent') THEN
    user_role := 'seeker';
  END IF;

  INSERT INTO public.users (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    user_role
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
