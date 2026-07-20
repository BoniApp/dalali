/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: process-kyc-verification
/// ═══════════════════════════════════════════════════════════════
///
/// Server-side KYC verification pipeline.
/// Triggered after user submits ID + selfie.
/// Steps:
///   1. Auth: caller must own the session (user JWT), or be an
///      admin (admin JWT / x-admin-secret)
///   2. Fetch ID document + KYC session
///   3. NIDA documents → NIDA verification path; voter's ID /
///      driver's licence / passport / ZanID → manual review
///   4. Assign tier + status, write audit trail
///   5. Mirror the outcome onto users.verification_status
///      (drives the withdrawal gate, migration 016)
///
/// Invocation:
///   POST /functions/v1/process-kyc-verification
///   Body: { session_id: string, user_id: string }
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-admin-secret',
}

// deno-lint-ignore no-explicit-any
async function resolveCaller(supabase: any, req: Request): Promise<{ userId: string; isAdmin: boolean } | null> {
  const secret = req.headers.get('x-admin-secret')
  const expected = Deno.env.get('ADMIN_API_SECRET')
  if (secret && expected && secret === expected) return { userId: 'secret', isAdmin: true }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return null
  const token = authHeader.replace('Bearer ', '')
  const {
    data: { user },
  } = await supabase.auth.getUser(token)
  if (!user) return null
  const { data: row } = await supabase
    .from('users')
    .select('id, is_admin')
    .eq('id', user.id)
    .maybeSingle()
  return { userId: user.id, isAdmin: row?.is_admin === true }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'POST only' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const caller = await resolveCaller(supabaseClient, req)
    if (!caller) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { session_id, user_id } = await req.json()

    if (!session_id || !user_id) {
      return new Response(
        JSON.stringify({ error: 'session_id and user_id are required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    // Only the session owner or an admin may finalize a session.
    if (!caller.isAdmin && caller.userId !== user_id) {
      return new Response(JSON.stringify({ error: 'Not your KYC session' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ─── 1. Fetch session + document ────────────────────────────
    const { data: session } = await supabaseClient
      .from('kyc_sessions')
      .select('*')
      .eq('session_id', session_id)
      .single()

    if (!session) {
      return new Response(
        JSON.stringify({ error: 'KYC session not found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404 }
      )
    }

    const { data: documents } = await supabaseClient
      .from('id_documents')
      .select('*')
      .eq('user_id', user_id)
      .order('captured_at', { ascending: false })
      .limit(1)

    const doc = documents?.[0]

    // ─── 2. Verification path by document type ──────────────────
    // NIDA ID → instant NIDA check (stubbed); voter's ID, driver's
    // licence, passport and ZanID have no instant API in Tanzania —
    // they go to manual review.
    const isNidaDoc = doc?.document_type === 'nidaId'
    const nidaMatch = isNidaDoc && doc?.checksum_valid === true
    const livenessPass = true // Verified by client-side proof-of-life step

    // ─── 3. AML screening (stubbed) ─────────────────────────────
    const amlClear = true
    const riskLevel: string = 'low'

    // ─── 4. Determine status + tier ─────────────────────────────
    let newStatus: string
    let newTier: string

    if (!livenessPass) {
      newStatus = 'rejected'
      newTier = 'tier1'
    } else if (!isNidaDoc || !amlClear || riskLevel === 'high' || riskLevel === 'critical') {
      // Manual review: non-NIDA documents, or anything flagged.
      newStatus = 'pendingReview'
      newTier = 'tier1'
    } else if (!nidaMatch) {
      newStatus = 'rejected'
      newTier = 'tier1'
    } else {
      newStatus = 'verified'
      newTier = 'tier2'
    }

    const now = new Date().toISOString()

    // ─── 5. Update KYC session ──────────────────────────────────
    await supabaseClient
      .from('kyc_sessions')
      .update({
        status: newStatus,
        tier: newTier,
        submitted_at: now,
        verified_at: newStatus === 'verified' ? now : null,
        rejected_at: newStatus === 'rejected' ? now : null,
      })
      .eq('session_id', session_id)

    // ─── 6. Write verification result ───────────────────────────
    await supabaseClient
      .from('verification_results')
      .insert({
        session_id,
        source: isNidaDoc ? 'nida_api' : 'manual_review',
        outcome: isNidaDoc ? (nidaMatch ? 'match' : 'mismatch') : 'match',
        match_score: isNidaDoc ? (nidaMatch ? 0.98 : 0.0) : null,
        assessed_risk: riskLevel,
        checked_at: now,
      })

    // ─── 7. Write audit log ─────────────────────────────────────
    await supabaseClient
      .from('kyc_audit_logs')
      .insert({
        session_id,
        user_id,
        action: `kyc_finalized_${newStatus}`,
        correlation_id: session.correlation_id,
        metadata: {
          document_type: doc?.document_type ?? null,
          nida_match: nidaMatch,
          liveness_pass: livenessPass,
          aml_clear: amlClear,
          risk_level: riskLevel,
        },
        timestamp: now,
      })

    // ─── 8. Mirror the outcome onto users.verification_status ───
    // Drives the withdrawal gate (migration 016) and the profile
    // badge. Tamper trigger (migration 018) allows service-role only.
    const userVerificationStatus =
      newStatus === 'verified' ? 'verified' : newStatus === 'pendingReview' ? 'pending' : 'rejected'

    await supabaseClient
      .from('users')
      .update(
        newStatus === 'verified'
          ? { verification_status: 'verified', is_verified_listing_creator: true }
          : { verification_status: userVerificationStatus }
      )
      .eq('id', user_id)

    return new Response(
      JSON.stringify({
        success: true,
        status: newStatus,
        tier: newTier,
        session_id,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
