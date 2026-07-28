# SoberBuddyDriver Flutter — Codebase Documentation

Flutter port of the SoberBuddyDriver React Native/Expo app. This is the **driver-side** companion app for the SoberBuddy ride-hailing platform (India, INR pricing).

## Project Overview

| Property | Value |
|----------|-------|
| Project path | `M:\me\Projects\SoberBuddyDriver\SoberBuddyDriverF` |
| Package name | `sober_buddy_driver` |
| Bundle ID | `com.soberbuddy.driver` |
| Version | 1.0.2+7 |
| Firebase project | `soberbuddy-8367f` |
| Source RN app | `M:\me\Projects\SoberBuddyDriver` |

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.35+ / Dart 3.9+ |
| State | `provider` (AuthProvider) |
| Navigation | `go_router` |
| Backend | Firebase Auth + Cloud Firestore |
| Maps | `google_maps_flutter` |
| Location | `geolocator` + `geocoding` |
| Images | `image_picker` + `flutter_image_compress` |
| Icons | `ionicons` |
| External links | `url_launcher` |

## Getting Started

```bash
cd M:\me\Projects\SoberBuddyDriver\SoberBuddyDriverF
flutter pub get
flutter run
```

### Firebase setup

1. Add Android/iOS apps to Firebase Console with bundle ID `com.soberbuddy.driver`
2. Run `flutterfire configure` to regenerate `lib/firebase_options.dart` with correct app IDs
3. Enable Email/Password auth in Firebase Console

### Google Maps setup

- API key is configured in `android/app/src/main/AndroidManifest.xml`
- For iOS, add the key in `ios/Runner/AppDelegate.swift` or Info.plist
- Restrict keys to your app package/bundle in Google Cloud Console

## Architecture

```
Screens → Providers → Services → Firestore
                ↓
            Widgets (shared UI)
```

### Auth gate

1. `AuthProvider` listens to `authStateChanges`
2. Loads `users/{uid}` from Firestore
3. Signs out if: no doc, `userType != 'driver'`, account deleted/inactive
4. `go_router` redirects unauthenticated users to `/login`

## Folder Structure

```
lib/
├── main.dart                    # Entry, splash delay, theme, Provider
├── firebase_options.dart        # Firebase config
├── app/
│   └── router.dart              # go_router routes + bottom nav shell
├── core/
│   ├── constants/
│   │   ├── app_constants.dart   # userType, bundle ID
│   │   └── theme.dart           # Colors, spacing, ThemeData
│   └── utils/
│       └── helpers.dart         # Fare calc, formatting
├── models/
│   └── trip_model.dart          # Trip document wrapper
├── services/
│   ├── firebase_service.dart    # Firebase init
│   ├── location_service.dart    # GPS + geocoding
│   └── trip_service.dart        # All Firestore trip operations
├── providers/
│   └── auth_provider.dart       # Auth state + login/signup/delete
├── guards/
│   └── user_type_guard.dart     # Driver-only guard
├── widgets/
│   ├── loading_spinner.dart
│   ├── map_component.dart
│   ├── shared_widgets.dart      # Inputs, buttons, cards, etc.
│   └── trip_alert_overlay.dart
└── screens/
    ├── auth/                    # Login, Signup, ForgotPassword
    ├── dashboard/               # Dashboard, Trip, TripCompletion
    ├── history/                 # Earnings, TripHistory, TripDetails, RatingHistory
    └── profile/                 # Profile, Help
```

## Navigation Map

### Auth routes (unauthenticated)
| Route | Screen |
|-------|--------|
| `/login` | LoginScreen |
| `/signup` | SignupScreen |
| `/forgot-password` | ForgotPasswordScreen |

### Tab routes (authenticated shell)
| Route | Tab | Screen |
|-------|-----|--------|
| `/drive` | Drive | DashboardScreen |
| `/earnings` | Earnings | EarningsScreen |
| `/profile` | Profile | ProfileScreen |

### Stack routes
| Route | Params | Screen |
|-------|--------|--------|
| `/trip` | `extra: TripModel` | TripScreen |
| `/trip-completion` | `extra: Map` | TripCompletionScreen |
| `/trip-history` | — | TripHistoryScreen |
| `/trip-details/:tripId` | path param | TripDetailsScreen |
| `/rating-history` | — | RatingHistoryScreen |
| `/help` | — | HelpScreen |

## Firestore Schema

### Collections

| Collection | Purpose |
|------------|---------|
| `users` | Account metadata, userType, status |
| `drivers` | Availability, location, stats, profile |
| `trips` | Ride lifecycle |
| `payments` | Payment records |
| `ratings` | Post-trip ratings |

### Trip status lifecycle

```
pending → accepted → in_progress → completed
        ↘ declined
        ↘ cancelled
```

## Business Rules

### Fare calculation (`lib/core/utils/helpers.dart`)

- Base fare: ₹350 (first 5 km / 30 min)
- Extra distance: ₹20/km after 5 km
- Extra time: ₹5/min after 30 min
- Night charge: ₹200 (10pm–6am)
- Driver earns **80%**, company **20%**

## Theme Reference

| Token | Value |
|-------|-------|
| primary | `#00D4AA` |
| accent | `#FF6B35` |
| background | `#121212` |
| surface | `#1E1E1E` |
| text | `#FFFFFF` |
| textSecondary | `#B3B3B3` |
| border | `#333333` |
| success | `#4CAF50` |
| error | `#F44336` |
| warning | `#FF9800` |

Spacing: 4 / 8 / 16 / 24 / 32 / 48 px  
Border radius: 8 / 12 / 16 px

## Widget Catalog

| Widget | File | Usage |
|--------|------|-------|
| LoadingSpinner | `widgets/loading_spinner.dart` | Full-screen loading |
| MapComponent | `widgets/map_component.dart` | Dark Google Map + markers |
| IconTextInput | `widgets/shared_widgets.dart` | Auth/profile inputs |
| PrimaryButton | `widgets/shared_widgets.dart` | Teal CTA buttons |
| SurfaceCard | `widgets/shared_widgets.dart` | Dark surface cards |
| LocationRow | `widgets/shared_widgets.dart` | Pickup/dropoff display |
| TripAlertOverlay | `widgets/trip_alert_overlay.dart` | Incoming trip modal |
| StarRating | `widgets/shared_widgets.dart` | 5-star rating UI |
| FilterPills | `widgets/shared_widgets.dart` | Trip history filters |
| EmptyState | `widgets/shared_widgets.dart` | List empty states |

## Screen Inventory (RN → Flutter mapping)

| RN Screen | Flutter Screen |
|-----------|----------------|
| `LoginScreen.js` | `screens/auth/login_screen.dart` |
| `SignupScreen.js` | `screens/auth/signup_screen.dart` |
| `ForgotPasswordScreen.js` | `screens/auth/forgot_password_screen.dart` |
| `DashboardScreen.js` | `screens/dashboard/dashboard_screen.dart` |
| `TripScreen.js` | `screens/dashboard/trip_screen.dart` |
| `TripCompletionScreen.js` | `screens/dashboard/trip_completion_screen.dart` |
| `EarningsScreen.js` | `screens/history/earnings_screen.dart` |
| `TripHistoryScreen.js` | `screens/history/trip_history_screen.dart` |
| `TripDetailsScreen.js` | `screens/history/trip_details_screen.dart` |
| `RatingHistoryScreen.js` | `screens/history/rating_history_screen.dart` |
| `ProfileScreen.js` | `screens/profile/profile_screen.dart` |
| `HelpScreen.js` | `screens/profile/help_screen.dart` |

## RN → Flutter Dependency Mapping

| React Native | Flutter |
|--------------|---------|
| `firebase` | `firebase_core`, `firebase_auth`, `cloud_firestore` |
| `@react-navigation/*` | `go_router` |
| React Context | `provider` |
| `react-native-maps` | `google_maps_flutter` |
| `expo-location` | `geolocator`, `geocoding` |
| `expo-image-picker` | `image_picker` |
| `expo-image-manipulator` | `flutter_image_compress` |
| `@expo/vector-icons` | `ionicons` |
| `Alert.alert` | `showDialog` / `SnackBar` |
| `Linking.openURL` | `url_launcher` |

## Platform Config

### Android permissions
- `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `CAMERA`, `RECORD_AUDIO`

### iOS permissions (Info.plist)
- Location (when-in-use + always), Camera, Photo Library

## Known Differences from RN

1. **Payment confirmation** — RN attempts doc ID `{tripId}_payment`; Flutter matches this behavior with fallback on error
2. **TripHistory row tap** — RN has navigation commented out; Flutter matches (no navigation on tap)
3. **Help sub-routes** — `ReportIssue` / `SafetyGuidelines` not implemented (see `future-features.md`)
4. **Profile Help/Rating links** — Commented out in RN; not in active Flutter UI
5. **Firebase app IDs** — `firebase_options.dart` uses placeholder Android/iOS app IDs; run `flutterfire configure` for production

## Future Features

See [future-features.md](future-features.md) for commented-out RN features not included in this migration.

## Manual Test Checklist

- [ ] Signup creates `users` + `drivers` docs
- [ ] Login rejects non-driver accounts
- [ ] Dashboard online toggle updates Firestore
- [ ] Trip alert accept/decline works
- [ ] Active trip: start, complete, payment, rating
- [ ] Passenger cancellation resets driver
- [ ] Earnings and trip history load
- [ ] Profile edit + photo upload
- [ ] Sign out + account deletion
- [ ] Help FAQ and contact links
