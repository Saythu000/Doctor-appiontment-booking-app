# Background Work & Health Connect Audit

**Date:** 2026-09-30  
**Project:** DrGodly (PHIA - Personal Health Insight Assistance)  
**Target Android:** Android 14 to 16 (`minSdk 34`, `targetSdk 36`)

---

## 1. Audit Overview of All Continuous & Background Work Mechanisms

This audit analyzes every continuous sensor, background task, periodic timer, and notification mechanism in the application:
1. **Foreground Task** (`VitalsForegroundService`)
2. **Periodic UI Auto-Sync** (`ActivityViewModel._autoSyncTimer` & `ProfileViewModel._backgroundSyncTimer`)
3. **Pedometer Sensor & Accelerometer Fallback** (`PedometerSensor` & actigraphy)
4. **BLE Heart Rate Connection** (`BleHeartRateService`)
5. **GPS Location Tracking** (`GPSLocationSensor`)
6. **Scheduled Alarms & Notifications** (`NotificationService`)

---

## 2. Detailed Technical Breakdown by Mechanism

### 1. Foreground Task (`VitalsForegroundService`)
- **File:** `lib/data/service/vitals_foreground_service.dart`
- **1. Start & Stop Conditions; Runs when Closed?:**
  - **Start:** Started explicitly in `ActivityViewModel.initDashboard()` via `VitalsForegroundService.start()` when the dashboard initializes.
  - **Stop:** Only stopped if `VitalsForegroundService.stop()` is called (not called anywhere in standard app navigation; no stop button in UI).
  - **Runs when Closed:** **YES**. Because it is registered as an Android Foreground Service with a sticky ongoing notification (`serviceId: 256`), the Android OS keeps the process alive even when the app is swiped away from recent tasks, unless killed by the OS under severe memory pressure or stopped manually in system settings.
- **2. CPU Wake / Callback Frequency:**
  - Configured with `ForegroundTaskEventAction.repeat(15 * 60000)` (fires every **15 minutes** / 900 seconds).
  - **Wake Lock Impact:** Explicitly requests `allowWakeLock: true` and `allowWifiLock: true`. This prevents the CPU and Wi-Fi subsystem from entering deep Doze sleep mode while active.
- **3. Health Connect Data Read per Cycle:**
  - Reads a **48-hour time window** (`startTime: now.subtract(const Duration(hours: 48))` to `endTime: now`).
  - Queries **18 candidate HealthDataTypes**: `HEART_RATE`, `RESTING_HEART_RATE`, `HEART_RATE_VARIABILITY_RMSSD`, `STEPS`, `SLEEP_SESSION`, `SLEEP_ASLEEP`, `SLEEP_LIGHT`, `SLEEP_DEEP`, `SLEEP_REM`, `SLEEP_AWAKE`, `ACTIVE_ENERGY_BURNED`, `TOTAL_CALORIES_BURNED`, `BASAL_ENERGY_BURNED`, `DISTANCE_WALKING_RUNNING`, `BLOOD_OXYGEN`, `WORKOUT`, `HEIGHT`, `WEIGHT`.
  - Fallback logic: If batch query returns empty, loops through all 18 types sequentially. If SpO2 is missing, queries an extended **7-day window**.
- **4. Network Calls per Cycle:**
  - **0 network calls** inside `VitalsTaskHandler._performSync()`. It calls `_service.fetchLatestVitals()` which reads local Health Connect IPC and then calls `FlutterForegroundTask.sendDataToMain()`.
  - *Note:* If the main isolate is listening, `ActivityViewModel` may trigger 1 remote network call (`vitalsRepository.submitVitals()`) to `https://fhirgql.drgodly.com`.

---

### 2. Periodic UI Timers (Auto-Sync & Background Sync)
- **Files:** `lib/viewmodel/activity_viewmodel.dart` (Line 522), `lib/viewmodel/profile_viewmodel.dart` (Line 323)
- **1. Start & Stop Conditions; Runs when Closed?:**
  - **Start:** In `ActivityViewModel.initDashboard()` (`_autoSyncTimer`) and `ProfileViewModel` constructor (`_startBackgroundSyncTimer`).
  - **Stop:** In `dispose()` of the respective ViewModels.
  - **Runs when Closed:** **NO**. Standard Dart `Timer.periodic` instances live inside the Flutter Engine VM isolate and terminate when the application process dies.
- **2. CPU Wake / Callback Frequency:**
  - `ActivityViewModel._autoSyncTimer`: Fires every **5 minutes** (300 seconds).
  - `ProfileViewModel._backgroundSyncTimer`: Fires every **60 seconds** (1 minute).
  - `ActivityViewModel._stopwatchTimer`: Fires every **1 second** during active workout sessions only.
- **3. Health Connect Data Read per Cycle:**
  - `ActivityViewModel`: Reads the exact same 48-hour window across 18 HealthDataTypes via `openWearablesService.fetchLatestVitals()`.
  - `ProfileViewModel`: 0 Health Connect reads (reads local SQLite `health_metrics` table).
- **4. Network Calls per Cycle:**
  - `ActivityViewModel`: **2 network calls** per 5-minute cycle:
    1. `vitalsRepository.getMyVitals()` (GET from `https://fhirgql.drgodly.com`)
    2. `vitalsRepository.submitVitals()` (POST to `https://fhirgql.drgodly.com/api/v1/vitals/`)
  - `ProfileViewModel`: **1 network call** per 60-second cycle (`healthRepository.uploadPendingMetrics()`).

---

### 3. Pedometer Sensor & Accelerometer Fallback
- **Files:** `lib/data/service/pedometer_sensor.dart`, `lib/viewmodel/activity_viewmodel.dart`
- **1. Start & Stop Conditions; Runs when Closed?:**
  - **Hardware step counting via phone sensors is DISABLED.** `pedometer_sensor.dart` has empty `startSensor()` and `stopSensor()` methods.
  - In `activity_viewmodel.dart`: Actigraphy accelerometer subscription `_sleepAccSub` is explicitly cancelled in `startSleepTracking()` (Line 740).
  - **Runs when Closed:** **NO**. Sensor streams are inactive.
- **2. CPU Wake / Callback Frequency:**
  - **0 Hz / Dormant**. Neither hardware pedometer nor accelerometer listeners are active. All step data is queried on-demand from Health Connect.
- **3. Health Connect Data Read per Cycle:**
  - 0 direct reads from the sensor file itself (handled by `OpenWearablesService` during sync).
- **4. Network Calls per Cycle:**
  - **0 network calls**.

---

### 4. BLE Connection (`BleHeartRateService`)
- **File:** `lib/data/service/ble_heart_rate_service.dart`
- **1. Start & Stop Conditions; Runs when Closed?:**
  - **Start:** Started manually when user scans and connects to a BLE peripheral in `DeviceManagerSheet` (`connectToDevice()`).
  - **Stop:** Stopped via `disconnect()`, app teardown, or when the peripheral goes out of range.
  - **Runs when Closed:** **NO** (unless retained by a persistent native service, which is not implemented for BLE). The GATT connection drops when the app process is destroyed.
- **2. CPU Wake / Callback Frequency:**
  - Subscribed to GATT Characteristic `0x2A37` (Heart Rate Measurement) notifications.
  - Fires callbacks approximately **1 Hz (once per second)** whenever the peripheral transmits an updated heart rate packet.
- **3. Health Connect Data Read per Cycle:**
  - **0 Health Connect reads**. Operates via direct Bluetooth Low Energy GATT streaming.
- **4. Network Calls per Cycle:**
  - **0 direct network calls**. Live heart rate is buffered and saved locally to SQLite (`HealthRepository.saveMetric`).

---

### 5. GPS Location Tracking (`GPSLocationSensor`)
- **File:** `lib/data/service/gps_location_sensor.dart`, `lib/viewmodel/activity_viewmodel.dart`
- **1. Start & Stop Conditions; Runs when Closed?:**
  - **Start:** User taps "Start Workout" in the dashboard (`startGpsWorkout()`).
  - **Stop:** User taps "Finish" or "Discard Workout" (`stopGpsWorkout()`).
  - **Runs when Closed:** **NO**. The stream is tied to `_gpsSub` in `ActivityViewModel` and is not wrapped in a background location service.
- **2. CPU Wake / Callback Frequency:**
  - Configured with `LocationAccuracy.high` and `distanceFilter: 3` (meters).
  - Fires callbacks **every 3 meters of physical movement**, keeping the GPS baseband and application CPU active throughout the workout.
- **3. Health Connect Data Read per Cycle:**
  - **0 Health Connect reads**.
- **4. Network Calls per Cycle:**
  - **0 network calls during tracking**. Waypoints are written to SQLite table `workout_route_points`.

---

### 6. Notifications & Alarms (`NotificationService`)
- **File:** `lib/data/service/notification_service.dart`
- **1. Start & Stop Conditions; Runs when Closed?:**
  - **Start:** Scheduled when an appointment is booked (60 min, 30 min, 10 min prior) or when daily vitals reminders are configured.
  - **Stop:** Triggers once at the scheduled timestamp, or cancelled via `cancelAppointmentReminders()`.
  - **Runs when Closed:** **YES**. Uses Android system `AlarmManager` / `NotificationManager` via `flutter_local_notifications`. The OS wakes the device to display the notification even if the app is closed.
- **2. CPU Wake / Callback Frequency:**
  - Wakes the CPU at exact scheduled target times using `AndroidScheduleMode.exactAllowWhileIdle`.
- **3. Health Connect Data Read per Cycle:**
  - **0 Health Connect reads**.
- **4. Network Calls per Cycle:**
  - **0 network calls**. Local notification triggered on-device.

---

## 3. Android 14+ Foreground Service Compliance

Android 14 (API 34) and Android 15 (API 35) enforce strict runtime foreground service rules:

| Requirement | Project Implementation | Status |
| :--- | :--- | :--- |
| **`android:foregroundServiceType` in Manifest** | Declared on `ForegroundService`: `android:foregroundServiceType="health\|dataSync"` | **COMPLIANT** |
| **Matching Manifest Permissions** | `android.permission.FOREGROUND_SERVICE`<br>`android.permission.FOREGROUND_SERVICE_HEALTH`<br>`android.permission.FOREGROUND_SERVICE_DATA_SYNC` | **COMPLIANT** |
| **Runtime Policy Constraints** | Android 14+ requires `health` type services to be linked to an active user session or sensor stream, and `dataSync` jobs are subject to 6-hour execution limits. Running indefinitely every 15 mins with wake locks risks OS termination. | **AT RISK** |

---

## 4. Complete Manifest Permissions Audit

All 20 permissions declared in `android/app/src/main/AndroidManifest.xml`:

| Permission | Declared In Manifest | Actually Used in Code? | Location & Usage Analysis |
| :--- | :--- | :--- | :--- |
| `android.permission.INTERNET` | Yes | **YES** | Dio HTTP client connecting to FHIR server and IAM. |
| `android.permission.CAMERA` | Yes | **DEAD / UNUSED** | Declared for camera. `camera` package is in `pubspec.yaml`, but no camera preview or scanning screen exists in `lib/`. Photo picker uses system intents. |
| `android.permission.ACCESS_FINE_LOCATION` | Yes | **YES** | Used in `GPSLocationSensor` for outdoor workout route tracking. |
| `android.permission.ACCESS_COARSE_LOCATION` | Yes | **YES** | Fallback for GPS geolocation. |
| `android.permission.ACTIVITY_RECOGNITION` | Yes | **PARTIALLY USED** | Requested at runtime in `ActivityViewModel.requestRuntimePermissions()`, but hardware pedometer is disabled in code. |
| `android.permission.POST_NOTIFICATIONS` | Yes | **YES** | Android 13+ permission for showing appointment alerts and sync notifications. |
| `android.permission.SCHEDULE_EXACT_ALARM` | Yes | **YES** | Used for appointment reminders via `flutter_local_notifications`. |
| `android.permission.USE_EXACT_ALARM` | Yes | **DEAD / UNNECESSARY** | Over-privileged. Play Store restricts this permission to calendar/alarm apps. Not required if using inexact alarms. |
| `android.permission.RECEIVE_BOOT_COMPLETED` | Yes | **YES** | Used by `flutter_local_notifications` to reschedule alarms after device reboot. |
| `android.permission.BLUETOOTH` (maxSdk 30) | Yes | **YES** | Legacy BLE compatibility for older Android versions. |
| `android.permission.BLUETOOTH_ADMIN` (maxSdk 30) | Yes | **YES** | Legacy BLE adapter control. |
| `android.permission.BLUETOOTH_SCAN` | Yes | **YES** | BLE device scanning (`neverForLocation` flag properly set). |
| `android.permission.BLUETOOTH_CONNECT` | Yes | **YES** | BLE GATT connection in `BleHeartRateService`. |
| `READ_STEPS` | Yes | **YES** | Reads steps from Health Connect in `open_wearables_service.dart`. |
| `READ_HEART_RATE` | Yes | **YES** | Reads continuous & sample HR points. |
| `READ_RESTING_HEART_RATE` | Yes | **YES** | Populates resting heart rate tile. |
| `READ_ACTIVE_CALORIES_BURNED` | Yes | **YES** | Active workout calorie calculation. |
| `READ_TOTAL_CALORIES_BURNED` | Yes | **YES** | Total daily energy expenditure calculation. |
| `READ_BASAL_METABOLIC_RATE` | Yes | **YES** | Baseline metabolic burn. |
| `READ_EXERCISE` | Yes | **YES** | Imports workout sessions. |
| `READ_DISTANCE` | Yes | **YES** | Aggregates daily distance in meters. |
| `READ_SLEEP` | Yes | **YES** | Reads sleep sessions and sleep stages. |
| `READ_HEART_RATE_VARIABILITY` | Yes | **YES** | RMSSD stress & recovery calculations. |
| `READ_OXYGEN_SATURATION` | Yes | **YES** | SpO2 monitoring with fallback queries up to 7 days. |
| `READ_BLOOD_PRESSURE` | Yes | **DEAD / UNUSED** | Declared in Manifest, but no read logic exists in `open_wearables_service.dart`. |
| `READ_HEALTH_DATA_IN_BACKGROUND` | Yes | **DEAD / UNUSED** | Declared in Manifest, but native Health Connect 1.1.0 background session contracts are not implemented. |
| `FOREGROUND_SERVICE` | Yes | **YES** | Required for `vitals_foreground_service.dart`. |
| `FOREGROUND_SERVICE_HEALTH` | Yes | **YES** | Android 14+ requirement for health-related foreground service. |
| `FOREGROUND_SERVICE_DATA_SYNC` | Yes | **YES** | Android 14+ requirement for data sync foreground service. |

---

## 5. Ranking of Mechanisms by Battery Drain Impact

| Rank | Mechanism | Severity | Primary Reason for Battery Drain |
| :---: | :--- | :---: | :--- |
| **1** | **`VitalsForegroundService`** | **CRITICAL** | Runs indefinitely even when closed; **holds active `allowWakeLock: true` and `allowWifiLock: true`**; executes 18+ Health Connect IPC queries every 15 minutes; prevents Android Doze mode. |
| **2** | **GPS Location Tracking** (`GPSLocationSensor`) | **HIGH** *(During Workout)* | Keeps hardware GPS chipset and CPU continuously active with a high-accuracy 3-meter distance filter. |
| **3** | **`ProfileViewModel._backgroundSyncTimer`** | **HIGH** | Fires every **60 seconds**, repeatedly polling SQLite and keeping cellular/Wi-Fi modem radios in high-power state to POST metrics. |
| **4** | **`ActivityViewModel._autoSyncTimer`** | **MEDIUM-HIGH** | Fires every **5 minutes** while UI is active, executing duplicate 48-hour Health Connect queries and making 2 remote HTTP calls to `fhirgql.drgodly.com`. |
| **5** | **BLE Heart Rate Stream** (`BleHeartRateService`) | **MEDIUM** *(When Connected)* | 1 Hz GATT notification callbacks keep Bluetooth controller and application isolate processing events every second. |
| **6** | **Exact Alarms** (`NotificationService`) | **LOW-MEDIUM** | Uses `exactAllowWhileIdle` to wake CPU from deep sleep at scheduled times. |
| **7** | **Pedometer & Accelerometer** | **NEGLIGIBLE** | Completely disabled in code (0 Hz). |

