# Driver App — Release

Same Play Store listing as the React Native/Expo app (`com.soberbuddy.driver`).

## Version

- `pubspec.yaml`: `1.0.3+17` (Android versionCode 17, above RN `7`; iOS build above RN `16`)

## Signing

1. `android/key.properties` points to RN EAS keystore (gitignored)
2. Release builds **fail** if `key.properties` is missing (no debug-signing fallback)
3. Build:

```powershell
cd SoberBuddyDriverF
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

## Phone OTP (2Factor)

Driver OTP uses **2Factor.in** via Cloud Functions (`sendPhoneOtp` / `verifyPhoneOtp`), then Firebase `signInWithCustomToken`. See [`functions/OTP.md`](../../functions/OTP.md) for secret setup and deploy.

Firebase Phone Auth SMS / SHA fingerprints are **not** required for Driver OTP anymore.

See root [PUBLISH.md](../../PUBLISH.md) for full release checklist.
