import { assertEquals } from 'https://deno.land/std@0.201.0/testing/asserts.ts'
import { handler } from './index.ts'

Deno.test('process-withdrawal: manual payout success path', async () => {
  Deno.env.set('SUPABASE_URL', 'https://example.supabase.co')
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'svc-role')
  Deno.env.set('ADMIN_API_SECRET', 'topsecret')

  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : (input instanceof URL ? input.toString() : (input as Request).url)
    const method = init?.method ?? 'GET'

    if (url.includes('/rest/v1/withdrawals') && method === 'GET') {
      return new Response(JSON.stringify([{ id: 'w1', status: 'pending', user_id: 'u1', amount: 100, currency: 'TZS', phone: '+255700000000' }]), { status: 200 })
    }
    if (url.includes('/rest/v1/wallets') && method === 'GET') {
      return new Response(JSON.stringify([{ user_id: 'u1', available_balance: 1000, total_withdrawn: 0 }]), { status: 200 })
    }
    if (url.endsWith('/rpc/wallet_debit')) {
      return new Response(JSON.stringify({}), { status: 200 })
    }
    if (url.includes('/rest/v1/wallets') || url.includes('/rest/v1/withdrawals') || url.includes('/rest/v1/notifications')) {
      return new Response(JSON.stringify({}), { status: 200 })
    }
    return new Response('not found', { status: 404 })
  }

  try {
    const req = new Request('https://fn', {
      method: 'POST',
      headers: { 'x-admin-secret': 'topsecret', 'content-type': 'application/json' },
      body: JSON.stringify({ withdrawal_id: 'w1' }),
    })
    const res = await handler(req)

    assertEquals(res.status, 200)
    const body = JSON.parse(await res.text())
    assertEquals(body.ok, true)
    assertEquals(body.provider_tx, 'MANUAL-w1')
  } finally {
    globalThis.fetch = originalFetch
  }
})
