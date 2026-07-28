# Migration Status

Last updated: 2026-07-03

## Phase 0 — Bootstrap
- [x] Flutter project created at `SoberBuddyRiderF`
- [x] Dependencies configured
- [x] Assets copied from RN
- [x] `codebase.md` + docs created
- [x] Android/iOS permissions + Maps API key

## Phase 1 — Foundation
- [x] Theme (`app_theme.dart`)
- [x] Pricing/helpers (`pricing.dart`, `helpers.dart`)
- [x] Firebase service
- [x] Riverpod auth provider
- [x] go_router shell
- [x] LoadingSpinner, BlockedUserMessage

## Phase 2 — Auth
- [x] LoginScreen
- [x] SignupScreen
- [x] ForgotPasswordScreen
- [x] Consumer guard + deleted account check

## Phase 3 — Booking
- [x] HomeScreen + MapWidget
- [x] LocationAutocomplete (Google Places)
- [x] VehicleSelector
- [x] BookingConfirmationScreen
- [x] TermsConditionsScreen
- [x] BookingScreen (finding driver)

## Phase 4 — Trip Lifecycle
- [x] TripDetailsScreen (realtime)
- [x] Cancellation/block logic
- [x] PaymentSummaryScreen + rating
- [x] trip/payment/rating services

## Phase 5 — History & Profile
- [x] HistoryScreen
- [x] ProfileScreen (photo, edit, delete)
- [x] ProfileEditButton

## Phase 6 — Polish
- [x] Tab bar icons/labels match RN
- [x] Tab focus refresh on Home/History (`shell_tab_notifier.dart`)
- [x] Support contacts in `AppConfig` (used by BlockedUserMessage)
- [x] Trip summary bottom sheet for completed/cancelled history items
- [x] Unit tests for pricing logic (`test/helpers_test.dart`)
- [ ] End-to-end device testing — see [E2E_QA.md](E2E_QA.md)

## Phase 7 — Release
- [x] Google Services Gradle plugin wired (conditional on `google-services.json`)
- [x] Firebase config templates (`google-services.json.example`, `GoogleService-Info.plist.example`)
- [x] Release signing scaffold (`key.properties.example`, conditional release keystore in `build.gradle.kts`)
- [x] Release guide — [RELEASE.md](RELEASE.md)
- [ ] Copy real `google-services.json` / `GoogleService-Info.plist` from Firebase Console
- [ ] Run `flutterfire configure` to replace placeholder app IDs in `firebase_options.dart`
- [ ] Android release AAB with production keystore
- [ ] iOS TestFlight build

## Parity audit (2026-07-03)

All active RN screens, business rules, and T&C content are covered in Flutter. See plan `rn_flutter_parity_audit`.
