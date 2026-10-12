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

### Phone OTP — 2Factor (Rider & Driver)

Rider/Driver SMS OTP is sent by **2Factor.in** through Cloud Functions; apps sign in with a Firebase custom token. The 2Factor API key must be stored as a Functions secret (never in the apps).

```powershell
cd M:\me\Projects\SoberBuddyF
firebase functions:secrets:set TWOFACTOR_API_KEY
firebase deploy --only functions:sendPhoneOtp,functions:verifyPhoneOtp
```

Details: [`functions/OTP.md`](functions/OTP.md).

Firebase Console **Phone** sign-in / SHA fingerprints are no longer required for Rider/Driver OTP.

**Local fingerprints (this machine):**

| Cert | SHA-1 | SHA-256 |
|------|-------|---------|
| Debug | `7F:1A:69:9B:D2:22:20:F9:97:A5:0C:F5:1A:D6:16:22:BD:18:36:52` | `8D:78:14:5C:45:66:78:E3:30:F1:0D:2B:4E:2D:31:68:AD:1D:31:77:27:BD:89:F3:1A:FB:FC:6B:68:F1:BC:12` |
| Rider release | `69:24:BA:51:FE:92:7E:E4:E1:5B:62:8A:96:90:54:6C:BF:99:6E:90` | `8F:BE:AC:E6:6E:76:8D:A8:26:32:C3:D6:55:F0:87:D1:2D:49:2B:BC:A9:5F:A3:72:AB:3D:D9:A8:63:EA:1E:DA` |
| Driver release | `D7:FF:69:2C:5E:7E:3A:F3:B7:8D:21:F8:5D:5A:95:49:C8:37:CF:47` | `24:2F:C3:03:B3:78:A6:31:6E:40:26:B8:86:23:E9:B2:7B:61:1C:11:B3:E7:59:5F:A0:47:DD:F1:FE:65:BC:56` |

For Play Store installs, also add SHA from **Play Console → App → Setup → App signing → App signing key certificate**.

After adding fingerprints, wait a few minutes, then reinstall a fresh release build.

## Pre-upload checklist

- [ ] Test release APK/AAB on a physical device
- [ ] Rider: book trip end-to-end
- [ ] Driver: go online, accept trip, complete
- [ ] Admin dashboard shows trips
- [ ] OTP login works (rider + driver test accounts)

See `SoberBuddyRiderF/docs/E2E_QA.md` for full QA.
