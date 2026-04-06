# Vibes

A modern video player app with TikTok-style vertical scrolling, likes, and notes.

## Features

- Vertical swipe video feed
- Support for multiple video formats (mp4, mov, mkv, webm, avi, m4v, 3gp)
- Like and save notes per video
- Auto-shuffle and loop
- Modern Gen-Z aesthetic UI
- Screen stays awake during playback

## Build Commands

### Debug Build
```bash
flutter run
```

### Release APK (Direct Install)
```bash
flutter build apk --release
```

### Release App Bundle (Play Store)
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
```

### Split APKs by Architecture
```bash
flutter build apk --release --split-per-abi
```

Output locations:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

---

## Signing Credentials

| Property | Value |
|----------|-------|
| Keystore | `android/app/vibes-upload-key.jks` |
| Alias | `vibes` |
| Password | `vibes2024` |
| Valid Until | Aug 2053 |

### Certificate Fingerprint (SHA256)
```
A4:A1:B1:E4:F4:D6:5D:72:65:3C:1D:89:2B:A3:B6:DA:DB:50:05:57:84:EF:3C:92:38:33:9F:38:8D:93:59:DC
```

### Manual Signing (if needed)
```bash
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore android/app/vibes-upload-key.jks \
  -storepass vibes2024 \
  your-app.apk vibes
```

### Verify Signature
```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

---

## App Info

| Property | Value |
|----------|-------|
| Package ID | `com.axvrma.vibes` |
| App Name | Vibes |
| Version | 1.0.0+1 |

---

## Project Structure

```
lib/
└── main.dart          # Main app code

android/
├── app/
│   ├── vibes-upload-key.jks    # Upload keystore
│   ├── proguard-rules.pro      # ProGuard config
│   └── build.gradle.kts        # Build config
└── key.properties              # Signing config

assets/
└── icons/                      # App icons
```

## Requirements

- Flutter 3.8.1+
- Android SDK 34+
- JDK 17+
