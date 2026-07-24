Supabase Edge Functions & Migration Deployment Guide

Prerequisites
- Supabase CLI installed (`npm install -g supabase` or `brew install supabase/tap/supabase`)
- You have access to the Supabase project and service role key

1) Run database migrations

From project root:

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
# Or apply a single migration via psql:
psql "<your_db_connection>" -f supabase/migrations/022_dpo_payments.sql
```

2) Deploy Edge Functions

```bash
# DPO Pay (payment collections)
supabase functions deploy create-dpo-token
supabase functions deploy verify-dpo-payment
supabase functions deploy dpo-callback

# Withdrawals (manual ops payout) + the rest
supabase functions deploy process-withdrawal
supabase functions deploy listing-share
```

Secrets (set once per project):

```bash
# DPO Pay — the company token must NEVER appear in client code
supabase secrets set DPO_COMPANY_TOKEN="<company-token>"
supabase secrets set DPO_SERVICE_TYPE="85325"   # test service; replace with live service type

# Existing
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<service_role_key>"
supabase secrets set ADMIN_API_SECRET="<long-secret>"       # process-withdrawal admin calls
supabase secrets set COMMISSION_SECRET="<long-secret>"      # influencer commission endpoints
```

`SUPABASE_URL` is injected automatically. `dpo-callback` and `listing-share` are
`verify_jwt = false` in `supabase/config.toml` (browser redirect / social crawlers).

3) DPO configuration

- In the DPO back office, set the payment page's redirect to:
  `https://<project-ref>.functions.supabase.co/dpo-callback`
  (the function already receives it as `RedirectURL` per CreateToken call;
  configure it in DPO only if your account requires a whitelisted URL).
- Test service types: `85325` (test service), `54841` (test product). Use `85325`.

4) Testing

```bash
# Deno unit tests for all functions (CI runs these on push to main)
cd supabase/functions && deno test --unstable --quiet --allow-env

# CreateToken smoke test (requires a logged-in user JWT):
curl -X POST "https://<project-ref>.functions.supabase.co/create-dpo-token" \
  -H "Authorization: Bearer <user-jwt>" -H 'Content-Type: application/json' \
  -d '{"property_id":"<uuid>"}'
```

5) Security notes
- Never expose `SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_API_SECRET`, `COMMISSION_SECRET`, or `DPO_COMPANY_TOKEN` in client apps.
- All DPO XML API calls happen inside edge functions only; the app talks to Supabase.

6) Rollback
- If migration fails, use your DB backups or run appropriate DROP TABLE statements.
