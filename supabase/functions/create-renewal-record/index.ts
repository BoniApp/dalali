/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: create-renewal-record
/// ═══════════════════════════════════════════════════════════════
///
/// Landlord-confirmed renewal. Creates a NEW tenancies row for the
/// next lease term (back-linked via renewed_from_tenancy_id) instead
/// of mutating the closed one — reuses setup_new_tenancy() (020) for
/// rent-schedule seeding, and keeps the terminal-state guard on the
/// original tenancy intact. The property stays occupied throughout
/// (no vacancy — this is a rollover, not a move-out).
///
/// Invocation:
///   POST /functions/v1/create-renewal-record
///   Headers: Authorization: Bearer <landlord's JWT>
///   Body: { tenancy_id, new_rent_amount?, new_deposit_amount?, lease_days? }
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { notifyUser } from '../_shared/notify.ts'

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

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const callerClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user: caller } } = await callerClient.auth.getUser()
    if (!caller) return json({ error: 'Unauthorized' }, 401)

    const { tenancy_id, new_rent_amount, new_deposit_amount, lease_days } = await req.json()
    if (!tenancy_id) return json({ error: 'tenancy_id is required' }, 400)

    const supabase = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '')

    const { data: source } = await supabase.from('tenancies').select('*').eq('id', tenancy_id).maybeSingle()
    if (!source) return json({ error: 'Tenancy not found' }, 404)
    if (source.landlord_id !== caller.id) return json({ error: 'Only the landlord can confirm a renewal' }, 403)
    if (source.status !== 'active') return json({ error: 'Only an active tenancy can be renewed' }, 409)

    const termDays = Number(lease_days) > 0 ? Number(lease_days) : 365
    const moveIn = new Date()
    const moveOut = new Date(moveIn.getTime() + termDays * 24 * 60 * 60 * 1000)

    const { data: renewed, error: insertError } = await supabase
      .from('tenancies')
      .insert({
        property_id: source.property_id,
        property_title: source.property_title,
        property_location: source.property_location,
        tenant_id: source.tenant_id,
        tenant_name: source.tenant_name,
        landlord_id: source.landlord_id,
        landlord_name: source.landlord_name,
        move_in_date: moveIn.toISOString(),
        expected_move_out_date: moveOut.toISOString(),
        rent_amount: new_rent_amount ?? source.rent_amount,
        deposit_amount: new_deposit_amount ?? source.deposit_amount,
        status: 'upcoming',
        renewed_from_tenancy_id: source.id,
      })
      .select()
      .single()
    if (insertError) throw insertError

    // Order matters: closing the old tenancy's handle_tenancy_status_change
    // trigger parks the property at 'unlisted'; activating the new one
    // re-occupies it. Doing this in the other order would leave the
    // property stuck at 'unlisted' even though a tenant is still in
    // place, because the LAST trigger to fire wins.
    const { error: closeError } = await supabase
      .from('tenancies')
      .update({ status: 'renewed' })
      .eq('id', source.id)
    if (closeError) throw closeError

    const { error: activateError } = await supabase
      .from('tenancies')
      .update({ status: 'active' })
      .eq('id', renewed.id)
    if (activateError) throw activateError

    // handle_tenancy_status_change already set status='occupied';
    // listing_status is a finer-grained field it doesn't touch.
    await supabase.from('properties').update({ listing_status: 'tenancyConfirmed' }).eq('id', source.property_id)

    await notifyUser(supabase, {
      user_id: source.tenant_id,
      type: 'system',
      title: 'Tenancy Renewed',
      body: `Your tenancy for ${source.property_title} has been renewed.`,
      target_id: renewed.id,
      target_collection: 'tenancies',
    })

    return json({ success: true, tenancy_id: renewed.id })
  } catch (error) {
    console.error('create-renewal-record error:', error)
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
})
