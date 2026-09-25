import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/model/health_metrics.dart';
import '../../domain/model/vitals_payload.dart';
import '../../data/service/pedometer_sensor.dart';
import '../../data/service/gps_location_sensor.dart';
import '../../data/repository/health_repository.dart';
import '../../data/repository/vitals_repository.dart';
import '../../data/service/notification_service.dart';
import '../../data/service/ble_heart_rate_service.dart';
import '../../data/service/open_wearables_service.dart';
import '../../data/service/vitals_foreground_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:health/health.dart';

class ActivityViewModel extends ChangeNotifier {
  final PedometerSensor pedometer;
  final GPSLocationSensor gps;
  final HealthRepository repository;
  final VitalsRepository vitalsRepository = VitalsRepository();
  final BleHeartRateService bleService = BleHeartRateService();
  final OpenWearablesService openWearablesService = OpenWearablesService();

  // --- BLE & Smartwatch Telemetry State ---
  StreamSubscription<int>? _bleHrSub;
  StreamSubscription<double>? _bleHrvSub;
  String? connectedBleDeviceName;

  // --- Live Steps State ---
  int liveSteps = 0;
  StreamSubscription<int>? _stepsSub;

  // --- Runtime Permission Handler Status ---
  bool hasActivityPermission = false;
  bool hasLocationPermission = false;

  // --- Sleep & Actigraphy State ---
  double liveSleep = 0.0;
  double dashboardSleep = 0.0;
  int deepSleepMinutes = 0;
  int lightSleepMinutes = 0;
  int remSleepMinutes = 0;
  int awakeMinutes = 0;
  double? dashboardSpo2;
  StreamSubscription<UserAccelerometerEvent>? _sleepAccSub;
  Timer? _actigraphyTimer;

  // --- Weekly Progress List ---
  List<int> weeklyCaloriesList = [0, 0, 0, 0, 0, 0, 0];

  // --- Live GPS Workout State ---
  bool isGpsTracking = false;
  bool isGpsPaused = false;
  int elapsedSeconds = 0;
  double totalDistanceKm = 0.0;
  double currentSpeedKmh = 0.0;
  double gpsAccuracy = 0.0;
  final List<Position> routeCoordinates = [];
  
  StreamSubscription<Position>? _gpsSub;
  Timer? _stopwatchTimer;
  Position? _lastGpsPosition;
  String? _currentWorkoutId;

  // --- Dashboard Metrics Cache (SQLite Historical Reads) ---
  int dashboardSteps = 0;
  double dashboardHr = 0.0;
  int? dashboardMinHr;
  int? dashboardMaxHr;
  double dashboardHrv = 0.0;
  double dashboardDistanceKm = 0.0;
  int dashboardActiveTimeMins = 0;
  double dashboardCalories = 0.0;

  // --- User Bio-Data State (Weight, Height, Age) ---
  double userWeight = 0.0;
  double userHeight = 0.0;
  int userAge = 0;

  int liveActiveMins = 0;

  // --- Open-Wearables / Health Connect Sync State ---
  bool isOpenWearablesSynced = false;
  String? syncedProviderName;
  Timer? _autoSyncTimer;

  // Steps strictly reflect synced data from Google Fit / Health Connect / Wearables
  int get currentSteps => dashboardSteps;
  int get currentActiveMins => liveActiveMins > 0 ? liveActiveMins : (dashboardActiveTimeMins > 0 ? dashboardActiveTimeMins : 0);
  // Calories strictly reflect synced data from Google Fit / Health Connect / Wearables (no mathematical formula fallback)
  int get currentCalories => dashboardCalories > 0 ? dashboardCalories.toInt() : 0;
  double get currentSleep => liveSleep > 0.0 ? liveSleep : (dashboardSleep > 0.0 ? dashboardSleep : 0.0);
  bool get isStepSensorFallback => pedometer.isUsingAccelerometer;

  /// Energy Meter / Body Battery score computed from Sleep, Steps, and Activity (0-100)
  int get energyMeterScore {
    if (currentSteps == 0 && currentSleep == 0.0 && currentActiveMins == 0) {
      return 0; // Fresh account or pending sync
    }
    double score = 50.0; // Baseline
    // Sleep contribution (up to +35 pts for 7-8h sleep)
    final sleepH = currentSleep;
    if (sleepH >= 7.0) {
      score += 35.0;
    } else if (sleepH > 0) {
      score += (sleepH / 7.0) * 35.0;
    } else {
      score += 10.0;
    }

    // Step drain (more steps drain energy throughout the day)
    final drain = (currentSteps / 10000.0) * 20.0;
    score -= drain;

    // Active minutes drain
    final activeDrain = (currentActiveMins / 60.0) * 15.0;
    score -= activeDrain;

    return score.clamp(10, 100).round();
  }

  DateTime? _lastBleFhirSyncTime;

  ActivityViewModel({
    required this.pedometer,
    required this.gps,
    required this.repository,
  }) {
    // Listen to real-time BLE Heart Rate packets (GATT 0x180D / 0x2A37)
    _bleHrSub = bleService.heartRateStream.listen((bpm) {
      if (bpm > 0) {
        dashboardHr = bpm.toDouble();
        _recordLiveBleHeartRate(bpm);
        notifyListeners();
      }
    });

    // Listen to real-time BLE HRV packets (RR-interval)
    _bleHrvSub = bleService.hrvStream.listen((hrv) {
      if (hrv > 0) {
        dashboardHrv = hrv;
        notifyListeners();
      }
    });

    initDashboard();
  }

  /// Store live BLE HR into local repository and throttle sync to FHIR server
  void _recordLiveBleHeartRate(int bpm) async {
    try {
      final now = DateTime.now();
      await repository.saveMetric(HealthMetric(
        id: 'ble_hr_${now.millisecondsSinceEpoch}',
        type: 'heart_rate',
        value: bpm.toDouble(),
        timestamp: now,
      ));

      // Throttle FHIR server POSTs to once every 15 seconds to avoid network spam
      if (_lastBleFhirSyncTime == null || now.difference(_lastBleFhirSyncTime!).inSeconds >= 15) {
        _lastBleFhirSyncTime = now;
        final userId = await repository.getSetting('iam_user_id') ?? 'usr_demo_101';
        final orgId = await repository.getSetting('iam_org_id') ?? 'org_drgodly_default';

        await vitalsRepository.submitVitals(
          VitalsRecord(
            heartRate: bpm,
            heartRateVariability: dashboardHrv > 0 ? dashboardHrv : null,
          ),
          userId: userId,
          orgId: orgId,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Error recording live BLE HR: $e');
      }
    }
  }

  Future<void> requestHardwarePermissions() async {
    if (kDebugMode) {
      print('[ActivityViewModel] Starting runtime hardware permission requests...');
    }

    // A. Request Notifications (for vital alerts & appointment updates)
    try {
      final notifStatus = await Permission.notification.request();
      if (kDebugMode) {
        print('[ActivityViewModel] Notification permission status: ${notifStatus.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to request notification permission: $e');
      }
    }

    // B. Request Activity Recognition (Pedometer)
    try {
      final activityStatus = await Permission.activityRecognition.request();
      hasActivityPermission = activityStatus.isGranted;
      if (kDebugMode) {
        print('[ActivityViewModel] Activity Recognition status: ${activityStatus.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to request activity recognition permission: $e');
      }
    }

    // C. Request Location (GPS)
    try {
      final locationStatus = await Permission.locationWhenInUse.request();
      hasLocationPermission = locationStatus.isGranted;
      if (kDebugMode) {
        print('[ActivityViewModel] Location status: ${locationStatus.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to request location permission: $e');
      }
    }

    // D. Request Camera (Flash/BPM Vital Sensing)
    try {
      final cameraStatus = await Permission.camera.request();
      if (kDebugMode) {
        print('[ActivityViewModel] Camera status: ${cameraStatus.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to request camera permission: $e');
      }
    }

    // Small delay so Android OS dismisses earlier permission dialogs cleanly before Health Connect modal
    await Future.delayed(const Duration(milliseconds: 600));

    // E. Request Android Health Connect permissions popup directly on launch
    try {
      final candidateTypes = [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.WORKOUT,
      ];
      final health = Health();
      await health.configure();
      final types = candidateTypes.where((t) => health.isDataTypeAvailable(t)).toList();
      bool? hasPerm;
      try {
        hasPerm = await health.hasPermissions(types);
      } catch (_) {}
      if (hasPerm != true) {
        try {
          await health.requestAuthorization(types);
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Auto Health Connect permission request error: $e');
      }
    }

    notifyListeners();

    // If activity recognition was granted, start native steps tracker immediately
    if (hasActivityPermission) {
      await startStepsTracking();
    }
    
    // Start background sync service
    VitalsForegroundService.start();

    // Always initialize dashboard after permission check (fallback stats load if denied)
    await initDashboard();
  }

  double _getTodayMetricValue(List<HealthMetric> metrics) {
    final now = DateTime.now();
    for (var m in metrics) {
      if (m.timestamp.year == now.year &&
          m.timestamp.month == now.month &&
          m.timestamp.day == now.day) {
        return m.value;
      }
    }
    return 0.0;
  }

  Future<void> initDashboard() async {
    // 1. Fetch latest baseline logs from local database first (immediate load)
    try {
      // Load user bio data (Weight, Height, Age) first from SQLite
      final weightMetric = await repository.getRecentMetrics('weight');
      if (weightMetric.isNotEmpty) {
        userWeight = weightMetric.first.value;
      } else {
        final cachedWeight = await repository.getProfileValue('user_weight');
        if (cachedWeight != null && cachedWeight.isNotEmpty) {
          userWeight = double.tryParse(cachedWeight) ?? 0.0;
        }
      }
      
      final heightMetric = await repository.getRecentMetrics('height');
      if (heightMetric.isNotEmpty) {
        userHeight = heightMetric.first.value;
      } else {
        final cachedHeight = await repository.getProfileValue('user_height');
        if (cachedHeight != null && cachedHeight.isNotEmpty) {
          userHeight = double.tryParse(cachedHeight) ?? 0.0;
        }
      }
      
      final ageMetric = await repository.getRecentMetrics('age');
      if (ageMetric.isNotEmpty) {
        userAge = ageMetric.first.value.toInt();
      } else {
        final cachedAge = await repository.getProfileValue('user_age');
        if (cachedAge != null && cachedAge.isNotEmpty) {
          userAge = int.tryParse(cachedAge) ?? 0;
        }
      }

      final steps = await repository.getRecentMetrics('steps');
      dashboardSteps = steps.isNotEmpty ? _getTodayMetricValue(steps).toInt() : 0;
      
      await repository.clearSyntheticHeartRate();
      final hr = await repository.getRecentMetrics('heart_rate');
      final double rawHr = hr.isNotEmpty ? _getTodayMetricValue(hr) : 0.0;
      dashboardHr = (rawHr > 0 && rawHr != 72.0) ? rawHr : 0.0;
      
      final hrv = await repository.getRecentMetrics('hrv');
      final double rawHrv = hrv.isNotEmpty ? _getTodayMetricValue(hrv) : 0.0;
      dashboardHrv = (rawHrv > 0 && rawHrv != 45.5) ? rawHrv : 0.0;

      final distance = await repository.getRecentMetrics('distance');
      dashboardDistanceKm = distance.isNotEmpty ? _getTodayMetricValue(distance) : 0.0;

      final activeTime = await repository.getRecentMetrics('active_time');
      dashboardActiveTimeMins = activeTime.isNotEmpty ? _getTodayMetricValue(activeTime).toInt() : 0;
      liveActiveMins = dashboardActiveTimeMins;

      final sleep = await repository.getRecentMetrics('sleep');
      final double sleepVal = sleep.isNotEmpty ? _getTodayMetricValue(sleep) : 0.0;
      dashboardSleep = (sleepVal > 0 && sleepVal <= 18.0) ? sleepVal : 0.0;

      final calories = await repository.getRecentMetrics('calories');
      dashboardCalories = calories.isNotEmpty ? _getTodayMetricValue(calories) : 0.0;

      // Group weekly progress chart
      final calMetrics = await repository.getRecentMetrics('calories');
      if (calMetrics.isNotEmpty) {
        final now = DateTime.now();
        final Map<int, double> dayValues = {};
        for (var m in calMetrics) {
          if (now.difference(m.timestamp).inDays < 7) {
            final dayIndex = m.timestamp.weekday - 1; // 0-indexed (Mon-Sun)
            if (!dayValues.containsKey(dayIndex)) {
              dayValues[dayIndex] = m.value;
            }
          }
        }
        for (int i = 0; i < 7; i++) {
          if (dayValues.containsKey(i)) {
            weeklyCaloriesList[i] = dayValues[i]!.toInt();
          }
        }
      }

      notifyListeners();
    } catch (e) {
      // Swallowed safely
    }

    // 2. Fetch live metrics from local FHIR server to hydrate with latest remote data
    try {
      final userId = await repository.getSetting('iam_user_id') ?? '';
      final orgId = await repository.getSetting('iam_org_id') ?? '';
      final records = await vitalsRepository.getMyVitals(userId: userId, orgId: orgId, limit: 5);
      if (records.isNotEmpty) {
        final latest = records.first;
        if (latest.steps != null && latest.steps! > 0) {
          dashboardSteps = latest.steps!;
        }
        if (latest.distanceMeters != null && latest.distanceMeters! > 0) {
          dashboardDistanceKm = latest.distanceMeters! / 1000.0;
        }
        if (latest.totalActiveMinutes != null && latest.totalActiveMinutes! > 0) {
          dashboardActiveTimeMins = latest.totalActiveMinutes!;
        }
        if (latest.heartRate != null && latest.heartRate! > 0 && latest.heartRate != 72) {
          dashboardHr = latest.heartRate!.toDouble();
        }
        if (latest.heartRateVariability != null && latest.heartRateVariability! > 0.0 && latest.heartRateVariability != 45.5) {
          dashboardHrv = latest.heartRateVariability!;
        }
        if (latest.weightKg != null && latest.weightKg! > 0) {
          userWeight = latest.weightKg!;
          await repository.saveMetric(HealthMetric(
            id: 'weight_${DateTime.now().millisecondsSinceEpoch}',
            type: 'weight',
            value: latest.weightKg!,
            timestamp: DateTime.now(),
            isSynced: true,
          ));
        }
        if (latest.heightCm != null && latest.heightCm! > 0) {
          userHeight = latest.heightCm!;
          await repository.saveMetric(HealthMetric(
            id: 'height_${DateTime.now().millisecondsSinceEpoch}',
            type: 'height',
            value: latest.heightCm!,
            timestamp: DateTime.now(),
            isSynced: true,
          ));
        }
        if (latest.age != null && latest.age! > 0) {
          userAge = latest.age!;
          await repository.saveMetric(HealthMetric(
            id: 'age_${DateTime.now().millisecondsSinceEpoch}',
            type: 'age',
            value: latest.age!.toDouble(),
            timestamp: DateTime.now(),
            isSynced: true,
          ));
        }
        if (userAge == 0) {
          final dobStr = await repository.getProfileValue('birth_date');
          if (dobStr != null && dobStr.isNotEmpty) {
            final dob = DateTime.tryParse(dobStr);
            if (dob != null) {
              final now = DateTime.now();
              int age = now.year - dob.year;
              if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
                age--;
              }
              if (age > 0) {
                userAge = age;
              }
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to hydrate dashboard from FHIR vitals: $e');
      }
    }

    // 3. Auto-query Health Connect on launch so fresh watch vitals immediately reflect on dashboard
    syncOpenWearablesVitals('Android Health Connect');

    // Setup seamless recurring auto-sync (every 5 minutes) so telemetry stays updated automatically
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (kDebugMode) {
        print('[ActivityViewModel] Triggering automatic 5-minute wearable sync...');
      }
      syncOpenWearablesVitals('Android Health Connect');
    });

    // Start background sync service to keep syncing even when app is minimized
    VitalsForegroundService.start();

    // Run vitals warning checks against thresholds
    await checkVitalsThresholds();
  }

  /// Evaluates vitals (HR, BP) against active warning thresholds and triggers system alerts
  Future<void> checkVitalsThresholds() async {
    try {
      final thresholds = await repository.getVitalsThresholds();
      
      // A. Check Resting Heart Rate
      final hrThreshold = thresholds['heart_rate'];
      if (hrThreshold != null && dashboardHr > 0) {
        final double minHr = hrThreshold['min'] ?? 50.0;
        final double maxHr = hrThreshold['max'] ?? 100.0;
        if (dashboardHr < minHr || dashboardHr > maxHr) {
          await NotificationService.instance.showImmediateNotification(
            id: 101,
            title: 'Vitals Warning: Heart Rate ⚠️',
            body: 'Your resting heart rate of ${dashboardHr.toStringAsFixed(0)} BPM is outside the safe range (${minHr.toStringAsFixed(0)}-${maxHr.toStringAsFixed(0)} BPM).',
            channelId: 'vitals_warnings',
            channelName: 'Vitals Warnings',
            channelDesc: 'Alerts for vital signs outside healthy thresholds',
          );
        }
      }

      // B. Check Blood Pressure (Systolic & Diastolic)
      final userId = await repository.getSetting('iam_user_id') ?? '';
      final orgId = await repository.getSetting('iam_org_id') ?? '';
      final records = await vitalsRepository.getMyVitals(userId: userId, orgId: orgId, limit: 1);
      if (records.isNotEmpty) {
        final latest = records.first;
        if (latest.bloodPressureSystolic != null) {
          final sysThreshold = thresholds['systolic'];
          if (sysThreshold != null) {
            final double maxSys = sysThreshold['max'] ?? 140.0;
            final double minSys = sysThreshold['min'] ?? 90.0;
            if (latest.bloodPressureSystolic! > maxSys || latest.bloodPressureSystolic! < minSys) {
              await NotificationService.instance.showImmediateNotification(
                id: 102,
                title: 'Vitals Warning: Blood Pressure ⚠️',
                body: 'Your Systolic Blood Pressure of ${latest.bloodPressureSystolic} mmHg is outside the safe limit (${minSys.toStringAsFixed(0)}-${maxSys.toStringAsFixed(0)} mmHg).',
                channelId: 'vitals_warnings',
                channelName: 'Vitals Warnings',
                channelDesc: 'Alerts for vital signs outside healthy thresholds',
              );
            }
          }
        }
        
        if (latest.bloodPressureDiastolic != null) {
          final diaThreshold = thresholds['diastolic'];
          if (diaThreshold != null) {
            final double maxDia = diaThreshold['max'] ?? 90.0;
            final double minDia = diaThreshold['min'] ?? 60.0;
            if (latest.bloodPressureDiastolic! > maxDia || latest.bloodPressureDiastolic! < minDia) {
              await NotificationService.instance.showImmediateNotification(
                id: 103,
                title: 'Vitals Warning: Blood Pressure ⚠️',
                body: 'Your Diastolic Blood Pressure of ${latest.bloodPressureDiastolic} mmHg is outside the safe limit (${minDia.toStringAsFixed(0)}-${maxDia.toStringAsFixed(0)} mmHg).',
                channelId: 'vitals_warnings',
                channelName: 'Vitals Warnings',
                channelDesc: 'Alerts for vital signs outside healthy thresholds',
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Error checking vitals thresholds: $e');
      }
    }
  }

  // --- Runtime Permission Handler ---
  Future<void> requestRuntimePermissions() async {
    try {
      // 1. Request Activity Recognition (Pedometer)
      final activityStatus = await Permission.activityRecognition.request();
      hasActivityPermission = activityStatus.isGranted;

      // 2. Request Location (GPS)
      final locationStatus = await Permission.locationWhenInUse.request();
      hasLocationPermission = locationStatus.isGranted;

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to request permissions: $e');
      }
    }
  }

  Future<void> startStepsTracking() async {
    // Request native Android runtime permissions first!
    await requestRuntimePermissions();

    await _stepsSub?.cancel();
    
    // Periodically start Actigraphy Sleep tracking as well
    startSleepTracking();
    
    // Hardware sensor step tracking is completely disabled.
    // Steps are exclusively retrieved from Google Fit / Health Connect via syncOpenWearablesVitals().
    try {
      await _stepsSub?.cancel();
      _stepsSub = null;
    } catch (_) {}
  }

  /// Persists height, weight, and age directly to the SQLite cache and triggers remote sync
  Future<void> saveBioData({required double weight, required double height, required double age}) async {
    userWeight = weight;
    userHeight = height;
    userAge = age.toInt();
    notifyListeners();
    
    final now = DateTime.now();
    
    // Save to local profile key-value storage for instant synchronous retrieval
    await repository.saveProfileValue('user_weight', weight.toString());
    await repository.saveProfileValue('user_height', height.toString());
    await repository.saveProfileValue('user_age', age.toInt().toString());

    // Save to local database with unique baseline keys
    await repository.saveMetric(HealthMetric(
      id: 'bio_weight_${now.millisecondsSinceEpoch}',
      type: 'weight',
      value: weight,
      timestamp: now,
    ));
    await repository.saveMetric(HealthMetric(
      id: 'bio_height_${now.millisecondsSinceEpoch}',
      type: 'height',
      value: height,
      timestamp: now,
    ));
    await repository.saveMetric(HealthMetric(
      id: 'bio_age_${now.millisecondsSinceEpoch}',
      type: 'age',
      value: age,
      timestamp: now,
    ));
    
    // Remote Sync biometrics immediately if authenticated
    try {
      final userId = await repository.getSetting('iam_user_id') ?? '';
      final orgId = await repository.getSetting('iam_org_id') ?? '';
      if (userId.isNotEmpty && orgId.isNotEmpty) {
        final cachedGender = await repository.getProfileValue('gender');
        final int steps = liveSteps > 0 ? liveSteps : dashboardSteps;
        final int activeMins = currentActiveMins;
        final int calories = currentCalories;

        await vitalsRepository.submitVitals(
          VitalsRecord(
            steps: steps,
            caloriesKcal: calories.toDouble(),
            distanceMeters: steps * 0.8,
            totalActiveMinutes: activeMins,
            restingHeartRate: dashboardHr > 0 ? dashboardHr.toInt() : null,
            heartRate: dashboardHr > 0 ? dashboardHr.toInt() : null,
            heartRateVariability: dashboardHrv > 0 ? dashboardHrv : null,
            weightKg: weight > 0 ? weight : null,
            heightCm: height > 0 ? height : null,
            age: age > 0 ? age.toInt() : null,
            gender: cachedGender,
          ),
          userId: userId,
          orgId: orgId,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to push immediate biometrics: $e');
      }
    }
  }

  /// Wipes all in-memory user data so switching accounts loads authentic new records
  void resetState() {
    dashboardSteps = 0;
    dashboardHr = 0.0;
    dashboardMinHr = null;
    dashboardMaxHr = null;
    dashboardHrv = 0.0;
    dashboardDistanceKm = 0.0;
    dashboardActiveTimeMins = 0;
    dashboardCalories = 0.0;
    userWeight = 0.0;
    userHeight = 0.0;
    userAge = 0;
    liveSteps = 0;
    liveActiveMins = 0;
    liveSleep = 0.0;
    dashboardSleep = 0.0;
    deepSleepMinutes = 0;
    lightSleepMinutes = 0;
    remSleepMinutes = 0;
    awakeMinutes = 0;
    isOpenWearablesSynced = false;
    syncedProviderName = null;
    weeklyCaloriesList = [0, 0, 0, 0, 0, 0, 0];
    notifyListeners();
  }

  Future<void> startSleepTracking() async {
    await _sleepAccSub?.cancel();
    _actigraphyTimer?.cancel();
    liveSleep = 0.0;
    
    // Read previous genuine sleep from database if any
    final sleepRecords = await repository.getRecentMetrics('sleep');
    final genuineSleep = sleepRecords.where((r) => r.value > 0.0 && r.value <= 18.0).toList();
    if (genuineSleep.isNotEmpty) {
      dashboardSleep = genuineSleep.first.value;
    } else {
      dashboardSleep = 0.0; // Clean initial state - strictly reflects watch sync
    }
    notifyListeners();
  }



  // --- GPS Workout Controller ---

  Future<void> startGpsWorkout() async {
    isGpsTracking = true;
    isGpsPaused = false;
    elapsedSeconds = 0;
    totalDistanceKm = 0.0;
    currentSpeedKmh = 0.0;
    gpsAccuracy = 0.0;
    _lastGpsPosition = null;
    routeCoordinates.clear();
    _currentWorkoutId = 'workout_${DateTime.now().millisecondsSinceEpoch}';
    notifyListeners();

    // Start workout stopwatch
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isGpsPaused) {
        elapsedSeconds++;
        notifyListeners();
      }
    });

    try {
      await gps.startSensor();
      _gpsSub = gps.dataStream.listen((Position position) {
        if (!isGpsPaused) {
          gpsAccuracy = position.accuracy;
          currentSpeedKmh = position.speed > 0 ? (position.speed * 3.6) : 0.0;

          if (_lastGpsPosition != null) {
            double distance = Geolocator.distanceBetween(
              _lastGpsPosition!.latitude,
              _lastGpsPosition!.longitude,
              position.latitude,
              position.longitude,
            );
            
            if (position.accuracy < 15) {
              totalDistanceKm += distance / 1000.0;
              routeCoordinates.add(position);
              
              repository.saveRoutePoint(
                workoutId: _currentWorkoutId!,
                latitude: position.latitude,
                longitude: position.longitude,
                speed: currentSpeedKmh,
              );
            }
          } else {
            routeCoordinates.add(position);
          }
          _lastGpsPosition = position;
          notifyListeners();
        }
      });
    } catch (e) {
      await stopGpsWorkout();
    }
  }

  void toggleGpsPause() {
    isGpsPaused = !isGpsPaused;
    notifyListeners();
  }

  Future<void> stopGpsWorkout() async {
    isGpsTracking = false;
    isGpsPaused = false;
    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;
    await _gpsSub?.cancel();
    _gpsSub = null;

    try {
      await gps.stopSensor();

      if (totalDistanceKm > 0.01) {
        final timestamp = DateTime.now();
        double activeMins = elapsedSeconds / 60.0;
        double calculatedCalories = activeMins * 8.5; // ~8.5 kcal per running minute
        double distanceMeters = totalDistanceKm * 1000.0;
        
        await repository.saveMetric(HealthMetric(
          id: '${_currentWorkoutId}_dist',
          type: 'distance',
          value: totalDistanceKm,
          timestamp: timestamp,
        ));
        
        await repository.saveMetric(HealthMetric(
          id: '${_currentWorkoutId}_time',
          type: 'active_time',
          value: activeMins,
          timestamp: timestamp,
        ));

        try {
          final userId = await repository.getSetting('iam_user_id') ?? '';
          final orgId = await repository.getSetting('iam_org_id') ?? '';
          await vitalsRepository.submitVitals(VitalsRecord(
            distanceMeters: distanceMeters,
            totalActiveMinutes: activeMins.toInt(),
            caloriesKcal: calculatedCalories,
          ), userId: userId, orgId: orgId);
        } catch (e) {
          if (kDebugMode) {
            print('[ActivityViewModel] Live workout FHIR sync failed: $e');
          }
        }

        dashboardDistanceKm = totalDistanceKm;
        dashboardActiveTimeMins = activeMins.toInt();
      }
    } catch (e) {
      // Safe swallow
    }

    _lastGpsPosition = null;
    _currentWorkoutId = null;
    notifyListeners();

    repository.uploadPendingMetrics();
  }

  // --- Bluetooth LE & Open-Wearables Integration Methods ---

  /// Connect to a nearby Bluetooth smartwatch (boAt, Fire-Boltt, Noise, etc.)
  Future<bool> connectBleDevice(BluetoothDevice device) async {
    final success = await bleService.connect(device);
    if (success) {
      connectedBleDeviceName = device.platformName.isNotEmpty ? device.platformName : 'Smartwatch';
      notifyListeners();
    }
    return success;
  }

  /// Disconnect current active Bluetooth smartwatch
  Future<void> disconnectBleDevice() async {
    await bleService.disconnect();
    connectedBleDeviceName = null;
    notifyListeners();
  }

  /// Synchronize rich biometrics and sleep stages from Open-Wearables / Health Connect providers
  /// and stream the normalized payload to the live FHIR server
  /// Returns true if real records were fetched and synced, false otherwise
  Future<bool> syncOpenWearablesVitals([String? providerName]) async {
    try {
      final userId = await repository.getSetting('iam_user_id') ?? 'usr_demo_101';
      final orgId = await repository.getSetting('iam_org_id') ?? 'org_drgodly_default';

      final cloudVitals = await openWearablesService.fetchLatestVitals(userId: userId, orgId: orgId);
      if (cloudVitals != null) {
        // Update Resting HR or HR only if real values are reported
        final realHr = cloudVitals.restingHeartRate ?? cloudVitals.heartRate;
        if (realHr != null && realHr > 0 && realHr != 72) {
          dashboardHr = realHr.toDouble();
        } else if (bleService.currentState != BleDeviceState.connected) {
          if (dashboardHr == 72.0) {
            dashboardHr = 0.0;
          }
        }

        dashboardMinHr = cloudVitals.minHeartRate;
        dashboardMaxHr = cloudVitals.maxHeartRate;

        if (cloudVitals.heartRateVariability != null && cloudVitals.heartRateVariability! > 0.0 && cloudVitals.heartRateVariability != 45.5) {
          dashboardHrv = cloudVitals.heartRateVariability!;
        } else if (bleService.currentState != BleDeviceState.connected) {
          if (dashboardHrv == 45.5) {
            dashboardHrv = 0.0;
          }
        }

        if (cloudVitals.sleepMinutes != null) {
          liveSleep = cloudVitals.sleepMinutes! / 60.0;
          dashboardSleep = liveSleep;
          deepSleepMinutes = cloudVitals.deepSleepMinutes ?? 0;
          lightSleepMinutes = cloudVitals.lightSleepMinutes ?? 0;
          remSleepMinutes = cloudVitals.remSleepMinutes ?? 0;
          awakeMinutes = cloudVitals.awakeMinutes ?? 0;
        }

        if (cloudVitals.steps != null && cloudVitals.steps! > 0) {
          dashboardSteps = cloudVitals.steps!;
          liveSteps = cloudVitals.steps!;
        }

        if (cloudVitals.caloriesKcal != null && cloudVitals.caloriesKcal! > 0) {
          dashboardCalories = cloudVitals.caloriesKcal!;
          final now = DateTime.now();
          await repository.saveMetric(HealthMetric(
            id: 'synced_cal_${now.millisecondsSinceEpoch}',
            type: 'calories',
            value: dashboardCalories,
            timestamp: now,
          ));
        }

        if (cloudVitals.totalActiveMinutes != null && cloudVitals.totalActiveMinutes! > 0) {
          dashboardActiveTimeMins = cloudVitals.totalActiveMinutes!;
          liveActiveMins = cloudVitals.totalActiveMinutes!;
          final now = DateTime.now();
          await repository.saveMetric(HealthMetric(
            id: 'synced_active_${now.millisecondsSinceEpoch}',
            type: 'active_time',
            value: dashboardActiveTimeMins.toDouble(),
            timestamp: now,
          ));
        }

        if (cloudVitals.oxygenSaturation != null && cloudVitals.oxygenSaturation! > 0) {
          dashboardSpo2 = cloudVitals.oxygenSaturation!;
        }

        isOpenWearablesSynced = true;
        syncedProviderName = providerName ?? 'Android Health Connect';

        // Persist heart rate metric locally ONLY if real data was measured
        final now = DateTime.now();
        if (realHr != null && realHr > 0 && realHr != 72) {
          await repository.saveMetric(HealthMetric(
            id: 'synced_hr_${now.millisecondsSinceEpoch}',
            type: 'heart_rate',
            value: dashboardHr,
            timestamp: now,
          ));
        }

        // Stream merged vitals record to FHIR Server with exact, unchanged schema
        await vitalsRepository.submitVitals(cloudVitals, userId: userId, orgId: orgId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Open-Wearables sync error: $e');
      }
      return false;
    }
  }

  @override
  void dispose() {
    _bleHrSub?.cancel();
    _bleHrvSub?.cancel();
    _stepsSub?.cancel();
    _gpsSub?.cancel();
    _stopwatchTimer?.cancel();
    _sleepAccSub?.cancel();
    _actigraphyTimer?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}
