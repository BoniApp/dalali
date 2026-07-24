// ═══════════════════════════════════════════════════════════════
// SUPABASE EDGE FUNCTION: process-withdrawal (manual ops payout)
// ═══════════════════════════════════════════════════════════════
//
// DPO Pay handles COLLECTIONS only; payouts run as manual ops for
// now (DPO disbursements are a documented follow-up). Flow:
//   admin (x-admin-secret or admin JWT) → validate withdrawal →
//   wallet_debit RPC (atomic) → mark completed → notify user.
// Ops then sends the money out-of-band (M-Pesa/bank) against the
// MANUAL-<id> reference recorded on the row.
//
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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

export async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method Not Allowed' }, 405)

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // ─── Admin auth: shared secret, or an admin user's JWT ─────
    const adminSecret = Deno.env.get('ADMIN_API_SECRET')
    const provided = req.headers.get('x-admin-secret')
    if (!adminSecret || provided !== adminSecret) {
      const jwt = req.headers.get('Authorization')?.replace('Bearer ', '')
      if (!jwt) return json({ error: 'Unauthorized' }, 401)
      const { data: { user } } = await supabase.auth.getUser(jwt)
      if (!user) return json({ error: 'Unauthorized' }, 401)
      const { data: me } = await supabase.from('users').select('is_admin').eq('id', user.id).maybeSingle()
      if (!me?.is_admin) return json({ error: 'Forbidden' }, 403)
    }

    const { withdrawal_id: withdrawalId } = await req.json()
    if (!withdrawalId) return json({ error: 'withdrawal_id required' }, 400)

    // ─── Validate ──────────────────────────────────────────────
    const { data: wd } = await supabase
      .from('withdrawals')
      .select('*')
      .eq('id', withdrawalId)
      .eq('status', 'pending')
      .maybeSingle()
    if (!wd) return json({ error: 'Withdrawal not found or not pending' }, 404)

    const { data: wallet } = await supabase
      .from('wallets')
      .select('*')
      .eq('user_id', wd.user_id)
      .maybeSingle()
    if (!wallet || (wallet.available_balance ?? 0) < wd.amount) {
      await supabase.from('withdrawals')
        .update({ status: 'failed', failure_reason: 'Insufficient balance' })
        .eq('id', withdrawalId)
      return json({ error: 'Insufficient balance' }, 400)
    }

    // ─── Debit atomically, mark completed (manual payout) ──────
    const { error: debitError } = await supabase.rpc('wallet_debit', {
      p_user_id: wd.user_id,
      p_amount: wd.amount,
    })
    if (debitError) return json({ error: `Debit failed: ${debitError.message}` }, 400)

    const manualRef = `MANUAL-${withdrawalId}`
    await supabase.from('wallets').update({
      total_withdrawn: (wallet.total_withdrawn ?? 0) + wd.amount,
      updated_at: new Date().toISOString(),
    }).eq('user_id', wd.user_id)

    await supabase.from('withdrawals').update({
      status: 'completed',
      processed_at: new Date().toISOString(),
      selcom_payout_id: manualRef, // legacy column, repurposed as the payout reference
    }).eq('id', withdrawalId)

    await supabase.from('notifications').insert({
      user_id: wd.user_id,
      type: 'withdrawalProcessed',
      title: 'Withdrawal processed',
      body: `Your withdrawal of ${wd.amount} ${wd.currency ?? 'TZS'} has been processed (ref ${manualRef}).`,
      target_id: withdrawalId,
      target_collection: 'withdrawals',
    })

    return json({ ok: true, provider_tx: manualRef })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
}

// Serve for deployment (skipped when imported by tests)
if (import.meta.main) serve(handler)
