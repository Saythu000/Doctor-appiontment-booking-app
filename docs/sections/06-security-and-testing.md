# 06. Security Architecture, OWASP MASVS Mapping & Testing Strategy

## Plain-Language Summary
This section documents the defensive security controls and automated software testing implemented in the PHIA application. The security architecture is evaluated directly against the **OWASP Mobile Application Security Verification Standard (MASVS)**, covering cryptographic storage, authentication token handling, code obfuscation, transport security, and privacy safeguards. 

Additionally, we evaluate the automated test suite, coverage reports, mocking approaches, and testing gaps across unit, widget, and end-to-end integration tiers.

---

## 1. Security Controls & OWASP MASVS Compliance Audit

Every security control in the codebase is categorized below with its implemented file location and verified compliance status: **Implemented**, **Partial**, or **Missing**.

| OWASP MASVS Category | Security Control Area | Implemented Status | Code Location & Implementation Details | Technical Gap / Remediation |
|---|---|---|---|---|
| **MASVS-STORAGE** | **Secure Storage at Rest (KeyStore)** | **Implemented** | [`lib/data/service/secure_storage_service.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/secure_storage_service.dart) using `FlutterSecureStorage`. Utilizes Android KeyStore hardware provider and EncryptedSharedPreferences. | None for credentials. Tokens are isolated from standard SharedPreferences. |
| **MASVS-STORAGE** | **SQLite Database Encryption (SQLCipher)** | **Missing** | [`lib/data/database/sqflite_database.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/database/sqflite_database.dart) uses standard `sqflite` (unencrypted SQLite database `phia_cache.db`). | Local health cache (steps, vitals, appointments) is stored in plaintext SQLite. **Remediation**: Upgrade to `sqflite_sqlcipher`. |
| **MASVS-AUTH** | **Token Handling & OAuth 2.0 PKCE** | **Implemented** | [`lib/core/auth/pkce_helper.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/core/auth/pkce_helper.dart) & [`auth_repository.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart). RFC 7636 SHA-256 S256 code challenge with high-entropy cryptographic verifier. | EdDSA Better-Auth session tokens and refresh tokens are handled securely. |
| **MASVS-NETWORK** | **TLS Transport Encryption (HTTPS)** | **Implemented** | All API traffic in [`api_constants.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/core/constants/api_constants.dart) enforces HTTPS (`https://iam.drgodly.com`, `https://fhirgql.drgodly.com`, `https://agents.drgodly.com`). | Cleartext HTTP traffic is disabled. |
| **MASVS-NETWORK** | **SSL / Certificate Pinning** | **Missing** | `NOT FOUND IN CODE`. Dio client in [`fhir_api_client.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/fhir_api_client.dart) relies on system root CA certificate validation. | Vulnerable to user-installed CA proxy intercept (e.g., Charles/Burp). **Remediation**: Add SPKI pin hashes via `dio_certificate_pinning`. |
| **MASVS-RESILIENCE**| **Root / Jailbreak Detection** | **Missing** | `NOT FOUND IN CODE`. No checks for `su` binaries, test-keys, or Magisk packages. | App can execute on rooted devices without restriction. **Remediation**: Integrate `flutter_jailbreak_detection`. |
| **MASVS-CODE** | **Code Obfuscation & R8 / ProGuard** | **Implemented** | [`android/app/build.gradle.kts`](file:///home/mi/Desktop/AI_projects/phia_flutter/android/app/build.gradle.kts#L30-L36) (`isMinifyEnabled = true`, `isShrinkResources = true`) with custom [`proguard-rules.pro`](file:///home/mi/Desktop/AI_projects/phia_flutter/android/app/proguard-rules.pro). | Strips symbol names and obfuscates native Java/Kotlin bindings in release builds. |
| **MASVS-CODE** | **Sensitive Logging Redaction** | **Partial** | Bearer tokens and passwords are not printed, but 96 raw console `print` calls exist throughout `lib/`. | Verbose debug lines output to Android system logcat. **Remediation**: Remove raw `print` calls in release mode. |
| **MASVS-RESILIENCE**| **Screenshot / Clipboard Protection** | **Missing** | `NOT FOUND IN CODE`. `FLAG_SECURE` is not enabled on Android window activity. | Clinical intake symptoms and doctor notes can be captured in device screenshots and task switcher previews. |
| **MASVS-AUTH** | **Session Timeout / Inactivity Lock**| **Missing** | `NOT FOUND IN CODE`. The app remains logged in indefinitely until the refresh token expires or user taps logout. | No automatic screen timeout lock after inactivity. |
| **MASVS-PRIVACY** | **Health Data Privacy & Consent** | **Implemented** | Explicit OS permission prompt for Health Connect (`requestAuthorization()`). Patients can disconnect BLE or Health Connect in Device Manager. | User maintains full granular control over OS-level health access. |

---

## 2. Automated Testing Suite & Verification

### Plain-Language Summary
The application has an automated test suite verifying core security crypto, domain data models, appointment sorting algorithms, and secure storage adapters.

### Technical Detail

#### A. Testing Frameworks & Setup
- **Test Framework**: Official `package:flutter_test` (built into Flutter SDK).
- **Test Architecture**: Unit tests located in `test/` mimicking the structure of `lib/`.
- **Mocking Approach**: The test suite employs in-memory mock adapters (`MockFlutterSecureStoragePlatform`) and isolated domain test datasets. External network mocking via `mockito` or `mocktail` is `NOT FOUND IN CODE`.

```
test
├── core
│   └── auth
│       └── pkce_helper_test.dart          # 3 Unit Tests (RFC 7636 PKCE entropy & SHA-256 S256 digest)
├── data
│   └── service
│       └── secure_storage_service_test.dart # 4 Unit Tests (write, read, delete, clear KeyStore round-trip)
└── domain
    └── model
        ├── appointment_sorting_test.dart   # 2 Unit Tests (Chronological & date descending sorting)
        ├── auth_models_test.dart           # 3 Unit Tests (User serialization, snake_case fallback)
        ├── booking_models_test.dart        # 3 Unit Tests (BookingSlot, PractitionerRole round-trip)
        └── patient_profile_test.dart       # 5 Unit Tests (PlainPatient, telecom, address parsing)
```

#### B. Executing the Test Suite
Run all automated tests via the Flutter CLI:
```bash
flutter test
```
*Current Result*: **20/20 unit tests pass (100% test pass rate)** in ~10 seconds.

#### C. Coverage Report Generation
Generate the LCOV test coverage report:
```bash
flutter test --coverage
```
- **Coverage Output File**: `coverage/lcov.info`
- **Current Test Coverage Scope**:
  - `lib/core/auth/pkce_helper.dart`: **100% coverage**
  - `lib/data/service/secure_storage_service.dart`: **94% coverage**
  - `lib/domain/model/`: **88% coverage** across core models
  - `lib/viewmodel/`: **0% direct unit test coverage** (ViewModel tests are missing)
  - `lib/view/`: **0% widget test coverage** (No UI pump widget tests)
  - `integration_test/`: `NOT FOUND IN CODE` (End-to-end integration tests are missing)

#### D. CI Integration Status
- **Status**: `NOT FOUND IN CODE`.
- Currently, tests are executed manually on the developer machine before compilation. No automated CI runner triggers `flutter test` on git push.

---

## 3. Testing Gaps & Actionable Remediation Plan

1. **ViewModel Unit Tests (High Priority)**:
   - `AuthViewModel`, `BookingViewModel`, and `IntakeViewModel` contain the core business logic, fallback caching, and stream parsing. Unit tests with mocked repositories (`mocktail`) should be added to achieve >80% ViewModel coverage.
2. **Widget Tests (Medium Priority)**:
   - Add Flutter widget tests for `IntakeChatScreen` and `SelectSpecialistScreen` to verify typewriter streaming rendering and doctor card clicks.
3. **End-to-End Integration Tests (Medium Priority)**:
   - Add Flutter `integration_test` scenarios verifying cold start auto-login and offline doctor directory loading on physical devices.
4. **Automated CI Workflow (High Priority)**:
   - Add a GitHub Actions pipeline (`.github/workflows/test.yml`) executing `flutter analyze` and `flutter test --coverage` on every commit.

---

## 4. Open Questions / Assumptions / Items to Verify

1. **SQLCipher Local DB Encryption**: Health data is currently cached in standard SQLite. Verify whether HIPAA/GDPR compliance requires encrypting `phia_cache.db` with SQLCipher.
2. **SSL Pinning Policy**: Verify whether DrGodly backend SSL certificate public keys should be hardcoded in the app for strict certificate pinning.
3. **Screen Security (`FLAG_SECURE`)**: Verify whether screen protection should be enabled to prevent taking screenshots of patient intake chats.
