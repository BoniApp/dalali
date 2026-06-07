# Dalali / HTN — Deployment Guide

> Complete deployment instructions for the Housing Transition Network Flutter + Firebase application.

---

## 📋 Pre-Deployment Checklist

Before deploying, ensure:

- [ ] `flutter doctor` passes with no critical errors
- [ ] Firebase project `dalali-83f65` is active
- [ ] `firebase login` has been run (required for Firebase deploys)
- [ ] Android keystore is configured (for release APK)
- [ ] iOS provisioning profile is set (for iOS builds)

---

## 1. Firebase Backend Deployment

### 1.1 Authenticate Firebase CLI

```bash
firebase login
```

This opens a browser window. Sign in with the Google account that owns the `dalali-83f65` Firebase project.

### 1.2 Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

**What this deploys:**
- 368 lines of role-based security rules
- Anti-tamper protection for moderation fields
- Tenant/landlord isolation for tenancy lifecycle collections
- New rules for: `tenancy_applications`, `tenancies`, `maintenance_requests`, `rent_schedules`, `move_checklists`, `agreements`, `handover_reports`

### 1.3 Deploy Firestore Indexes

```bash
firebase deploy --only firestore:indexes
```

**What this deploys:**
- 25 composite indexes across all collections
- Includes new indexes for tenancy collections
- Takes ~2-5 minutes to build after deployment

### 1.4 Seed Demo Data (Optional)

```bash
# Run from the project root
flutter run -t lib/utils/seed_firestore.dart -d windows
```

Or use the seeder from a dev screen:
```dart
await FirestoreSeeder().seedAll(mode: SeedMode.demoLarge);
```

---

## 2. Android Deployment

### 2.1 Debug APK (For Testing)

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### 2.2 Release APK

**Prerequisite:** Configure signing keystore

Create `android/key.properties`:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=your_key_alias
storeFile=../app/your-keystore.jks
```

Update `android/app/build.gradle` signing config (already partially set up).

Then build:
```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 2.3 App Bundle (Google Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

---

## 3. iOS Deployment

### 3.1 Build iOS Release

```bash
flutter build ios --release
```

### 3.2 Archive & Upload via Xcode

```bash
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release archive -archivePath build/Runner.xcarchive
```

Then open Xcode and distribute via Organizer.

---

## 4. Web Deployment

### 4.1 Build Web App

```bash
flutter build web --release
```

### 4.2 Deploy to Firebase Hosting

```bash
firebase deploy --only hosting
```

**Note:** Web Firebase config in `lib/firebase_options.dart` currently has placeholder values. Update with real web credentials from Firebase Console → Project Settings → Web App before deploying.

---

## 5. Post-Deployment Verification

### 5.1 Test Core Flows

| Flow | Steps |
|---|---|
| **Auth** | Register → Login → Logout |
| **Property Listing** | Landlord adds property → appears in feed |
| **Reservation** | Seeker applies → Landlord approves → Tenancy created |
| **Maintenance** | Tenant submits → Landlord resolves |
| **Rent Payment** | Schedule shows due → Mark paid |
| **Move Checklist** | Toggle items → Progress updates |

### 5.2 Check Firebase Console

- [ ] Firestore Database: Collections populated
- [ ] Authentication: Users registered
- [ ] Storage: Images uploaded (if tested)
- [ ] Rules Playground: Test read/write permissions

---

## 6. Production Checklist

### 6.1 Security

- [ ] Firestore rules deployed and tested
- [ ] Firestore indexes deployed
- [ ] Firebase Auth email verification enabled
- [ ] Cloud Functions deployed (if implemented)
- [ ] API keys restricted (Android/iOS apps only)

### 6.2 Performance

- [ ] Offline persistence enabled
- [ ] Images optimized/compressed before upload
- [ ] Pagination tested on large datasets
- [ ] Memory leaks checked (profile mode)

### 6.3 Monitoring

- [ ] Firebase Crashlytics enabled
- [ ] Firebase Analytics events added
- [ ] Performance monitoring traces added

---

## 7. Cloud Functions (Future)

Deploy these serverless functions for full automation:

```bash
cd functions && firebase deploy --only functions
```

**Functions to implement:**
- `sendRentReminder` — Daily cron: notify tenants 7/3/0 days before due date
- `autoCompleteTenancy` — Trigger: mark tenancy complete on move-out date
- `recomputeSafetyScores` — Trigger: update property safety on new reports
- `notifyLandlordOfApplication` — Trigger: FCM push on new reservation
- `notifyTenantOfMaintenanceUpdate` — Trigger: FCM push on status change

---

## 8. Troubleshooting

### Gradle build fails / Out of memory
```bash
# Already fixed in android/gradle.properties:
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=512m
```

### Missing index errors
Deploy indexes and wait 2-5 minutes:
```bash
firebase deploy --only firestore:indexes
```

### Permission denied on Firestore
1. Check rules deployed: `firebase deploy --only firestore:rules`
2. Verify user is authenticated
3. Check role field exists in user document

### APK build too slow (first time)
Gradle downloads dependencies on first build. Subsequent builds are fast.
```bash
# Pre-download dependencies
flutter precache --android
```

### iOS build fails
```bash
cd ios && pod install --repo-update
```

---

## 9. Environment Summary

| Service | Project ID | Status |
|---|---|---|
| Firebase Project | `dalali-83f65` | ✅ Active |
| Firestore Database | `(default)` | ✅ Configured |
| Firebase Auth | Email/Password | ✅ Enabled |
| Firebase Storage | `dalali-83f65.appspot.com` | ✅ Enabled |
| Firebase Hosting | `dalali-83f65.web.app` | ⚠️ Web config placeholder |
| Cloud Functions | — | ❌ Not deployed |
| FCM Notifications | — | ❌ Not configured |

---

## 10. Quick Commands Reference

```bash
# Full Firebase deploy
firebase deploy

# Deploy only rules
firebase deploy --only firestore:rules

# Deploy only indexes
firebase deploy --only firestore:indexes

# Deploy only hosting
firebase deploy --only hosting

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build app bundle
flutter build appbundle --release

# Build web
flutter build web --release

# Run tests
flutter test

# Analyze code
flutter analyze

# Clean build
flutter clean && flutter pub get
```
