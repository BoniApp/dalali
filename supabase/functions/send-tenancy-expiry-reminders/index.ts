/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: send-tenancy-expiry-reminders
/// ═══════════════════════════════════════════════════════════════
///
/// Scheduled job (same CRON_SECRET-gated shape as
/// scheduled-settlement). Finds active tenancies whose lease ends
/// within 60 days (planned_move_out_date if notice was given,
/// otherwise expected_move_out_date) and reminds both parties once —
/// expiry_reminder_sent_at makes the scan idempotent across runs.
///
/// Invocation: POST /functions/v1/send-tenancy-expiry-reminders
/// Headers: Authorization: Bearer <CRON_SECRET>
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { notifyUser } from '../_shared/notify.ts'

const REMINDER_WINDOW_DAYS = 60

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

    const cutoff = new Date(Date.now() + REMINDER_WINDOW_DAYS * 24 * 60 * 60 * 1000).toISOString()

    // Whichever end date applies (planned_move_out_date once notice
    // has been given, otherwise expected_move_out_date) may trigger
    // the reminder, so both columns are checked.
    const { data: tenancies, error } = await supabase
      .from('tenancies')
      .select('*')
      .eq('status', 'active')
      .is('expiry_reminder_sent_at', null)
      .or(`expected_move_out_date.lte.${cutoff},planned_move_out_date.lte.${cutoff}`)
      .limit(200)

    if (error) throw error

    let reminded = 0
    for (const t of tenancies || []) {
      const body = `Your tenancy for ${t.property_title} expires in about ${REMINDER_WINDOW_DAYS} days. Renew or submit a move-out notice.`
      await notifyUser(supabase, {
        user_id: t.tenant_id,
        type: 'tenancyExpiring',
        title: 'Tenancy Expiring Soon',
        body,
        target_id: t.id,
        target_collection: 'tenancies',
      })
      await notifyUser(supabase, {
        user_id: t.landlord_id,
        type: 'tenancyExpiring',
        title: 'Tenancy Expiring Soon',
        body: `Your property "${t.property_title}" tenancy expires soon.`,
        target_id: t.id,
        target_collection: 'tenancies',
      })
      if (t.agent_id) {
        await notifyUser(supabase, {
          user_id: t.agent_id,
          type: 'tenancyExpiring',
          title: 'Managed Property Needs Attention',
          body: `The tenancy at ${t.property_title} expires soon.`,
          target_id: t.id,
          target_collection: 'tenancies',
        })
      }

      await supabase.from('tenancies').update({
        expiry_reminder_sent_at: new Date().toISOString(),
      }).eq('id', t.id)

      reminded++
    }

    return new Response(JSON.stringify({ reminded }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('send-tenancy-expiry-reminders error:', err)
    return new Response(JSON.stringify({ error: err instanceof Error ? err.message : String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
