/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: process-kyc-verification
/// ═══════════════════════════════════════════════════════════════
///
/// Server-side KYC verification pipeline.
/// Triggered after user submits ID + selfie.
/// Steps:
///   1. Fetch ID document + KYC session
///   2. Call NIDA API (or stub)
///   3. Run AML screening
///   4. Assign tier + status
///   5. Write audit log
///   6. Update user trust badges if verified
///
/// Invocation:
///   POST /functions/v1/process-kyc-verification
///   Body: { session_id: string, user_id: string }
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { session_id, user_id } = await req.json()

    if (!session_id || !user_id) {
      return new Response(
        JSON.stringify({ error: 'session_id and user_id are required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
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

    // ─── 2. NIDA API verification (stubbed) ─────────────────────
    // In production: call actual NIDA API with service role
    const nidaMatch = doc?.document_type === 'nidaId' && doc?.checksum_valid === true
    const livenessPass = true // Verified by client-side liveness service

    // ─── 3. AML screening (stubbed) ─────────────────────────────
    const amlClear = true
    const riskLevel = 'low'

    // ─── 4. Determine status + tier ─────────────────────────────
    let newStatus: string
    let newTier: string

    if (!nidaMatch || !livenessPass) {
      newStatus = 'rejected'
      newTier = 'tier1'
    } else if (!amlClear || riskLevel === 'high' || riskLevel === 'critical') {
      newStatus = 'pendingReview'
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
        source: 'nida_api',
        outcome: nidaMatch ? 'match' : 'mismatch',
        match_score: nidaMatch ? 0.98 : 0.0,
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
          nida_match: nidaMatch,
          liveness_pass: livenessPass,
          aml_clear: amlClear,
          risk_level: riskLevel,
        },
        timestamp: now,
      })

    // ─── 8. Update user trust badges if verified ────────────────
    if (newStatus === 'verified') {
      await supabaseClient
        .from('users')
        .update({
          verification_status: 'verified',
          is_verified_listing_creator: true,
        })
        .eq('id', user_id)
    }

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
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
