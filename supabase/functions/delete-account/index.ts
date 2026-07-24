/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: delete-account
/// ═══════════════════════════════════════════════════════════════
///
/// Industry-standard account deletion (Play Store / App Store /
/// GDPR erasure): the user deletes their own account from inside
/// the app. JWT-gated — callers can only delete themselves.
///
///   POST /functions/v1/delete-account   (user JWT required)
///   → { ok: true } | 409 { error: 'active_tenancy' | ... }
///
/// What happens:
///   1. BLOCKED while obligations exist: active/upcoming tenancies,
///      pending withdrawals, pending DPO payments, pending tenancy
///      applications — resolve those first.
///   2. Financial ledger rows (`transactions`) are RETAINED for
///      accounting but de-linked (payer/payee set to NULL). Fee
///      receipts in `payments` cascade with the tenant; the money
///      trail survives in `transactions`.
///   3. Storage cleanup: avatars/<uid> and images of owned
///      properties (their rows cascade with the user).
///   4. auth.users row deleted via admin API → all FK-cascaded
///      personal data goes with it (profile, notifications, access,
///      checklists, maintenance, favorites, referrals, wallet).
///
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

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method Not Allowed' }, 405)

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // ─── Auth: caller deletes THEMSELVES only ──────────────────
    const jwt = req.headers.get('Authorization')?.replace('Bearer ', '')
    if (!jwt) return json({ error: 'Unauthorized' }, 401)
    const { data: { user } } = await supabase.auth.getUser(jwt)
    if (!user) return json({ error: 'Unauthorized' }, 401)
    const uid = user.id

    // ─── 1. Blockers: outstanding obligations ──────────────────
    async function exists(table: string, build: (q: any) => any): Promise<boolean> {
      const { count } = await build(supabase.from(table).select('id', { count: 'exact', head: true }))
      return (count ?? 0) > 0
    }
    const checks: [string, () => Promise<boolean>][] = [
      ['active tenancy', () => exists('tenancies', (q) =>
        q.or(`tenant_id.eq.${uid},landlord_id.eq.${uid}`).in('status', ['upcoming', 'active']))],
      ['pending withdrawal', () => exists('withdrawals', (q) =>
        q.eq('user_id', uid).in('status', ['pending', 'processing']))],
      ['pending payment', () => exists('payments', (q) =>
        q.eq('tenant_id', uid).eq('status', 'pending'))],
      ['pending tenancy application', () => exists('tenancy_applications', (q) =>
        q.or(`seeker_id.eq.${uid},landlord_id.eq.${uid}`).eq('status', 'pending'))],
    ]
    for (const [label, check] of checks) {
      if (await check()) {
        return json({
          error: 'blocked',
          message: `You have a ${label} to resolve before deleting your account.`,
        }, 409)
      }
    }

    // ─── 2. De-link the financial ledger (retain amounts) ──────
    await supabase.from('transactions').update({ payer_id: null }).eq('payer_id', uid)
    await supabase.from('transactions').update({ payee_id: null }).eq('payee_id', uid)

    // ─── 3. Storage cleanup (best-effort) ──────────────────────
    try {
      const { data: avatarFiles } = await supabase.storage.from('avatars').list(uid)
      if (avatarFiles?.length) {
        await supabase.storage.from('avatars').remove(avatarFiles.map((f) => `${uid}/${f.name}`))
      }
      const { data: ownedProps } = await supabase
        .from('properties').select('id').or(`landlord_id.eq.${uid},listing_creator_id.eq.${uid}`)
      for (const p of ownedProps ?? []) {
        const { data: files } = await supabase.storage.from('properties').list(p.id)
        if (files?.length) {
          await supabase.storage.from('properties').remove(files.map((f) => `${p.id}/${f.name}`))
        }
      }
    } catch (e) {
      console.error('Storage cleanup failed (continuing):', e)
    }

    // ─── 4. Delete the auth user (cascades everything else) ────
    const { error: deleteError } = await supabase.auth.admin.deleteUser(uid)
    if (deleteError) return json({ error: deleteError.message }, 500)

    return json({ ok: true })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
})
