import { assertEquals } from 'https://deno.land/std@0.201.0/testing/asserts.ts'
import { handler } from './index.ts'

Deno.test('process_withdrawal success path', async () => {
  // Arrange: set env
  Deno.env.set('SUPABASE_URL', 'https://example.supabase.co')
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'svc-role')
  Deno.env.set('ADMIN_API_SECRET', 'topsecret')

  // Mock fetch sequence
  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : (input instanceof URL ? input.toString() : (input as Request).url)

    if (url.includes('/rest/v1/withdrawals')) {
      return new Response(JSON.stringify([{ id: 'w1', status: 'pending', user_id: 'u1', amount: 100, provider: 'selcom', phone: '+255700000000' }]), { status: 200 })
    }
    if (url.endsWith('/rpc/wallet_debit')) {
      return new Response(JSON.stringify({ success: true }), { status: 200 })
    }
    if (url.includes('/rest/v1/payment_gateways')) {
      return new Response(JSON.stringify([{ config: { payout_url: 'https://selcom.mock/payout', api_key: 'k', api_secret: 's' }, enabled: true }]), { status: 200 })
    }
    if (url.startsWith('https://selcom.mock/payout')) {
      return new Response(JSON.stringify({ transaction_id: 'tx123' }), { status: 200 })
    }
    if (url.includes('/rest/v1/gateway_logs') || url.includes('/rest/v1/withdrawals?id=eq.')) {
      return new Response(JSON.stringify({}), { status: 200 })
    }

    return new Response('not found', { status: 404 })
  }

  // Act
  const req = new Request('https://fn', { method: 'POST', headers: { 'x-admin-secret': 'topsecret', 'content-type': 'application/json' }, body: JSON.stringify({ withdrawal_id: 'w1' }) })
  const res = await handler(req)

  // Assert
  assertEquals(res.status, 200)
  const body = JSON.parse(await res.text())
  assertEquals(body.ok, true)
  assertEquals(body.provider_tx, 'tx123')

  // Cleanup
  globalThis.fetch = originalFetch
})
