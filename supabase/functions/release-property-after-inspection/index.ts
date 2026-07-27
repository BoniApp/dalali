/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: release-property-after-inspection
/// ═══════════════════════════════════════════════════════════════
///
/// Landlord finalizes a move-out inspection. Marks the inspection
/// completed and routes the property to the next turnover state:
///   damage_cost > 0  -> listing_status = 'maintenanceInProgress'
///   damage_cost == 0 -> listing_status = 'availableAgain'
///
/// Does NOT flip properties.status back to 'available' — matching
/// migration 021's "no auto-relist" rule, the landlord relists
/// explicitly from the dashboard (PropertyState.relistProperty()).
///
/// Invocation:
///   POST /functions/v1/release-property-after-inspection
///   Headers: Authorization: Bearer <landlord's JWT>
///   Body: { inspection_id, condition_after, damage_cost?, notes? }
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

    const { inspection_id, condition_after, damage_cost, notes } = await req.json()
    if (!inspection_id || !condition_after) {
      return json({ error: 'inspection_id and condition_after are required' }, 400)
    }

    const supabase = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '')

    const { data: inspection } = await supabase
      .from('inspections')
      .select('*')
      .eq('id', inspection_id)
      .maybeSingle()
    if (!inspection) return json({ error: 'Inspection not found' }, 404)
    if (inspection.landlord_id !== caller.id) return json({ error: 'Only the landlord can complete this inspection' }, 403)
    if (inspection.status !== 'scheduled') return json({ error: 'Inspection is already completed' }, 409)

    const cost = Number(damage_cost) || 0

    const { error: updateError } = await supabase
      .from('inspections')
      .update({
        status: 'completed',
        condition_after,
        damage_cost: cost,
        notes: notes ?? inspection.notes,
        inspector_id: caller.id,
      })
      .eq('id', inspection_id)
    if (updateError) throw updateError

    const nextStage = cost > 0 ? 'maintenanceInProgress' : 'availableAgain'
    await supabase.from('properties').update({ listing_status: nextStage }).eq('id', inspection.property_id)

    const { data: tenancy } = await supabase
      .from('tenancies')
      .select('tenant_id, property_title')
      .eq('id', inspection.tenancy_id)
      .maybeSingle()

    if (tenancy) {
      await notifyUser(supabase, {
        user_id: tenancy.tenant_id,
        type: 'system',
        title: 'Move-Out Inspection Completed',
        body: cost > 0
          ? `Inspection for ${tenancy.property_title} found damages of TZS ${cost.toFixed(0)}.`
          : `Inspection for ${tenancy.property_title} is complete — no damages found.`,
        target_id: inspection_id,
        target_collection: 'inspections',
      })
    }

    return json({ success: true, listing_status: nextStage })
  } catch (error) {
    console.error('release-property-after-inspection error:', error)
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
})
