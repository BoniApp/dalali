/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: process-tenancy-expiry
/// ═══════════════════════════════════════════════════════════════
///
/// Scheduled job (CRON_SECRET-gated, same shape as
/// scheduled-settlement). Finds active tenancies past their move-out
/// date (planned_move_out_date if notice was given, otherwise
/// expected_move_out_date) that the landlord hasn't already closed
/// via "Mark Tenancy Complete", and closes the lifecycle server-side:
///   - tenancies.status -> completed
///   - properties.status -> unlisted (trg_tenancy_status_change, 019/021)
///   - properties.listing_status -> inspection
///   - a scheduled inspections row is created so it surfaces as a
///     landlord task
/// Both parties are notified.
///
/// Invocation: POST /functions/v1/process-tenancy-expiry
/// Headers: Authorization: Bearer <CRON_SECRET>
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { notifyUser } from '../_shared/notify.ts'

serve(async (req) => {
  const cronSecret = Deno.env.get('CRON_SECRET')
  const authHeader = req.headers.get('Authorization')
  if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const now = new Date().toISOString()

    const { data: tenancies, error } = await supabase
      .from('tenancies')
      .select('*')
      .eq('status', 'active')
      .or(`expected_move_out_date.lte.${now},planned_move_out_date.lte.${now}`)
      .limit(200)

    if (error) throw error

    let processed = 0
    for (const t of tenancies || []) {
      const endDate = t.planned_move_out_date ?? t.expected_move_out_date
      if (new Date(endDate).getTime() > Date.now()) continue

      const { error: updateError } = await supabase
        .from('tenancies')
        .update({ status: 'completed' })
        .eq('id', t.id)
        .eq('status', 'active') // guard against a concurrent manual completion
      if (updateError) {
        console.error(`process-tenancy-expiry: update failed for ${t.id}:`, updateError.message)
        continue
      }

      await supabase.from('properties').update({ listing_status: 'inspection' }).eq('id', t.property_id)

      await supabase.from('inspections').insert({
        property_id: t.property_id,
        tenancy_id: t.id,
        landlord_id: t.landlord_id,
        status: 'scheduled',
      })

      await notifyUser(supabase, {
        user_id: t.tenant_id,
        type: 'system',
        title: 'Tenancy Ended',
        body: `Your tenancy for ${t.property_title} has ended.`,
        target_id: t.id,
        target_collection: 'tenancies',
      })
      await notifyUser(supabase, {
        user_id: t.landlord_id,
        type: 'inspectionScheduled',
        title: 'Move-Out Inspection Needed',
        body: `The tenancy at ${t.property_title} has ended. Schedule the move-out inspection.`,
        target_id: t.id,
        target_collection: 'tenancies',
      })

      processed++
    }

    return new Response(JSON.stringify({ processed }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('process-tenancy-expiry error:', err)
    return new Response(JSON.stringify({ error: err instanceof Error ? err.message : String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
