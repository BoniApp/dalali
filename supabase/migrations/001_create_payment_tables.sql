-- Supabase migration: create payment related tables

-- payment_gateways: stores provider configs (sensitive fields should be stored encrypted or via server only access)
CREATE TABLE IF NOT EXISTS payment_gateways (
  id text PRIMARY KEY,
  provider_name text NOT NULL,
  environment text NOT NULL DEFAULT 'production',
  enabled boolean NOT NULL DEFAULT false,
  config jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- transactions: payments made via Dalali for services
CREATE TABLE IF NOT EXISTS transactions (
  id text PRIMARY KEY,
  user_id text REFERENCES users(id) ON DELETE SET NULL,
  payer_id text,
  payee_id text,
  property_id text,
  property_title text,
  amount numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'TZS',
  provider text,
  reference text,
  selcom_transaction_id text,
  type text,
  status text NOT NULL DEFAULT 'pending',
  metadata jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- gateway_logs: raw gateway callbacks for auditing
CREATE TABLE IF NOT EXISTS gateway_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id text,
  payload jsonb,
  status text,
  created_at timestamptz DEFAULT now()
);

-- wallets: user wallets and balances (agents and users)
CREATE TABLE IF NOT EXISTS wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  balance numeric NOT NULL DEFAULT 0,
  commission_total numeric NOT NULL DEFAULT 0,
  withdrawn_amount numeric NOT NULL DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

-- commissions: records agent commission allocations
CREATE TABLE IF NOT EXISTS commissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id text REFERENCES users(id) ON DELETE SET NULL,
  transaction_id text REFERENCES transactions(id) ON DELETE SET NULL,
  percentage numeric NOT NULL DEFAULT 0,
  amount numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  paid_at timestamptz
);

-- refunds
CREATE TABLE IF NOT EXISTS refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id text REFERENCES transactions(id) ON DELETE SET NULL,
  reason text,
  amount numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'requested',
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- indexes
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_wallets_user ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_commissions_agent ON commissions(agent_id);
