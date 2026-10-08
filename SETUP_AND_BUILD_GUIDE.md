# Developer Setup & APK Build Guide (PHIA Mobile App)

This guide covers everything required to clone, configure, install dependencies, and build the release APK for the **PHIA (DrGodly Mobile)** application.

---

## 1. Prerequisites & System Requirements

Ensure the following tools are installed and accessible from the system terminal:

| Tool | Recommended Version | Notes |
|---|---|---|
| **Git** | `2.30+` | Version control |
| **Flutter SDK** | `3.24.x` or `3.27+` (Stable) | Dart `3.5+` |
| **Java Development Kit (JDK)** | **JDK 17** (or JDK 21) | Required by Gradle 8/9 and Android Gradle Plugin |
| **Android Studio / Android SDK** | Latest stable | Platform SDK 34/35 + Build Tools 34.0.0+ |

### Verify Environment
Run the Flutter diagnosis command:
```bash
flutter doctor
```
Ensure Flutter, Android toolchain, and connected device/licenses are green checkmarks (`✓`). If Android licenses are missing, accept them with:
```bash
flutter doctor --android-licenses
```

---

## 2. Clone the Repository

Clone the project repository:

```bash
git clone https://github.com/Saythu000/Doctor-appiontment-booking-app.git
cd Doctor-appiontment-booking-app
```
*(Or clone `https://github.com/Saythu000/DrGodly-Mobile-Aplication.git`).*

---

## 3. Install Flutter Dependencies

Run the following command to download all packages:

```bash
flutter pub get
```

### Core Architecture & Dependencies:
- **State Management**: `provider`
- **Network & Streaming**: `dio` (with SSE / line-by-line streaming)
- **Local Database & Storage**: `sqflite`, `flutter_secure_storage`, `path`
- **Sensors & Wearables**: `health` (Google Health Connect), `flutter_blue_plus` (BLE)
- **Background Execution**: `workmanager`, `flutter_foreground_task`
- **In-App OAuth & Web**: `flutter_web_auth_2`, `webview_flutter`

---

## 4. Run Automated Unit Tests

Before building, verify that all local unit and regression tests pass:

```bash
flutter test
```
*Expected result: `All tests passed!` (20/20 tests passing).*

---

## 5. Compile the Release APK

To compile the production release APK:

```bash
flutter build apk --release
```

### Build Specifications:
- **R8 / ProGuard**: Minification (`isMinifyEnabled = true`) and resource shrinking (`isShrinkResources = true`) are enabled.
- **Minimum Android Version**: Android 8.0 (API 26).
- **Target Android Version**: Android 14+ (API 34/35).
- **Desugaring**: Core library desugaring enabled (Java 17 compatibility).

### Output Artifact:
Upon completion, the compiled APK is located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. Install & Run on an Android Device

### Option A: Direct Flutter Run
Connect an Android phone (with USB Debugging enabled) or start an Android Emulator, then run:
```bash
flutter run --release
```

### Option B: Direct ADB Install
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 7. Troubleshooting

1. **Java / Gradle Compatibility Issues**:
   - Verify active JDK version:
     ```bash
     java -version
     ```
   - Must be JDK 17 (or JDK 21). In Android Studio, check: **Settings > Build, Execution, Deployment > Build Tools > Gradle > Gradle JDK**.
2. **Stale Cache / Build Artifacts**:
   - If Gradle throws compilation or dependency resolution errors:
     ```bash
     flutter clean
     flutter pub get
     flutter build apk --release
     ```
3. **Android Keystore / Signing**:
   - The release build currently defaults to the standard debug signing configuration for seamless developer local testing (`signingConfig = signingConfigs.getByName("debug")`), so no separate keystore setup is required for team testing.
