# AGENTS.md — Dalali / HTN (Housing Transition Network)

Guidance for AI coding agents working in this repository. This file assumes no prior knowledge of the project.

---

## Project Overview

**Dalali** is a Flutter application that connects landlords, house seekers, and agents in Tanzania (initially Dar es Salaam). The broader vision (see `REQUIREMENTS.md`) is a "Housing Transition Network": property listings & search, a move/relocation engine, tenancy lifecycle management, a neighbourhood safety network, a wallet/payments system (TZS), KYC verification, and an admin back office.

- **Package name**: `dalali` (Dart), Android namespace/applicationId `dalali.tz`
- **Version**: 1.0.0+1, Dart SDK `^3.6.1`, Flutter stable (CI pins 3.44.6; `pubspec.lock` requires Flutter >=3.38.1 / Dart >=3.10)
- **Platforms**: Android, iOS, Web (plus generated desktop scaffolding for macOS/Linux/Windows)

### Backend: Supabase (migrated from Firebase)

The current backend is **Supabase** (Postgres + Auth + Storage + Realtime + Edge Functions). The app was previously built on Firebase/Firestore, and several docs are stale:

- **`FIREBASE_SETUP.md` and `DEPLOY.md` describe the old Firebase setup and are outdated** — no Firebase packages remain in `pubspec.yaml`. Do not follow them.
- `REQUIREMENTS.md` still references Firestore collections; treat it as a module/feature spec, not a schema reference. The authoritative schema is in `supabase/migrations/*.sql` and `SUPABASE_SCHEMA_UPGRADE.md`.
- Supabase connection details live in `lib/config/supabase_config.dart` (project URL + anon key, currently hardcoded).

---

## Repository Layout

```
lib/
  main.dart            # Main app entry point (user app)
  main_admin.dart      # Separate admin dashboard entry point
  config/              # supabase_config.dart (URL + anon key)
  models/              # Plain Dart model classes with fromJson/toJson
    admin/  kyc/       # Domain subfolders
  providers/           # app_state.dart (central state), theme_provider.dart, language_provider.dart
  screens/             # UI organized by role/domain:
    auth/              #   login, register
    seeker/ landlord/ agent/
    shared/            #   main_navigation, profile, property_detail, settings, ...
    tenancy/ move/ safety/ claims/ deals/ earnings/ opportunity/ wallet/ kyc/
    admin/             #   ~18 admin screens (users, wallets, withdrawals, fraud, ...)
  services/            # Business logic + Supabase access
    supabase_service.dart   # Singleton wrapper (SupabaseService.client)
    data_service.dart       # CRUD for core tables (replaces old FirestoreService)
    auth_service.dart, payment_service.dart, wallet_service.dart,
    selcom_service.dart (payment gateway), earnings_service.dart, deal_service.dart,
    property_registry_service.dart, matching_engine.dart, recommendation_engine.dart,
    safety_engine.dart, report_service.dart, notification_service.dart,
    storage_service.dart, location_service.dart, ...
    admin/  kyc/            # Domain subfolders (admin_service, KYC: NIDA, OCR, liveness, AML)
  widgets/             # Reusable widgets (property_card, verification_badge, safety_badge, ...)
  utils/helpers.dart   # Formatting helpers (TZS currency, dates)
  l10n/                # ARB files (app_en.arb, app_sw.arb) + generated localizations
supabase/
  migrations/          # Numbered SQL migrations (001–009; note there are two 001_* and two 002_* files)
  functions/           # Deno/TypeScript Edge Functions (payment webhooks, withdrawals, KYC, ...)
  DEPLOYMENT_GUIDE.md  # How to run migrations & deploy edge functions (current, use this one)
test/widget_test.dart  # Widget tests (flutter_test)
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
- **Roles**: Seeker, Landlord, Agent, plus Admin (admin shell under `lib/screens/admin/`, gated by `users.is_admin` in RLS policies).
- **Localization**: English (`en`) and Kiswahili (`sw`) via ARB files. `l10n.yaml` outputs generated code into `lib/l10n` (`generate: true` in `pubspec.yaml`). When adding user-facing strings, add keys to **both** `app_en.arb` and `app_sw.arb`, then run `flutter gen-l10n` (or `flutter pub get` / any build, which triggers generation).
- **Money**: TZS; agency fee is a fixed 20,000 TZS per confirmed tenancy. Prices formatted with `Helpers.formatPrice` (`sw_TZ` locale).
- **Maps**: `flutter_map` + OpenStreetMap (chosen deliberately to avoid Google Maps API keys). Haversine-based distance/safety scoring in `safety_engine.dart` / `property_registry_service.dart`.
- **Comment style**: Services and important files use boxed banner comments (`/// ═══...═══`) — match this when editing those files.
- **Linting**: `flutter_lints` defaults only (`analysis_options.yaml` has no custom rules). Keep code `flutter analyze`-clean.
- **Dead code note**: `lib/services/mock_data_service.dart` exists but is not referenced elsewhere; verify before building on it.

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

Supabase Edge Functions in `supabase/functions/` are TypeScript on Deno. Some have Deno tests (`_shared/hmac_test.ts`, `process_withdrawal/index.test.ts`):

```bash
cd supabase/functions && deno test --unstable --quiet
```

Deploy per `supabase/DEPLOYMENT_GUIDE.md` (Supabase CLI: `supabase db push`, `supabase functions deploy <name>`). CI (`deploy_edge_functions.yml`) runs Deno tests on push to `main` and deploys if `SUPABASE_ACCESS_TOKEN`/`SUPABASE_PROJECT_REF` secrets are set.

### Database migrations

SQL migrations in `supabase/migrations/` are applied in filename order via `supabase db push` or `psql -f`. **Caution**: there are two files numbered `001_*` and two numbered `002_*` — check actual file contents before adding a new migration; use the next free number (`010_...`).

## Testing Instructions

- Tests use `flutter_test`; currently only widget tests in `test/widget_test.dart` (e.g., `VerificationBadge`). There is no large test suite — add tests alongside new logic, especially for services/engines (matching, safety scoring, earnings) and new widgets.
- Keep tests independent of Supabase (no network); pump widgets inside a `MaterialApp` as in existing tests.
- Run `flutter test` and `flutter analyze` before considering a change done.

## Security Considerations

- **Secrets**: `SUPABASE_SERVICE_ROLE_KEY` and `ADMIN_API_SECRET` must never appear in client code — they are Edge Function environment variables only (set via `supabase secrets set`). The anon key in `lib/config/supabase_config.dart` is the publishable client key and relies on RLS for protection.
- **Row Level Security** is the primary authorization mechanism. Policies gate admin access via `users.is_admin`; see `supabase/migrations/006_admin_rls_policies.sql` and `SUPABASE_SCHEMA_UPGRADE.md`. When adding tables/columns, also add RLS policies and test them.
- **Anti-tamper**: Postgres triggers (e.g., `prevent_property_tamper`) block clients from modifying moderation fields like `is_approved`, `view_count`, `inquiry_count`, ratings, and safety scores. Don't attempt to write these from the client.
- **Payments**: Webhook Edge Functions (`payment_webhook`, `selcom-webhook`) verify provider signatures/HMAC (see `_shared/hmac.ts`). Preserve signature verification when editing payment flows.
- **KYC**: Sensitive identity data (NIDA integration, OCR, liveness) flows through `lib/services/kyc/` and the `process-kyc-verification` function; location data collection is opt-in and requires explicit user consent.
- New properties default to unapproved (`is_approved: false` / `listing_status: 'draft'`) pending admin moderation.

## CI/CD

- `.github/workflows/build.yml`: on push/PR to `main`/`master`, builds a release Android APK (Flutter 3.44.6, JDK 17, Android platform/build-tools 36, NDK 28.2.13676358, adds swap, `--no-tree-shake-icons`, arm64) and uploads it as an artifact.
- Release signing: `android/app/build.gradle` signs release builds with the upload keystore described by `android/key.properties` (gitignored) when that file exists; otherwise it falls back to the debug key so CI and local `flutter run --release` keep working.
- `.github/workflows/deploy_edge_functions.yml`: on push to `main`, runs Deno tests for Edge Functions and conditionally deploys them.

## Key Documentation Files

- `REQUIREMENTS.md` — module/feature specification (partially stale: says Firestore; backend is now Supabase)
- `SUPABASE_SCHEMA_UPGRADE.md` — schema for property registry, deals, agency fees, earnings + RLS examples
- `KYC_MODULE_DESIGN.md` — KYC module design
- `supabase/DEPLOYMENT_GUIDE.md` — current backend deployment guide (use this, not root `DEPLOY.md`)
- `DEPLOY.md`, `FIREBASE_SETUP.md` — **outdated** Firebase-era docs
