Supabase Edge Functions & Migration Deployment Guide

Prerequisites
- Supabase CLI installed (`npm install -g supabase`)
- You have access to Supabase project and service role key

1) Run database migrations

From project root (or supabase folder):

```bash
# Login to supabase
supabase login
# Set project
supabase link --project-ref <your-project-ref>
# Run migrations (if using supabase migrations)
supabase db push --project-ref <your-project-ref>
# Or run SQL directly via psql using connection string
psql "<your_db_connection>" -f supabase/migrations/001_create_payment_tables.sql
psql "<your_db_connection>" -f supabase/migrations/002_wallet_rpcs_and_withdrawals.sql
```

2) Deploy Edge Functions

Set environment variables in Supabase dashboard for each function or use the CLI:
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY (keep this secret)
- ADMIN_API_SECRET (for `update_gateway` function)

```bash
# Navigate to functions folder
cd supabase/functions
# Deploy each function
supabase functions deploy payment_webhook --project-ref <your-project-ref>
supabase functions deploy update_gateway --project-ref <your-project-ref>
# Set env vars
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<service_role_key>" --project-ref <your-project-ref>
supabase secrets set SUPABASE_URL="https://<your-project>.supabase.co" --project-ref <your-project-ref>
supabase secrets set ADMIN_API_SECRET="<long-secret>" --project-ref <your-project-ref>
```

3) Register webhook URL with payment provider
- Configure the provider callback URL to: `https://<project>.functions.supabase.co/payment_webhook`
- Ensure provider sends identifying headers (e.g., `x-provider: selcom`, or provider-specific signature headers like `x-selcom-signature`)

4) Testing
- Use `curl` to simulate a callback:

```bash
curl -X POST "https://<project>.functions.supabase.co/payment_webhook" \
  -H 'Content-Type: application/json' \
  -H 'x-provider: selcom' \
  -d '{"transaction_id":"DAL-TEST-1","status":"success","amount":20000}'
```

5) Security notes
- Never expose `SUPABASE_SERVICE_ROLE_KEY` or `ADMIN_API_SECRET` in client apps.
- Use HTTPS-only endpoints and verify provider signatures.

6) Rollback
- If migration fails, use your DB backups or run appropriate DROP TABLE statements.

7) Further work
- Implement specific provider signature logic for M-Pesa & Airtel per their docs.
- Add monitoring and retry logic for webhook processing.
