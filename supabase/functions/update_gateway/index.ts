// Supabase Edge Function: Update Gateway Config (secure)
// Requires header 'x-admin-secret' matching ADMIN_API_SECRET env var.
// Deploy to Supabase functions and set ADMIN_API_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY env vars.

import { serve } from 'std/server'

serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })

    const adminSecret = Deno.env.get('ADMIN_API_SECRET')
    const provided = req.headers.get('x-admin-secret')
    if (!adminSecret || provided !== adminSecret) return new Response('Unauthorized', { status: 401 })

    const body = await req.json()
    const id = body.id
    if (!id) return new Response('Missing gateway id', { status: 400 })

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return new Response('Server misconfigured', { status: 500 })

    const payload = { ...body }
    delete payload.id

    const res = await fetch(`${SUPABASE_URL}/rest/v1/payment_gateways?id=eq.${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: {
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    })

    if (!res.ok) {
      console.error('Failed to update gateway', await res.text())
      return new Response('Update failed', { status: 500 })
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 })
  } catch (e) {
    console.error('Update gateway error', e)
    return new Response('Server error', { status: 500 })
  }
})
