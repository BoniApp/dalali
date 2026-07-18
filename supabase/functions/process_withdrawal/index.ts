// Supabase Edge Function: Process Withdrawal (payout)
// Flow:
// - Verify admin via x-admin-secret
// - Fetch withdrawal record
// - Call RPC wallet_debit to atomically debit user wallet
// - Initiate payout via provider (Selcom placeholder)
// - Update withdrawal status and log

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { computeHmacHex } from '../_shared/hmac.ts'

export async function handler(req: Request): Promise<Response> {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })

    const adminSecret = Deno.env.get('ADMIN_API_SECRET')
    const provided = req.headers.get('x-admin-secret')
    if (!adminSecret && !req.headers.get('authorization')) return new Response('Unauthorized', { status: 401 })

    const body = await req.json()
    const withdrawalId = body.withdrawal_id || body.id
    if (!withdrawalId) return new Response('Missing withdrawal id', { status: 400 })

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return new Response('Server misconfigured', { status: 500 })

    // If admin secret not provided, verify Authorization token belongs to an admin user
    if (provided !== adminSecret) {
      const authHeader = req.headers.get('authorization')
      if (!authHeader) return new Response('Unauthorized', { status: 401 })
      // Validate token by asking Supabase auth endpoint for the user
      const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { authorization: authHeader } })
      if (!userRes.ok) return new Response('Invalid token', { status: 401 })
      const user = await userRes.json()
      // Check users table for is_admin flag via service role
      const uid = user.id
      const checkRes = await fetch(`${SUPABASE_URL}/rest/v1/users?id=eq.${uid}&select=is_admin`, {
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      if (!checkRes.ok) return new Response('Forbidden', { status: 403 })
      const rows = await checkRes.json()
      const isAdmin = rows && rows[0] && rows[0].is_admin
      if (!isAdmin) return new Response('Forbidden', { status: 403 })
    }

    // Fetch withdrawal
    const wRes = await fetch(`${SUPABASE_URL}/rest/v1/withdrawals?id=eq.${encodeURIComponent(withdrawalId)}&select=*`, {
      headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
    })
    if (!wRes.ok) return new Response('Withdrawal fetch failed', { status: 500 })
    const wRows = await wRes.json()
    const withdrawal = wRows && wRows[0]
    if (!withdrawal) return new Response('Withdrawal not found', { status: 404 })
    if (withdrawal.status !== 'pending' && withdrawal.status !== 'processing') return new Response('Withdrawal not pending', { status: 400 })

    const userId = withdrawal.user_id
    const amount = withdrawal.amount

    // Call RPC wallet_debit
    const rpcRes = await fetch(`${SUPABASE_URL}/rpc/wallet_debit`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ p_user_id: userId, p_amount: amount }),
    })

    if (!rpcRes.ok) {
      const text = await rpcRes.text()
      console.error('RPC debit failed', text)
      return new Response('Insufficient funds or RPC failed', { status: 400 })
    }

    // Initiate provider payout (Selcom integration)
    // Fetch gateway config
    let payoutResult = { success: false as boolean, provider_tx: '' }
    try {
      const gwRes = await fetch(`${SUPABASE_URL}/rest/v1/payment_gateways?provider_name=eq.${encodeURIComponent(withdrawal.provider || 'selcom')}&select=config,enabled`, {
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      const gwRows = gwRes.ok ? await gwRes.json() : null
      const cfg = gwRows && gwRows[0] && gwRows[0].config ? gwRows[0].config : null

      if (cfg && gwRows[0].enabled) {
        // Example Selcom payout call (placeholder) - configure per Selcom API
        const selcomUrl = cfg.payout_url || cfg.api_base + '/payout'
        const selcomKey = cfg.api_key
        const selcomSecret = cfg.api_secret

        // Build payout payload
        const payoutPayload = { phone: withdrawal.destination?.phone || withdrawal.phone, amount: amount, reference: withdrawalId }

        // Attempt payout with retries
        const maxRetries = 3
        let attempt = 0
        while (attempt < maxRetries) {
          attempt++
          try {
            // Sign payload using HMAC-SHA256 and send signature header
            const payloadText = JSON.stringify(payoutPayload)
            const signature = selcomSecret ? await computeHmacHex(selcomSecret, payloadText) : ''
            const resp = await fetch(selcomUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'x-api-key': selcomKey || '',
                'x-hmac-sha256': signature,
              },
              body: payloadText,
            })
            if (resp.ok) {
              const data = await resp.json()
              payoutResult = { success: true, provider_tx: data.transaction_id || data.id || `selcom-${withdrawalId}` }
              break
            } else {
              const txt = await resp.text()
              console.warn('Selcom payout failed', attempt, txt)
            }
          } catch (e) {
            console.warn('Selcom payout attempt error', attempt, e)
          }
          // exponential backoff
          await new Promise((r) => setTimeout(r, 500 * attempt))
        }
      } else {
        console.warn('No gateway config or gateway disabled; skipping provider payout')
        payoutResult = { success: true, provider_tx: `SKIPPED-${withdrawalId}` }
      }
    } catch (e) {
      console.warn('Payout integration error', e)
    }

    if (!payoutResult.success) {
      // Attempt to credit back the user's wallet to compensate
      try {
        const creditRes = await fetch(`${SUPABASE_URL}/rpc/wallet_credit`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ p_user_id: userId, p_amount: amount }),
        })
        if (!creditRes.ok) {
          const txt = await creditRes.text()
          console.error('Compensation credit failed', txt)
        }
      } catch (e) {
        console.error('Compensation credit error', e)
      }

      // Mark withdrawal failed
      await fetch(`${SUPABASE_URL}/rest/v1/withdrawals?id=eq.${encodeURIComponent(withdrawalId)}`, {
        method: 'PATCH',
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'failed', processed_at: new Date().toISOString() }),
      })
      return new Response('Payout failed', { status: 500 })
    }

    // Update withdrawal to processed
    await fetch(`${SUPABASE_URL}/rest/v1/withdrawals?id=eq.${encodeURIComponent(withdrawalId)}`, {
      method: 'PATCH',
      headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'processed', processed_at: new Date().toISOString(), metadata: { provider_tx: payoutResult.provider_tx } }),
    })

    // Log to gateway_logs
    try {
      await fetch(`${SUPABASE_URL}/rest/v1/gateway_logs`, {
        method: 'POST',
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ transaction_id: withdrawalId, payload: { payout: payoutResult }, status: 'processed', created_at: new Date().toISOString() }),
      })
    } catch (e) {
      console.warn('Failed to write gateway log', e)
    }

    return new Response(JSON.stringify({ ok: true, provider_tx: payoutResult.provider_tx }), { status: 200 })
  } catch (e) {
    console.error('Process withdrawal error', e)
    return new Response('Server error', { status: 500 })
  }
}

// Serve the handler for deployment (skipped when imported by tests)
if (import.meta.main) serve(handler)
