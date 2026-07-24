# FCM Push Notification Setup — DalaliApp

Firebase Cloud Messaging covers the **app-closed** case; the in-app stack (Supabase Realtime + `flutter_local_notifications`) is unchanged. Sending is server-side only via the `send-notification` edge function.

## Architecture

```
trigger (DPO settlement, send-notification callers)
      │
      ▼
send-notification edge function ──► notifications row (Realtime badge, in-app)
      │  (x-admin-secret)
      ▼
_shared/fcm.ts ── OAuth2 (service account JWT) ──► FCM HTTP v1 ──► device
      ▼
FcmService (app): token → users.fcm_token · fg → local notification · tap → navigate
```

## Firebase console (one-time)

1. Project `dalali-83f65` (reused from the app's earlier Firebase setup).
2. **Android app**: package `dalali.tz` → `google-services.json` → `android/app/google-services.json` (reference only — the app initializes with manual options from `lib/config/firebase_options.dart`, so no Gradle plugin is required).
3. **iOS app**: bundle ID `dalali` → `GoogleService-Info.plist` → `ios/Runner/` (checked in).
4. **APNs auth key**: Apple Developer → Keys → APNs key (.p8) → Firebase console → Cloud Messaging → iOS app → upload (required for iOS delivery; Android works without it).
5. **Service account**: Project settings → Service accounts → Generate new private key → keep safe, never commit.

## Android configuration

- `POST_NOTIFICATIONS` is declared and requested at runtime (done earlier).
- Foreground messages render through the existing `dalali_channel` (`NotificationService`).
- Tap navigation routes by `data.target_collection` / `data.target_id` (`FcmService._openFromMessage`): `properties` → listing, `payments` → receipt, `conversations` → messages.

## iOS configuration

- `ios/Runner/Runner.entitlements` with `aps-environment=development` (switch to `production` for release), wired via `CODE_SIGN_ENTITLEMENTS` in `project.pbxproj`.
- `Info.plist` has `UIBackgroundModes = [remote-notification]`.
- In Xcode, confirm the **Push Notifications** capability shows for the Runner target (the entitlements file provides it); push works only on a **physical device**, not the simulator.

## Supabase configuration

- Migration `024_fcm_tokens.sql`: `users.fcm_token`, `device_platform`, `notifications_enabled`, `last_token_update`. Tokens sync on login/refresh and clear on logout (`FcmService`).
- Dead tokens (`UNREGISTERED`) are cleared automatically by `send-notification`.

## Edge function deployment

```bash
supabase db push                                   # migration 024
supabase functions deploy send-notification
supabase secrets set FCM_SERVICE_ACCOUNT='<full service-account JSON>'
supabase secrets set ADMIN_API_SECRET='<existing>' # gates send-notification
```

Callers (e.g. `_shared/dpo_settlement.ts`) POST `{user_id, title, body, type, target_collection, target_id}` with `x-admin-secret`. The function inserts the in-app row and pushes in one call; `fcm: not_configured` in the response means the secret is missing.

## Testing

- **Android foreground**: run the app → trigger a payment (sandbox) → local banner appears.
- **Android background/killed**: same trigger → system notification → tap → receipt screen.
- **iOS**: physical device, accept the permission prompt; same checks (needs the APNs key uploaded).
- **Tap navigation**: property/payment/chat pushes open the right screen.
- **Token lifecycle**: login → `users.fcm_token` set; logout → cleared; delete/reinstall app → old token cleared server-side on first failed send.
- **Console test**: Firebase console → Cloud Messaging → "Send test message" with the device token from `users.fcm_token`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `fcm: no_token` in response | App hasn't synced a token yet — log in on the device after deploy, or reinstall |
| iOS silent, Android fine | APNs key missing/wrong; simulator (use a device); entitlements not applied (clean build folder) |
| `UNREGISTERED` repeatedly | Token rotated — app re-syncs on next launch; rows self-heal (cleared) |
| 401 from send-notification | Wrong/missing `x-admin-secret` header |
| `not_configured` | `FCM_SERVICE_ACCOUNT` secret not set on the project |
| Android build error re google-services | The app uses manual `FirebaseOptions`; delete `android/app/google-services.json` if a plugin was added by mistake |
