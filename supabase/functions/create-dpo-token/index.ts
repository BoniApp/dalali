/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: create-dpo-token
/// ═══════════════════════════════════════════════════════════════
///
/// Starts a DPO agency-fee payment for the calling tenant.
///
///   POST /functions/v1/create-dpo-token   (user JWT required)
///   Body: { property_id: string }
///   → { paymentUrl, token, paymentId }
///
/// Idempotent: an open (pending) payment for the same tenant+property
/// returns its existing token; a paid one returns 409.
///
/// Secrets: DPO_COMPANY_TOKEN (never in client code), DPO_SERVICE_TYPE
/// (default 85325 — DPO test service).
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  buildCreateTokenXml,
  DPO_API_BASE,
  DPO_PAY_PAGE,
  dpoServiceDate,
  parseCreateTokenResponse,
} from '../_shared/dpo.ts'

/// Fixed agency fee — mirrors AppSettings.agencyFee on the client.
const AGENCY_FEE_TZS = 20000

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
    const serviceType = Deno.env.get('DPO_SERVICE_TYPE') ?? '85325'

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // ─── Auth: caller must be a logged-in user ────────────────
    const jwt = req.headers.get('Authorization')?.replace('Bearer ', '')
    if (!jwt) return json({ error: 'Unauthorized' }, 401)
    const { data: { user } } = await supabase.auth.getUser(jwt)
    if (!user) return json({ error: 'Unauthorized' }, 401)

    const { property_id: propertyId } = await req.json()
    if (!propertyId) return json({ error: 'property_id is required' }, 400)

    // ─── Load property + parties ──────────────────────────────
    const { data: property } = await supabase
      .from('properties')
      .select('id, title, landlord_id, listing_creator_id')
      .eq('id', propertyId)
      .maybeSingle()
    if (!property) return json({ error: 'Property not found' }, 404)
    if (property.landlord_id === user.id || property.listing_creator_id === user.id) {
      return json({ error: 'You cannot pay a fee on your own listing' }, 400)
    }

    // ─── Idempotency ──────────────────────────────────────────
    const { data: existing } = await supabase
      .from('payments')
      .select('*')
      .eq('tenant_id', user.id)
      .eq('property_id', propertyId)
      .in('status', ['pending', 'paid'])
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (existing?.status === 'paid') {
      return json({ error: 'Agency fee already paid for this property' }, 409)
    }
    if (existing?.status === 'pending' && existing.dpo_token) {
      return json({
        paymentUrl: `${DPO_PAY_PAGE}${existing.dpo_token}`,
        token: existing.dpo_token,
        paymentId: existing.id,
        reused: true,
      })
    }

    // ─── Create the payment row ───────────────────────────────
    const { data: payment, error: insertError } = await supabase
      .from('payments')
      .insert({
        property_id: property.id,
        tenant_id: user.id,
        agent_id: property.listing_creator_id || null,
        landlord_id: property.landlord_id || null,
        amount: AGENCY_FEE_TZS,
        currency: 'TZS',
        status: 'pending',
      })
      .select()
      .single()
    if (insertError || !payment) {
      return json({ error: `Could not create payment: ${insertError?.message}` }, 500)
    }

    // ─── DPO CreateToken ──────────────────────────────────────
    const fnBase = (Deno.env.get('SUPABASE_URL') ?? '').replace('.supabase.co', '.functions.supabase.co')
    const xml = buildCreateTokenXml({
      companyToken,
      amount: AGENCY_FEE_TZS,
      currency: 'TZS',
      companyRef: payment.id,
      redirectUrl: `${fnBase}/dpo-callback`,
      backUrl: 'https://dalaliapp.com/payment-back',
      serviceType,
      serviceDescription: `Dalali agency fee — ${property.title}`,
      serviceDate: dpoServiceDate(),
      customerPhone: (user.user_metadata?.phone as string) || undefined,
      customerEmail: user.email || undefined,
    })

    const dpoRes = await fetch(DPO_API_BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/xml' },
      body: xml,
    })
    const dpoBody = await dpoRes.text()
    const parsed = parseCreateTokenResponse(dpoBody)

    if (!parsed.ok) {
      await supabase.from('payments').update({ status: 'failed' }).eq('id', payment.id)
      return json({ error: `DPO CreateToken failed (${parsed.result}): ${parsed.explanation}` }, 502)
    }

    await supabase.from('payments').update({ dpo_token: parsed.transToken }).eq('id', payment.id)

    return json({
      paymentUrl: `${DPO_PAY_PAGE}${parsed.transToken}`,
      token: parsed.transToken,
      paymentId: payment.id,
    })
  } catch (error) {
    return json({ error: error.message }, 500)
  }
})
