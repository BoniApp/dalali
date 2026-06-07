# Housing Transition Network (HTN) — Firebase Setup Guide

This project uses **Firebase Firestore** as the cloud database for a housing mobility system where users list homes while moving, find new homes, and build trust through reviews and utility transparency.

---

## Collections Overview

| Collection                | Purpose                                                         |
|--------------------------|-----------------------------------------------------------------|
| `users`                  | Profiles with roles, verification, move mode, rewards           |
| `properties`             | Rental listings with **utility transparency** & source type     |
| `move_listings`          | User move records — current home listed while searching         |
| `reviews`                | Verified stay reviews (property + landlord dimensions)          |
| `favorites`              | Saved properties                                                |
| `appointments`           | Property viewing bookings                                       |
| `inquiries`              | Messages from seekers to landlords                              |
| `rewards`                | HTN reward points for moves, listings, reviews, referrals       |
| `tenancy_applications`   | Reservation requests (pending → approved → rejected)            |
| `tenancies`              | Active lease records with move-in/out dates                     |
| `maintenance_requests`   | Tenant-submitted repair tickets                                 |
| `rent_schedules`         | Monthly rent due dates & payment status                         |
| `move_checklists`        | Move preparation task lists                                     |
| `agreements`             | Digital tenancy agreement storage                               |
| `handover_reports`       | Property condition & meter readings at move-in                  |

---

## 1. Deploy Security Rules

```bash
firebase deploy --only firestore:rules
```

### Rule highlights:
- **Authentication required** for all writes
- **Role-based access**: seekers, landlords, agents
- **Anti-tamper**: clients cannot write moderation/engagement fields (`isApproved`, `isBoosted`, `viewCount`, `rating`, etc.)
- **New listings default to `isApproved: false`** — requires agent moderation
- **Move listings** are public read; only owner can write
- **Reviews** are public read; authenticated users can submit (app enforces verified stays)
- **Rewards** are read-only for users; only admins/cloud functions create them

---

## 2. Deploy Indexes

```bash
firebase deploy --only firestore:indexes
```

**Key indexes:**
- `properties`: multi-field filters for feed, featured, landlord, price, location
- `appointments`: by seeker/landlord + scheduled date
- `inquiries`: by property + created date
- `move_listings`: by status + created date; by user + created date
- `reviews`: by property + created date
- `rewards`: by user + created date

---

## 3. Seed Demo Data

```bash
# Small dataset (default)
flutter run -t lib/utils/seed_firestore.dart -d windows

# Large dataset (50+ extra properties, appointments, reviews, moves)
# Edit seed_firestore.dart main() → SeedMode.demoLarge
flutter run -t lib/utils/seed_firestore.dart -d windows
```

Or from a dev screen:
```dart
await FirestoreSeeder().seedAll(mode: SeedMode.demoLarge);
```

---

## 4. Collection Schema

### `users`
```json
{
  "fullName": "string",
  "email": "string",
  "phone": "string",
  "role": "seeker | landlord | agent",
  "verificationStatus": "unverified | pending | verified",
  "isPhoneVerified": "boolean",
  "profileImage": "string | null",
  "createdAt": "timestamp",
  "nationalId": "string | null",
  "agentLicense": "string | null",
  "subscriptionTier": "number",
  "isVerifiedLandlord": "boolean",
  "lastActive": "timestamp | null",
  "savedSearches": ["string"],
  "preferredLocations": ["string"],
  "moveMode": "none | planning | active",
  "activeMoveListingId": "string | null",
  "totalRewardPoints": "number"
}
```

### `properties`
```json
{
  "title": "string",
  "description": "string",
  "location": "string",
  "latitude": "number",
  "longitude": "number",
  "rentPrice": "number",
  "bedrooms": "number",
  "bathrooms": "number",
  "propertyType": "apartment | house | villa | bedsitter | office | shop",
  "isFurnished": "boolean",
  "hasWater": "boolean",
  "hasParking": "boolean",
  "hasSecurity": "boolean",
  "sharedCompound": "boolean",
  "hasBorehole": "boolean",
  "images": ["string (URL)"],
  "videoUrl": "string | null",
  "status": "available | occupied | pending",
  "listingType": "basic | featured",
  "sourceType": "landlordListing | userMoveListing | agentListing",
  "landlordId": "string",
  "landlordName": "string",
  "landlordPhone": "string",
  "isLandlordVerified": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp | null",
  "viewCount": "number",
  "inquiryCount": "number",
  "isApproved": "boolean",
  "rating": "number (0-5)",
  "reviewCount": "number",
  "isBoosted": "boolean",
  "boostExpiresAt": "timestamp | null",
  "tags": ["string"],
  "utilities": {
    "water": "tenant | landlord | shared",
    "electricity": "tenant | landlord | shared",
    "internet": "included | tenant | notAvailable",
    "wasteCollection": "tenant | landlord | shared",
    "security": "included | notIncluded"
  }
}
```

### `move_listings`
```json
{
  "userId": "string",
  "userName": "string",
  "currentPropertyId": "string | null",
  "currentPropertyTitle": "string",
  "currentLocation": "string",
  "moveDate": "timestamp",
  "status": "planning | active | completed | cancelled",
  "newPropertyId": "string | null",
  "budgetMin": "number | null",
  "budgetMax": "number | null",
  "preferredLocation": "string | null",
  "createdAt": "timestamp",
  "updatedAt": "timestamp | null"
}
```

### `reviews`
```json
{
  "propertyId": "string",
  "propertyTitle": "string",
  "reviewerId": "string",
  "reviewerName": "string",
  "stayVerified": "boolean",
  "cleanliness": "number (1-5)",
  "valueForMoney": "number (1-5)",
  "safety": "number (1-5)",
  "communication": "number (1-5)",
  "fairness": "number (1-5)",
  "maintenance": "number (1-5)",
  "comment": "string | null",
  "createdAt": "timestamp"
}
```

### `rewards`
```json
{
  "userId": "string",
  "type": "listingBonus | referral | moveComplete | reviewSubmitted",
  "points": "number",
  "description": "string",
  "createdAt": "timestamp",
  "claimed": "boolean",
  "claimedAt": "timestamp | null"
}
```

### `favorites`, `appointments`, `inquiries`
*(Same as before — see original schema)*

---

## 5. Services Architecture

| Service | Purpose |
|---------|---------|
| `FirestoreService` | CRUD + pagination for all 8 collections |
| `MoveEngineService` | Start / activate / complete / cancel moves; auto-list current home |
| `MatchingEngine` | Score properties against move budgets, locations, utilities |
| `ReviewService` | Submit reviews; calculate property averages |
| `RewardService` | Award points for listings, moves, reviews, referrals |
| `RecommendationEngine` | General property scoring (quality, engagement, personalization) |
| `FirebaseAuthService` | Auth + user data sync |

---

## 6. Performance Checklist

- [ ] **Pagination** — all list queries use `.limit()` + `startAfterDocument()`
- [ ] **Offline persistence** — call `FirestoreService().enableOfflinePersistence()` on app start
- [ ] **Batch writes** — seeder uses 450-doc batches (under Firestore's 500 limit)
- [ ] **Composite indexes** — deployed for every multi-field query
- [ ] **Security rules** — deployed to prevent data tampering

---

## Troubleshooting

### Gradle memory error
Fixed in `android/gradle.properties`. JVM heap reduced to 2GB.

### Missing index errors
Deploy indexes (`firebase deploy --only firestore:indexes`). They take a few minutes to build.

### Permission denied
Ensure `firestore.rules` are deployed and user is authenticated.
