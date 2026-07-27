// ═══════════════════════════════════════════════════════════════
// Shared notify helper for server-side jobs (shared)
//
// Same two-step pipeline as send-notification/index.ts (in-app row
// + FCM push), factored out so the property-lifecycle functions
// (cron and client-invoked) don't each re-implement it.
// ═══════════════════════════════════════════════════════════════
import { sendFcm, type FcmServiceAccount } from './fcm.ts'

// deno-lint-ignore no-explicit-any
type SupabaseClient = any

export interface NotifyParams {
  user_id: string
  type: string
  title: string
  body: string
  target_id?: string
  target_collection?: string
}

export async function notifyUser(supabase: SupabaseClient, params: NotifyParams): Promise<void> {
  const { user_id, type, title, body, target_id, target_collection } = params

  const { error: insertError } = await supabase.from('notifications').insert({
    user_id,
    type,
    title,
    body,
    target_id: target_id ?? null,
    target_collection: target_collection ?? null,
  })
  if (insertError) {
    console.error(`notifyUser: insert failed for ${user_id}:`, insertError.message)
  }

  const saJson = Deno.env.get('FCM_SERVICE_ACCOUNT')
  if (!saJson) return

  const { data: user } = await supabase
    .from('users')
    .select('fcm_token, notifications_enabled')
    .eq('id', user_id)
    .maybeSingle()

  if (!user?.fcm_token || user.notifications_enabled === false) return

  const sa = JSON.parse(saJson) as FcmServiceAccount
  const result = await sendFcm(sa, { token: user.fcm_token, title, body, data: { type } })

  if (result === 'unregistered') {
    await supabase.from('users').update({
      fcm_token: null,
      last_token_update: new Date().toISOString(),
    }).eq('id', user_id)
  }
}
