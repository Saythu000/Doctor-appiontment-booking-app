# Structure & Code Quality Audit

**Date:** 2026-09-30  
**Project:** DrGodly (PHIA - Personal Health Insight Assistance)  
**Flutter SDK:** `>=3.5.0 <4.0.0`

---

## 1. Current Folder Structure and Component Roles

```
lib/
├── core/
│   ├── theme/
│   │   ├── colors.dart             # Palette definition (PhiaColors: navy, teal, white, text levels)
│   │   ├── dot_matrix.dart         # Custom painter for health matrix visualization
│   │   └── typography.dart         # GoogleFonts text theme styling (Inter, Plus Jakarta Sans)
│   ├── utils/
│   │   └── language_helper.dart    # In-app localization dictionary (EN, TA, HI, TE)
│   └── widgets/
│       ├── image_helper.dart       # Network image fallbacks with asset placeholders
│       └── notification_center_modal.dart # Dropdown sheet for active reminders & warnings
│
├── data/
│   ├── database/
│   │   └── sqflite_database.dart   # SQLite initialization, schema migrations, and single DB instance
│   ├── repository/
│   │   ├── auth_repository.dart    # IAM authentication client (login, token lifecycle)
│   │   ├── booking_repository.dart # Practitioner directory, slots query, booking & cancellation APIs
│   │   ├── health_repository.dart  # Local metric CRUD (SQLite) and remote FHIR vitals bridge
│   │   ├── profile_repository.dart # Local settings & patient metadata key-value storage
│   │   └── vitals_repository.dart  # FHIR observation payload extraction & remote transmission
│   └── service/
│       ├── ble_heart_rate_service.dart     # Direct BLE GATT client for wearable heart rate
│       ├── fhir_api_client.dart            # Dio HTTP client configured for FHIR server with auth interceptor
│       ├── gps_location_sensor.dart        # Geolocator stream handler for outdoor workouts
│       ├── notification_service.dart       # Local scheduled notification trigger
│       ├── open_wearables_service.dart     # Health Connect aggregator (steps, distance, sleep, SpO2)
│       ├── pedometer_sensor.dart           # Native step counter sensor listener
│       └── vitals_foreground_service.dart  # Android foreground service for recurring background sync
│
├── domain/
│   ├── model/
│   │   ├── auth_models.dart        # User credential and session DTOs
│   │   ├── booking_models.dart     # Doctor, PractitionerRole, Slot, Appointment DTOs
│   │   ├── health_metrics.dart     # Core HealthMetric entity
│   │   ├── patient_profile.dart    # Patient biographical data model
│   │   └── vitals_payload.dart     # HL7 FHIR observation model & VitalsRecord payload
│   └── repository/
│       └── i_health_repository.dart # Abstract contract for health metric persistence
│
├── view/
│   ├── auth/                       # Login and credential screens
│   ├── booking/                    # Doctor selection, slot booking, confirmation screens
│   ├── dashboard/                  # Home dashboard shell, overview tiles, live tracking UI
│   ├── devices/                    # Bluetooth scan & wearable pairing sheet
│   ├── onboarding/                 # Initial welcome, profile wizard, goal selection screens
│   ├── profile/                    # User profile, clinical units, vitals threshold settings
│   └── splash/                     # Launch screen and session check
│
├── viewmodel/                      # State management layer (ChangeNotifier classes)
│   ├── activity_viewmodel.dart     # Manages steps, calories, sleep, SpO2, and GPS workout states
│   ├── auth_viewmodel.dart         # Authentication lifecycle, login state, and patient registration
│   ├── booking_viewmodel.dart      # Specialist directory, slot selection, and appointment bookings
│   ├── profile_viewmodel.dart      # Profile editing and biometric baseline management
│   └── settings_viewmodel.dart     # Notification preferences and unit settings
│
└── main.dart                       # App entry point, dependency injection, and route declarations
```

---

## 2. State Management Consistency

- **Architecture:** `Provider` pattern using `ChangeNotifier` classes (`ChangeNotifierProvider` in `main.dart`).
- **Consistency Analysis:**
  - **Strengths:** All main feature domains have a corresponding ViewModel (`ActivityViewModel`, `BookingViewModel`, `AuthViewModel`, `ProfileViewModel`, `SettingsViewModel`). ViewModels are provided globally at the application root (`MultiProvider` in `main.dart`).
  - **Inconsistencies & Anti-Patterns:**
    1. **Bypassed State Layer:** Several UI screens instantiate repositories or call APIs directly rather than using their ViewModels (e.g. `ProfileSetupScreen` directly invokes `fhir_api_client.dart` and `HealthRepository`, `LoginScreen` directly writes settings).
    2. **Massive Monolithic ViewModels:** `ActivityViewModel` (1,071 lines) mixes sensor streams (Pedometer, GPS, BLE), Health Connect synchronization, local SQLite caching, FHIR API calls, and threshold warning logic in a single class.
    3. **Tight Coupling between ViewModels:** `BookingViewModel` takes `HealthRepository` and `ProfileRepository` directly rather than depending on domain contracts or services.

---

## 3. Package Audit (`pubspec.yaml`)

| Package | Declared Version | Status | Risk / Observations |
|---|---|---|---|
| `sensors_plus` | `^6.0.0` | Active | Used for accelerometer fallback step sensing. |
| `pedometer` | `^4.2.0` | Active | Hardware step sensor listener. Applies Kotlin Gradle Plugin (legacy). |
| `geolocator` | `^13.0.1` | Active | Used for GPS outdoor workout tracking. Requires runtime permission check. |
| `camera` | `^0.11.0` | Partially Unused | Included for camera/photoplethysmography heart-rate estimation. High build size footprint. |
| `sqflite` | `^2.3.0` | Active | Local storage engine for health metrics and settings. Stable. |
| `path` | `^1.9.0` | Active | Path helper for SQLite DB initialization. |
| `provider` | `^6.1.2` | Active | Primary state management library. |
| `google_fonts` | `^6.2.1` | Active | Font provider (Inter & Plus Jakarta Sans). Needs asset bundling for offline reliability. |
| `dio` | `^5.7.0` | Active | HTTP client for IAM and FHIR API communications. |
| `intl` | `^0.20.2` | Active | Date, time, and number formatting. |
| `permission_handler` | `^12.0.2` | Active | Manages Android permissions (Activity Recognition, Location, Notification, Camera). |
| `flutter_local_notifications` | `^17.2.2` | Active | Schedules local appointment and vital reminder notifications. |
| `timezone` | `^0.9.4` | Active | Timezone database for notification scheduling. |
| `flutter_timezone` | `^3.0.1` | Active | Fetches device native timezone identifier. Applies KGP. |
| `image_picker` | `^1.1.2` | Active | Profile photo selection. |
| `flutter_blue_plus` | `^1.34.5` | Active | Bluetooth Low Energy scanning and GATT communication for smartwatches. |
| `health` | `^13.3.2` | Active | Android Health Connect and Google Fit integration bridge. Applies KGP. |
| `flutter_foreground_task` | `^11.0.3` | Active | Persistent background sync service for wearable vitals. |
| `flutter_lints` | `^5.0.0` | Active (dev) | Static analysis rule set. Passing cleanly. |

---

## 4. Architectural Patterns: Navigation, Networking, & Dependency Injection

### Navigation Approach
- **Approach:** Named declarative routes mapped in `MaterialApp(routes: { ... })` in `main.dart`.
- **Limitation:**
  - Route navigation relies on `Navigator.pushNamed(context, '/route')`.
  - Type-safe argument passing is absent (parameters are frequently passed via static singletons or global ViewModel state before navigation).
  - No deep-linking library (such as `go_router`) is integrated.

### Networking Approach
- **Approach:** Handled via `Dio` across separate service/repository layers:
  - `FHIRApiClient` handles requests to the FHIR Gateway (`https://fhirgql.drgodly.com`) with an `InterceptorsWrapper` for auth token injection and 401 retry loops.
  - `AuthRepository` maintains its own `Dio` instance for IAM authentication (`https://iam.drgodly.com`).
  - `BookingRepository` maintains another `Dio` instance for appointment and consultation services.
- **Risks:** Multiple uncoordinated `Dio` instances with repeated interceptor logic and disparate timeout configurations.

### Dependency Injection Approach
- **Approach:** Primitive constructor injection configured in `main.dart` within `MultiProvider`.
- **Limitation:** Repositories (`HealthRepository`, `BookingRepository`, `ProfileRepository`) are instantiated multiple times across different ViewModels instead of as shared singletons or registered via a service locator (like `get_it`).

---

## 5. Largest Files (>300 lines) and UI Business Logic Leaks

| File Path | Line Count | Primary Role | Business Logic Concerns |
|---|---|---|---|
| `lib/view/dashboard/dashboard_screen.dart` | 1,467 lines | Main Dashboard UI | Computes BMI classification colors, formats duration calculations, builds modals, and directly handles UI formatting logic inline. |
| `lib/view/profile/profile_screen.dart` | 1,136 lines | Profile & Settings UI | Contains sheet-building logic, metric conversion arithmetic, and dialog controllers. |
| `lib/viewmodel/activity_viewmodel.dart` | 1,071 lines | Core Activity ViewModel | Combines sensor logic (pedometer, GPS, BLE), SQLite DB querying, Health Connect synchronization, and notification triggers in one file. |
| `lib/view/devices/device_manager_sheet.dart` | 979 lines | Wearable Manager UI | Contains direct BLE GATT byte stream parsing and hardware device discovery state. |
| `lib/view/dashboard/activity_tracking_screen.dart` | 743 lines | Workout Screen | Contains direct GPS math, pace calculation, and timer controllers. |
| `lib/view/booking/select_date_time_screen.dart` | 741 lines | Slot Booking UI | Contains appointment date slot filtering, timezone conversions, and slot availability sorting logic. |
| `lib/view/onboarding/profile_setup_screen.dart` | 641 lines | Onboarding Step 2 | Makes direct calls to FHIR API and SQLite repositories inside `StatefulWidget`. |
| `lib/view/profile/vitals_reminders_screen.dart` | 616 lines | Reminder Config UI | Manages reminder scheduling logic and local database saves directly inside UI callbacks. |
| `lib/data/service/open_wearables_service.dart` | 594 lines | Health Connect Aggregator | Aggregates steps, calories, and sleep stages. High complexity. |
| `lib/data/repository/booking_repository.dart` | 579 lines | Booking Repository | Contains payload construction and remote mapping. |
| `lib/view/profile/general_settings_screen.dart` | 518 lines | Settings UI | Direct database access and preference saving within the widget tree. |
| `lib/viewmodel/booking_viewmodel.dart` | 491 lines | Booking ViewModel | High complexity in slot querying and appointment state transitions. |
| `lib/core/utils/language_helper.dart` | 487 lines | In-app Localizations | Hardcoded translation map. |
| `lib/core/widgets/notification_center_modal.dart` | 471 lines | Notification Modal | Directly queries repositories for threshold warnings. |
| `lib/view/booking/select_specialist_screen.dart` | 451 lines | Specialist Selection UI | Specialist filtering and categorization logic inside UI. |
| `lib/view/auth/login_screen.dart` | 431 lines | Login Screen UI | Authentication credential verification and navigation side-effects. |
| `lib/data/repository/health_repository.dart` | 428 lines | Health Repository | Handles both SQLite data management and remote FHIR vitals syncing. |
| `lib/view/booking/review_booking_screen.dart` | 390 lines | Booking Review Screen | Appointment payload validation inside widget. |
| `lib/view/onboarding/goals_screen.dart` | 363 lines | Goals Screen | Goal calculation and baseline persistence inside widget. |
| `lib/view/profile/appointment_history_screen.dart` | 362 lines | Appointment List UI | Appointment cancellation and status mapping logic. |
| `lib/data/service/notification_service.dart` | 353 lines | Notification Service | Channel creation, permission requests, and scheduling logic. |
| `lib/viewmodel/profile_viewmodel.dart` | 348 lines | Profile ViewModel | Patient record creation and profile field management. |
| `lib/view/onboarding/complete_screen.dart` | 340 lines | Onboarding Complete UI | Account finalization steps. |
| `lib/viewmodel/auth_viewmodel.dart` | 339 lines | Auth ViewModel | Token handling, session validation, and patient check. |
| `lib/view/onboarding/welcome_screen.dart` | 331 lines | Welcome Carousel | UI carousel animations and navigation routing. |
| `lib/view/profile/vitals_thresholds_screen.dart` | 301 lines | Vitals Threshold UI | Direct threshold boundary validation and persistence. |

---

## 6. Top 15 Code-Quality Problems Ranked by Severity

1. **[CRITICAL] Hardcoded Production Endpoints and Origins:**
   - Base URLs (`https://iam.drgodly.com`, `https://fhirgql.drgodly.com`, `https://app.drgodly.com`) and origin headers are hardcoded as string literals across `auth_repository.dart`, `fhir_api_client.dart`, `booking_repository.dart`, and `auth_viewmodel.dart` instead of using environment configuration (`--dart-define` or `.env`).

2. **[CRITICAL] Console Logging of Sensitive Data:**
   - Over 50 `print()` statements exist throughout network services and repositories (e.g., logging request payloads in `fhir_api_client.dart:171`, appointment payloads in `booking_repository.dart:120`, and vitals calculations in `open_wearables_service.dart`), which can expose sensitive parameters or health indicators in production logs.

3. **[CRITICAL] Completely Missing Automated Test Suite:**
   - The `test/` directory contains 0 test files (`flutter test` fails due to no `*_test.dart` files found), resulting in zero automated test coverage for critical health metrics calculations, booking flows, and authentication.

4. **[HIGH] Monolithic God ViewModels (`ActivityViewModel` - 1,071 lines):**
   - Single class handles Pedometer sensor streams, GPS location tracking, BLE GATT device connections, SQLite metrics persistence, Health Connect batch querying, energy meter scoring, and threshold checking.

5. **[HIGH] Massive Widget Files Exceeding 1,000 Lines:**
   - `dashboard_screen.dart` (1,467 lines) and `profile_screen.dart` (1,136 lines) embed entire modal bottom sheets, form validation, formatting arithmetic, and complex sub-component trees within single monolithic files.

6. **[HIGH] Redundant Instantiation of Repositories (No Singleton / Shared Container):**
   - `HealthRepository` is instantiated 5 separate times in `main.dart` for each provider, creating redundant instances rather than sharing a single repository or interface.

7. **[HIGH] Direct Repository/API Calls from UI Widgets:**
   - `ProfileSetupScreen`, `GeneralSettingsScreen`, and `VitalsRemindersScreen` directly instantiate and call `HealthRepository` or `FHIRApiClient` methods rather than routing state and actions through their respective ViewModels.

8. **[MEDIUM] Multiple Uncoordinated `Dio` Clients:**
   - `auth_repository.dart`, `fhir_api_client.dart`, and `booking_repository.dart` maintain separate `Dio` instances, preventing unified interceptor management, shared cookie/token jar, or centralized SSL/TLS pinning.

9. **[MEDIUM] Fragile Named Route Parameter Passing:**
   - Routes in `main.dart` lack typed arguments, forcing screens to either access global ViewModel state prematurely or depend on pre-loaded static identifiers.

10. **[MEDIUM] Build Warning on Obsolete Plugins Applying Kotlin Gradle Plugin (KGP):**
    - Plugins `camera_android_camerax`, `flutter_timezone`, `health`, `pedometer`, and `sensors_plus` trigger deprecation warnings during Android builds regarding future incompatibility with Flutter's built-in Kotlin.

11. **[MEDIUM] In-Memory Hardcoded Translations (`language_helper.dart` - 487 lines):**
    - Multi-language dictionary is implemented as a giant static Map instead of utilizing Flutter's native `flutter_localizations` with ARB files.

12. **[LOW] Unused Large Dependencies (`camera: ^0.11.0`):**
    - Camera plugin is pulled into the project and Android manifest permissions, but photoplethysmography heart-rate scanning remains largely experimental and unused on the dashboard.

13. **[LOW] Lack of Comprehensive Error Boundaries:**
    - Asynchronous repository calls frequently utilize catch-all blocks (`catch (_) {}`) that swallow network and database exceptions, masking connectivity failures from user feedback.

14. **[LOW] Hardcoded Unsplash Asset URLs:**
    - `dashboard_screen.dart` and `appointment_history_screen.dart` contain hardcoded Unsplash fallback URLs for doctor avatars, creating potential visual breaks when offline.

15. **[LOW] Magic Numbers in Health Math:**
    - Hardcoded constants (e.g. `0.762` stride length, `45.5` synthetic HRV check, `65.0` step-to-minute divisor) are sprinkled throughout ViewModels and services rather than defined as named domain constants.
