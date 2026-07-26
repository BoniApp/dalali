// Constant-time string comparison for shared-secret checks
// (x-admin-secret / x-commission-secret). A plain `===` short-circuits
// on the first differing byte, leaking a timing signal proportional to
// how many leading characters an attacker guessed correctly; this
// always walks every byte of both inputs regardless of where they
// first differ.
export function timingSafeEqual(a: string, b: string): boolean {
  const bufA = new TextEncoder().encode(a);
  const bufB = new TextEncoder().encode(b);
  const len = Math.max(bufA.length, bufB.length, 1);
  let diff = bufA.length ^ bufB.length;
  for (let i = 0; i < len; i++) {
    diff |= (bufA[i] ?? 0) ^ (bufB[i] ?? 0);
  }
  return diff === 0;
}
