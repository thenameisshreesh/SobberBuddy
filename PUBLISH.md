# SoberBuddy — Play Store Release (Flutter update over React Native)

Version **1.0.3** replaces the Expo/React Native builds on the same store listings.

| App | Package | Version | AAB output |
|-----|---------|---------|------------|
| **SoberBuddy** (Rider) | `com.soberbuddy.rider` | `1.0.3+11` | `SoberBuddyRiderF/build/app/outputs/bundle/release/app-release.aab` |
| **SoberBuddyDriver** | `com.soberbuddy.driver` | `1.0.3+17` | `SoberBuddyDriverF/build/app/outputs/bundle/release/app-release.aab` |

## Build (Windows)

**Important:** Your **C: drive needs free space** (Gradle/Android use it for paging). If builds fail with OOM or "paging file too small", free several GB on C: and set temp/cache to M::

```powershell
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:GRADLE_USER_HOME="M:\me\Projects\SoberBuddyF\.gradle"
$env:TEMP="M:\me\Projects\SoberBuddyF\.tmp"
$env:TMP="M:\me\Projects\SoberBuddyF\.tmp"
$env:GRADLE_OPTS="-Xmx2048m -Djava.io.tmpdir=M:/me/Projects/SoberBuddyF/.tmp"
```

Keystore credentials are read from `android/key.properties` (gitignored), pointing to the original RN/EAS keystores under `M:\me\Projects\SoberBuddyRN\`.

```powershell
# Rider — DONE (see release/ folder)
cd M:\me\Projects\SoberBuddyF\SoberBuddyRiderF
flutter pub get
flutter build appbundle --release

# Driver — run after freeing C: disk space
cd M:\me\Projects\SoberBuddyF\SoberBuddyDriverF
flutter pub get
flutter build appbundle --release
```

**Ready to upload (Rider):** `M:\me\Projects\SoberBuddyF\release\SoberBuddy-rider-1.0.3+11.aab`

## Upload to Google Play Console

1. Open [Google Play Console](https://play.google.com/console)
2. **SoberBuddy** → Production (or Internal testing first) → Create new release
3. Upload `app-release.aab` from Rider build
4. Repeat for **SoberBuddyDriver** with Driver AAB
5. Release notes example:
   > Flutter app update — improved trip booking, driver broadcast, admin integration, and stability fixes.

**Important:** Upload keys must match the existing RN app (same `.jks` from EAS credentials). Version codes must be higher than the live RN build (Rider > 10, Driver > 7).

## iOS (requires Mac)

- Rider bundle ID: `com.soberbuddy.rider`
- Driver bundle ID: `com.soberbuddy.driver`
- Build: `flutter build ipa --release`
- Upload via Transporter or Xcode Organizer to App Store Connect

## Firebase

- Project: `soberbuddy-8367f`
- Production Rider Android app registered: `com.soberbuddy.rider`
- Debug Rider builds use `com.soberbuddy.rider.dev` (side-by-side with Play Store app)

## Pre-upload checklist

- [ ] Test release APK/AAB on a physical device
- [ ] Rider: book trip end-to-end
- [ ] Driver: go online, accept trip, complete
- [ ] Admin dashboard shows trips
- [ ] OTP login works (rider + driver test accounts)

See `SoberBuddyRiderF/docs/E2E_QA.md` for full QA.
