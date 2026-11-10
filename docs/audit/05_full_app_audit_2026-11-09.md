# DrGodly (phia_flutter) — Full App Audit

**Date:** 2026-11-09 · **Commit:** `d1c5c28` · **Branch:** `main`

The codebase was read in full by four parallel reviewers, and every Critical finding was checked against the source. Toolchain results:
- **`flutter analyze`:** no issues.
- **`flutter test`:** all 20 tests pass.
- **`flutter pub outdated`:** results are in section 7.

No files were changed during the audit. Anything that couldn't be confirmed without a device or the backend is marked **(unverified)**.

---

## 1. Project overview and tech stack

**Purpose.** DrGodly is an Android telehealth app with wearable vitals tracking.
- **Who it's for:** patients, mainly in India (going by doctor data and the BLE watch brands named in the manifest: boAt, Fire-Boltt, Noise).
- **Use cases:**
  1. OAuth sign-in to the DrGodly IAM.
  2. Profile onboarding into a FHIR patient record.
  3. Syncing vitals from Health Connect and BLE heart-rate straps to a FHIR backend.
  4. Booking specialist consultations.
  5. A pre-consultation AI intake by chat or voice that produces a clinical report linked to the appointment.
  6. Reminders and threshold alerts.

**Platform.** Flutter 3.44.0 (stable), Dart 3.12.0, `sdk: '>=3.5.0 <4.0.0'`. App version `0.0.2+8`.

| Area | Packages (resolved versions) |
|---|---|
| State management | provider 6.1.5+1 (ChangeNotifier) |
| Networking | dio 5.9.2, web_socket_channel 3.0.3 |
| Auth | flutter_web_auth_2 4.1.0 (dead path), webview_flutter 4.14.1 (live path), crypto (PKCE) |
| Local storage | sqflite 2.4.2+1 (`phia_cache.db`, unencrypted), flutter_secure_storage 11.2.0 |
| Health and devices | health 13.3.2 (Health Connect), flutter_blue_plus 1.36.8 |
| Background | workmanager 0.10.10, flutter_foreground_task 11.0.3 (never started) |
| Notifications | flutter_local_notifications 17.2.4, timezone 0.9.4, flutter_timezone 3.0.1 (local only, no FCM) |
| Media | record 7.1.2, audioplayers 6.8.1, image_picker 1.2.2 |
| UI | google_fonts 6.3.3, intl 0.20.2, Material 3 |

**Backends.** These are custom services. There is no Firebase or Supabase.
- `iam.drgodly.com`: Better-Auth with OAuth2 PKCE.
- `fhirgql.drgodly.com`: a FHIR REST middleware.
- `app.drgodly.com`: intake records.
- `agents.drgodly.com`: AI intake over HTTP streaming and WebSocket.

**Missing pieces.** There is no crash reporting (Crashlytics or Sentry), no analytics, no CI and no push notifications.

**Android setup.**
- **SDK and build:**
  - minSdk 26 (hardcoded); compileSdk and targetSdk 36 (Flutter defaults).
  - AGP 9.0.1, Kotlin 2.3.20, Gradle 9.1.0.
  - Java 17 with desugaring.
  - R8 minify and shrinkResources are on.
- **Identity and signing:** `applicationId = "com.example.phia_flutter"`. The **release build is signed with the debug key** (`android/app/build.gradle.kts:20,39`). There are no flavors.
- **Manifest gaps:** there is no `allowBackup`, `dataExtractionRules` or network security config.
- **Permissions:** the manifest declares camera, mic, BLE, 12 Health Connect reads, exact alarms and `FOREGROUND_SERVICE_HEALTH`.

---

## 2. Architecture and data flow

```
lib/
 core/       theme, constants, PKCE helper, i18n map, shared widgets
 data/       database (sqflite), repository/ (auth, health, profile, booking, vitals),
             service/ (FHIR Dio client, intake, voice WS, BLE, Health Connect, notifications, WorkManager, foreground)
 domain/     models (FHIR patient, booking, intake, vitals payload)
 viewmodel/  7 ChangeNotifiers, all global in main.dart MultiProvider
 view/       auth, splash, onboarding, dashboard, booking, intake, profile, devices
```

**Navigation.** Navigation uses named routes in `main.dart` (21 routes). The flow is:

```
/splash → (auth?) → /dashboard (shell: IndexedStack tabs) or /welcome → /login → /profile_setup → /goals → /complete → /dashboard
/dashboard → /booking_specialist → [AI intake: /intake | /voice_intake → /intake_completion]
           → /booking_date_time → /booking_review → /booking_confirmed
```

**Data flow.** View → `context.watch/read<VM>` → repository or service → `FhirApiClient` (a Dio singleton with Bearer auth and a 401 refresh interceptor) or SQLite → `notifyListeners`.

- **Login:** `LoginScreen` → `AuthViewModel.loginWithPKCE` → `AuthRepository.signInWithInAppOAuth`. That pushes `OAuthWebViewScreen`, which catches the `com.drgodly.app:` redirect and reads the IAM cookies over a MethodChannel. The repository then exchanges the code at `/oauth2/token`, calls `/oauth2/userinfo` and mints a Better-Auth JWT via `/token`.
- **Session restore:** `SplashScreen` → `checkAutoLogin` tries three things in turn: the session cookie, then the refresh_token, then the stored JWT (with no expiry check).
- **Vitals:** Health Connect → `OpenWearablesService.fetchLatestVitals` → `ActivityViewModel`. A 5-minute timer writes to SQLite and POSTs to `/api/v1/vitals/`. BLE heart rate goes through a stream into the same view model: one SQLite row per beat, POSTed at most every 15s.
- **Background:** WorkManager runs hourly. The foreground service is never started.
- **Booking:** `/practitioner-roles/booking` → `/slots?status=free` → `POST /appointments/book`, plus an unawaited `app.drgodly.com/api/consultation/create`. The appointment is mirrored to SQLite and reminders are scheduled.
- **Intake:** chat streams from `/api/agent/intake` (SSE-style); voice uses `wss://…/ws/audio` with PCM16 mic in and 24 kHz WAV out. The report comes from `/api/agent/assessment`, then `/api/intake/create` and `/api/intake/update`, and is linked with `/api/intake/link`.

**Assessment.** The layout is MVVM-shaped, but it doesn't actually keep the layers apart:
- There is no dependency injection: repositories call `new HealthRepository()` inside view models.
- `AuthRepository` imports a View and calls `Navigator` (`auth_repository.dart:2,46`).
- Screens hold business logic. For example, `review_booking_screen.dart:224-301` orchestrates booking and intake linking.
- `dashboard_screen.dart` is 1,831 lines.
- Provider is a fine choice at this scale. The problems are that every view model is global and never reset on logout, which causes the cross-account leak in C9, and that rebuilds are coarse (`context.watch` on 4 view models at the top of the dashboard build).

---

## 3. Issues

Critical issues have corrected code after the table.

| ID | Category | Severity | File:line | Description | Suggested fix |
|---|---|---|---|---|---|
| C1 | Security | Critical | `health_repository.dart:255-298` | The "secure" tokens are also written to plaintext SQLite (`saveSetting` writes to both stores). `iam_refresh_token` and `iam_id_token` go **only** to SQLite. With no `allowBackup="false"`, the DB holding tokens and PHI can leave the device in Auto Backup. | Store secrets only in secure storage, migrate and delete legacy rows, disable backup (code below). |
| C2 | Auth | Critical | `splash_screen.dart:87` | `if (isAuthenticated \|\| hasProfile) → /dashboard`. A revoked session, failed refresh or the 10s timeout still lands the user on the dashboard with cached PHI. | Route on `isAuthenticated` only (code below). |
| C3 | Android / Health | Critical | `MainActivity.kt:10` | `MainActivity : FlutterActivity()`. health 13.3.2 does `(activity as ComponentActivity)` (HealthPlugin.kt:206), and FlutterActivity extends plain `Activity`, so that cast fails. Health Connect permission requests can't work. Whether this crashes or fails silently is unverified on a device. | Extend `FlutterFragmentActivity`. |
| C4 | Startup | Critical | `main.dart:49-62`, `notification_service.dart:64-74` | Before `runApp`, the app awaits the WorkManager and timezone setup **plus permission prompts**, including opening the exact-alarm Settings page. First launch shows a blank screen behind system dialogs. | Call `runApp` first; ask for permissions in context (code below). |
| C5 | Booking integrity | Critical | `booking_viewmodel.dart:202-245`, `review_booking_screen.dart:232,241` | If the slot match fails, which it always does (`"09:30"` never equals `"09:30 AM"`), it books `freeSlots.first`. If that fails, it books **any free slot in the org (possibly another doctor)**, and finally `slot_id: 0`. The local copy keeps the user's chosen time, which hides the mismatch. | Refuse to book without an explicit slot ID (code below). |
| C6 | PHI integrity | Critical | `voice_intake_viewmodel.dart:359` | `patientFhirId ?? 10001`: when the agent ends a call, the intake is saved to **patient 10001** (the mock patient). | Capture the ID at `startCall` and never default it (code below). |
| C7 | Privacy / lifecycle | Critical | `voice_intake_screen.dart:41-46` | `dispose()` doesn't end the call. Pressing back leaves the mic streaming patient audio over the WebSocket, with no way to stop it. | Add `abortCall()` in `dispose` plus a `PopScope` confirm (code below). |
| C8 | BLE | Critical | `ble_heart_rate_service.dart:137-145` | `connectionState` emits an initial `disconnected` straight away, which runs `_cleanupConnection()`. The device ref is nulled, real disconnects are never seen and `disconnect()` never closes GATT. | Subscribe after `connect()` with `.skip(1)` (code below). |
| C9 | Cross-account leak | Critical | `auth_viewmodel.dart:582-641`, `intake_viewmodel.dart:416-422` | Logout doesn't reset the Intake, Voice or Booking view models, or `last_intake_record_id` / `cached_specialists_json`. The next user sees the previous chat transcript, and a new booking can be linked to another user's intake. | Reset every view model and wipe all user tables plus secure storage in one `clearAllUserData()` (code below). |
| H1 | Fake data in prod | High | `fhir_api_client.dart:21-160`, `auth_viewmodel.dart:635-639` | Logout switches the client to a **mock interceptor** that returns fake 201s and a "John Doe 10001". Background sync then "succeeds" against it with `usr_demo_101`. | Compile the mock out (`kDebugMode`) and stop syncs on logout. |
| H2 | Release | High | `build.gradle.kts:20,39` | `com.example` app ID plus debug signing. Play rejects this, and anyone with the public debug key can sign an "update". | Real app ID plus a release keystore from `key.properties`. |
| H3 | Auth | High | `oauth_webview_screen.dart:41-100`, `MainActivity.kt:44-71` | OAuth in an embedded WebView (against RFC 8252) with unrestricted JavaScript. The app harvests the whole `iam.drgodly.com` cookie jar, with a `.drgodly.com` fallback. | Use Custom Tabs (`signInWithPKCE` exists but is unreachable) and have the server mint the FHIR JWT. |
| H4 | Concurrency | High | `fhir_api_client.dart:184-205` | 401 refresh has no single-flight lock and no retry flag. Parallel 401s refresh concurrently (breaking refresh-token rotation). A rejected fresh token loops forever. | Shared `Completer` plus `extra['retried']`. |
| H5 | Concurrency | High | `auth_viewmodel.dart:96-103` | A refresh in flight during logout re-saves the JWT and re-enables live mode, which brings the session back. | Session-generation counter; try/finally in `signOut`. |
| H6 | Logging / PHI | High | `voice_intake_service.dart:115,160`, `fhir_api_client.dart:185`, `auth_repository.dart:99` | `debugPrint` isn't stripped in release. The app logs the WS URI with the **JWT and patient email and phone**, live transcripts, FHIR error bodies and part of the JWT. | Guard with `kDebugMode` and use a redacting logger. |
| H7 | PHI in URL | High | `voice_intake_service.dart:108-114` | The JWT and patient context go in the WebSocket query string, which ends up in server and proxy logs. Email and phone are sent to the LLM without need. | Send auth in a header or first message; send only the minimum data needed. |
| H8 | Fake success | High | `booking_viewmodel.dart:528-553` | A failed cancel still deletes locally and shows "Appointment Cancelled". | Rethrow; update locally only after the server succeeds. |
| H9 | Fake success | High | `intake_viewmodel.dart:392-404`, `voice_intake_viewmodel.dart:357-377` | A failed intake save still shows `completed` and "saved to medical record". | Add a `saveFailed` state with retry. |
| H10 | Hardcoded PHI | High | `booking_viewmodel.dart:179-197` | `if (pName.isEmpty) pName = 'surya';` is **written to the patient's FHIR record**. | Delete it; block booking without a name. |
| H11 | Logic | High | `intake_chat_screen.dart:32-34,185-193` | Chat intake works once per app session; reopening it jumps to the old completion screen. | Always `reset()` on entry. |
| H12 | Logic | High | `voice_intake_screen.dart:157-168` | When the agent ends the call, the app never navigates. Tapping "Start Call" wipes the saved report and ID. | Listen for `completed` and navigate once. |
| H13 | Booking | High | `booking_viewmodel.dart:576` | A reschedule falls back to `specialists.first` and can rebook with the wrong doctor. | Resolve by `practitioner_role_id`; fail if not found. |
| H14 | Booking | High | `booking_repository.dart:186` | `int.parse(data['id'])` failing after a successful POST surfaces as "Booking error", and the retry double-books. | `tryParse`; treat post-processing failures separately. |
| H15 | Data loss | High | `profile_setup_screen.dart:615-631`, `profile_repository.dart:137-152`, `profile_screen.dart:434-446` | The guard is always true (gender defaults to `'MALE'`), so the full-replace PATCH sends empty telecom and address and **erases phone, email and address on the server**. The same happens when a field is cleared in the Edit Profile sheet. | Partial PATCH of changed fields only. |
| H16 | Validation | High | `profile_setup_screen.dart:602-604` | Empty input becomes **175 cm / 70 kg / 25 y**, saved and synced as real biometrics. Negatives are accepted, and there are no Form validators. | `Form` + validators with ranges; derive age from DOB. |
| H17 | Health Connect | High | `open_wearables_service.dart:211-229` | It requests HEIGHT, WEIGHT and ACTIVITY_INTENSITY, which the manifest doesn't declare. `hasPermissions` is therefore never true, and every sync (every 5 minutes) asks again. | Declare them or drop them; never prompt from the sync path. |
| H18 | Background | High | `background_sync_service.dart`, `vitals_foreground_service.dart` | The background Health Connect permission (`requestHealthDataInBackgroundAuthorization`) is never requested, so the worker can't read. The foreground service is never started and has hardcoded IDs (`patient-drgodly-01`). Its `health` service type is missing the permissions Android 14 requires. | Request the background permission, or remove the dead service. |
| H19 | Concurrency / storage | High | `activity_viewmodel.dart:125-160,514-909` | No sync re-entrancy guard; there are duplicate POSTs of the same record. About 8 SQLite rows per sync plus 1 per BLE beat (around 86k a day), never pruned. | In-flight guard, change detection, deterministic daily IDs, downsampling. |
| H20 | Clinical correctness | High | `ble_heart_rate_service.dart:276-286` | A single RR interval (300-2000 ms) is POSTed as **HRV**. | Compute RMSSD over a window of beats, or don't send it. |
| H21 | Alerts | High | `sqflite_database.dart:74`, `activity_viewmodel.dart:529-585` | The thresholds table is never seeded, so there are **no HR or BP alerts by default**, although the UI shows defaults. There is no de-duplication, and BLE uses its own hardcoded 130/45 limits. | Seed defaults in migration; one threshold source. |
| H22 | Reminders | High | `settings_viewmodel.dart:81-101`, `notification_service.dart:311-342` | Editing a reminder leaves the old alarms in place. On Android 14, `exact_alarms_not_permitted` throws, uncaught. | Cancel before rescheduling; fall back to inexact. |
| H23 | Fake features | High | `profile_screen.dart:22-23,743-763` | The Notifications and **Biometric login** toggles do nothing; there is no `local_auth`. | Remove them or implement them. |
| H24 | Fake data | High | `activity_tracking_screen.dart:509-530,680-731,310-334`, `dashboard_screen.dart:1540` | The hourly steps chart is an even split of the daily total, the HR curve is a fixed decorative wave, and sleep stages are made up (22/50/20/8%). Age defaults to 25 and is POSTed. | Use real Health Connect samples; show "unavailable". |
| H25 | Fake integrations | High | `open_wearables_service.dart:138-158`, `device_manager_sheet.dart:917-931` | Garmin, WHOOP, Oura and Fitbit "Link" waits 600ms, then marks the provider connected with the fake email `patient.auth@drgodly.com`. | Hide them or label them "Coming soon". |
| M1 | Session | Medium | `auth_viewmodel.dart:520-569` | A stored JWT is accepted without an expiry check, even after a server 401. `isJwtValid` returns true when `exp` is missing. | Fall back only on network errors, and only with a valid `exp`. |
| M2 | Race | Medium | `profile_viewmodel.dart:20` + splash | The constructor and splash both call `fetchOrInitProfile`, so the patient may be POSTed twice (unverified server-side dedupe). | Memoize the future; no network calls in constructors. |
| M3 | Tenant | Medium | `api_constants.dart:12`, `auth_viewmodel.dart:204` | When the org can't be resolved, the user is silently put in a hardcoded tenant UUID. | Fail the login. |
| M4 | Exported component | Medium | `AndroidManifest.xml:82-99` | The exported callback activity accepts `com.drgodly.app://*`, which other apps can intercept. | Use a verified App Link. |
| M5 | Offline | Medium | `booking_viewmodel.dart:394-401` | Any fetch error returns `[]`, then the local table is cleared, so appointments vanish offline. Errors are swallowed throughout `booking_repository.dart`. | Throw from the repository; clear only on success. |
| M6 | Race | Medium | `select_date_time_screen.dart:92-97` | Overlapping slot requests mean the last response wins, so date A's slots can show under date B. | Request token. |
| M7 | Re-entrancy | Medium | `intake_viewmodel.dart:262-319`, `select_date_time_screen.dart:629-660`, `profile_setup_screen.dart:598` | Double taps create duplicate intakes, reschedules or saves. | Busy flags. |
| M8 | WebSocket | Medium | `voice_intake_service.dart:184-197,448-453` | A network drop is treated as "end", which saves a partial intake. The socket leaks when mic permission is denied. `add` can be called after `close`. | Add a `disconnected` event plus reconnect; `await disconnect()`; check `isClosed`. |
| M9 | Leaks | Medium | `ble_heart_rate_service.dart:91`, `device_manager_sheet.dart:41,49`, `profile_screen.dart:153-199`, `dashboard_screen.dart:1369-1377`, `general_settings_screen.dart:195` | Stream subscriptions and around 17 `TextEditingController`s are never cancelled or disposed. | Make sheets stateful widgets and dispose. |
| M10 | Context after await | Medium | `profile_screen.dart:407-461`, `appointment_history_screen.dart:396-446` | The sheet or dialog `context` shadows the screen context. After `pop`, `context.mounted` is false, so success and error snackbars never appear. | Capture `ScaffoldMessenger` before popping. |
| M11 | Onboarding | Medium | `splash_screen.dart:80`, `goals_screen.dart` | No `onboarding_completed` flag. Users with an IAM name skip setup, so height, weight and DOB are never collected. Goals are never saved, and "modify anytime in Settings" is false. | Persist the flag; save goals or remove the screen. |
| M12 | Units | Medium | grep | `heightUnit`, `tempUnit` and `glucoseUnit` are saved but never read. The dashboard hardcodes cm/kg and goals of 10k steps / 500 kcal / 60 min. "Start week on" is saved and never read. | Apply the settings. |
| M13 | Data semantics | Medium | `open_wearables_service.dart:425-687` | "Resting HR" is often live HR. `contains('fit')` matches Fitbit. Steps from several sources are summed (double-counted). RMSSD and SDNN are mixed. `recordedAt` has no time-zone offset. | Fix the aggregation and use UTC ISO timestamps. |
| M14 | Rebuilds | Medium | `dashboard_screen.dart:20-23` | It watches 4 view models; BLE notifies about once a second and rebuilds two 700-1,800-line trees kept alive in the IndexedStack. | `Selector` / `context.select`; throttle; split widgets. |
| M15 | Validation | Medium | `vitals_thresholds_screen.dart:174-185`, `profile_screen.dart:345-368` | No min < max check, negatives accepted, no phone or email keyboards or formats. | Validators. |
| M16 | Dismissible | Medium | `vitals_reminders_screen.dart:499`, `notification_center_modal.dart` | Items are removed only after an async delete, which triggers the "still part of the tree" assertion. | Remove synchronously, then persist. |
| M17 | Notification IDs | Medium | `notification_service.dart:166,234,300` | Overlapping ID ranges built on `String.hashCode`, which isn't stable across Dart versions. Tapping a notification does nothing. | Deterministic ID scheme; handle `onDidReceiveNotificationResponse`. |
| M18 | Casts | Medium | `intake_models.dart:112-120`, `booking_models.dart:60,142,202,233,267`, `select_date_time_screen.dart:74`, `review_booking_screen.dart:17` | `as int?` / `int.parse(...toString())` on JSON; route arguments are hard-cast. One bad row crashes the whole list. | `tryParse`; skip bad rows; null-check arguments. |
| M19 | Hardcoded UI | Medium | `select_specialist_screen.dart:375-415`, `review_booking_screen.dart:171-187`, `booking_viewmodel.dart:432-442` | Every doctor shows "4.9 (120+ reviews)" and "Available Today". The fee is a hardcoded $120 with no payment flow. Doctor images are chosen by surname. | Use API fields or remove them. |
| M20 | Back navigation | Medium | `review_booking_screen.dart:270` | `pushNamedAndRemoveUntil(…, (r)=>false)` means back on the Confirmed screen exits the app. | Keep `/dashboard` underneath. |
| M21 | Dashboard | Medium | `dashboard_screen.dart:314-318,158,721-731` | `confirmed` shows as "Cancelled"; rescheduled is badged "BOOKED"; "Enter Room" only opens the details dialog. | Fix the status mapping; wire or hide the button. |
| L1 | Dead code | Low | various | `notification_center_modal.dart` (unreachable), `signInWithPKCE`, `login/register`, `UserHeaderAvatar`, `CleanWeightBarPainter`/`CleanEcgLinePainter`, about 20 unused color tokens, `VitalsTaskHandler`, `abandonIntakeRecord`, the `45.5` HRV filter left over from mock data. | Delete. |
| L2 | Wrong key | Low | `booking_viewmodel.dart:177` | Reads `iam_user_name`, a key that is never written. | Use `user_name`. |
| L3 | Misleading copy | Low | `login_screen.dart:260`, `welcome_screen.dart:181`, `device_manager_sheet.dart:228,616,721` | "HIPAA … Compliant" claims, "PART A · ACTIVE DEMO", and a wrong endpoint URL shown to users. | Remove. |
| L4 | Sync | Low | `health_repository.dart:182-187` | `timestamp LIKE 'date%'` marks rows inserted during an upload as synced, so they are never sent. | Mark rows by ID. |
| L5 | Tests / PII | Low | `test/domain/model/*`, `all_doctors_extracted.json` | Test fixtures contain what looks like real personal data (email, phone, DOB). The repo root has `all_doctors_extracted.json` with real-looking doctor phones and emails; it's unused. | Replace with synthetic data; remove from history. |
| L6 | Header spoofing | Low | `auth_repository.dart:22-23,283-284` | Hardcoded `Origin`/`Referer` headers to get past Better-Auth's CSRF check. | Register the app origin server-side. |
| L7 | Layering | Low | `auth_repository.dart:2,6,46` | The data layer imports a View and uses `Navigator`. | View pushes the WebView; VM receives the result. |
| L8 | Avatar | Low | `profile_screen.dart:66-87` | The picked photo is stored by its cache path (OS can purge it); "Remove" stores `''`, which leaves an inconsistent state. | Copy to the documents directory; store null. |

### Corrected code for Critical issues

**C1: secrets only in secure storage, plus backup off** (`health_repository.dart`)
```dart
static const _secureKeys = {'iam_session_token','iam_jwt_token','iam_refresh_token','iam_id_token'};

Future<String?> getSetting(String key) async {
  final db = await _dbHelper.database;
  if (_secureKeys.contains(key)) {
    final v = await SecureStorageService().readSecure(key);
    if (v != null && v.isNotEmpty) return v;
    final legacy = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (legacy.isEmpty) return null;
    final lv = legacy.first['value'] as String? ?? '';
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]); // purge plaintext
    if (lv.isEmpty) return null;
    await SecureStorageService().writeSecure(key, lv);
    return lv;
  }
  final m = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
  final v = m.isNotEmpty ? (m.first['value'] as String? ?? '') : '';
  return v.isEmpty ? null : v;
}

Future<void> saveSetting(String key, String value) async {
  final db = await _dbHelper.database;
  if (_secureKeys.contains(key)) {
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    value.isEmpty
        ? await SecureStorageService().deleteSecure(key)
        : await SecureStorageService().writeSecure(key, value); // must rethrow on failure
    return;
  }
  await db.insert('app_settings', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);
}
```
Two more changes go with this:
- In `AndroidManifest.xml`, add `android:allowBackup="false" android:fullBackupContent="false"` to `<application>`.
- Remove the `catch (_) {}` in `secure_storage_service.dart:16-18` so a failed secure write isn't silent.

**C2: splash routing** (`splash_screen.dart`)
```dart
if (!isAuthenticated) {
  if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
  return;
}
try {
  await Future.wait([profileVM.fetchOrInitProfile(), /* … */]).timeout(const Duration(seconds: 12));
} catch (_) {/* load lazily; don't block an authenticated user */}
if (!mounted) return;
Navigator.pushReplacementNamed(context, profileVM.hasCompletedOnboarding ? '/dashboard' : '/profile_setup');
```
Also stop the `ProfileViewModel` constructor from calling `fetchOrInitProfile()` (profile_viewmodel.dart:20).

**C3: `MainActivity.kt`**
```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity : FlutterFragmentActivity() { /* keep configureFlutterEngine + channels */ }
```

**C4: `main()`**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final token = await HealthRepository().getSetting('iam_jwt_token');
  if (token?.isNotEmpty == true) {
    FhirApiClient().configure(baseUrl: ApiConstants.fhirGqlUrl, token: token, isLiveMode: true);
  }
  runApp(MultiProvider(providers: [/* … */], child: const PhiaApp()));
  unawaited(NotificationService.instance.init());   // no permission prompts here
  unawaited(BackgroundSyncService.initialize());     // schedule only after login
}
// Request POST_NOTIFICATIONS inside the shell; exact alarms only when creating a reminder
// (or use AndroidScheduleMode.inexactAllowWhileIdle and drop SCHEDULE_EXACT_ALARM).
```

**C5: booking only the chosen slot** (`booking_viewmodel.dart`)
```dart
if (slotId == null || slotId <= 0) {
  throw StateError('Please select an available time slot.');
}
final effectiveSlotId = slotId;           // delete the lines 202-245 fallback chain
// …and persist the server's start time, never the client's guess:
final startStr = result['start']?.toString() ?? (throw StateError('Server returned no start time'));
```
Also remove `?? 1` for `practitionerId` at `review_booking_screen.dart:232`.

**C6 and C7: voice intake patient ID and lifecycle**
```dart
// voice_intake_viewmodel.dart
int? _patientFhirId; String? _orgId;
Future<void> startCall({required String authToken, required int patientFhirId, String? orgId}) async {
  reset(); _patientFhirId = patientFhirId; _orgId = orgId; /* … */
}
Future<void> abortCall() async {
  await _eventsSubscription?.cancel(); _eventsSubscription = null;
  await _voiceService.disconnect();
  _callState = VoiceCallState.offline; _isEndingCall = false; notifyListeners();
}
// in endCall: final pid = patientFhirId ?? _patientFhirId;
// if (pid == null) { set error 'Profile not loaded; intake not saved'; return; }   // never 10001

// voice_intake_screen.dart
late final VoiceIntakeViewModel _vm = context.read<VoiceIntakeViewModel>();
@override
void dispose() {
  if (_vm.isCallActive) _vm.abortCall();
  _pulseController.dispose(); _scrollController.dispose();
  super.dispose();
}
// Wrap Scaffold in PopScope(canPop: !_vm.isCallActive, onPopInvokedWithResult: confirm → abortCall → pop)
```
Pass `profileVm.patientFhirId` and `authVm.orgId` from `_handleStartCall`.

**C8: BLE connect** (`ble_heart_rate_service.dart`)
```dart
await _deviceStateSubscription?.cancel();
await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
_connectedDevice = device;
_deviceStateSubscription = device.connectionState.skip(1).listen((s) {
  if (s == BluetoothConnectionState.disconnected) { _cleanupConnection(); _updateState(BleDeviceState.disconnected); }
});
// after service discovery: if (_hrCharacteristic == null) { await device.disconnect(); _cleanupConnection(); return false; }
```

**C9: logout**: one place that clears everything (`auth_viewmodel.dart`)
```dart
Future<void> signOut(BuildContext context) async {
  final gen = ++_sessionGeneration;                 // invalidates in-flight refreshes (H5)
  context.read<ActivityViewModel>().pauseAutoSync();
  context.read<IntakeViewModel>().reset();
  context.read<VoiceIntakeViewModel>().reset();
  context.read<BookingViewModel>().reset();
  await Workmanager().cancelAll();
  try {
    await healthRepository.clearAllUserData();      // every user table + app_settings user keys
    await SecureStorageService().clearAll();
    FhirApiClient().configure(baseUrl: ApiConstants.fhirGqlUrl, token: null, isLiveMode: true);
  } finally {
    notifyListeners();
  }
  unawaited(_authRepository.revokeAndSignOut(_refreshToken, _sessionToken)); // best effort, after local wipe
}
```

---

## 4. Feature status

| Feature / screen | Status | Notes |
|---|---|---|
| Splash / session restore | Partial | Real get-session and refresh, but the cached-profile bypass (C2) and the unchecked JWT fallback (M1) |
| Login (OAuth PKCE) | Dynamic | Real IAM; WebView plus cookie harvest (H3); hardcoded tenant fallback |
| Logout | Partial | Incomplete wipe (C9); switches to mock backend (H1) |
| Welcome | Static | Marketing copy; both buttons go to `/login` |
| Profile setup | Partial | Saves to SQLite and FHIR, but fake defaults (H16), erases server data (H15), rarely reached (M11) |
| Goals | Static | Selections discarded |
| Complete | Partial | Gender defaults to MALE; "synchronized" copy is static |
| Dashboard rings and vitals | Partial | Real Health Connect values (subject to C3); goals hardcoded; "Resting HR" often live |
| Dashboard upcoming consultation | Dynamic | "Enter Room" does nothing; `confirmed` shows as "Cancelled" (M21) |
| Activity: hourly steps / HR curve | Static (fake) | H24 |
| Activity: sleep stages | Partial | Made-up split when stage data is missing |
| BLE pairing | Partial / broken | C8; listener leaks; false "connected" |
| Garmin / WHOOP / Oura / Fitbit | Static (mock) | H25 |
| Background sync | Non-functional | H18 |
| Foreground service | Dead | Never started |
| Reminders | Dynamic | H22 |
| Thresholds / alerts | Partial | Off by default (H21) |
| Clinical units | Mostly static | Only weight is applied, on one tile |
| Specialist list | Dynamic | API plus SQLite cache; ratings and "Available Today" hardcoded |
| Search / filter | Partial | Client-side; name and first specialty only |
| Date / time slots | Dynamic | Real `/slots`; race on date change; no filter for past slots |
| Review / fee | Partial | $120 hardcoded, no payment |
| Create appointment | Partial | Real POST, but wrong-slot fallback (C5) and "surya" (H10) |
| Confirmed screen | Static | Shows the arguments it was passed |
| Appointment history | Dynamic | Wiped when offline (M5) |
| Cancel | Partial | Fake success (H8) |
| Reschedule | Partial | Dashboard only; wrong-doctor fallback (H13) |
| Chat intake | Dynamic | Works once per session (H11); save failures hidden |
| Voice intake | Dynamic | C6, C7, H12 |
| Intake completion / summary | Partial | Real report; "saved" claims unconditional; can mix chat and voice data |
| Intake → appointment link | Partial | Stale or other-user fallback (C9) |
| Profile screen / edit | Partial | Edit can erase server fields; Notifications and biometric toggles are fake |
| General settings: language | Partial | Hand-rolled map; 6 of 22 keys used in 2 screens; no RTL |
| General settings: start week on | Static | Saved, never read |
| Notification center | Dead | Unreachable since the bell was removed |
| Push notifications / role-based access / pagination | Not implemented | Local notifications only; one patient role; `limit=50`, no paging |

---

## 5. Standards scorecard

| Area | Score | Justification |
|---|---|---|
| Code quality | 4/10 | `analyze` is clean but uses only stock `flutter_lints`. Files run to 1,800 lines, about 365 inline `GoogleFonts` calls, widespread `catch (_) {}`, unsafe casts. |
| Architecture | 4/10 | MVVM folders exist, but there is no DI, a repository imports a View, business logic sits in screens, all view models are global and never reset, and mock code is mixed into the production client. |
| Security (OWASP Mobile) | 2/10 | Plaintext tokens and PHI (M2: insecure storage), backup enabled, debug signing, WebView OAuth plus cookie harvest, PHI in logs and URLs, auth bypass on splash. No certificate pinning. Mitigating: HTTPS everywhere, PKCE with `Random.secure`, R8 on. |
| Performance | 4/10 | Startup blocked by permissions; per-second rebuilds of huge trees; unbounded SQLite growth; duplicate POSTs; around 5 MB of doctor PNGs (5 unused); four ~68 MB APKs. |
| Accessibility | 2/10 | 0 `Semantics` widgets, 3 tooltips across 23 IconButtons, several touch targets under 48dp, fixed-height inputs, `textMuted` contrast about 3.4:1. |
| Testing / observability | 1.5/10 | 6 unit test files (models and PKCE only). The 81% coverage figure covers only 293 lines (about 1-2% of 23.5k). One test is tautological and depends on the time zone. No widget or integration tests, no CI, no crash reporting or analytics. |
| UI consistency | 5/10 | Consistent palette and visual identity, but 153 hex literals, `colorScheme` and `textTheme` never referenced, and one screen in a dark DotMatrix style. |
| i18n / dark mode / RTL | 1/10 | Hand-rolled map; no `gen-l10n`; light theme only; Arabic and Farsi offered without RTL. |
| Play Store readiness | 2/10 | `com.example` ID, debug signing, no privacy policy found in the app, Health Connect rationale screen unverified, exact-alarm and health foreground-service declarations without justification. 64-bit is fine (Flutter default). |

---

## 6. UI/UX recommendations

1. **Build a real design system.** Move colors into `ColorScheme`, add `textTheme` roles, and add `elevatedButtonTheme` and `inputDecorationTheme`. Then extract the most duplicated widgets: the navy header card (around 9 copies), the logo app bar (4 copies), the sticky bottom action bar, the labelled input, the gender chip (3 variants), the sheet handle (8 copies) and the status badge.
2. **Be honest about state.** Remove or mark every fake success, fake chart, fake toggle and fake integration. Show "unavailable" or "not saved, retry" instead.
3. **Loading, empty and error states.**
   - The dashboard shows "telemetry is synchronized" while values are still `--`.
   - Repositories return `[]` on error, so the UI can't tell "no doctors" from "offline".
   - `RefreshIndicator` doesn't wrap the empty state.
   - Appointment history has no loader.
4. **Permissions.** Ask in context with an explanation first. Add an "Open settings" path for permanently denied mic or Health Connect.
5. **Back navigation.** Add `PopScope` to voice and chat intake (abandon or confirm), keep the dashboard under the Confirmed screen, and handle system back on the completion screen.
6. **Responsiveness.** Many `Row`s have no `Expanded` around their text (goals, profile nav rows, dashboard stat row, navy titles). Fixed heights of 48, 38 and 60×92 break at 320dp or at text scale 1.3 and above (needs a device check). Test with `MediaQuery.textScaler` 2.0 and at tablet width; nothing adapts to wide layouts.
7. **Accessibility.** Add `Semantics` and `tooltip` to icon buttons, the camera badge, chips and painted charts; use minimum 48dp targets; replace the `GestureDetector`+`AbsorbPointer` DOB field with a focusable control.
8. **Localization, dark mode and RTL.** Migrate to ARB / `gen-l10n`, drive `MaterialApp.locale` from settings, add a `darkTheme`, and use `EdgeInsetsDirectional`.
9. **Copy.** Remove dev and roadmap labels and unbacked "HIPAA compliant" claims. Fix "Vitals Reminders & Thresholds" on the reminders-only screen.
10. **Consistency.** The thresholds screen uses a dark DotMatrix style unlike every other screen; bring it in line.

---

## 7. Dependency audit

| Package | Current → latest | Note |
|---|---|---|
| flutter_local_notifications | 17.2.4 → 23.0.0 | 6 majors behind; newer versions improve exact-alarm handling |
| flutter_blue_plus | 1.36.8 → 2.3.15 | Major behind; check the license terms of 2.x before upgrading |
| permission_handler | 12.0.2 → 13.0.2 | |
| flutter_web_auth_2 | 4.1.0 → 5.1.0 | **Effectively unused** (only the dead `signInWithPKCE` path); `OAuthCallbackActivity` depends on it |
| timezone / flutter_timezone | 0.9.4 / 3.0.1 → 0.11.2 / 5.1.1 | |
| google_fonts | 6.3.3 → 9.0.0 | Fetches fonts at runtime by default; bundle them and set `allowRuntimeFetching = false` for offline use and privacy |
| flutter_lints | 5.0.0 → 6.0.0 | Also consider stricter rules (`unawaited_futures`, `use_build_context_synchronously`, `avoid_dynamic_calls`, `cancel_subscriptions`, `close_sinks`) |
| flutter_launcher_icons | 0.13.1 → 0.14.4 | |
| dio, sqflite, intl, image_picker, crypto | minor or patch behind | Safe upgrades |
| flutter_foreground_task | 11.0.3 | **Unused in practice** (service never started); remove it, along with `FOREGROUND_SERVICE_HEALTH` |
| webview_flutter | 4.14.1 | Risky use (H3) |
| sqflite (no encryption) | — | ProGuard keeps `net.sqlcipher`, but SQLCipher isn't a dependency. Adopt `sqflite_sqlcipher` for PHI, or drop that rule. |
| Missing | — | `local_auth` (the biometric toggle implies it), a crash reporter, `mocktail` for tests |

`pub outdated` doesn't check for known vulnerabilities, so this table covers versions only and not security advisories.

**Asset usage:** `assets/doctors/doctor_4..8.png` (about 3.3 MB) are declared in `pubspec.yaml` but never used.

---

## 8. Action plan

**Quick wins (about 1-3 days)**
1. C3 (`FlutterFragmentActivity`), C8 (BLE `.skip(1)`), C6 (patient-ID default), C5 (delete slot fallback), H10 ("surya"), H16 (fake 175/70/25), H15 (send only changed fields).
2. C1 plus `allowBackup=false`; wrap every `debugPrint` touching tokens or PHI in `kDebugMode` (H6).
3. C2 splash routing; C4 move permission prompts after `runApp`.
4. C7 voice `dispose` / `PopScope`; H11 chat reset; H12 auto-end navigation.
5. Remove the fake toggles, fake provider linking, fake charts and dev copy (H23-H25, L3).
6. Release config: real `applicationId`, release keystore (H2). Delete the unused `all_doctors_extracted.json` and the tracked `android/build/reports/problems/problems-report.html`, and the stray APKs at the repo root (about 405 MB on disk; they're gitignored, so never committed).

**Short term (about 1-2 weeks)**
- Logout overhaul (C9, H1, H5, M3).
- Single-flight token refresh (H4).
- Custom Tabs login (H3).
- Server-success-first semantics for cancel and intake (H8, H9).
- Sync guard, deduplication and pruning (H19).
- Health Connect permission set and background permission (H17, H18).
- Threshold seeding and de-duplication (H21).
- Reminder fixes (H22).
- Form validation (M15).
- Repositories throw typed errors; UI shows error states (M5).

**Long term**
- Real DI (`get_it` or Riverpod); remove `BuildContext` from view models and repositories; split the 900-1,800-line screens; move logic out of `build`.
- Design system plus `gen-l10n`, dark mode and RTL; accessibility pass.
- Tests: view model unit tests with mocked repositories, widget tests for the booking and intake flows, an `integration_test` smoke test. CI (GitHub Actions: analyze, test, build) with a coverage gate.
- Crashlytics or Sentry with PHI scrubbing; structured redacting logger.
- SQLCipher for local PHI; consider certificate pinning; App Links for the OAuth redirect.
- Play compliance: privacy policy, Health Connect declaration form, data safety form.

---

## 9. Overall health

**About 3.5/10: a feature-rich prototype, not production-ready.** Most features hit real backends (OAuth/IAM, FHIR booking, streaming AI intake, voice WebSocket, Health Connect aggregation), and the code compiles cleanly.

For a health app, the dangerous part is that the code quietly substitutes data:
- intake saved to the wrong patient (C6);
- bookings for a slot or doctor the user didn't pick (C5);
- made-up names and biometrics written to FHIR (H10, H16);
- server profile fields erased (H15);
- fake successes on cancel and save (H8, H9);
- fabricated charts (H24).

The session and storage layer has several Critical flaws: plaintext tokens, the splash bypass and the incomplete logout. Health Connect and BLE, the app's core sensor features, have blocking bugs (C3, C8). Fix the Critical and High items before any real-patient release; most of them are small, local changes.

**Not verified:**
- Runtime behaviour on a device, including whether C3 crashes or fails silently, and real overflow at large font sizes.
- Server-side semantics: whether patient creation is de-duplicated, the time zone of slot dates, and the shape of the booking response.
- iOS: it wasn't reviewed.
