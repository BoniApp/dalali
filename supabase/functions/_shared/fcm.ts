// ═══════════════════════════════════════════════════════════════
// FCM HTTP v1 client (shared)
//
// Sends push notifications through Firebase Cloud Messaging's HTTP
// v1 API. Auth is OAuth2 with a service-account JWT bearer
// (RS256, WebCrypto) — the service account JSON lives ONLY in the
// FCM_SERVICE_ACCOUNT secret, never in client code.
// ═══════════════════════════════════════════════════════════════

export interface FcmServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
}

export interface FcmMessage {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

const TOKEN_URI = "https://oauth2.googleapis.com/token";
const SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const der = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) der[i] = bin.charCodeAt(i);
  return der;
}

/// Build the unsigned JWT (header.claims) for the OAuth2 bearer grant.
/// Exported for tests.
export function buildJwtClaims(clientEmail: string, nowSec: number): Record<string, unknown> {
  return {
    iss: clientEmail,
    scope: SCOPE,
    aud: TOKEN_URI,
    iat: nowSec,
    exp: nowSec + 3600,
  };
}

/// Build the FCM v1 message payload. Exported for tests.
export function buildFcmPayload(m: FcmMessage): Record<string, unknown> {
  return {
    message: {
      token: m.token,
      notification: { title: m.title, body: m.body },
      data: m.data ?? {},
      android: {
        priority: "HIGH",
        notification: { channel_id: "dalali_channel", sound: "default" },
      },
      apns: {
        payload: { aps: { sound: "default", "content-available": 1 } },
      },
    },
  };
}

let cachedToken: { value: string; expiresAt: number } | null = null;

/// Mint (and cache) an OAuth2 access token for the service account.
export async function getAccessToken(sa: FcmServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.value;
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify(buildJwtClaims(sa.client_email, nowSec)));
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key).buffer as ArrayBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)),
  );
  const jwt = `${unsigned}.${b64url(signature)}`;

  const res = await fetch(sa.token_uri ?? TOKEN_URI, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`OAuth token exchange failed: ${JSON.stringify(data)}`);

  cachedToken = {
    value: data.access_token,
    expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
  };
  return cachedToken.value;
}

export type FcmSendResult = "sent" | "unregistered" | "failed";

/// Send one push. 'unregistered' means the device token is dead and
/// should be cleared from the user's profile.
export async function sendFcm(
  sa: FcmServiceAccount,
  message: FcmMessage,
): Promise<FcmSendResult> {
  const accessToken = await getAccessToken(sa);
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(buildFcmPayload(message)),
    },
  );
  if (res.ok) return "sent";
  const err = await res.text();
  if (err.includes("UNREGISTERED") || err.includes("INVALID_ARGUMENT")) {
    return "unregistered";
  }
  console.error("FCM send failed:", res.status, err);
  return "failed";
}
