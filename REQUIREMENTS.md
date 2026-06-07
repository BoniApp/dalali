# Dalali / HTN — Project Requirements

> **Housing Transition Network (HTN)** — A comprehensive housing and relocation ecosystem for Tanzanian cities and beyond.

---

## 🎯 Vision

The platform is:

- 🏠 **Housing Transition Network**
- 🚚 **Relocation Management System**
- 🛡️ **Neighbourhood Safety Network**
- 📊 **Housing Intelligence Dashboard**
- 📍 **Location-Aware Urban Living Platform**

This makes HTN far more than a rental app — it becomes a complete housing and relocation ecosystem for cities such as Dar es Salaam and beyond.

---

## 📦 Modules

### 1. Core Property Listing & Search
- Property listings with images, pricing, amenities
- Role-based access (Seeker, Landlord, Agent)
- Favorites, appointments, and inquiries
- Verification system for landlords & agents

### 2. Move Engine
- `MoveListingModel` for users planning a move
- Start-a-move flow with budget & date preferences
- Move Dashboard with status tracking (`planning`, `active`, `completed`)
- Automatic property sourcing from move listings

### 3. Utility Transparency
- `PropertyUtilities` model (water, electricity, internet, waste, security)
- Responsibility mapping: tenant vs landlord vs shared
- `UtilityDisplay` widget on property detail screens

### 4. Reviews & Reputation
- 6-dimension rating system (cleanliness, value, safety, communication, fairness, maintenance)
- Verified-stay gating (only verified tenants can review)
- Reviews screen with aggregated scores

### 5. Rewards System
- Point accrual for platform actions
- `RewardModel` with claim/expiration logic
- Dashboard integration in user profile

### 6. Matching Engine
- Budget, location, move-date, and utility-preference scoring
- Compatibility ranking between seekers and properties

### 7. Neighbourhood Watch & Safety
- `NeighbourhoodReportModel` for incident reporting
- `SafetyEngine` with time-decay haversine scoring (1.5km radius, 30-day half-life, 90-day cutoff)
- Severity weights: Low=1, Medium=3, High=6, Critical=10
- `ReportService` with anti-spam rate limiting (5/day, 10-min cooldown)
- `SafetyBadge` widget on property cards and detail screens
- `NeighbourhoodSafetyScreen` with live map of incidents

### 8. Personalization & Localization
- `UserPreferencesModel`: theme mode + language
- `ThemeProvider` with Material 3 + SharedPreferences persistence
- `LanguageProvider` supporting English (`en`) and Kiswahili (`sw`)
- ARB localization files (`app_en.arb`, `app_sw.arb`)
- `SettingsScreen` for theme and language selection
- Firestore sync for cross-device preference persistence

---

## ➕ Location Intelligence Module *(New)*

Implement phone location integration throughout the application.

### Requirements
- Request location permission using platform best practices.
- Support:
  - **Current location** — real-time device position for nearby discovery
  - **Background-safe location usage** where OS permits (for commute tracking and safety alerts)
  - **Manual location selection** if permission is denied (map pin drop or area search)

### Features
| Feature | Description |
|---|---|
| **Nearby property discovery** | Surface properties within a configurable radius of the user's current location |
| **Map-based property search** | Full-screen interactive map showing all available listings as clustered pins |
| **Distance calculations** | Haversine distance from user to each property, with walking/driving time estimates |
| **Nearby POI discovery** | Schools, hospitals, markets, and transport stops within property vicinity |
| **Neighbourhood safety integration** | Overlay incident heatmap on the explore map; filter properties by safety score |
| **Housing demand heatmaps** | Aggregate search and inquiry density to visualize high-demand zones |
| **Move recommendation engine** | Suggest target neighborhoods based on commute time, budget, and safety preferences |
| **Commute estimation** | Estimate travel time from a property to user-defined work/school locations |
| **Area insights & housing intelligence** | Average rent, vacancy rate, safety score, and trend indicators per neighborhood |

### Data

Store for **all properties**:
- `latitude` — double
- `longitude` — double
- `geohash` — string (for Firestore geospatial indexing and radius queries)

Store for **users** (optional, with consent):
- `lastKnownLatitude`
- `lastKnownLongitude`
- `preferredCommuteLocation` (work/school lat/lng)

### UI

Create the following screens:

| Screen | Purpose |
|---|---|
| **Nearby Homes** | List of properties sorted by distance from current/manual location; filter by radius |
| **Explore Map** | Full-screen map with property pins, POI layers, safety heatmap toggle, and demand overlay |
| **Area Insights** | Neighborhood-level dashboard: avg rent, safety score, vacancy, trends, commute stats |

### Architecture
- **Google Maps Flutter** (`google_maps_flutter`) for primary map rendering on mobile
- **Geohash** encoding (`geohash` package or custom impl) for scalable Firestore queries
- **Firestore queries** using geohash prefix range scans for sub-second radius searches
- **Fallback**: OpenStreetMap + `flutter_map` for web or where Google Maps is unavailable
- **Permissions**: `geolocator` package for cross-platform location permission handling

---

## 🛡️ Security & Compliance

- Firestore security rules with role-based access control
- Anti-tamper fields (clients cannot write `isApproved`, `isBoosted`, `viewCount`, `inquiryCount`, `rating`, `reviewCount`, `safetyScore`, `incidentCount`)
- New properties default to `isApproved: false`
- Location data collection requires explicit user consent and must be opt-in

---

## 🌍 Localization

- English (`en`) and Kiswahili (`sw`)
- Full ARB-based localization across all user-facing screens
- Right-to-left layout readiness for future Arabic support

---

## 📱 Supported Platforms

- Android
- iOS
- Web (progressive, with feature degradation where APIs are unavailable)

---

## 🗄️ Firestore Collections

| Collection | Purpose |
|---|---|
| `users` | Identity, preferences, verification, move state, reward points |
| `properties` | Listings with utilities, safety score, geohash, images |
| `appointments` | Viewing schedules between seekers and landlords |
| `inquiries` | Messages/questions about listings |
| `favorites` | Seeker-saved properties |
| `move_listings` | HTN move engine entries |
| `reviews` | Verified-stay reviews with 6-dimension ratings |
| `rewards` | Point accrual and redemption records |
| `neighbourhood_reports` | Safety incidents with severity and reporter trust |
