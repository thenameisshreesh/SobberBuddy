# SoberBuddy Rider Flutter — Codebase Context

> Attach this file to every Cursor prompt for this project.
> Last updated: 2026-07-03 | Migration phase: 6/8 (feature complete, polish/release pending)

## Quick Facts

- **App:** Consumer ride-hailing (NOT driver app)
- **Package:** `com.soberbuddy.rider` | **Firebase:** `soberbuddy-8367f`
- **Stack:** Flutter + Riverpod + go_router + Firebase + Google Maps
- **RN reference:** `M:\me\Projects\SoberBuddyRider\` (Expo/React Native)
- **Flutter project:** `M:\me\Projects\SoberBuddyRider\SoberBuddyRiderF\`

## Current Migration Status

See [docs/MIGRATION_STATUS.md](docs/MIGRATION_STATUS.md).

## Architecture

```
lib/
├── main.dart, app.dart
├── firebase_options.dart
├── core/constants/     # theme, pricing, app_config
├── core/router/        # go_router
├── core/utils/         # helpers (fare, distance, dates)
├── core/widgets/       # LoadingSpinner, BlockedUserMessage
├── features/
│   ├── auth/           # login, signup, forgot password
│   ├── booking/        # home, confirmation, terms, finding driver
│   ├── trip/           # trip details (realtime)
│   ├── payment/        # payment summary + rating
│   ├── history/        # trip list + stats
│   └── profile/        # edit profile, photo, delete account
└── services/           # firebase, trip, payment, rating, location, places
```

## Routes (go_router)

| Route | Screen | Status |
|-------|--------|--------|
| `/splash` | Splash (2s) | Done |
| `/login` | LoginScreen | Done |
| `/signup` | SignupScreen | Done |
| `/forgot-password` | ForgotPasswordScreen | Done |
| `/home` | HomeScreen (Book Ride) | Done |
| `/history` | HistoryScreen | Done |
| `/profile` | ProfileScreen | Done |
| `/booking-confirmation` | BookingConfirmationScreen | Done |
| `/terms` | TermsConditionsScreen | Done |
| `/booking` | BookingScreen (Finding Driver) | Done |
| `/trip-details` | TripDetailsScreen | Done |
| `/payment-summary` | PaymentSummaryScreen | Done |

## Firestore Collections

`users`, `drivers`, `trips`, `payments`, `ratings`, `fees` — see [docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md)

## Business Rules

See [docs/BUSINESS_RULES.md](docs/BUSINESS_RULES.md). DO NOT change pricing/cancellation logic without approval.

## Theme

| Token | Value |
|-------|-------|
| primary | `#205090` |
| accent | `#FF6B35` |
| background | `#121212` |
| surface | `#1E1E1E` |

## Key Files When Working On...

| Task | Read First |
|------|-----------|
| Auth | `lib/features/auth/`, `lib/services/firebase_service.dart` |
| Booking | `lib/features/booking/`, `lib/services/trip_service.dart` |
| Maps | `lib/features/booking/widgets/`, `lib/services/location_service.dart` |
| Profile | `lib/features/profile/` |
| Navigation | `lib/core/router/app_router.dart` |

## Setup Requirements

1. Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) from Firebase console for native Firebase apps
2. Google Maps API key is in `lib/core/constants/app_config.dart` and platform manifests
3. Run: `cd SoberBuddyRiderF && flutter pub get && flutter run`

## Prompt Instructions for AI

1. Read this file + relevant `docs/` file only
2. Match existing Riverpod/go_router patterns
3. Preserve Firestore field names exactly (driver app compatibility)
4. Update `docs/MIGRATION_STATUS.md` when completing a feature
