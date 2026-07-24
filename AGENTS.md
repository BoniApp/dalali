# AGENTS.md — Dalali / HTN (Housing Transition Network)

Guidance for AI coding agents working in this repository. This file assumes no prior knowledge of the project.

---

## Project Overview

**Dalali** is a Flutter application that connects landlords, house seekers, and agents in Tanzania (initially Dar es Salaam). The broader vision (see `REQUIREMENTS.md`) is a "Housing Transition Network": property listings & search, a move/relocation engine, tenancy lifecycle management, a neighbourhood safety network, a wallet/payments system (TZS), KYC verification, an influencer partnership program, and an admin back office.

- **Package name**: `dalali` (Dart), Android namespace/applicationId `dalali.tz`
- **Version**: 1.0.0+1, Dart SDK `^3.6.1`, Flutter stable (CI pins 3.44.6; `pubspec.lock` requires Flutter >=3.38.1 / Dart >=3.10)
- **Platforms**: Android, iOS, Web (plus generated desktop scaffolding for macOS/Linux/Windows)

### Backend: Supabase (migrated from Firebase)

The current backend is **Supabase** (Postgres + Auth + Storage + Realtime + Edge Functions). The app was previously built on Firebase/Firestore; all Firebase artefacts (packages, configs, the old `FIREBASE_SETUP.md`/`DEPLOY.md` docs) have been removed.

- `REQUIREMENTS.md` describes planned modules/features; treat it as a spec, not a schema reference. The authoritative schema is in `supabase/migrations/*.sql` and `SUPABASE_SCHEMA_UPGRADE.md`.
- Supabase connection details live in `lib/config/supabase_config.dart` (project URL + anon key, currently hardcoded).

---

## Repository Layout

```
lib/
  main.dart            # Main app entry point (user app)
  main_admin.dart      # Separate admin dashboard entry point
  config/              # supabase_config.dart (URL + anon key), app_theme.dart (design system)
  models/              # Plain Dart model classes with fromJson/toJson
    admin/  kyc/  influencer/  # Domain subfolders
  providers/           # app_state.dart (central state), theme_provider.dart, language_provider.dart
  screens/             # UI organized by role/domain:
    auth/              #   login, register
    seeker/ landlord/ agent/ influencer/
    shared/            #   main_navigation, profile, property_detail, settings, ...
    tenancy/ move/ safety/ claims/ deals/ earnings/ opportunity/ wallet/ kyc/
    admin/             #   ~22 admin screens (users, wallets, withdrawals, fraud, influencers, ...)
  services/            # Business logic + Supabase access
    supabase_service.dart   # Singleton wrapper (SupabaseService.client)
    data_service.dart       # CRUD for core tables
    auth_service.dart, dpo_payment_service.dart (DPO Pay), wallet_service.dart,
    earnings_service.dart, deal_service.dart,
    property_registry_service.dart, matching_engine.dart, recommendation_engine.dart,
    safety_engine.dart, report_service.dart, notification_service.dart,
    storage_service.dart, location_service.dart, ...
    admin/  kyc/  influencer/ # Domain subfolders (admin_service, KYC: NIDA/OCR/liveness/AML, influencer + campaign services)
  widgets/             # Reusable widgets (property_card, verification_badge, safety_badge, ...)
  utils/helpers.dart   # Formatting helpers (TZS currency, dates)
  l10n/                # ARB files (app_en.arb, app_sw.arb) + generated localizations
supabase/
  migrations/          # Numbered SQL migrations (001–026; note there are two 001_* and two 002_* files)
  functions/           # Deno/TypeScript Edge Functions (payment webhooks, withdrawals, KYC, influencer commissions, ...)
  DEPLOYMENT_GUIDE.md  # How to run migrations & deploy edge functions (current, use this one)
test/                  # flutter_test widget + unit tests (widget_test.dart, influencer_models_test.dart)
.github/workflows/     # build.yml (Android APK), deploy_edge_functions.yml (Deno tests + deploy)
android/ ios/ web/ ... # Standard Flutter platform folders
assets/images/         # Bundled image assets
```

## Architecture & Conventions

- **State management**: `provider` package. `AppState` (`lib/providers/app_state.dart`) is the central `ChangeNotifier` holding the current user and cached lists of properties, appointments, tenancies, deals, earnings, etc., wired to Supabase Realtime subscriptions. `ThemeProvider` and `LanguageProvider` persist preferences via `shared_preferences`.
- **Data access**: Services call Supabase through `SupabaseService.client` (singleton over `Supabase.instance.client`). Models are plain Dart classes; services convert rows via `fromJson` helpers. Follow the existing pattern: add a model in `lib/models/`, CRUD methods in `DataService` or a domain service, then expose state via `AppState`.
- **Two entry points**:
  - User app: `lib/main.dart` (default)
  - Admin dashboard: `lib/main_admin.dart` — run with `flutter run -t lib/main_admin.dart -d chrome`
- **Roles**: Seeker, Landlord, Agent, Influencer, plus Admin (admin shell under `lib/screens/admin/`, gated by `users.is_admin` in RLS policies). `UserRole` lives in `lib/models/user_model.dart`; `lib/screens/shared/main_navigation.dart` has exhaustive switches over it (adding a role breaks compilation until extended — intended). Influencer role is granted by admin approval (edge function flips `users.role`), not picked at signup.
- **Localization**: English (`en`) and Kiswahili (`sw`) via ARB files. `l10n.yaml` outputs generated code into `lib/l10n` (`generate: true` in `pubspec.yaml`). When adding user-facing strings, add keys to **both** `app_en.arb` and `app_sw.arb`, then run `flutter gen-l10n` (or `flutter pub get` / any build, which triggers generation). Admin screens conventionally hardcode English.
- **Money**: TZS; agency fee is a fixed 20,000 TZS per payment, collected via **DPO Pay (sole gateway)** — see `DPO_INTEGRATION.md`. Flow: `payment_screen.dart` → `create-dpo-token` (mints the hosted-page token + a pending `payments` row) → customer pays on DPO → settlement in `_shared/dpo_settlement.ts` (via `dpo-callback` redirect or the app's `verify-dpo-payment` poll) marks the payment paid, upserts `property_access` (unlocks the landlord card's call/SMS/chat in `property_detail_screen.dart`), writes the `transactions` ledger row, applies the split rule (`_shared/agency_fee_split.ts`: the listing creator earns 60% / platform 40% — **agents and seekers alike**; **landlord-sourced listings are 100% platform revenue** — no share, no `agency_fees`/`earnings` rows, and no wallet UI for landlords), then the influencer commission. DPO credentials are function secrets only (`DPO_COMPANY_TOKEN`, `DPO_SERVICE_TYPE`) — never in client code. Prices formatted with `Helpers.formatPrice` (`sw_TZ` locale).
- **Maps**: `flutter_map` + OpenStreetMap (chosen deliberately to avoid Google Maps API keys). Haversine-based distance/safety scoring in `safety_engine.dart` / `property_registry_service.dart`.
- **Comment style**: Services and important files use boxed banner comments (`/// ═══...═══`) — match this when editing those files.
- **Notifications & app badge**: in-app notifications live in the `notifications` table (RLS: read/update/delete own) and stream into `AppState` via Supabase Realtime — migration 023 publishes all streamed tables in `supabase_realtime` (only conversations/messages were published before, so most streams silently delivered no live events; keep new streamed tables added there). `NotificationService` wraps `flutter_local_notifications` for device alerts (channel `dalali_channel`), and **FCM** (`firebase_messaging`, manual options in `lib/config/firebase_options.dart` — no Gradle plugin or Xcode edit) covers the app-closed case via `FcmService` (token → `users.fcm_token`, cleared on logout; foreground → local alert; tap → target navigation). Sending is server-side only: the `send-notification` edge function (gated by `x-admin-secret` = `ADMIN_API_SECRET`) inserts the in-app row AND pushes via FCM HTTP v1 (`_shared/fcm.ts`, service account in the `FCM_SERVICE_ACCOUNT` secret) — route new server-side notifications through it. Setup: `docs/FCM_NOTIFICATION_SETUP.md`. Tapping a notification marks it read and navigates by `target_collection` (properties → detail, payments → receipt, conversations/message → messages, tenancies/tenancy_applications). The unread count mirrors to the launcher icon: iOS via the `dalali/app_badge` MethodChannel in `ios/Runner/AppDelegate.swift` (`NotificationService.updateAppBadge`), Android via the automatic launcher dot from the background summary alert (fixed id `NotificationService.newNotificationsId`, posted only while the app is backgrounded and cancelled when all notifications are read). Sync logic lives in `AppState._syncNotificationBadge` (called from the notifications stream, read-marking, and logout, which clears it). Android 13+ requires `POST_NOTIFICATIONS` — declared in `android/app/src/main/AndroidManifest.xml` and requested at runtime in `NotificationService.initialize()`; keep both.
- **Design system**: `lib/config/app_theme.dart` defines the semantic colors (primary `#0D9488` teal, action `#F97316` orange CTA, text `#1F2937`, border `#E5E7EB`, dark bg `#0F172A`), the typography scale (32/24/18/16/14), button/input states, and 8pt spacing constants, per the DalaliApp UI Component Specification. `ThemeProvider` and `main_admin.dart` both consume `AppTheme.light()/dark()` — prefer `AppTheme` constants over hardcoded `Colors.teal`.
- **Brand asset**: `assets/images/dalali_logo.png` (512×512) is the canonical logo; the Android/iOS/web launcher icons are generated from it.
- **Linting**: `flutter_lints` defaults only (`analysis_options.yaml` has no custom rules). Keep code `flutter analyze`-clean.
- **Dead code note**: `lib/services/mock_data_service.dart` exists but is not referenced elsewhere; verify before building on it.

## Influencer Partnership System (migration 011)

- **Flow**: two entry paths. (a) Signup with role "Influencer" (register screen picker) → migration 013's `handle_new_influencer` trigger instantly creates the active `influencers` row, mints the referral code + default `referral_links` row, and ensures a wallet exists — no approval step. (b) In-app application (`influencer_applications`) → admin approves in the admin dashboard → `generate-referral-code` edge function does the same setup and flips `users.role` to `influencer`; for users who already signed up as influencer it reuses their existing code instead of minting a new one.
- **Attribution**: new users enter a referral code at registration → `referral_clicks` + a zero-amount `referral_conversions('registration')` row (client-insertable under tight RLS). **Deep links** (`https://dalaliapp.com/ref/CODE`, optional `?listing=<id>`) are handled by `lib/services/deep_link_service.dart` (`app_links` plugin): the code prefills the register screen's referral field (`pendingReferralCode`), and a `?listing` id pushes `PropertyDetailScreen` — immediately when the app is running logged-in, otherwise stashed (`pendingListingId`) until `MainNavigation` mounts. `InfluencerService.buildReferralUrl(code, listingId:)` builds them (the "Listings to Share" carousel attaches the listing id). **Social previews**: the carousel shares `${supabaseUrl}/functions/v1/listing-share?l=<id>&r=<code>` (via `buildListingShareUrl`) — the `listing-share` edge function serves an Open Graph page (listing photo as `og:image`, page builder in `_shared/listing_share_page.ts`) so WhatsApp/Facebook render a photo card, then redirects humans to the deep link; it is `verify_jwt = false` in `supabase/config.toml` because crawlers send no auth. Android: `/ref` intent-filter in the manifest (no `autoVerify` — needs `assetlinks.json` hosted on the domain). iOS: not wired — needs the `applinks:dalaliapp.com` associated-domain entitlement + a hosted AASA file (server-side follow-up).
- **Commissions**: computed server-side only. `_shared/dpo_settlement.ts` calls `attributeAndCredit` (in `_shared/influencer_commission.ts`) after a payment settles: it attributes the payer, computes the rate from `system_settings` (`influencer_agency_fee_pct` 10% of the 20,000 TZS agency fee = 2,000 TZS; `influencer_premium_pct` 20% for other payment types), inserts `referral_conversions` + an `earnings` row (`type='referralCommission'`), and credits the influencer's existing `wallets` row. Idempotent via `UNIQUE(referred_user_id, conversion_type)`. `scheduled-settlement` later moves pending → available and marks conversions paid. `verify-referral-payment` re-processes an idempotency key for ops backfill.
- **No parallel money tables**: influencer balances/payouts reuse `wallets`, `transactions`, `withdrawals`, and the existing `process-withdrawal` function — do not create influencer-specific wallet tables.
- **Campaigns**: `campaigns` + `campaign_participants` (admin-managed; influencers join in-app). `match_influencers_for_campaign(uuid)` is an admin-only SQL RPC returning heuristic scores — the documented swap-in point for a real AI matcher.
- **Fraud**: self-referral/duplicate/suspended-influencer crediting is blocked server-side and logged to `fraud_logs` (admin-visible). `prevent_influencer_tamper` trigger protects `influencers` status/counters/code from client writes.
- **Client code**: `lib/models/influencer/`, `lib/services/influencer/`, `lib/screens/influencer/` (dashboard, referral link, campaigns, application, `shareable_listings_section.dart` — a "Listings to Share" carousel on the dashboard whose share messages carry the influencer's referral code/URL, WhatsApp via `wa.me` + copy-to-paste for other platforms) + admin screens (`influencers_admin_screen`, `influencer_detail_admin_screen`, `campaigns_admin_screen`, `influencer_reports_admin_screen`) wired into `admin_shell.dart` via `AdminPermissions.canManageInfluencers`.

## Listings Near Me (migration 012)

- **Backend**: `012_nearby_listings.sql` adds a generated PostGIS `geo geography(Point,4326)` column + GIST index on `properties` and the `properties_nearby` RPC (radius/price/bedrooms/type/premium/verified filters; results sorted by distance → featured → newest; paginated via limit/offset). SECURITY INVOKER — visibility matches the app feed (`status='available' AND is_approved=true`). Requires the `postgis` extension.
- **Client**: `lib/screens/seeker/nearby_map_screen.dart` (full-screen `flutter_map` + `flutter_map_marker_cluster` price-badge markers, radius chips, draggable card sheet, optional heatmap, GPS FAB) backed by `lib/services/nearby_listings_service.dart` (RPC wrapper, smart-radius expansion, 2-min cache, `formatDistanceMeters`/`compactTzs`/`nextRadiusMeters` pure helpers — unit-tested in `test/nearby_listings_test.dart`) and `lib/services/device_location_service.dart` (`geolocator` permission + position stream; distinct from the static-data `LocationService`). Live distances ride on `PropertyModel.distanceMeters` (populated only by geo queries). New-listing alerts use a Realtime `onPostgresChanges` insert subscription on `properties`. Entry point: map icon in the seeker home AppBar.
- **Permissions**: `ACCESS_FINE/COARSE_LOCATION` (Android) and `NSLocationWhenInUseUsageDescription` (iOS) are declared; keep them if the feature stays.

## Chat & Broadcast (migration 017)

- **Tables**: `conversations` (one per user pair, enforced by a `LEAST/GREATEST` unique index; participant names denormalized because `users` RLS only exposes one's own row; optional `property_id` context) and `messages`. RLS: participants can read/create; clients get **no UPDATE** — `last_message_*` and the per-participant `unread_a/b` counters are maintained only by the `handle_new_chat_message` trigger (which also fans out a `notifications` row, `type='message'`), and read-marking goes through the `mark_conversation_read(uuid)` RPC only.
- **Client**: `lib/models/chat_models.dart` + `lib/services/chat_service.dart` (singleton, `.stream(primaryKey:)` realtime; the stream builder has no `.or()`, so `watchConversations` streams unfiltered — RLS scopes the rows — and filters client-side). UI: `lib/screens/shared/conversations_screen.dart` (list + unread pills) and `chat_screen.dart` (WhatsApp-style bubbles; marks read via RPC when open). Entry points: Messages tab in `main_navigation.dart` (all 4 roles, `Badge` over the icon via `watchTotalUnread`) and the chat icon on the landlord card in `property_detail_screen.dart` (targets `listingCreatorId` else `landlordId`).
- **Admin broadcast**: `supabase/functions/admin-broadcast` (admin JWT or `x-admin-secret` + `admin_user_id`; targets `all|seeker|landlord|agent|influencer`; non-admin recipients only) fans out admin↔user conversations + messages; `lib/screens/admin/broadcast_admin_screen.dart` composes it (permission `AdminPermissions.canBroadcast` = superAdmin/supportAgent). Replies surface in the admin shell "Messages" item, which reuses `ConversationsScreen`.
- `notifications.type` CHECK was extended with `'message'` and `'broadcast'` — keep them if you re-create the constraint.

## Tenancy Applications & Tenancies (migration 019)

- "Reservations" in the UI (`ReservationRequestsScreen`) are `tenancy_applications` rows: `pending → approved | rejected`, then terminal. Transition legality, field immutability, and `resolved_at` stamping are enforced by the `tenancy_application_guard` trigger; a partial unique index (`uniq_open_application`) allows only one open application per seeker per property.
- **All side effects are server-trigger-owned** — never duplicate them client-side: application INSERT → landlord notification; approval → tenancy creation + property `status='pending'` (atomic `WHERE status='available'` guard aborts double-bookings) + tenant notification; rejection → tenant notification. Clients only write `status` via `DataService.updateApplicationStatus` / `updateTenancyStatus`; realtime streams reconcile `AppState`.
- `tenancies`: `upcoming → active → completed | terminated` (guard-enforced; `upcoming → terminated` is the early-exit path). `handle_tenancy_status_change` reconciles the listing: active → `occupied`, completed/terminated → `unlisted` (migration 021 — **no auto-relist**; the landlord relists explicitly via `AppState.relistProperty` → `DataService.updatePropertyStatus`, which flips `status` back to `'available'`). Tenancy rows are created only by the approval trigger (no client INSERT policy).
- Full state machines, dead ends, and the remaining gap register (G2–G10) are documented in `LISTING_WORKFLOW_SPEC.md`.

## Move Checklists & Rent Schedules (migration 020)

- **Both are seeded server-side only**: the `setup_new_tenancy` trigger (AFTER INSERT on `tenancies`) creates the tenant's default `move_checklists` row (8 items as JSONB) and 12 monthly `rent_schedules` rows from `move_in_date`. Clients never INSERT these tables — there are no client INSERT policies.
- `move_checklists`: one row per tenancy per tenant (`UNIQUE(tenancy_id, user_id)`), owner read/update of `items` only. Toggling goes through `AppState.toggleChecklistItem` → `DataService.updateMoveChecklist` (whole `items` array + `updated_at`).
- `rent_schedules`: `pending → paid` is the only legal transition; the `rent_schedule_guard` trigger makes paid rows terminal, stamps `paid_at`, and freezes the terms (parties, due date, amount). `'overdue'` is never stored — the client derives it from `due_date` (`RentScheduleModel.isOverdue`). Either party can mark paid via `AppState.markRentPaid` → `DataService.markRentPaid`; tenant and landlord both read via RLS.
- Client: `lib/models/move_checklist_model.dart`, `lib/models/rent_schedule_model.dart`, streams in `DataService` (`getMoveChecklistsForUser`, `getRentSchedulesForTenant/Landlord`), `AppState` subscriptions wired per role (landlords stream by `landlord_id`). UI: `lib/screens/tenancy/move_checklist_screen.dart` and the rent tab in `tenancy_detail_screen.dart`.

## Maintenance Requests (migration 025)

- Was client-complete with **no table** (stubbed `DataService` methods); 025 adds `maintenance_requests` (RLS: tenants insert own `open` rows, only the landlord updates, no deletes) plus the `maintenance_request_guard` trigger (`open → inProgress → resolved`, resolved terminal, details immutable, `resolved_at` stamped). Also joined to the realtime publication there (023 skips tables that don't exist yet).
- Client: `lib/models/maintenance_request_model.dart`, `DataService` (`getMaintenanceForTenant/Landlord`, `addMaintenanceRequest`, `updateMaintenanceStatus`), UI in `tenancy_detail_screen.dart` (tenant files, landlord advances status).

## Build & Test Commands

```bash
flutter pub get                 # Install dependencies (also triggers l10n generation)
flutter analyze                 # Static analysis
flutter test                    # Run widget/unit tests (test/)
flutter run                     # Run user app
flutter run -t lib/main_admin.dart -d chrome   # Run admin dashboard

flutter build apk --release     # Android APK (debug: --debug)
flutter build appbundle --release
flutter build web --release
flutter build web -t lib/main_admin.dart       # Admin web build
```

### Edge Functions (Deno)

Supabase Edge Functions in `supabase/functions/` are TypeScript on Deno (v2). Tests live next to the code (`_shared/hmac_test.ts`, `_shared/influencer_commission_test.ts`, `process_withdrawal/index.test.ts`):

```bash
cd supabase/functions && deno test --unstable --quiet --allow-env
```

Deploy per `supabase/DEPLOYMENT_GUIDE.md` (Supabase CLI: `supabase db push`, `supabase functions deploy <name>`). CI (`deploy_edge_functions.yml`) runs Deno tests on push to `main` and deploys if `SUPABASE_ACCESS_TOKEN`/`SUPABASE_PROJECT_REF` secrets are set.

### Database migrations

SQL migrations in `supabase/migrations/` are applied in filename order via `supabase db push` or `psql -f`. **Caution**: there are two files numbered `001_*` and two numbered `002_*` — check actual file contents before adding a new migration; use the next free number (`027_...`).

## Testing Instructions

- Tests use `flutter_test`; widget tests in `test/widget_test.dart` (e.g., `VerificationBadge`) and model unit tests in `test/influencer_models_test.dart`. There is no large test suite — add tests alongside new logic, especially for services/engines (matching, safety scoring, earnings) and new widgets.
- Keep tests independent of Supabase (no network); pump widgets inside a `MaterialApp` as in existing tests.
- Run `flutter test` and `flutter analyze` before considering a change done.

## Security Considerations

- **Secrets**: `SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_API_SECRET`, `COMMISSION_SECRET`, and `FCM_SERVICE_ACCOUNT` (Firebase service account JSON, used by `send-notification`) must never appear in client code — they are Edge Function environment variables only (set via `supabase secrets set`). `COMMISSION_SECRET` gates the server-to-server influencer commission endpoints (`calculate-influencer-commission`, `verify-referral-payment`). The anon key in `lib/config/supabase_config.dart` is the publishable client key and relies on RLS for protection.
- **Row Level Security** is the primary authorization mechanism. Policies gate admin access via `users.is_admin`; see `supabase/migrations/006_admin_rls_policies.sql` and `SUPABASE_SCHEMA_UPGRADE.md`. When adding tables/columns, also add RLS policies and test them.
- **Anti-tamper**: Postgres triggers (`prevent_property_tamper`, `prevent_influencer_tamper`) block clients from modifying moderation fields like `is_approved`, `view_count`, ratings, safety scores, influencer status/counters/referral_code. `prevent_user_verification_tamper` (018/026) additionally locks `users.role` after signup — one role per user, changeable only by admins or the service role (re-setting the same value is a no-op, so registration still works). Don't attempt to write these from the client.
- **Payments**: DPO Pay is the sole gateway. The `DPO_COMPANY_TOKEN` is a function secret only — all DPO API calls (`CreateToken`/`VerifyToken`, XML in `_shared/dpo.ts`) happen inside edge functions; the app only calls Supabase. `dpo-callback` is intentionally `verify_jwt = false` (browser redirect) but only ever settles idempotently via `_shared/dpo_settlement.ts`. Commission crediting happens server-side only; wallet mutations are service-role only (`USING (false)` client policies).
- **KYC**: Sensitive identity data (NIDA integration, OCR, liveness) flows through `lib/services/kyc/` and the `process-kyc-verification` function (JWT-gated: caller must own the session, or be admin); location data collection is opt-in and requires explicit user consent. Liveness is a real two-capture front-camera proof-of-life challenge (`liveness_service.dart`), not a pass-through.
- **Withdrawals require KYC**: only users with `users.verification_status = 'verified'` can request a withdrawal — enforced by the `trg_withdrawal_verification` trigger (migration 016) on `withdrawals` INSERT; `withdrawal_screen.dart` shows a verify prompt instead of the form for unverified users. `verification_status` itself is set **server-side only** by `process-kyc-verification` (client persists session + document, then invokes it with the user JWT; NIDA docs verify instantly, other docs go to `pendingReview` → `users.verification_status='pending'`) and is protected from client self-edits by the `trg_prevent_user_verification_tamper` trigger (migration 018, allows admins + service role only).
- New properties default to unapproved (`is_approved: false` / `listing_status: 'draft'`) pending admin moderation.

## CI/CD

- `.github/workflows/build.yml`: on push/PR to `main`/`master`, builds a release Android APK (Flutter 3.44.6, JDK 17, Android platform/build-tools 36, NDK 28.2.13676358, adds swap, `--no-tree-shake-icons`, arm64) and uploads it as an artifact.
- Android toolchain: Gradle 8.14.3 / AGP 8.11.1 / Kotlin 2.2.20 (in `android/gradle/wrapper/gradle-wrapper.properties` and `android/settings.gradle`). Flutter 3.44.6 hard-fails below Gradle 8.7 / AGP 8.6 / KGP 2.0 — do not downgrade.
- Release signing: `android/app/build.gradle` signs release builds with the upload keystore described by `android/key.properties` (gitignored) when that file exists; otherwise it falls back to the debug key so CI and local `flutter run --release` keep working.
- `.github/workflows/deploy_edge_functions.yml`: on push to `main`, runs Deno tests (Deno 2.9.3, `--allow-env`) for Edge Functions and conditionally deploys them.

## Key Documentation Files

- `REQUIREMENTS.md` — module/feature specification (planned vision; backend reality is Supabase)
- `SUPABASE_SCHEMA_UPGRADE.md` — schema for property registry, deals, agency fees, earnings + RLS examples
- `KYC_MODULE_DESIGN.md` — KYC module design
- `supabase/DEPLOYMENT_GUIDE.md` — current backend deployment guide
