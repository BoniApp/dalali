-- Supabase migration: wallet RPCs and withdrawals

-- withdrawals table
CREATE TABLE IF NOT EXISTS withdrawals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'TZS',
  method text,
  destination jsonb,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- RPC for crediting wallet atomically
CREATE OR REPLACE FUNCTION public.wallet_credit(p_user_id text, p_amount numeric)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE wallets SET balance = balance + p_amount, updated_at = now() WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    INSERT INTO wallets(user_id, balance, commission_total, withdrawn_amount, updated_at)
    VALUES (p_user_id, p_amount, 0, 0, now());
  END IF;
END;
$$;

-- RPC for debiting wallet atomically (returns boolean success)
CREATE OR REPLACE FUNCTION public.wallet_debit(p_user_id text, p_amount numeric)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  cur_balance numeric;
BEGIN
  SELECT balance INTO cur_balance FROM wallets WHERE user_id = p_user_id FOR UPDATE;
  IF cur_balance IS NULL THEN
    RETURN false;
  END IF;
  IF cur_balance < p_amount THEN
    RETURN false;
  END IF;
  UPDATE wallets SET balance = balance - p_amount, withdrawn_amount = withdrawn_amount + p_amount, updated_at = now() WHERE user_id = p_user_id;
  RETURN true;
END;
$$;

-- RPC to payout commission (marks commission record paid and optionally debit platform wallet)
CREATE OR REPLACE FUNCTION public.payout_commission(p_commission_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE commissions SET status = 'paid', paid_at = now() WHERE id = p_commission_id;
END;
$$;

-- indexes
CREATE INDEX IF NOT EXISTS idx_withdrawals_user ON withdrawals(user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON withdrawals(status);
