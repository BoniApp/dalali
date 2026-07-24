/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: dpo-callback
/// ═══════════════════════════════════════════════════════════════
///
/// Browser redirect target for the DPO hosted payment page. DPO
/// appends the transaction token to our RedirectURL; we settle
/// (idempotently — the app's verify-dpo-payment poll may race us)
/// and bounce the customer back into the app via the dalali:// deep
/// link. Deployed with verify_jwt = false (see supabase/config.toml):
/// this is a browser redirect, no auth headers exist.
///
///   GET /functions/v1/dpo-callback?TransactionToken=…&CompanyRef=…
///   → 302 dalali://payment-success?token=… | dalali://payment-failed?token=…
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyAndSettle } from '../_shared/dpo_settlement.ts'

serve(async (req) => {
  const url = new URL(req.url)
  const token = url.searchParams.get('TransactionToken') ?? url.searchParams.get('token') ?? ''

  const redirect = (path: string) =>
    Response.redirect(`dalali://${path}${token ? `?token=${token}` : ''}`, 302)

  if (!token) return redirect('payment-failed')

  try {
    const companyToken = Deno.env.get('DPO_COMPANY_TOKEN')
    if (!companyToken) return redirect('payment-failed')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { data: payment } = await supabase
      .from('payments')
      .select('*')
      .eq('dpo_token', token)
      .maybeSingle()
    if (!payment) return redirect('payment-failed')

    const outcome = await verifyAndSettle(supabase, payment, { companyToken })
    if (outcome.status === 'paid') return redirect('payment-success')
    if (outcome.status === 'pending') return redirect('payment-pending')
    return redirect('payment-failed')
  } catch (error) {
    console.error('dpo-callback error:', error)
    return redirect('payment-failed')
  }
})
