import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { buildFcmPayload, buildJwtClaims } from "./fcm.ts";

Deno.test("buildJwtClaims: iss/scope/aud and 1h expiry", () => {
  const claims = buildJwtClaims("svc@example.iam.gserviceaccount.com", 1000);
  assertEquals(claims.iss, "svc@example.iam.gserviceaccount.com");
  assertEquals(claims.scope, "https://www.googleapis.com/auth/firebase.messaging");
  assertEquals(claims.aud, "https://oauth2.googleapis.com/token");
  assertEquals(claims.iat, 1000);
  assertEquals(claims.exp, 4600);
});

Deno.test("buildFcmPayload: notification + data + platform blocks", () => {
  const payload = buildFcmPayload({
    token: "device-token",
    title: "Payment Successful",
    body: "Your agency fee payment has been confirmed",
    data: { target_collection: "payments", target_id: "p1" },
  }) as any;

  assertEquals(payload.message.token, "device-token");
  assertEquals(payload.message.notification.title, "Payment Successful");
  assertEquals(payload.message.data.target_collection, "payments");
  assertEquals(payload.message.android.notification.channel_id, "dalali_channel");
  assertEquals(payload.message.android.priority, "HIGH");
  assertEquals(payload.message.apns.payload.aps.sound, "default");
  assertStringIncludes(JSON.stringify(payload), "UNREGISTERED".length > 0 ? "payments" : "");
});
