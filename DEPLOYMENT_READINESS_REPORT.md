# DalaliApp — Deployment Readiness Report

**Audit date:** 2026-07-29 · **Auditor:** senior cross-discipline review (Flutter, Supabase, Firebase, stores, security, QA, DevOps, UI/UX, product)
**Scope:** every migration (001–034), all 19 Edge Functions + `_shared/`, full `lib/` tree, Android/iOS/Web platform config, CI, dependencies. `flutter analyze`, `flutter test`, and `flutter pub outdated` were executed; every finding below cites the file and line it was verified against.
**Not verifiable from the repo** (must be checked in the Supabase/Firebase/Store dashboards): live storage-bucket policies (migration 005 is a manual-steps document), auth Site URL + redirect URLs, email templates, secrets actually set (`DPO_COMPANY_TOKEN`, `DPO_SERVICE_TYPE`, `ADMIN_API_SECRET`, `CRON_SECRET`, `COMMISSION_SECRET`, `FCM_SERVICE_ACCOUNT`), backups/PITR, DPO production vs test mode, App Store / Play Console listing content. The end-to-end flows below were traced through code, not executed against the live backend with real money.

---

## 1. Executive Summary

The **application code is in good shape**: `flutter analyze` reports zero issues, all 84 unit/widget tests pass, localization files are perfectly in sync (272/272 keys), the DPO settlement path is idempotent and transactional (migration 027), KYC has no self-serve auto-verify path, and secrets hygiene in the repo is clean (no service-role key, keystore and `key.properties` untracked and gitignored).

However, the app is **not production-ready**. The audit found **six launch-blocking issues**, including one critical privilege-escalation vulnerability (any user can make themselves an admin with a single API call), a broken account-deletion path for any user with listings (both stores reject for this), a missing iOS privacy manifest (hard App Store upload rejection), a settlement job that is never invoked (agent/influencer money never becomes withdrawable), a payment deep-link scheme registered nowhere in native config (users are stranded in the browser after paying), and three legacy database tables exposed to the public with no RLS.

Most blockers are small, well-understood fixes (one migration, one plist, one manifest edit, one cron row). With the critical and high issues resolved and an on-device verification pass, this app can reach a confident launch state quickly.

## 2. Overall Readiness Score

## **58 / 100 — NO-GO until Section 3 is cleared**

| Area | Score | Area | Score |
|---|---|---|---|
| Flutter code quality | 85 | Payments (DPO) | 65 |
| Dependencies | 75 | Property module | 75 |
| Firebase / FCM | 55 | Messaging | 60 |
| Supabase / Database | 60 | Notifications | 70 |
| Authentication | 55 | Security | **40** |
| Offline behavior | 20 | Admin | 70 |
| Performance | 65 | Play Store readiness | 55 |
| UI/UX | 65 | App Store readiness | **35** |
| Legal / compliance | 60 | Code quality / architecture | 80 |

## 3. Critical Blockers (must fix before any store submission)

### C1 — Any user can self-promote to admin (privilege escalation)
The `users` table has an "update own profile" policy with no column restriction (`supabase/migrations/031_initial_schema.sql:46-47`). The tamper trigger `prevent_user_verification_tamper` (`018_protect_verification_status.sql:13-43`) shields `verification_status` and the verification badges, and 026 shields `role` — **but `is_admin` (and `admin_role`) are protected by nothing**. Verified: no migration contains a trigger referencing `is_admin`.

Exploit (any logged-in user, via the public anon key):
```sql
update users set is_admin = true where id = auth.uid();
```
Impact: read every wallet/transaction/withdrawal/user, pass every `is_admin` RLS check, and — worst — call `process-withdrawal` with an **admin JWT** (accepted at `supabase/functions/process-withdrawal/index.ts:42-47`) and approve arbitrary payouts. This is the single most severe finding of the audit.
**Fix:** migration 035 in Section 16 (extend the existing tamper trigger to `is_admin`/`admin_role`).

### C2 — Account deletion fails for landlords, agents, and anyone with disputes
`delete-account` (`supabase/functions/delete-account/index.ts`) de-links `transactions` then calls `auth.admin.deleteUser`, but several FKs to `users(id)` were created **without `ON DELETE`** (default `NO ACTION`):
- `properties.listing_creator_id` — `supabase/migrations/010_architecture_upgrade_and_kyc.sql:395`
- `inquiries.landlord_id` — `supabase/migrations/008_add_landlord_id_to_inquiries.sql:4`
- `fraud_reports.reporter_id` / `resolved_by` — `supabase/migrations/003_wallet_system.sql:112`
- `disputes.reporter_id` / `respondent_id` — `supabase/migrations/003_wallet_system.sql:137-138`

For any such user, `deleteUser` raises an FK violation → 500 → the account cannot be deleted. Apple (5.1.1(v)) and Google Play both **require working account deletion**; GDPR erasure depends on it too.
**Fix:** migration 036 in Section 16 (re-create FKs `ON DELETE SET NULL`/`CASCADE`) + extend `delete-account` to handle creator-owned listings.

### C3 — iOS privacy manifest missing (`PrivacyInfo.xcprivacy`)
`find ios -name PrivacyInfo.xcprivacy` → none. The app and its plugins use required-reason APIs (`shared_preferences` → UserDefaults; `path_provider`/image handling → file timestamps; `flutter_local_notifications`). App Store Connect **rejects uploads** that use these APIs without declared reasons. This is a hard submission blocker.
**Fix:** add `ios/Runner/PrivacyInfo.xcprivacy` (Section 16) and confirm plugin-level manifests at build time.

### C4 — `scheduled-settlement` is never invoked — earnings never become withdrawable
Settlement moves agent/influencer balances `pending → available` after the 48 h hold. But `033_cron_tenancy_jobs.sql:68-78` schedules **only** `process-tenancy-expiry` and `send-tenancy-expiry-reminders`; nothing schedules `scheduled-settlement`, and it is absent from `supabase/config.toml`. Additionally its secret check is a no-op when `CRON_SECRET` is unset (`supabase/functions/scheduled-settlement/index.ts:6-10`). Net effect in production: **every commission stays `pending` forever; every withdrawal fails with "Insufficient balance."**
**Fix:** schedule it via `invoke_edge_function`, add `verify_jwt = false` to `config.toml`, and make `CRON_SECRET` mandatory (Section 16).

### C5 — `dalali://` deep-link scheme registered nowhere → payment return dead-ends
`dpo-callback` redirects the customer's browser to `dalali://payment-success|pending|failed` (`supabase/functions/dpo-callback/index.ts:23-24,45-47`) and the app handles those links (`lib/services/deep_link_service.dart:85-97`) — but the scheme is declared in **neither** `android/app/src/main/AndroidManifest.xml` (only `https://dalaliapp.com/ref`) **nor** `ios/Runner/Info.plist` (no `CFBundleURLTypes`). After paying, the user lands on a dead browser page. The in-app verify poll saves the payment itself, but the launch-day UX is broken precisely at the money moment.
**Fix:** register the `dalali` scheme on both platforms (Section 16).

### C6 — Three legacy tables exposed with no RLS
`commissions`, `gateway_logs`, `refunds` were created in `supabase/migrations/001_create_payment_tables.sql:35-74` and no migration enables RLS or adds policies (`payment_gateways` was dropped by 022:108; these three remain). On Supabase, public-schema tables without RLS are **fully readable/writable by anyone holding the public anon key**. No code uses them (Selcom-era leftovers) — so lock them down or drop them.
**Fix:** migration in Section 16 (RLS `USING (false)` or `DROP TABLE`).

## 4. High-Priority Issues

- **H1 — Withdrawal double-spend path** (`supabase/functions/process-withdrawal/index.ts:54-91`): the `status='pending'` check is a non-atomic read, the post-debit `UPDATE … status='completed'` is **not error-checked**, and there is no status transition guard. A crash/retry between debit and update (or two concurrent admin clicks) debits the wallet twice. Fix: atomically claim the row (`UPDATE … WHERE status='pending' RETURNING`) before debiting; check every error (Section 16).
- **H2 — FCM token is never actually cleared on logout** (`lib/services/fcm_service.dart:53,90-92`): `_clearToken()` reads `SupabaseService.currentUserId` **after** the `signedOut` event, when it is already `null`, so it returns early. A signed-out device keeps receiving the previous user's push notifications (privacy issue on shared devices; also true after account deletion). Fix: clear the token *before* calling `signOut()` (Section 16).
- **H3 — Settlement never validates the paid amount/currency**: `parseVerifyTokenResponse` parses `amount`/`currency` (`supabase/functions/_shared/dpo.ts:117-127`) but `verifyAndSettle` never compares them to the `payments` row (`supabase/functions/_shared/dpo_settlement.ts:76-103`). A transaction settled for the wrong amount/currency still unlocks access and writes a full-amount ledger row. Fix: two `if`s in Section 16.
- **H4 — `properties` storage bucket policies exist only as manual dashboard steps** (`supabase/migrations/005_storage_buckets.sql:27-69`), and the documented INSERT policy is `auth.uid() IS NOT NULL` **with no folder scoping** — any authenticated user can upload into any property's folder (storage abuse/orphan injection). It is also unverifiable config drift. Fix: script owner-scoped policies in SQL like 014 did for avatars (Section 16).
- **H5 — Migrations cannot rebuild the schema on a fresh project**: `001` creates `wallets`/`transactions` with `text` ids and a `balance` column; `003` re-creates them `IF NOT EXISTS` with the real (uuid, available/pending/locked) schema — so on a fresh `supabase db push`, 001 wins and the live-schema RPCs of 027 break. Disaster recovery / new-environment deploys are broken. Fix: align 001's definitions with 003 (or strip the duplicate CREATEs) in a repair migration.
- **H6 — iOS build config is release-risky**: `IPHONEOS_DEPLOYMENT_TARGET = 12.0` (`ios/Runner.xcodeproj/project.pbxproj`) while `firebase_core` 4.x / `firebase_messaging` 16.x pods require a much newer minimum (build will fail or has never been run — there is **no `ios/Podfile`/`Podfile.lock`** in the repo, strong evidence an iOS build has never been completed); `Runner.entitlements` pins `aps-environment = development` (push notifications point at the APNs sandbox). Fix: raise the deployment target, run `flutter build ios`, and set the APNs environment for release (Section 16).
- **H7 — Dead session keeps the app logged in** (`lib/providers/user_state.dart:38-64`): the auth listener only handles `user != null`. If Supabase signs the user out server-side (refresh-token revocation/expiry), `currentUser` stays set and `AuthWrapper` keeps routing to `MainNavigation` (`lib/main.dart:170`) with a dead session — every query then fails. Fix: clear state on the null-user branch (Section 16).

## 5. Medium Issues

- **M1** No release hardening on Android: `minifyEnabled`/`shrinkResources` unset in `android/app/build.gradle:49-56` (larger AAB, no obfuscation). CI (`.github/workflows/build.yml:71`) builds only a **debug APK** — no release AAB pipeline.
- **M2** **Zero offline handling**: no connectivity checks anywhere in `lib/` (only legal text matches "offline"); network loss ⇒ unhandled exceptions / infinite spinners. No retry or cache fallback.
- **M3** **No crash reporting or analytics**: `firebase_crashlytics`/`firebase_analytics` are not in `pubspec.yaml` — you will be blind to production crashes on launch day.
- **M4** **Google Sign-In and Apple Sign-In do not exist** (no packages, no `signInWithOAuth`, nothing in `lib/screens/auth/`) despite being in the stated stack. Email-only auth is store-compliant (Sign in with Apple is only mandatory *if* other social logins are offered), but the feature gap is real. Password reset (`lib/services/auth_service.dart:82-84`) passes no `redirectTo`, and there is no in-app "set new password" deep-link flow — reset lands the user on a web page.
- **M5** Dead code: `AuthService.submitVerification` (writes `verification_status` client-side — would be **rejected by the 018 trigger** if called; zero callers), `AuthService.updatePhoneVerification` (zero callers), `lib/services/mock_data_service.dart` (unreferenced).
- **M6** Money RPCs are executable by any authenticated user (no `REVOKE`): `wallet_credit`, `wallet_debit`, `wallet_credit_pending`, `wallet_settle_pending`, `platform_wallet_*`, `settle_dpo_payment` (027). RLS currently blocks harm, but this is a missing defense-in-depth layer — mirror 033's `REVOKE EXECUTE … FROM PUBLIC, anon, authenticated`.
- **M7** `SECURITY DEFINER` functions without `SET search_path` in `004_fix_user_role_trigger.sql`, `011_influencer_partnership.sql`, `031_initial_schema.sql` (search-path hijack class).
- **M8** `DPO_SERVICE_TYPE` defaults to the **test** service `85325` if the secret is unset (`create-dpo-token/index.ts:49`) — production payments would silently hit the test endpoint. Fail closed instead.
- **M9** 50 `print`/`debugPrint` calls across 15 `lib/` files ship in release builds (payment/deep-link data in device logs). Route through `dart:developer log` with `kDebugMode` guards.
- **M10** No certificate pinning and no rate limiting anywhere (registration + referral-code redemption = referral farming; payment-token creation = pending-row spam; messages = spam). Acceptable at small scale, plan it.
- **M11** **No refund flow at all** — the `refunds` table is an unused orphan, no edge function handles refunds/cancellations; required by your own Money Policy commitments.
- **M12** Dark-mode risk: hundreds of hardcoded `Colors.*`/`Color(0x…)` across screens (worst: `tenancy_detail_screen.dart` ×41, `profile_screen.dart` ×39, `property_detail_screen.dart` ×37). Many are white-on-brand surfaces (safe), but a device pass in dark mode is required before launch.
- **M13** Edge functions return raw `error.message` to clients (internal detail leakage, e.g. `create-dpo-token/index.ts:153-155`) and DPO API calls have **no fetch timeout** (`_shared/dpo_settlement.ts:25-32`, `create-dpo-token/index.ts:133-138`) — a hung DPO endpoint burns function wall-clock.
- **M14** Stale `pending` payments never expire: after DPO's 60-minute token lifetime (`PTL=60`, `_shared/dpo.ts:81`), `create-dpo-token` keeps returning the dead token (`reused: true`, `create-dpo-token/index.ts:90-97`) until a verify marks it failed. Add a pending-payment expiry sweep or regenerate tokens older than N minutes.
- **M15** No client-side image compression before upload (full-resolution photos against a 5 MB bucket cap over Tanzanian mobile networks) — use `image_picker`'s `imageQuality`/`maxWidth` (`lib/services/storage_service.dart:20-31`).
- **M16** `transactions` INSERT policy lets any user mint arbitrary `pending` ledger rows (`003_wallet_system.sql:56-57`) — ledger spam visible to admins; nothing uses it client-side anymore (server writes are service-role). Tighten to `USING (false)`/remove.

## 6. Low-Priority Improvements

- `timezone` is an unused dependency (0 imports) — remove. `js` (transitive) is discontinued — harmless. 55 packages upgradable (`flutter pub outdated`); direct majors behind: `app_links` 6→7, `geolocator` 13→14, `flutter_lints` 5→6. Nothing flagged vulnerable.
- `android:label="dalali"` should be `Dalali` (store display); iOS bundle id `dalali` is generic — consider `tz.dalali.app` before first submission (bundle ids are permanent).
- `lib/main.dart:39-43`: if Supabase init fails, the app launches anyway into a fully broken state — show a fatal-error screen with retry.
- `AGENTS.md` drift: it describes a central `AppState`, but the app now uses split providers (`UserState`, `PropertyState`, …) — update docs.
- No store assets in-repo (screenshots, feature graphic, store listing copy) — launch tasks outside the codebase.
- No database backups/PITR configuration in-repo — enable in Supabase dashboard (Pro) or schedule `pg_dump`.
- Add `ITSAppUsesNonExemptEncryption=false` to `Info.plist` to skip export-compliance prompts on every upload (HTTPS-only app).
- KYC `liveness_passed` is client-asserted (`process-kyc-verification/index.ts:129`) — acceptable today because it only gates `pendingReview` (never auto-verifies; humans finalize), but re-check if auto-verification is ever introduced.

## 7. Security Audit

**Verified good:** service-role key absent from the repo; `lib/config/supabase_config.dart:11` decodes to a `role:"anon"` JWT; Firebase API keys present but those are non-secret identifiers; keystore (`android/app/upload-keystore.jks`) and `key.properties` are untracked + gitignored; no `http://` URLs in `lib/`; secrets compared with a timing-safe helper; admin edge functions gate on secret **or verified admin JWT**; KYC function verifies session ownership (403 otherwise); storage buckets: `avatars` owner-folder-scoped (014), `id-documents` private + owner/admin read (028); `invoke_edge_function` is EXECUTE-revoked from API roles (033:53).

**Vulnerabilities (by severity):**
1. **C1** — `is_admin`/`admin_role` self-update privilege escalation (see §3).
2. **C6** — three public tables with no RLS (see §3).
3. **H2** — push tokens survive logout (data leakage to signed-out devices).
4. **H4** — unscoped storage INSERT on the public `properties` bucket.
5. **M6/M7** — unrevoked money RPCs; unhardened `SECURITY DEFINER` search paths.
6. **M13** — internal error messages returned to clients; no outbound timeouts.
7. **M10** — no rate limiting / replay protection on auth, referral, payment-token, chat endpoints.
8. No certificate pinning (recommended for a payments app; OkHttp/`cronet` pinning or `http_certificate_pinning`).
9. No SQL-injection vector found: all dynamic SQL in migrations uses quote-safe patterns; PostgREST parameterizes. XSS surface is minimal (Flutter renders no HTML; `listing-share` OG page is server-generated — spot-checked escaping exists in `listing_share_page.ts` with tests).

## 8. Performance Audit

- Startup: sequential awaits in `main()` (Firebase → Supabase → notifications → FCM → deep links) add cold-start latency; Firebase/Supabase failures are swallowed and the app boots broken (§6). Parallelize the independent inits.
- Image-heavy feed has **no client-side compression** (M15) — the single biggest data/battery cost in this app.
- Realtime: `AppState`-era doc vs split providers aside, per-user re-subscription is wired correctly; migration 023 publishes streamed tables — verified consistent with `.stream()` usage (notifications, conversations/messages, payments, property_access…).
- Database: money/lookup indexes exist (`payments` tenant/property/status/token, `transactions` payer/payee/status/idempotency, `withdrawals` user/status, PostGIS GIST for nearby). Gaps likely to matter at scale: `properties(status, is_approved, created_at)` feed query, `messages(conversation_id, created_at)` pagination, `notifications(user_id, read)` badge count, `properties.geo` is covered. Add composite indexes per §16.
- Memory: controllers/subscriptions audited in providers — dispose paths are clean; `DeepLinkService` exposes `dispose()` but is never disposed (singleton — acceptable).
- No memory leak patterns found in the code paths reviewed; 50 debug prints in release are the main runtime waste (M9).

## 9. Database Audit

- **RLS coverage:** 45 of 49 created tables have RLS enabled with sane policies; the 4 exceptions are `commissions`, `gateway_logs`, `refunds` (**C6**) and `private.app_settings` (acceptable — `private` schema is not exposed via PostgREST).
- **Money integrity:** `wallets`/`payments`/`transactions`/`property_access` are server-write-only (`USING (false)`); settlement is a single Postgres transaction with `SELECT … FOR UPDATE` (027) — race-safe; `uniq_open_payment` (022:58-59) prevents duplicate open payments; `UNIQUE(referred_user_id, conversion_type)` makes commissions idempotent; ledger is append-only with server-only updates. **Gaps:** H1 (withdrawal claim race), H3 (amount not cross-checked), M16 (client-insertable pending rows).
- **Constraints:** status CHECKs are consistent with client enums (spot-checked payments, tenancies, withdrawals, applications); `amount > 0` checks present on money tables.
- **Triggers:** anti-tamper coverage is good except `is_admin`/`admin_role` (**C1**).
- **Realtime publication** (023) matches client streams.
- **Cron:** tenancy jobs scheduled; `scheduled-settlement` missing (**C4**); `app.cron_secret` GUC approach superseded by `private.app_settings` (034) — secret must be inserted out-of-band (verify it exists).
- **Rebuildability:** broken (H5).
- **Backups:** nothing in-repo (ops gap, §6).

## 10. Payment Audit (DPO Pay)

**Architecture is sound:** client → `create-dpo-token` (JWT, server-side fixed 20 000 TZS, own-listing block, idempotent token reuse) → DPO hosted page → `dpo-callback` (redirect) / `verify-dpo-payment` (JWT + ownership check) → `verifyAndSettle` (VerifyToken is the sole source of truth; atomic `settle_dpo_payment`; 60/40 creator split with landlord-sourced = 100% platform; influencer commission idempotent; notifications best-effort).
**Confirmed gaps:**
- C4 — settlement job never runs (withdrawals starve).
- H1 — withdrawal double-spend path.
- H3 — settled amount/currency never compared to the order.
- M8 — test service type default; M14 — dead-token reuse; M11 — no refunds; M13 — no DPO call timeouts.
- C5 — return-to-app deep link broken.
- **Store money-policy compliance:** agency fees pay for a real-world service (property access) → external payment gateway is allowed on both stores (no IAP obligation). Manual payouts (M-Pesa out-of-band) are documented and acceptable at launch, but must be described in your Money Policy.
- Deno unit tests exist for `dpo`, `dpo_settlement`-adjacent modules, `agency_fee_split`, `influencer_commission`, `hmac`, `fcm`, `timing_safe_equal`, `listing_share_page` — run `cd supabase/functions && deno test --unstable --quiet --allow-env` in CI (workflow exists).

## 11. UI/UX Audit

- Theme discipline is uneven (M12): design system exists (`lib/config/app_theme.dart`) but ~60 screen files hardcode colors; dark mode needs a device pass.
- Loading/empty states: payment flow has proper phase handling with backoff (`payment_screen.dart`); add-property disables its submit button while uploading (`add_property_screen.dart:26,57`); empty-state coverage is inconsistent across lists (favorites/search/notifications) — sample each before launch.
- Localization: `app_en.arb`/`app_sw.arb` perfectly in sync (272/272) — exemplary.
- Accessibility: icon-only buttons largely lack semantic labels; brand teal `#0D9488` on white passes for large text but is marginal for small body text; verify 44 pt targets.
- Offline: nothing (M2) — biggest UX gap after payments.
- Missing UX expected by users of a chat marketplace: typing indicators, message read state display, image messages, block/report-in-chat.

## 12. Store Compliance Audit

**Google Play:** targetSdk comes from Flutter 3.44.6 (= API 36, satisfies the 35+ requirement); 64-bit ABIs via standard Flutter AAB (`flutter build appbundle`); signing via upload keystore with a documented debug fallback (keep the fallback out of CI release jobs); `POST_NOTIFICATIONS` declared + requested at runtime; permissions are minimal and justified; deep-link `assetlinks.json` must be hosted at `dalaliapp.com/.well-known/` to upgrade `/ref` links to verified app links; Data Safety form must disclose: location, photos, camera (KYC), phone number, financial transaction history; in-app account deletion exists but is **broken for some roles (C2)** — Play rejects for that.
**Apple App Store:** blocked today by C3 (privacy manifest) + H6 (deployment target 12.0, no Podfile, `aps-environment=development`); permission purpose strings are present and well-written; `UIBackgroundModes: remote-notification` set; no Sign in with Apple needed while no social login exists; account deletion must work (C2); export compliance — add `ITSAppUsesNonExemptEncryption`; iPad is declared — verify layout or restrict to iPhone.
**Legal surfaces:** in-app Terms + Privacy screens exist (`lib/screens/shared/legal_screens.dart`, linked from register/profile), in-app type-DELETE account deletion exists (`profile_screen.dart:360-421`); you still need hosted public URLs for the privacy policy (both stores mandate a link) plus Refund/Money Policy pages, and a data-retention statement.

## 13. Missing Features (vs. stated stack & launch expectations)

1. Google Sign-In — absent. 2. Apple Sign-In — absent. 3. Anonymous/guest auth (guest *browsing* exists; no anonymous accounts). 4. Crash reporting (Crashlytics) + analytics. 5. Chat: media messages, typing indicators, read-receipt display, user blocking. 6. Notification action buttons. 7. Offline mode (cache/retry/queue). 8. Refund flow end-to-end. 9. Automated payouts (manual ops by design at launch). 10. Verified app links (`assetlinks.json` + AASA + iOS associated domains). 11. Hosted privacy/terms/refund web pages. 12. Store listing assets. 13. Saved-searches UI (data model exists: `users.saved_searches`). 14. Database backup/PITR policy.

## 14. Suggested Improvements (beyond fixes)

- Add `firebase_crashlytics` + `firebase_analytics` pre-launch (you cannot operate a payments app blind).
- Add composite indexes (§16) and a `pending`-payment expiry sweep (piggyback `scheduled-settlement`).
- Introduce a thin connectivity wrapper (e.g. `connectivity_plus`) that gates all mutations with retry.
- Regenerate a fresh ` Podfile`-backed iOS build and run one physical-device pass: signup → pay (DPO sandbox) → deep link → push → chat → delete account.
- Add integration tests for the money path (create-token → settle → split → withdrawal) against a Supabase local dev instance.
- Move the admin web app behind a non-public URL or basic auth; it shares the anon key and is discoverable.

## 15. Exact Files Requiring Changes

| File | Why |
|---|---|
| `supabase/migrations/035_lock_admin_flags.sql` (new) | C1 |
| `supabase/migrations/036_fix_deletion_fks.sql` (new) | C2 |
| `supabase/migrations/037_lock_legacy_tables.sql` (new) | C6 |
| `supabase/migrations/038_settlement_cron_and_rpc_revokes.sql` (new) | C4, M6 |
| `supabase/migrations/039_properties_bucket_policies.sql` (new) | H4 |
| `supabase/config.toml` | C4 (`[functions.scheduled-settlement] verify_jwt = false`) |
| `supabase/functions/scheduled-settlement/index.ts` | C4 (mandatory CRON_SECRET) |
| `supabase/functions/process-withdrawal/index.ts` | H1 |
| `supabase/functions/_shared/dpo_settlement.ts` | H3, M13 |
| `supabase/functions/create-dpo-token/index.ts` | M8, M13, M14 |
| `supabase/functions/delete-account/index.ts` | C2 (creator listings) |
| `ios/Runner/PrivacyInfo.xcprivacy` (new) | C3 |
| `ios/Runner/Info.plist` | C5 (URL scheme), §6 (encryption flag) |
| `ios/Runner/Runner.entitlements` | H6 (aps-environment) |
| `ios/Runner.xcodeproj/project.pbxproj` | H6 (deployment target) |
| `android/app/src/main/AndroidManifest.xml` | C5 (scheme), label |
| `android/app/build.gradle` | M1 (minify/shrink) |
| `lib/services/fcm_service.dart` | H2 |
| `lib/providers/user_state.dart` | H7 |
| `lib/services/auth_service.dart` | M4 (redirectTo), M5 (dead methods) |
| `lib/services/mock_data_service.dart` | M5 (delete) |
| `pubspec.yaml` | remove `timezone`; add crashlytics/analytics |
| `lib/main.dart` | parallel init + fatal-error screen |
| `.github/workflows/build.yml` | release AAB job |
| 15 `lib/` files with `print`/`debugPrint` | M9 |

## 16. Exact Code Snippets

**C1 — `supabase/migrations/035_lock_admin_flags.sql`**
```sql
CREATE OR REPLACE FUNCTION public.prevent_user_verification_tamper()
RETURNS TRIGGER SECURITY DEFINER SET search_path = public AS $$
DECLARE v_privileged BOOLEAN;
BEGIN
  v_privileged :=
    COALESCE(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true);
  IF v_privileged THEN RETURN NEW; END IF;

  IF NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
    RAISE EXCEPTION 'Clients cannot modify verification_status'; END IF;
  IF NEW.is_verified_landlord IS DISTINCT FROM OLD.is_verified_landlord
     OR NEW.is_verified_agent IS DISTINCT FROM OLD.is_verified_agent
     OR NEW.is_verified_listing_creator IS DISTINCT FROM OLD.is_verified_listing_creator THEN
    RAISE EXCEPTION 'Clients cannot modify verification badges'; END IF;
  -- NEW: admin flags are server/admin-only
  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin
     OR NEW.admin_role IS DISTINCT FROM OLD.admin_role THEN
    RAISE EXCEPTION 'Clients cannot modify admin flags'; END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
```

**C2 — `supabase/migrations/036_fix_deletion_fks.sql`** (verify constraint names on the live DB first with `\d+ properties`)
```sql
ALTER TABLE properties DROP CONSTRAINT IF EXISTS properties_listing_creator_id_fkey;
ALTER TABLE properties ADD CONSTRAINT properties_listing_creator_id_fkey
  FOREIGN KEY (listing_creator_id) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE inquiries DROP CONSTRAINT IF EXISTS inquiries_landlord_id_fkey;
ALTER TABLE inquiries ADD CONSTRAINT inquiries_landlord_id_fkey
  FOREIGN KEY (landlord_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE fraud_reports DROP CONSTRAINT IF EXISTS fraud_reports_reporter_id_fkey;
ALTER TABLE fraud_reports ADD CONSTRAINT fraud_reports_reporter_id_fkey
  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE disputes DROP CONSTRAINT IF EXISTS disputes_reporter_id_fkey;
ALTER TABLE disputes ADD CONSTRAINT disputes_reporter_id_fkey
  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE disputes DROP CONSTRAINT IF EXISTS disputes_respondent_id_fkey;
ALTER TABLE disputes ADD CONSTRAINT disputes_respondent_id_fkey
  FOREIGN KEY (respondent_id) REFERENCES users(id) ON DELETE SET NULL;
```

**C3 — `ios/Runner/PrivacyInfo.xcprivacy`** (add to the Runner target in Xcode)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key><array>
    <dict><key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array></dict>
    <dict><key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>C617.1</string></array></dict>
  </array>
</dict></plist>
```

**C4 — schedule settlement + gate it**
```sql
-- 038_settlement_cron_and_rpc_revokes.sql
SELECT cron.schedule('scheduled-settlement-daily','29 2 * * *',
  $$SELECT public.invoke_edge_function('scheduled-settlement')$$);
REVOKE EXECUTE ON FUNCTION public.wallet_credit(uuid,numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.wallet_debit(uuid,numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.wallet_credit_pending(uuid,numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.wallet_settle_pending(uuid,numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.platform_wallet_credit_pending(numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.platform_wallet_settle_pending(numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.settle_dpo_payment(uuid,text,text,uuid,numeric,numeric) FROM PUBLIC, anon, authenticated;
```
```toml
# supabase/config.toml
[functions.scheduled-settlement]
verify_jwt = false
```
```ts
// scheduled-settlement/index.ts — fail closed
const cronSecret = Deno.env.get("CRON_SECRET");
if (!cronSecret) return new Response("CRON_SECRET not configured", { status: 500 });
if (req.headers.get("Authorization") !== `Bearer ${cronSecret}`)
  return new Response("Unauthorized", { status: 401 });
```

**C5 — register the `dalali` scheme**
```xml
<!-- AndroidManifest.xml, inside <activity> -->
<intent-filter>
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="dalali"/>
</intent-filter>
```
```xml
<!-- Info.plist -->
<key>CFBundleURLTypes</key>
<array><dict>
  <key>CFBundleURLName</key><string>tz.dalali.app</string>
  <key>CFBundleURLSchemes</key><array><string>dalali</string></array>
</dict></array>
```

**C6 — `037_lock_legacy_tables.sql`**
```sql
ALTER TABLE commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE gateway_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "server only" ON commissions FOR ALL USING (false);
CREATE POLICY "server only" ON gateway_logs FOR ALL USING (false);
CREATE POLICY "server only" ON refunds FOR ALL USING (false);
-- or, after confirming no data is needed: DROP TABLE commissions, gateway_logs, refunds;
```

**H1 — `process-withdrawal/index.ts` (claim-before-debit)**
```ts
const { data: wd, error: claimError } = await supabase
  .from('withdrawals')
  .update({ status: 'processing' })
  .eq('id', withdrawalId).eq('status', 'pending')
  .select().maybeSingle()
if (claimError || !wd) return json({ error: 'Not found or already processed' }, 409)
// … balance check + wallet_debit …
const { error: doneError } = await supabase.from('withdrawals')
  .update({ status: 'completed', processed_at: new Date().toISOString(), selcom_payout_id: manualRef })
  .eq('id', withdrawalId)
if (doneError) { // compensate: re-credit and flag for ops
  await supabase.rpc('wallet_credit', { p_user_id: wd.user_id, p_amount: wd.amount })
  await supabase.from('withdrawals').update({ status: 'pending' }).eq('id', withdrawalId)
  return json({ error: 'Completion failed — debit reversed' }, 500)
}
```

**H2 — clear the FCM token before sign-out** (`user_state.dart` / `fcm_service.dart`)
```dart
Future<void> logout() async {
  final uid = SupabaseService.currentUserId;
  if (uid != null) {
    try {
      await SupabaseService.client.from('users')
          .update({'fcm_token': null}).eq('id', uid);
    } catch (_) {}
  }
  await _authService.signOut();
  // …existing cleanup…
}
```

**H3 — validate settled amount** (`_shared/dpo_settlement.ts`, after `statusFromResult`)
```ts
if (status === "paid") {
  if (verify.amount != null && Number(verify.amount) !== Number(payment.amount)) {
    await supabase.from("payments").update({ status: "failed" }).eq("id", payment.id);
    return { status: "failed", payment, verify, note: "amount_mismatch" };
  }
  if (verify.currency && verify.currency !== payment.currency) {
    await supabase.from("payments").update({ status: "failed" }).eq("id", payment.id);
    return { status: "failed", payment, verify, note: "currency_mismatch" };
  }
}
```

**H4 — `039_properties_bucket_policies.sql`**
```sql
CREATE POLICY "Property images public read" ON storage.objects
  FOR SELECT USING (bucket_id = 'properties');
CREATE POLICY "Property images owner upload" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (
    bucket_id = 'properties' AND EXISTS (
      SELECT 1 FROM properties p
      WHERE p.id = (storage.foldername(name))[1]::uuid
        AND (p.landlord_id = auth.uid() OR p.listing_creator_id = auth.uid())));
```

**H6 — iOS**: set `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (or 15.0 if the Firebase pods require it) in `project.pbxproj` (all configurations); run `flutter build ios --release` once to generate `Podfile`/`Podfile.lock`; keep `aps-environment=development` for dev but ship release with `production` (verify the archived build's embedded entitlements; Xcode's App Store export normally rewrites this from the distribution profile — confirm, don't assume).

**H7 — `user_state.dart`**
```dart
_authService.authStateChanges.listen((AuthState state) async {
  final user = state.session?.user;
  if (user == null) {
    _unsubscribeInfluencerProfile();
    currentUser = null; influencerProfile = null;
    notifyListeners();
    return;
  }
  // …existing user != null branch…
});
```

**M1 — `android/app/build.gradle` release hardening** (test notifications/FCM after enabling)
```gradle
buildTypes {
  release {
    minifyEnabled true
    shrinkResources true
    proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    signingConfig = keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug
  }
}
```

**Indexes (add to a migration)**
```sql
CREATE INDEX IF NOT EXISTS idx_properties_feed ON properties(status, is_approved, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, read);
```

## 17. Deployment Checklist

**Code (this repo)**
- [ ] Apply migrations 035–039 (C1, C2, C6, C4+M6, H4) + index migration
- [ ] `config.toml`: `[functions.scheduled-settlement] verify_jwt = false`; redeploy `scheduled-settlement` with mandatory-secret code
- [ ] `process-withdrawal` claim-before-debit; `dpo_settlement` amount/currency check; `create-dpo-token` fail-closed service type + fetch timeouts
- [ ] `delete-account`: handle creator-owned listings; retest deletion for landlord, agent, disputed user
- [ ] Register `dalali://` on both platforms; set Android label `Dalali`
- [ ] `PrivacyInfo.xcprivacy`; iOS deployment target; production APNs entitlement; `ITSAppUsesNonExemptEncryption`
- [ ] `user_state.dart` signed-out branch; FCM token cleared before sign-out
- [ ] Remove dead code (`submitVerification`, `updatePhoneVerification`, `mock_data_service.dart`, `timezone` dep); gate debug prints
- [ ] Add Crashlytics + Analytics; `flutter pub upgrade` pass
- [ ] `flutter analyze` + `flutter test` + `deno test` green; `flutter build appbundle --release` + `flutter build ipa --release` succeed

**Dashboards / ops**
- [ ] Supabase: secrets set (`DPO_COMPANY_TOKEN` **production**, `DPO_SERVICE_TYPE` **production** (not 85325), `ADMIN_API_SECRET`, `CRON_SECRET`, `COMMISSION_SECRET`, `FCM_SERVICE_ACCOUNT`); `private.app_settings` cron secret inserted; storage bucket policies match 039; auth Site URL + `dalali://` redirect URLs; email templates branded; backups/PITR enabled
- [ ] DPO: production account, settlement currency TZS, callback allowlist
- [ ] Firebase: production APNs key uploaded; Android app registered (SHA-1/256 for future Google Sign-In)
- [ ] Host: `dalaliapp.com/.well-known/assetlinks.json` + AASA file; privacy policy, terms, refund/money policy public URLs
- [ ] Play Console: Data Safety, content rating, target audience, store listing + screenshots, AAB upload, Play App Signing enrolled
- [ ] App Store Connect: privacy nutrition labels, export compliance, review notes (demo account), listing assets

**Device QA pass (physical Android + iPhone)**
- [ ] Signup (incl. referral code) → browse → pay agency fee (DPO sandbox) → return-to-app deep link → contact unlock → chat → push (foreground/background/killed) → tenancy application → approval → wallet credit (48 h) → withdrawal → delete account — for **each role**
- [ ] Dark mode sweep of top 15 screens; small-screen (iPhone SE / low-end Android) sweep; Kiswahili sweep
- [ ] Airplane-mode behavior on every async screen

## 18. Go / No-Go Recommendation

## **NO-GO** for store submission today.

The blocking set is small and cheap to clear: one trigger extension (C1), one FK migration (C2), one plist (C3), one cron row + config flag (C4), two manifest edits (C5), one RLS migration (C6), plus the withdrawal race fix (H1). That is roughly **2–3 engineering days** including re-testing, followed by one full physical-device pass per platform. After the Section 17 checklist is complete — and the unverifiable dashboard items (DPO production credentials, secrets, backups, storage policies) are confirmed — this app is a credible **GO**: the underlying architecture, payment idempotency design, test suite, and localization discipline are above average for a first release.
