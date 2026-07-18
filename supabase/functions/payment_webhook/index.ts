// Supabase Edge Function: Payment Webhook Handler (stub)
// Deploy this to your Supabase project under `supabase/functions/payment_webhook`
// This handler accepts POST callbacks from payment gateways and updates the
// `transactions` row in Supabase. Implement provider-specific verification
// (HMAC signatures, timestamps) according to the gateway docs.

import { serve } from 'std/server'

serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })

    // Read body
    const body = await req.text()

    // Parse JSON payload
    const payload = JSON.parse(body)

    // Determine tx id and provider
    const txId = payload.transaction_id || payload.reference || payload.id
    const provider = (payload.provider || req.headers.get('x-provider') || '').toString().toLowerCase()
    const status = (payload.status || payload.state || 'pending').toString().toLowerCase()

    // Provider-specific verification: Selcom example
    if (provider === 'selcom' || req.headers.get('x-provider') === 'selcom') {
      // Fetch gateway config from payment_gateways table
      const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
      const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
      if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
        return new Response('Server misconfigured', { status: 500 })
      }

      try {
        const gwRes = await fetch(`${SUPABASE_URL}/rest/v1/payment_gateways?provider_name=eq.selcom&select=config`, {
          headers: { 'apikey': SUPABASE_SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
        })
        if (!gwRes.ok) {
          console.warn('Failed to fetch gateway config', await gwRes.text())
        } else {
          const gwRows = await gwRes.json()
          const cfg = (gwRows && gwRows[0] && gwRows[0].config) ? gwRows[0].config : null
          const secret = cfg?.api_secret || cfg?.secret || null
          const signatureHeader = req.headers.get('x-selcom-signature') || req.headers.get('x-signature')
          if (secret && signatureHeader) {
            const { computeHmacHex } = await import('./_shared/hmac.ts')
            const sigHex = await computeHmacHex(secret, body)
            if (sigHex !== signatureHeader) {
              return new Response('Invalid signature', { status: 401 })
            }
          }
        }
      } catch (e) {
        console.warn('Selcom verification error', e)
      }
    }

    // M-Pesa / Vodacom placeholder verification
    if (provider === 'mpesa' || provider === 'm-pesa' || req.headers.get('x-provider') === 'mpesa' || req.headers.get('x-provider') === 'm-pesa') {
      // M-Pesa typically signs callbacks differently; include placeholder for timestamp/consumerKey verification
      // TODO: implement M-Pesa STK/C2B verification per provider docs
      console.log('Received M-Pesa callback; signature verification placeholder');
    }

    // Airtel Money placeholder verification
    if (provider === 'airtel' || req.headers.get('x-provider') === 'airtel') {
      // Airtel callback verification placeholder
      console.log('Received Airtel callback; verification placeholder');
    }

    // Map provider statuses to our normalized states
    const normalized = status === 'success' || status === 'completed' ? 'success' : status === 'failed' ? 'failed' : 'pending'

    // Update transaction in Supabase using REST (edge function has ADMIN key via env)
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response('Server misconfigured', { status: 500 })
    }

    // Update via PostgREST
    const res = await fetch(`${SUPABASE_URL}/rest/v1/transactions?id=eq.${encodeURIComponent(txId)}`, {
      method: 'PATCH',
      headers: {
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ status: normalized, updated_at: new Date().toISOString() }),
    })

    if (!res.ok) {
      console.error('Failed to update transaction', await res.text())
      return new Response('Update failed', { status: 500 })
    }

    // Optionally log gateway callback to a `gateway_logs` table for auditing
    try {
      await fetch(`${SUPABASE_URL}/rest/v1/gateway_logs`, {
        method: 'POST',
        headers: {
          'apikey': SUPABASE_SERVICE_ROLE_KEY,
          'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ transaction_id: txId, payload: payload, status: normalized, created_at: new Date().toISOString() }),
      })
    } catch (e) {
      console.warn('Failed to write gateway log', e)
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 })
  } catch (e) {
    console.error('Webhook error', e)
    return new Response('Webhook handler error', { status: 500 })
  }
})
