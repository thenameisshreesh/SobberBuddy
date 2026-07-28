# Release & Firebase Setup

## Firebase native apps

The RN app used the Firebase **web** SDK only. Flutter requires native Android/iOS apps registered in Firebase.

1. Open [Firebase Console](https://console.firebase.google.com/) → project **soberbuddy-8367f**
2. Add Android app with package `com.soberbuddy.rider`
3. Add iOS app with bundle ID `com.soberbuddy.rider`
4. Download config files:
   - `google-services.json` → `android/app/google-services.json`
   - `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist`
5. Regenerate Dart options (recommended):

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project=soberbuddy-8367f
```

Example templates (do not use in production): `android/app/google-services.json.example`, `ios/Runner/GoogleService-Info.plist.example`.

The Google Services Gradle plugin applies automatically when `android/app/google-services.json` exists.

## Android release signing

1. Copy `android/key.properties.example` → `android/key.properties`
2. Create or reuse the Play Console upload keystore (same as RN app for in-place update)
3. Fill in `storeFile`, `storePassword`, `keyAlias`, `keyPassword`
4. Build release AAB:

```powershell
cd SoberBuddyRiderF
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

**Important:** Release builds use `com.soberbuddy.rider` (no `.dev` suffix). Debug builds use `com.soberbuddy.rider.dev` for side-by-side testing.

## iOS TestFlight

1. Add `GoogleService-Info.plist` to Xcode Runner target
2. Configure signing in Xcode (Team, provisioning profile)
3. Build:

```powershell
flutter build ipa --release
```

## Store metadata

- App name (production): **SoberBuddy**
- Version: `1.0.2+10` (matches RN `app.json`)
- Package: `com.soberbuddy.rider`

See [E2E_QA.md](E2E_QA.md) for manual test checklist before release.
