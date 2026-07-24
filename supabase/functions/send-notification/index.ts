/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: send-notification
/// ═══════════════════════════════════════════════════════════════
///
/// Single server-side pipeline for user notifications:
///   1. inserts the in-app `notifications` row (Realtime badge), and
///   2. pushes to the user's device via FCM HTTP v1 (app-closed case).
///
/// Server-to-server only — gated by x-admin-secret (ADMIN_API_SECRET),
/// like process-withdrawal. The FCM service account lives in the
/// FCM_SERVICE_ACCOUNT secret; the FCM v1 client is in _shared/fcm.ts.
///
///   POST /functions/v1/send-notification
///   Headers: x-admin-secret: <ADMIN_API_SECRET>
///   Body: { user_id, title, body, type?, target_collection?, target_id? }
///   → { ok, fcm: 'sent' | 'no_token' | 'unregistered' | 'failed' }
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { sendFcm, type FcmServiceAccount } from '../_shared/fcm.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-admin-secret',
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
    const adminSecret = Deno.env.get('ADMIN_API_SECRET')
    if (!adminSecret || req.headers.get('x-admin-secret') !== adminSecret) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const { user_id, title, body, type, target_collection, target_id } = await req.json()
    if (!user_id || !title || !body) {
      return json({ error: 'user_id, title and body are required' }, 400)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // ─── 1. In-app notification row (Realtime badge) ───────────
    const { error: insertError } = await supabase.from('notifications').insert({
      user_id,
      type: type ?? 'system',
      title,
      body,
      target_id: target_id ?? null,
      target_collection: target_collection ?? null,
    })
    if (insertError) return json({ error: insertError.message }, 500)

    // ─── 2. Push via FCM ───────────────────────────────────────
    const saJson = Deno.env.get('FCM_SERVICE_ACCOUNT')
    if (!saJson) {
      return json({ ok: true, fcm: 'not_configured' })
    }

    const { data: user } = await supabase
      .from('users')
      .select('fcm_token, notifications_enabled')
      .eq('id', user_id)
      .maybeSingle()

    if (!user?.fcm_token || user.notifications_enabled === false) {
      return json({ ok: true, fcm: 'no_token' })
    }

    const sa = JSON.parse(saJson) as FcmServiceAccount
    const result = await sendFcm(sa, {
      token: user.fcm_token,
      title,
      body,
      data: {
        type: type ?? 'system',
        ...(target_collection ? { target_collection } : {}),
        ...(target_id ? { target_id } : {}),
      },
    })

    // Dead token → clear it so we stop trying this device.
    if (result === 'unregistered') {
      await supabase.from('users').update({
        fcm_token: null,
        last_token_update: new Date().toISOString(),
      }).eq('id', user_id)
    }

    return json({ ok: true, fcm: result })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
})
