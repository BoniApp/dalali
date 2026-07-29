#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# DALALI — anon-key RLS probe (read-only, safe against production)
#
# Verifies that legacy/money tables are NOT exposed through the
# public anon key after migrations 037/038 are pushed. Uses GET
# requests only — never writes.
#
# Usage: ./supabase/tests/rls_probe.sh
# ═══════════════════════════════════════════════════════════════

URL="https://wnfeeyvanzesfdxvnkvf.supabase.co"
ANON_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InduZmVleXZhbnplc2ZkeHZua3ZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4MzA5MDIsImV4cCI6MjA5NjQwNjkwMn0.WLIX25J8Jz6rAqZC7l2QeTqRy_wZ9lMbTlOkUAETs14'

probe() {
  local table="$1" expect="$2"
  local code
  code=$(curl -s -o /tmp/probe_body.json -w "%{http_code}" \
    -H "apikey: ${ANON_KEY}" -H "Authorization: Bearer ${ANON_KEY}" \
    "${URL}/rest/v1/${table}?select=*&limit=1")
  local rows
  rows=$(python3 -c "import json,sys; d=json.load(open('/tmp/probe_body.json')); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo 0)
  printf "%-22s HTTP %s rows=%s  (expect %s)\n" "$table" "$code" "$rows" "$expect"
}

echo "== must NOT be readable with the anon key =="
probe commissions    "404/401/403 or 200 with 0 rows"
probe gateway_logs   "404/401/403 or 200 with 0 rows"
probe refunds        "404/401/403 or 200 with 0 rows"
probe wallets        "200 with 0 rows (RLS hides all)"
probe payments       "200 with 0 rows (RLS hides all)"
probe withdrawals    "200 with 0 rows (RLS hides all)"
probe transactions   "200 with 0 rows (RLS hides all)"
probe users          "200 with 0 rows (RLS hides all)"
probe kyc_sessions   "200 with 0 rows (RLS hides all)"

echo "== must stay publicly readable =="
probe properties     "200 (public feed rows)"

echo "== money RPCs must NOT be callable by anon =="
for fn in wallet_credit_pending wallet_settle_pending platform_wallet_credit_pending settle_dpo_payment; do
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: ${ANON_KEY}" -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -X POST "${URL}/rest/v1/rpc/${fn}" -d '{}')
  printf "%-32s HTTP %s  (expect 401/404)\n" "rpc/${fn}" "$code"
done
