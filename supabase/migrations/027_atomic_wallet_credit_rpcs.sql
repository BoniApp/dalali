-- ═══════════════════════════════════════════════════════════════
-- DALALI — Atomic wallet crediting RPCs
--
-- Fixes two real bugs found while auditing the DPO settlement path:
--
-- 1. `_shared/dpo_settlement.ts` and `_shared/influencer_commission.ts`
--    credit wallets via a JS read-then-write (select balance, add in
--    JS, update) instead of an atomic SQL update. Every agency-fee
--    payment credits the SAME shared platform wallet row this way —
--    concurrent settlements (callback + app-poll racing on the same
--    payment, or two different payments settling at once) can lose a
--    credit. `scheduled-settlement/index.ts`'s pending->available move
--    has the identical race.
--
-- 2. Those functions use the literal string "_platform" as a wallet
--    `user_id` to hold the platform's 40% revenue share. `wallets.user_id`
--    is `uuid references users(id)`, and `"_platform"` is neither a
--    valid uuid nor a real user — every insert/update against it has
--    been silently failing (errors were destructured away, never
--    checked), so the platform revenue share has never actually landed
--    in a queryable wallet balance. `users.id` itself is FK'd to
--    `auth.users(id)`, so a fake platform *user* can't be created by
--    plain SQL — instead we give the platform its own small table.
--
-- This migration:
--   - adds `platform_wallet` (a one-row table, admin-readable, server
--     write-only) to replace the "_platform" sentinel in `wallets`
--   - replaces the stale 002 wallet_credit/wallet_debit (which
--     referenced a `balance` column that predates the 003 schema —
--     available_balance/pending_balance/locked_balance — and would
--     error if actually invoked) with versions matching the live schema
--   - adds wallet_credit_pending / wallet_settle_pending (real users)
--     and platform_wallet_credit_pending / platform_wallet_settle_pending
--     (the platform row) as atomic single-statement RPCs
-- ═══════════════════════════════════════════════════════════════

-- ─── Platform revenue wallet (singleton, not FK'd to users) ────

CREATE TABLE IF NOT EXISTS platform_wallet (
  id TEXT PRIMARY KEY DEFAULT 'platform',
  pending_balance NUMERIC NOT NULL DEFAULT 0 CHECK (pending_balance >= 0),
  available_balance NUMERIC NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
  total_earned NUMERIC NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO platform_wallet (id) VALUES ('platform') ON CONFLICT (id) DO NOTHING;

ALTER TABLE platform_wallet ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins read platform wallet" ON platform_wallet;
CREATE POLICY "Admins read platform wallet" ON platform_wallet FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
);
DROP POLICY IF EXISTS "Server-only platform wallet mutations" ON platform_wallet;
CREATE POLICY "Server-only platform wallet mutations" ON platform_wallet FOR ALL USING (false);

-- ─── Fix stale user wallet RPCs (002 referenced a `balance` column ─
-- that the 003 schema replaced with available_balance/pending_balance/
-- locked_balance; these two functions would error if called against
-- the live table, and nothing currently calls wallet_credit).

CREATE OR REPLACE FUNCTION public.wallet_credit(p_user_id uuid, p_amount numeric)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE wallets SET available_balance = available_balance + p_amount, updated_at = now()
  WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    INSERT INTO wallets(user_id, available_balance) VALUES (p_user_id, p_amount);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.wallet_debit(p_user_id uuid, p_amount numeric)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  cur_balance numeric;
BEGIN
  SELECT available_balance INTO cur_balance FROM wallets WHERE user_id = p_user_id FOR UPDATE;
  IF cur_balance IS NULL OR cur_balance < p_amount THEN
    RETURN false;
  END IF;
  UPDATE wallets
  SET available_balance = available_balance - p_amount,
      total_withdrawn = total_withdrawn + p_amount,
      updated_at = now()
  WHERE user_id = p_user_id;
  RETURN true;
END;
$$;

-- ─── New atomic RPCs used by dpo_settlement / influencer_commission ─

-- Credit a real user's pending balance (agency-fee agent share,
-- influencer commission). Single atomic UPDATE — no read-modify-write.
CREATE OR REPLACE FUNCTION public.wallet_credit_pending(p_user_id uuid, p_amount numeric)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE wallets
  SET pending_balance = pending_balance + p_amount,
      total_earned = total_earned + p_amount,
      updated_at = now()
  WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    INSERT INTO wallets(user_id, pending_balance, total_earned) VALUES (p_user_id, p_amount, p_amount);
  END IF;
END;
$$;

-- Move an amount from pending to available for a real user (used by
-- scheduled-settlement for both agent agency-fee shares and influencer
-- referral commissions).
CREATE OR REPLACE FUNCTION public.wallet_settle_pending(p_user_id uuid, p_amount numeric)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE wallets
  SET pending_balance = GREATEST(0, pending_balance - p_amount),
      available_balance = available_balance + p_amount,
      updated_at = now()
  WHERE user_id = p_user_id;
END;
$$;

-- Platform-side equivalents against platform_wallet instead of wallets.
CREATE OR REPLACE FUNCTION public.platform_wallet_credit_pending(p_amount numeric)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE platform_wallet
  SET pending_balance = pending_balance + p_amount,
      total_earned = total_earned + p_amount,
      updated_at = now()
  WHERE id = 'platform';
END;
$$;

CREATE OR REPLACE FUNCTION public.platform_wallet_settle_pending(p_amount numeric)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE platform_wallet
  SET pending_balance = GREATEST(0, pending_balance - p_amount),
      available_balance = available_balance + p_amount,
      updated_at = now()
  WHERE id = 'platform';
END;
$$;

-- ─── Single-transaction DPO settlement core ─────────────────────
-- Previously `_shared/dpo_settlement.ts` made 4+ separate calls
-- (mark payment paid -> upsert property_access -> insert transaction
-- -> credit wallet(s)), with the idempotency guard ("already paid?")
-- checked *before* any of them ran. A crash between the first and
-- last call left a payment marked paid with no ledger row and no
-- wallet credit, and a retry would hit the idempotency guard and
-- never redo the crediting. Wrapping the money-moving steps in one
-- plpgsql function makes them succeed or fail together; the payment
-- can only ever be "paid" once everything else has committed too.
-- Notifications and the influencer commission (already best-effort
-- per the surrounding TS) intentionally stay outside this function.
CREATE OR REPLACE FUNCTION public.settle_dpo_payment(
  p_payment_id uuid,
  p_dpo_transaction_id text,
  p_payment_method text,
  p_agent_id uuid,
  p_payee_share numeric,
  p_platform_share numeric
) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_payment payments%ROWTYPE;
  v_property_title text;
  v_txn_id uuid;
BEGIN
  SELECT * INTO v_payment FROM payments WHERE id = p_payment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'payment % not found', p_payment_id;
  END IF;

  IF v_payment.status = 'paid' THEN
    RETURN jsonb_build_object('already_paid', true);
  END IF;

  UPDATE payments SET
    status = 'paid',
    paid_at = now(),
    dpo_transaction_id = p_dpo_transaction_id,
    payment_method = p_payment_method
  WHERE id = p_payment_id;

  INSERT INTO property_access (property_id, tenant_id, payment_id, paid)
  VALUES (v_payment.property_id, v_payment.tenant_id, v_payment.id, true)
  ON CONFLICT (property_id, tenant_id)
  DO UPDATE SET payment_id = excluded.payment_id, paid = true;

  SELECT title INTO v_property_title FROM properties WHERE id = v_payment.property_id;

  INSERT INTO transactions (
    type, status, amount, currency, payer_id, payee_id, property_id,
    property_title, payment_method, idempotency_key, split, processed_at
  ) VALUES (
    'agencyFee', 'processing', v_payment.amount, v_payment.currency,
    v_payment.tenant_id, p_agent_id, v_payment.property_id,
    coalesce(v_property_title, ''), 'dpo',
    coalesce(p_dpo_transaction_id, 'dpo_' || v_payment.id::text),
    jsonb_build_object('agent', p_payee_share, 'platform', p_platform_share),
    now()
  )
  RETURNING id INTO v_txn_id;

  IF p_agent_id IS NOT NULL AND p_payee_share > 0 THEN
    PERFORM public.wallet_credit_pending(p_agent_id, p_payee_share);
  END IF;
  IF p_platform_share > 0 THEN
    PERFORM public.platform_wallet_credit_pending(p_platform_share);
  END IF;

  RETURN jsonb_build_object(
    'already_paid', false,
    'transaction_id', v_txn_id,
    'property_title', coalesce(v_property_title, '')
  );
END;
$$;
