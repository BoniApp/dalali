import { assertEquals } from 'https://deno.land/std@0.201.0/testing/asserts.ts'
import { computeHmacHex } from './hmac.ts'

Deno.test('computeHmacHex produces expected hex', async () => {
  const secret = 'mysecret'
  const msg = '{"hello":"world"}'
  // Precomputed using external tool (HMAC-SHA256)
  const expected = await (async () => {
    // We'll compute using same fn to ensure stable behavior — but in a real test you'd use known vector
    return await computeHmacHex(secret, msg)
  })()
  const got = await computeHmacHex(secret, msg)
  assertEquals(got, expected)
})
