import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/model/health_metrics.dart';
import '../../domain/model/vitals_payload.dart';
import '../../data/repository/health_repository.dart';
import '../../data/repository/vitals_repository.dart';
import '../../data/service/notification_service.dart';
import '../../data/service/ble_heart_rate_service.dart';
import '../../data/service/open_wearables_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:health/health.dart';

class ActivityViewModel extends ChangeNotifier {
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

  // --- Sleep State ---
  double liveSleep = 0.0;
  double dashboardSleep = 0.0;
  int deepSleepMinutes = 0;
  int lightSleepMinutes = 0;
  int remSleepMinutes = 0;
  int awakeMinutes = 0;
  double? dashboardSpo2;

  // --- Weekly Progress List ---
  List<int> weeklyCaloriesList = [0, 0, 0, 0, 0, 0, 0];

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
  bool get isStepSensorFallback => false;

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

    // Small delay so Android OS initializes cleanly before Health Connect check
    await Future.delayed(const Duration(milliseconds: 300));

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
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.WORKOUT,
        HealthDataType.ACTIVITY_INTENSITY,
        HealthDataType.EXERCISE_TIME,
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

    await startStepsTracking();
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
        final cachedWeight = await repository.getProfileValue('user_weight') ?? await repository.getProfileValue('weight');
        if (cachedWeight != null && cachedWeight.isNotEmpty) {
          userWeight = double.tryParse(cachedWeight) ?? 0.0;
        }
      }
      
      final heightMetric = await repository.getRecentMetrics('height');
      if (heightMetric.isNotEmpty) {
        userHeight = heightMetric.first.value;
      } else {
        final cachedHeight = await repository.getProfileValue('user_height') ?? await repository.getProfileValue('height');
        if (cachedHeight != null && cachedHeight.isNotEmpty) {
          userHeight = double.tryParse(cachedHeight) ?? 0.0;
        }
      }
      
      final ageMetric = await repository.getRecentMetrics('age');
      if (ageMetric.isNotEmpty) {
        userAge = ageMetric.first.value.toInt();
      } else {
        final cachedAge = await repository.getProfileValue('user_age') ?? await repository.getProfileValue('age');
        if (cachedAge != null && cachedAge.isNotEmpty) {
          userAge = int.tryParse(cachedAge) ?? 0;
        }
      }

      final steps = await repository.getRecentMetrics('steps');
      dashboardSteps = steps.isNotEmpty ? _getTodayMetricValue(steps).toInt() : 0;
      
      await repository.clearSyntheticHeartRate();
      final hr = await repository.getRecentMetrics('heart_rate');
      final double rawHr = hr.isNotEmpty ? _getTodayMetricValue(hr) : 0.0;
      dashboardHr = rawHr > 0 ? rawHr : 0.0;
      
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

      final spo2Metrics = await repository.getRecentMetrics('blood_oxygen');
      if (spo2Metrics.isNotEmpty) {
        dashboardSpo2 = spo2Metrics.first.value;
      } else {
        final altSpo2 = await repository.getRecentMetrics('oxygen_saturation');
        if (altSpo2.isNotEmpty) {
          dashboardSpo2 = altSpo2.first.value;
        }
      }

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
        // Only hydrate Resting HR from today's remote record if recorded today
        bool isRecordToday = false;
        if (latest.recordedAt != null) {
          final recDate = DateTime.tryParse(latest.recordedAt!);
          if (recDate != null) {
            final now = DateTime.now();
            isRecordToday = recDate.year == now.year && recDate.month == now.month && recDate.day == now.day;
          }
        } else if (latest.date != null) {
          final now = DateTime.now();
          final todayPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          isRecordToday = latest.date!.startsWith(todayPrefix);
        }

        if (isRecordToday && latest.heartRate != null && latest.heartRate! > 0) {
          dashboardHr = latest.heartRate!.toDouble();
        }
        if (isRecordToday && latest.heartRateVariability != null && latest.heartRateVariability! > 0.0 && latest.heartRateVariability != 45.5) {
          dashboardHrv = latest.heartRateVariability!;
        }
        // Scan across remote vitals history to hydrate clinical baseline metrics (weight, height, age)
        for (final r in records) {
          if (userWeight == 0 && r.weightKg != null && r.weightKg! > 0) {
            userWeight = r.weightKg!;
            await repository.saveProfileValue('user_weight', userWeight.toString());
            await repository.saveProfileValue('weight', userWeight.toString());
            await repository.saveMetric(HealthMetric(
              id: 'weight_${DateTime.now().millisecondsSinceEpoch}',
              type: 'weight',
              value: userWeight,
              timestamp: DateTime.now(),
              isSynced: true,
            ));
          }
          if (userHeight == 0 && r.heightCm != null && r.heightCm! > 0) {
            userHeight = r.heightCm!;
            await repository.saveProfileValue('user_height', userHeight.toString());
            await repository.saveProfileValue('height', userHeight.toString());
            await repository.saveMetric(HealthMetric(
              id: 'height_${DateTime.now().millisecondsSinceEpoch}',
              type: 'height',
              value: userHeight,
              timestamp: DateTime.now(),
              isSynced: true,
            ));
          }
          if (userAge == 0 && r.age != null && r.age! > 0) {
            userAge = r.age!;
            await repository.saveProfileValue('user_age', userAge.toString());
            await repository.saveProfileValue('age', userAge.toString());
            await repository.saveMetric(HealthMetric(
              id: 'age_${DateTime.now().millisecondsSinceEpoch}',
              type: 'age',
              value: userAge.toDouble(),
              timestamp: DateTime.now(),
              isSynced: true,
            ));
          }
          if ((dashboardSpo2 == null || dashboardSpo2! <= 0) && r.oxygenSaturation != null && r.oxygenSaturation! > 0) {
            dashboardSpo2 = r.oxygenSaturation!;
            await repository.saveMetric(HealthMetric(
              id: 'synced_spo2_${DateTime.now().millisecondsSinceEpoch}',
              type: 'blood_oxygen',
              value: dashboardSpo2!,
              timestamp: DateTime.now(),
            ));
          }
          if (userWeight > 0 && userHeight > 0 && userAge > 0 && dashboardSpo2 != null && dashboardSpo2! > 0) break;
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
    await syncOpenWearablesVitals('Android Health Connect');

    // Setup seamless recurring auto-sync (every 5 minutes) so telemetry stays updated automatically
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (kDebugMode) {
        print('[ActivityViewModel] Triggering automatic 5-minute wearable sync...');
      }
      syncOpenWearablesVitals('Android Health Connect');
    });

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

  Future<void> startStepsTracking() async {
    await _stepsSub?.cancel();
    startSleepTracking();
    _stepsSub = null;
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
            distanceMeters: (dashboardDistanceKm > 0) ? (dashboardDistanceKm * 1000.0) : null,
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
        if (realHr != null && realHr > 0) {
          dashboardHr = realHr.toDouble();
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

        final now = DateTime.now();
        if (cloudVitals.sleepMinutes != null) {
          liveSleep = cloudVitals.sleepMinutes! / 60.0;
          dashboardSleep = liveSleep;
          deepSleepMinutes = cloudVitals.deepSleepMinutes ?? 0;
          lightSleepMinutes = cloudVitals.lightSleepMinutes ?? 0;
          remSleepMinutes = cloudVitals.remSleepMinutes ?? 0;
          awakeMinutes = cloudVitals.awakeMinutes ?? 0;
          await repository.saveMetric(HealthMetric(
            id: 'synced_sleep_${now.millisecondsSinceEpoch}',
            type: 'sleep',
            value: dashboardSleep,
            timestamp: now,
          ));
        }

        if (cloudVitals.steps != null && cloudVitals.steps! > 0) {
          dashboardSteps = cloudVitals.steps!;
          liveSteps = cloudVitals.steps!;
        }

        if (cloudVitals.caloriesKcal != null && cloudVitals.caloriesKcal! > 0) {
          dashboardCalories = cloudVitals.caloriesKcal!;
          await repository.saveMetric(HealthMetric(
            id: 'synced_cal_${now.millisecondsSinceEpoch}',
            type: 'calories',
            value: dashboardCalories,
            timestamp: now,
          ));
        }

        if (cloudVitals.totalActiveMinutes != null) {
          dashboardActiveTimeMins = cloudVitals.totalActiveMinutes!;
          liveActiveMins = cloudVitals.totalActiveMinutes!;
          await repository.saveMetric(HealthMetric(
            id: 'synced_active_${now.millisecondsSinceEpoch}',
            type: 'active_time',
            value: dashboardActiveTimeMins.toDouble(),
            timestamp: now,
          ));
        }

        if (cloudVitals.distanceMeters != null) {
          dashboardDistanceKm = cloudVitals.distanceMeters! / 1000.0;
          await repository.saveMetric(HealthMetric(
            id: 'synced_dist_${now.millisecondsSinceEpoch}',
            type: 'distance',
            value: dashboardDistanceKm,
            timestamp: now,
          ));
        }

        if (cloudVitals.oxygenSaturation != null && cloudVitals.oxygenSaturation! > 0) {
          dashboardSpo2 = cloudVitals.oxygenSaturation!;
          await repository.saveMetric(HealthMetric(
            id: 'synced_spo2_${now.millisecondsSinceEpoch}',
            type: 'blood_oxygen',
            value: dashboardSpo2!,
            timestamp: now,
          ));
        }

        if (cloudVitals.heightCm != null && cloudVitals.heightCm! > 0) {
          userHeight = cloudVitals.heightCm!;
          await repository.saveProfileValue('user_height', userHeight.toString());
          await repository.saveProfileValue('height', userHeight.toString());
          await repository.saveMetric(HealthMetric(
            id: 'synced_height_${now.millisecondsSinceEpoch}',
            type: 'height',
            value: userHeight,
            timestamp: now,
          ));
        }

        if (cloudVitals.weightKg != null && cloudVitals.weightKg! > 0) {
          userWeight = cloudVitals.weightKg!;
          await repository.saveProfileValue('user_weight', userWeight.toString());
          await repository.saveProfileValue('weight', userWeight.toString());
          await repository.saveMetric(HealthMetric(
            id: 'synced_weight_${now.millisecondsSinceEpoch}',
            type: 'weight',
            value: userWeight,
            timestamp: now,
          ));
        }

        isOpenWearablesSynced = true;
        syncedProviderName = providerName ?? 'Android Health Connect';

        // Persist heart rate metric locally ONLY if real data was measured
        if (realHr != null && realHr > 0) {
          await repository.saveMetric(HealthMetric(
            id: 'synced_hr_${now.millisecondsSinceEpoch}',
            type: 'heart_rate',
            value: dashboardHr,
            timestamp: now,
          ));
        }

        // Stream merged vitals record to FHIR Server with exact, unchanged schema
        // Merge baseline clinical metrics (height, weight, age, gender) so wearable sync never overrides them with nulls
        final cachedGender = await repository.getProfileValue('user_gender') ?? await repository.getProfileValue('gender');
        final mergedVitals = cloudVitals.copyWith(
          heightCm: (cloudVitals.heightCm != null && cloudVitals.heightCm! > 0)
              ? cloudVitals.heightCm
              : (userHeight > 0 ? userHeight : null),
          weightKg: (cloudVitals.weightKg != null && cloudVitals.weightKg! > 0)
              ? cloudVitals.weightKg
              : (userWeight > 0 ? userWeight : null),
          age: (cloudVitals.age != null && cloudVitals.age! > 0)
              ? cloudVitals.age
              : (userAge > 0 ? userAge : null),
          gender: cloudVitals.gender ?? cachedGender,
        );

        await vitalsRepository.submitVitals(mergedVitals, userId: userId, orgId: orgId);
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
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}
