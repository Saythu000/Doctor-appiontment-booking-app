# Security & Data Audit

**Date:** 2026-09-30  
**Project:** DrGodly (PHIA - Personal Health Insight Assistance)  
**Target Android:** Android 14 to 16 (`minSdk 34`, `targetSdk 36`)

---

## 1. Executive Summary

This security and data audit reviews the application across seven core vulnerability categories:
1. Hardcoded Secrets and Credentials
2. Insecure Storage of Authentication Tokens and Clinical Health Data
3. Plaintext HTTP Traffic & Cleartext Exposure
4. Missing SSL / TLS Certificate Pinning
5. Sensitive Clinical & Personal Data Leakage in Application Logs
6. Exported Android Components in `AndroidManifest.xml`
7. Missing Obfuscation & Shrinking in Release Build Configurations (`build.gradle.kts`)
8. Unnecessary / Over-Privileged Android Permissions

Findings are categorized and prioritized using standard risk ratings: **Critical**, **High**, **Medium**, and **Low**.

---

## 2. Findings Ranked by Severity

### Critical Severity

#### 1. Insecure Plaintext Storage of JWT and IAM Session Tokens in Unencrypted SQLite
- **File:** `lib/viewmodel/auth_viewmodel.dart` (Lines 321–337)
- **File:** `lib/data/repository/health_repository.dart` (Lines 286–306)
- **File:** `lib/data/database/sqflite_database.dart` (Lines 54–57)
- **Vulnerability:** 
  The authentication session cookie (`iam_session_token`) and the bearer JWT access token (`iam_jwt_token`) are saved directly into an unencrypted SQLite database table (`app_settings` within `phia_cache.db`).
- **Risk Impact:**
  On rooted devices, through adb backups, or via physical file system extraction, an attacker can extract valid bearer tokens and hijack the patient's authenticated clinical session.
- **Remediation:**
  Migrate token and session storage from SQLite `app_settings` to `flutter_secure_storage` (which backs onto Android Keystore / EncryptedSharedPreferences and iOS Keychain).

---

#### 2. Unencrypted Storage of Sensitive Protected Health Information (PHI) & PII
- **File:** `lib/data/database/sqflite_database.dart` (Lines 29–109)
- **File:** `lib/data/repository/health_repository.dart` (Lines 250–284)
- **Vulnerability:**
  The SQLite database `phia_cache.db` contains plaintext tables for:
  - `health_metrics`: Real-time and historical Heart Rate, HRV, SpO2, and Sleep minutes.
  - `workout_route_points`: Precise GPS latitude/longitude tracking history.
  - `local_profile`: Patient biographical details (Given Name, Family Name, Gender, Date of Birth, Phone, Home Address, Postal Code).
  - `appointments`: Scheduled consultations, doctor names, and medical notes.
- **Risk Impact:**
  Direct violation of HIPAA Security Rule (§ 164.312(a)(2)(iv) Encryption and Decryption) and GDPR technical safeguards. If the device is backed up or accessed locally, all raw clinical logs and patient demographic records are readable in plain text.
- **Remediation:**
  Implement database-level encryption using `sqflite_sqlcipher` with an AES-256 key securely generated and stored in Android Keystore via `flutter_secure_storage`.

---

### High Severity

#### 3. Sensitive Clinical Payload and PII Leakage in Console Logs
- **File:** `lib/data/service/fhir_api_client.dart` (Lines 169–188)
- **File:** `lib/data/repository/booking_repository.dart` (Lines 119–121, 159–161)
- **File:** `lib/data/service/open_wearables_service.dart` (Lines 281–283, 501–502, 541–542)
- **Vulnerability:**
  - `fhir_api_client.dart` logs the entire JSON request payload (`jsonEncode(options.data)`) and server response body (`response.data`) to `print()`. When posting observations or creating patient profiles, this dumps full names, phone numbers, addresses, DOB, and biometric vitals directly to system logcat.
  - `booking_repository.dart` logs patient appointment booking payloads (`POST /api/v1/appointments/book: $payload`) including doctor names and consultation comments.
  - `open_wearables_service.dart` prints raw calorie values and active minutes.
- **Risk Impact:**
  Any third-party app with log reading permissions or connected ADB debugger can inspect sensitive clinical telemetry and PII from Android log buffers.
- **Remediation:**
  Remove payload and response body logging. Ensure all remaining diagnostic logs are wrapped in an obfuscated audit logger that strictly defangs personal identifiers and clinical metrics.

---

#### 4. Complete Absence of SSL / TLS Certificate Pinning
- **File:** `lib/data/service/fhir_api_client.dart` (Lines 10–18)
- **File:** `lib/data/repository/auth_repository.dart` (Lines 5–15)
- **File:** `lib/data/service/open_wearables_service.dart` (Lines 84–90)
- **Vulnerability:**
  The `Dio` HTTP clients connecting to `iam.drgodly.com`, `fhirgql.drgodly.com`, and `api.openwearables.io` rely solely on the default system trust store. No certificate pinning or public key hash validation is implemented.
- **Risk Impact:**
  Vulnerable to Man-in-the-Middle (MitM) attacks if a malicious certificate authority is installed on the user device (e.g. corporate proxy, compromised root CA, or malicious Wi-Fi profile).
- **Remediation:**
  Implement public key pinning using `dio_certificate_pinning` or a custom `SecurityContext` in Dio's `HttpClientAdapter` matching SHA-256 SPKI hashes of `*.drgodly.com`.

---

#### 5. Missing Code Obfuscation and Resource Shrinking in Android Release Build
- **File:** `android/app/build.gradle.kts` (Lines 29–35)
- **Vulnerability:**
  The `release` build type block contains only signing configuration and lacks R8 minification/obfuscation directives:
  ```kotlin
  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("debug")
      }
  }
  ```
  `isMinifyEnabled = true`, `isShrinkResources = true`, and ProGuard rule files are absent.
- **Risk Impact:**
  The compiled Android APK/AAB retains full Java/Kotlin class and method symbols, making reverse engineering trivial with tools like JADX or APKTool. Furthermore, the release block defaults to signing with the debug keystore (`signingConfigs.getByName("debug")`), which is insecure for production distribution.
- **Remediation:**
  Enable R8 shrinking and obfuscation:
  ```kotlin
  buildTypes {
      release {
          isMinifyEnabled = true
          isShrinkResources = true
          proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
          // Configure production release keystore
      }
  }
  ```

---

### Medium Severity

#### 6. Hardcoded Fallback User and Organization Identifiers
- **File:** `lib/data/service/vitals_foreground_service.dart` (Lines 33–34)
- **Vulnerability:**
  Hardcoded sandbox credentials exist in the foreground sync loop:
  ```dart
  final vitals = await _service.fetchLatestVitals(
    userId: 'patient-drgodly-01',
    orgId: 'org-drgodly-dev',
  );
  ```
- **Risk Impact:**
  If the foreground service runs while no user is logged in, it attempts to fetch or transmit vitals using static development credentials, corrupting development database records and violating multi-tenancy boundaries.
- **Remediation:**
  Inject the authenticated user's dynamic `userId` and `orgId` from secure storage into `VitalsTaskHandler` rather than hardcoding static fallbacks.

---

#### 7. Insecure HTTP Fallback URL in Mock/Offline Reset
- **File:** `lib/viewmodel/auth_viewmodel.dart` (Line 313)
- **Vulnerability:**
  During sign-out, `auth_viewmodel.dart` reconfigures the API client with a plaintext HTTP URL:
  ```dart
  FhirApiClient().configure(
    baseUrl: 'http://10.0.2.2:8000',
    token: null,
    isLiveMode: false,
  );
  ```
- **Risk Impact:**
  Transmitting unencrypted requests over plaintext HTTP exposes request traffic to local network interception if `isLiveMode` is accidentally toggled or configured in development/QA builds without HTTPS.
- **Remediation:**
  Enforce HTTPS endpoints uniformly or isolate mock network environments using an in-memory mock adapter rather than pointing to a plaintext HTTP IP.

---

#### 8. Over-Privileged Permissions Declared in `AndroidManifest.xml`
- **File:** `android/app/src/main/AndroidManifest.xml` (Lines 6–13, 34–35)
- **Vulnerability:**
  - `android.permission.CAMERA`: Declared, but the application is primarily a wearable/vitals tracking client. If only profile pictures are taken, `image_picker` can utilize the system photo picker without requiring raw `CAMERA` permission on Android 13+.
  - `android.permission.ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION`: Declared for BLE and GPS workouts. `BLUETOOTH_SCAN` correctly uses `neverForLocation`, but location permissions remain high-scrutiny on Google Play.
  - `android.permission.SCHEDULE_EXACT_ALARM` & `USE_EXACT_ALARM`: Declared for local notification reminders. Google Play rejects apps using `USE_EXACT_ALARM` unless their core purpose is an alarm clock or timer.
  - `android.permission.health.READ_BLOOD_PRESSURE`: Declared, but unused in application code.
  - `android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND`: Declared, but no native Health Connect background read implementation exists.
- **Risk Impact:**
  Over-privilege increases app attack surface, causes user reluctance during onboarding permission prompts, and triggers Google Play policy rejection during review.
- **Remediation:**
  Remove unused permissions (`READ_BLOOD_PRESSURE`, `READ_HEALTH_DATA_IN_BACKGROUND`, `USE_EXACT_ALARM`). Use system photo picker intents instead of declaring camera hardware permission if custom camera views are not required.

---

### Low Severity

#### 9. Exported Android Activity and Alias Review
- **File:** `android/app/src/main/AndroidManifest.xml` (Lines 48–82)
- **Vulnerability Assessment:**
  - `MainActivity` has `android:exported="true"`, but is protected by the standard `android.intent.action.MAIN` / `android.intent.category.LAUNCHER` intent filter and Health Connect permission rationale filter.
  - `ViewPermissionUsageActivity` (activity-alias) has `android:exported="true"` and is protected by `android:permission="android.permission.START_VIEW_PERMISSION_USAGE"`.
- **Risk Impact:**
  Low risk; the alias is correctly guarded by the required system health permission. However, ensuring input sanitization on incoming intents to `MainActivity` is recommended to prevent intent-redirection vulnerabilities.

---

## 3. Summary of Vulnerabilities & Remediation Roadmap

| Severity | Vulnerability | File / Component | Primary Remediation |
| :--- | :--- | :--- | :--- |
| **CRITICAL** | Plaintext JWT & Session Tokens in SQLite | `auth_viewmodel.dart` / `health_repository.dart` | Store in Android Keystore via `flutter_secure_storage` |
| **CRITICAL** | Plaintext PHI/PII in Local SQLite Database | `sqflite_database.dart` / `health_repository.dart` | Implement AES-256 encryption using `sqflite_sqlcipher` |
| **HIGH** | PII and Clinical Observation Payload Logging | `fhir_api_client.dart` / `booking_repository.dart` | Strip payload logging and redact clinical telemetry |
| **HIGH** | Missing SSL/TLS Certificate Pinning | `fhir_api_client.dart` / `auth_repository.dart` | Implement SPKI public key pinning for `*.drgodly.com` |
| **HIGH** | Missing Obfuscation & Shrinking in Release | `android/app/build.gradle.kts` | Enable R8 `isMinifyEnabled` and `isShrinkResources` |
| **MEDIUM** | Hardcoded Development IDs in Sync Loop | `vitals_foreground_service.dart` | Pass dynamic session IDs from secure storage |
| **MEDIUM** | Insecure HTTP URL Fallback | `auth_viewmodel.dart` | Enforce HTTPS across all network configurations |
| **MEDIUM** | Unused / Over-Privileged Permissions | `android/app/src/main/AndroidManifest.xml` | Remove `READ_BLOOD_PRESSURE`, `USE_EXACT_ALARM`, etc. |
| **LOW** | Exported Components Intent Validation | `android/app/src/main/AndroidManifest.xml` | Validate and sanitize deep link intent parameters |

