/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: verify-dpo-payment
/// ═══════════════════════════════════════════════════════════════
///
/// App-side settlement path: after the customer returns from the DPO
/// hosted page, the app calls this to VerifyToken and settle.
///
///   POST /functions/v1/verify-dpo-payment   (user JWT required)
///   Body: { token: string }   (the DPO transaction token)
///   → { status: 'paid'|'pending'|'failed', payment, receipt? }
///
/// Only the paying tenant (or an admin) may verify a payment.
/// Settlement itself lives in _shared/dpo_settlement.ts and is
/// idempotent — safe to call repeatedly.
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyAndSettle } from '../_shared/dpo_settlement.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method Not Allowed' }, 405)

  try {
    const companyToken = Deno.env.get('DPO_COMPANY_TOKEN')
    if (!companyToken) return json({ error: 'DPO is not configured' }, 500)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const jwt = req.headers.get('Authorization')?.replace('Bearer ', '')
    if (!jwt) return json({ error: 'Unauthorized' }, 401)
    const { data: { user } } = await supabase.auth.getUser(jwt)
    if (!user) return json({ error: 'Unauthorized' }, 401)

    const { token } = await req.json()
    if (!token) return json({ error: 'token is required' }, 400)

    const { data: payment } = await supabase
      .from('payments')
      .select('*')
      .eq('dpo_token', token)
      .maybeSingle()
    if (!payment) return json({ error: 'Payment not found' }, 404)

    // Ownership: tenant who paid, or an admin.
    if (payment.tenant_id !== user.id) {
      const { data: me } = await supabase.from('users').select('is_admin').eq('id', user.id).maybeSingle()
      if (!me?.is_admin) return json({ error: 'Forbidden' }, 403)
    }

    const outcome = await verifyAndSettle(supabase, payment, { companyToken })

    return json({
      status: outcome.status,
      payment: outcome.payment,
      receipt: outcome.status === 'paid'
        ? {
            receiptNumber: outcome.payment.receipt_number,
            paymentId: outcome.payment.id,
            transactionId: outcome.payment.dpo_transaction_id,
            amount: outcome.payment.amount,
            currency: outcome.payment.currency,
            paymentMethod: outcome.payment.payment_method,
            paidAt: outcome.payment.paid_at,
          }
        : null,
    })
  } catch (error) {
    return json({ error: error.message }, 500)
  }
})
