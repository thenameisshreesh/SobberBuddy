# Driver App — Release

Same Play Store listing as the React Native/Expo app (`com.soberbuddy.driver`).

## Version

- `pubspec.yaml`: `1.0.3+17` (Android versionCode 17, above RN `7`; iOS build above RN `16`)

## Signing

1. `android/key.properties` points to RN EAS keystore (gitignored)
2. Build:

```powershell
cd SoberBuddyDriverF
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

See root [PUBLISH.md](../../PUBLISH.md) for full checklist.
