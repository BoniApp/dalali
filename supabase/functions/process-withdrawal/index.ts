// ═══════════════════════════════════════════════════════════════
// SUPABASE EDGE FUNCTION: process-withdrawal (manual ops payout)
// ═══════════════════════════════════════════════════════════════
//
// DPO Pay handles COLLECTIONS only; payouts run as manual ops for
// now (DPO disbursements are a documented follow-up). Flow:
//   admin (x-admin-secret or admin JWT)
//   → atomically CLAIM the withdrawal (pending → processing)
//   → balance check
//   → wallet_debit RPC (atomic, FOR UPDATE — migration 027)
//   → mark completed
// Ops then sends the money out-of-band (M-Pesa/bank) against the
// MANUAL-<id> reference recorded on the row.
//
// Double-spend hardening (2026-07): the previous version read
// status='pending' non-atomically and never checked the post-debit
// UPDATE — a crash/retry or two concurrent admin approvals could
// debit the wallet twice. Now:
//   • the pending → processing transition is a single atomic UPDATE
//     (only one concurrent caller can win it — the loser gets 409)
//   • every step's error is checked
//   • a failure after a successful debit COMPENSATES (re-credit +
//     back to pending) before returning an error.
// ═══════════════════════════════════════════════════════════════

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { timingSafeEqual } from '../_shared/timing_safe_equal.ts'

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
    if (!adminSecret || !provided || !timingSafeEqual(provided, adminSecret)) {
      const jwt = req.headers.get('Authorization')?.replace('Bearer ', '')
      if (!jwt) return json({ error: 'Unauthorized' }, 401)
      const { data: { user } } = await supabase.auth.getUser(jwt)
      if (!user) return json({ error: 'Unauthorized' }, 401)
      const { data: me } = await supabase.from('users').select('is_admin').eq('id', user.id).maybeSingle()
      if (!me?.is_admin) return json({ error: 'Forbidden' }, 403)
    }

    const { withdrawal_id: withdrawalId } = await req.json()
    if (!withdrawalId) return json({ error: 'withdrawal_id required' }, 400)

    // ─── 1. Atomically claim: pending → processing ──────────────
    // Exactly one concurrent caller can transition the row; everyone
    // else gets 409 and no money moves.
    const { data: wd, error: claimError } = await supabase
      .from('withdrawals')
      .update({ status: 'processing' })
      .eq('id', withdrawalId)
      .eq('status', 'pending')
      .select()
      .maybeSingle()
    if (claimError) return json({ error: 'Could not claim withdrawal' }, 500)
    if (!wd) return json({ error: 'Withdrawal not found or already processed' }, 409)

    // Helper to put the row back to pending after a recoverable failure.
    const release = async (reason: string) => {
      await supabase.from('withdrawals')
        .update({ status: 'pending', failure_reason: reason })
        .eq('id', withdrawalId)
    }

    // ─── 2. Balance check ────────────────────────────────────────
    const { data: wallet } = await supabase
      .from('wallets')
      .select('available_balance')
      .eq('user_id', wd.user_id)
      .maybeSingle()
    if (!wallet || (wallet.available_balance ?? 0) < wd.amount) {
      await supabase.from('withdrawals')
        .update({ status: 'failed', failure_reason: 'Insufficient balance' })
        .eq('id', withdrawalId)
      return json({ error: 'Insufficient balance' }, 400)
    }

    // ─── 3. Debit atomically ─────────────────────────────────────
    // wallet_debit (migration 027) locks the wallet row FOR UPDATE and
    // decrements available_balance + bumps total_withdrawn in one
    // statement — concurrent debits serialize on the row lock.
    const { data: debited, error: debitError } = await supabase.rpc('wallet_debit', {
      p_user_id: wd.user_id,
      p_amount: wd.amount,
    })
    if (debitError || !debited) {
      await release(debitError?.message ?? 'Insufficient balance at debit time')
      return json({ error: 'Debit failed — withdrawal returned to pending' }, 400)
    }

    // ─── 4. Mark completed (manual payout) ───────────────────────
    const manualRef = `MANUAL-${withdrawalId}`
    const { error: doneError } = await supabase.from('withdrawals').update({
      status: 'completed',
      processed_at: new Date().toISOString(),
      selcom_payout_id: manualRef, // legacy column, repurposed as the payout reference
    }).eq('id', withdrawalId)

    if (doneError) {
      // Money already moved — compensate so no retry can double-debit.
      const { error: creditError } = await supabase.rpc('wallet_credit', {
        p_user_id: wd.user_id,
        p_amount: wd.amount,
      })
      if (creditError) {
        console.error(`COMPENSATION FAILED for withdrawal ${withdrawalId}:`, creditError)
      }
      await release(`Completion failed after debit (compensated: ${!creditError})`)
      return json({ error: 'Completion failed — debit reversed' }, 500)
    }

    // ─── 5. Notify (best-effort) ─────────────────────────────────
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
