import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phia_flutter/core/data/local/health_repository.dart';
import 'package:phia_flutter/features/notifications/data/notification_service.dart';
import 'package:phia_flutter/features/vitals/data/health_connect_types.dart';
import 'package:phia_flutter/features/vitals/data/open_wearables_service.dart';
import 'package:phia_flutter/features/vitals/data/vitals_repository.dart';
import 'package:phia_flutter/features/vitals/domain/health_metrics.dart';
import 'package:phia_flutter/features/vitals/domain/vitals_payload.dart';

class ActivityViewModel extends ChangeNotifier {
  final HealthRepository repository;
  final VitalsRepository vitalsRepository = VitalsRepository();
  final OpenWearablesService openWearablesService = OpenWearablesService();

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
  /// True only while the most recent sync attempt succeeded.
  bool isOpenWearablesSynced = false;

  /// When this user's data last synced successfully (persisted, per user).
  DateTime? lastSyncAt;

  /// Result of the most recent sync attempt in this session.
  VitalsSyncOutcome lastSyncOutcome = VitalsSyncOutcome.none;
  static const _lastSyncKey = 'last_vitals_sync_at';
  String? syncedProviderName;
  Timer? _autoSyncTimer;

  // Steps strictly reflect synced data from Google Fit / Health Connect / Wearables
  int get currentSteps => dashboardSteps;
  int get currentActiveMins => liveActiveMins > 0 ? liveActiveMins : (dashboardActiveTimeMins > 0 ? dashboardActiveTimeMins : 0);
  // Calories strictly reflect synced data from Google Fit / Health Connect / Wearables (no mathematical formula fallback)
  int get currentCalories => dashboardCalories > 0 ? dashboardCalories.toInt() : 0;
  double get currentSleep => liveSleep > 0.0 ? liveSleep : (dashboardSleep > 0.0 ? dashboardSleep : 0.0);
  bool get isStepSensorFallback => false;

  Future<bool>? _syncInFlight;
  String? _lastSubmittedVitalsSignature;

  ActivityViewModel({
    required this.repository,
  }) {
    initDashboard();
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

    try {
      final hasPrompted = await repository.getSetting('has_prompted_health_connect');
      if (hasPrompted != 'true') {
        final health = Health();
        await health.configure();
        bool? hasPerm;
        try {
          hasPerm = await health.hasPermissions(availableHealthConnectTypes(health));
        } catch (_) {}
        if (hasPerm != true) {
          try {
            await requestHealthConnectPermissions(health);
          } catch (_) {}
        }
        await repository.saveSetting('has_prompted_health_connect', 'true');
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

  /// Explicitly request Health Connect authorization (e.g. from Pair Watch or Settings)
  Future<bool> requestHealthConnectAuthorization() async {
    try {
      final health = Health();
      await health.configure();
      final granted = await requestHealthConnectPermissions(health);
      await repository.saveSetting('has_prompted_health_connect', 'true');
      // The caller syncs after this; syncing here too ran every sync twice.
      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Error requesting Health Connect auth: $e');
      }
      return false;
    }
  }

  static bool _isToday(DateTime t) {
    final now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day;
  }

  /// A remote vitals record counts for "today" only if it was recorded today.
  static bool isRecordFromToday(VitalsRecord r) {
    if (r.recordedAt != null) {
      final d = DateTime.tryParse(r.recordedAt!);
      return d != null && _isToday(d.toLocal());
    }
    if (r.date != null) {
      final now = DateTime.now();
      final todayPrefix =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      return r.date!.startsWith(todayPrefix);
    }
    return false;
  }

  Future<void> _loadLastSync() async {
    try {
      final userId = await repository.getSetting('iam_user_id') ?? '';
      final raw = await repository.getSetting(_lastSyncKey) ?? '';
      final sep = raw.indexOf('|');
      // Stored as "<userId>|<time>" so another account's time is never shown.
      if (sep > 0 && userId.isNotEmpty && raw.substring(0, sep) == userId) {
        lastSyncAt = DateTime.tryParse(raw.substring(sep + 1));
      } else {
        lastSyncAt = null;
      }
    } catch (_) {}
  }

  Future<void> _saveLastSync(String userId, DateTime at) async {
    lastSyncAt = at;
    try {
      await repository.saveSetting(_lastSyncKey, '$userId|${at.toIso8601String()}');
    } catch (_) {}
  }

  double _getTodayMetricValue(List<HealthMetric> metrics) {
    final now = DateTime.now();
    for (final m in metrics) {
      if (m.timestamp.year == now.year &&
          m.timestamp.month == now.month &&
          m.timestamp.day == now.day) {
        return m.value;
      }
    }
    return 0.0;
  }

  Future<void> initDashboard() async {
    // Keep the local cache bounded.
    try {
      await repository.pruneOldMetrics();
    } catch (_) {}

    await _loadLastSync();

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

      // Blood oxygen: today's reading only (an old value must not look current).
      final spo2Metrics = await repository.getRecentMetrics('blood_oxygen');
      double spo2 = _getTodayMetricValue(spo2Metrics);
      if (spo2 <= 0) {
        spo2 = _getTodayMetricValue(await repository.getRecentMetrics('oxygen_saturation'));
      }
      dashboardSpo2 = spo2 > 0 ? spo2 : null;

      final calories = await repository.getRecentMetrics('calories');
      dashboardCalories = calories.isNotEmpty ? _getTodayMetricValue(calories) : 0.0;

      // Group weekly progress chart
      final calMetrics = await repository.getRecentMetrics('calories');
      if (calMetrics.isNotEmpty) {
        final now = DateTime.now();
        final Map<int, double> dayValues = {};
        for (final m in calMetrics) {
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
        // Daily totals and heart rate come from the remote record only if it
        // is from today; yesterday's totals must never show as today's.
        final isRecordToday = isRecordFromToday(latest);
        if (isRecordToday && latest.steps != null && latest.steps! > 0) {
          dashboardSteps = latest.steps!;
        }
        if (isRecordToday && latest.distanceMeters != null && latest.distanceMeters! > 0) {
          dashboardDistanceKm = latest.distanceMeters! / 1000.0;
        }
        if (isRecordToday && latest.totalActiveMinutes != null && latest.totalActiveMinutes! > 0) {
          dashboardActiveTimeMins = latest.totalActiveMinutes!;
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
          if ((dashboardSpo2 == null || dashboardSpo2! <= 0) &&
              isRecordFromToday(r) &&
              r.oxygenSaturation != null &&
              r.oxygenSaturation! > 0) {
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

    // 3. Auto-query Health Connect on launch and setup seamless recurring auto-sync
    resumeAutoSync();

    // Run vitals warning checks against thresholds
    await checkVitalsThresholds();
  }

  /// Pauses wearable auto-sync timer when the app is backgrounded to preserve battery
  void pauseAutoSync() {
    if (_autoSyncTimer != null) {
      if (kDebugMode) {
        print('[ActivityViewModel] App backgrounded/paused. Pausing wearable auto-sync timer.');
      }
      _autoSyncTimer?.cancel();
      _autoSyncTimer = null;
    }
  }

  /// Resumes wearable auto-sync timer when the app returns to foreground
  void resumeAutoSync() {
    if (_autoSyncTimer != null) return;
    if (kDebugMode) {
      print('[ActivityViewModel] App active/resumed. Resuming wearable auto-sync timer.');
    }
    syncOpenWearablesVitals('Android Health Connect');
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (kDebugMode) {
        print('[ActivityViewModel] Triggering automatic 5-minute wearable sync...');
      }
      syncOpenWearablesVitals('Android Health Connect');
    });
  }

  /// Evaluates vitals (HR, BP) against active warning thresholds and triggers system alerts
  /// Alert de-duplication: the threshold check runs on every dashboard load,
  /// pull-to-refresh and permission flow. Alert again for the same metric only
  /// if the value changed or 6 hours have passed.
  Future<bool> _shouldAlert(String metric, String value) async {
    final key = 'last_vitals_alert_$metric';
    final now = DateTime.now();
    try {
      final last = await repository.getSetting(key);
      if (last != null) {
        final sep = last.indexOf('|');
        final lastValue = sep > 0 ? last.substring(0, sep) : '';
        final lastAt = sep > 0 ? DateTime.tryParse(last.substring(sep + 1)) : null;
        if (lastValue == value && lastAt != null && now.difference(lastAt) < const Duration(hours: 6)) {
          return false;
        }
      }
      await repository.saveSetting(key, '$value|${now.toIso8601String()}');
    } catch (_) {}
    return true;
  }

  Future<void> checkVitalsThresholds() async {
    try {
      final thresholds = await repository.getVitalsThresholds();
      
      // A. Check Resting Heart Rate
      final hrThreshold = thresholds['heart_rate'];
      if (hrThreshold != null && dashboardHr > 0) {
        final double minHr = hrThreshold['min'] ?? 50.0;
        final double maxHr = hrThreshold['max'] ?? 100.0;
        if ((dashboardHr < minHr || dashboardHr > maxHr) &&
            await _shouldAlert('heart_rate', dashboardHr.toStringAsFixed(0))) {
          await NotificationService.instance.showVitalsAlert(
            title: 'Vitals Warning: Heart Rate ⚠️',
            body: 'Your heart rate of ${dashboardHr.toStringAsFixed(0)} BPM is outside the safe range (${minHr.toStringAsFixed(0)}-${maxHr.toStringAsFixed(0)} BPM).',
          );
        }
      }

      // B. Check Blood Pressure (Systolic & Diastolic)
      final userId = await repository.getSetting('iam_user_id') ?? '';
      final orgId = await repository.getSetting('iam_org_id') ?? '';
      if (userId.isEmpty || orgId.isEmpty) return;
      final records = await vitalsRepository.getMyVitals(userId: userId, orgId: orgId, limit: 1);
      if (records.isNotEmpty) {
        final latest = records.first;
        if (latest.bloodPressureSystolic != null) {
          final sysThreshold = thresholds['systolic'];
          if (sysThreshold != null) {
            final double maxSys = sysThreshold['max'] ?? 140.0;
            final double minSys = sysThreshold['min'] ?? 90.0;
            if ((latest.bloodPressureSystolic! > maxSys || latest.bloodPressureSystolic! < minSys) &&
                await _shouldAlert('systolic', '${latest.bloodPressureSystolic}')) {
              await NotificationService.instance.showVitalsAlert(
                title: 'Vitals Warning: Blood Pressure ⚠️',
                body: 'Your Systolic Blood Pressure of ${latest.bloodPressureSystolic} mmHg is outside the safe limit (${minSys.toStringAsFixed(0)}-${maxSys.toStringAsFixed(0)} mmHg).',
              );
            }
          }
        }
        
        if (latest.bloodPressureDiastolic != null) {
          final diaThreshold = thresholds['diastolic'];
          if (diaThreshold != null) {
            final double maxDia = diaThreshold['max'] ?? 90.0;
            final double minDia = diaThreshold['min'] ?? 60.0;
            if ((latest.bloodPressureDiastolic! > maxDia || latest.bloodPressureDiastolic! < minDia) &&
                await _shouldAlert('diastolic', '${latest.bloodPressureDiastolic}')) {
              await NotificationService.instance.showVitalsAlert(
                title: 'Vitals Warning: Blood Pressure ⚠️',
                body: 'Your Diastolic Blood Pressure of ${latest.bloodPressureDiastolic} mmHg is outside the safe limit (${minDia.toStringAsFixed(0)}-${maxDia.toStringAsFixed(0)} mmHg).',
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

  /// Saves height, weight and age on the phone, then sends them to the server.
  ///
  /// Returns true only if the server accepted them. On false the values are
  /// still saved on this phone; the UI should say the server update failed.
  Future<bool> saveBioData({required double weight, required double height, required double age}) async {
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
    if (age > 0) {
      await repository.saveMetric(HealthMetric(
        id: 'bio_age_${now.millisecondsSinceEpoch}',
        type: 'age',
        value: age,
        timestamp: now,
      ));
    }
    
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
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to push immediate biometrics: $e');
      }
      return false;
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
    dashboardSpo2 = null;
    isOpenWearablesSynced = false;
    syncedProviderName = null;
    lastSyncAt = null;
    lastSyncOutcome = VitalsSyncOutcome.none;
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



  // --- Open-Wearables / Health Connect Integration Methods ---

  /// Synchronize rich biometrics and sleep stages from Open-Wearables / Health Connect providers
  /// and stream the normalized payload to the live FHIR server
  /// Returns true if real records were fetched and synced, false otherwise
  ///
  /// Only one sync runs at a time: the 5-minute timer, app resume,
  /// pull-to-refresh and the device sheet can all trigger it, and overlapping
  /// runs used to POST the same record several times.
  Future<bool> syncOpenWearablesVitals([String? providerName]) {
    final inFlight = _syncInFlight;
    if (inFlight != null) return inFlight;
    final run = _syncOpenWearablesVitals(providerName).whenComplete(() {
      _syncInFlight = null;
      notifyListeners();
    });
    _syncInFlight = run;
    notifyListeners();
    return run;
  }

  /// True while a Health Connect sync is running.
  bool get isSyncing => _syncInFlight != null;

  Future<bool> _syncOpenWearablesVitals(String? providerName) async {
    try {
      final userId = await repository.getSetting('iam_user_id') ?? '';
      final orgId = await repository.getSetting('iam_org_id') ?? '';
      // Not signed in: nothing to sync, and never sync under a demo account.
      if (userId.isEmpty || orgId.isEmpty) return false;

      final cloudVitals = await openWearablesService.fetchLatestVitals(userId: userId, orgId: orgId);
      if (cloudVitals == null) {
        // Health Connect answered but had nothing new for today.
        isOpenWearablesSynced = false;
        lastSyncOutcome = VitalsSyncOutcome.noData;
        notifyListeners();
        return false;
      }
      {
        // Update Resting HR or HR only if real values are reported
        final realHr = cloudVitals.restingHeartRate ?? cloudVitals.heartRate;
        if (realHr != null && realHr > 0) {
          dashboardHr = realHr.toDouble();
        }

        dashboardMinHr = cloudVitals.minHeartRate;
        dashboardMaxHr = cloudVitals.maxHeartRate;

        if (cloudVitals.heartRateVariability != null && cloudVitals.heartRateVariability! > 0.0 && cloudVitals.heartRateVariability != 45.5) {
          dashboardHrv = cloudVitals.heartRateVariability!;
        } else {
          if (dashboardHrv == 45.5) {
            dashboardHrv = 0.0;
          }
        }

        final now = DateTime.now();
        // One row per metric per day, replaced on each sync. Timestamp-based
        // ids added ~8 new rows every 5 minutes and the table never shrank.
        final dayKey = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        if (cloudVitals.sleepMinutes != null) {
          liveSleep = cloudVitals.sleepMinutes! / 60.0;
          dashboardSleep = liveSleep;
          deepSleepMinutes = cloudVitals.deepSleepMinutes ?? 0;
          lightSleepMinutes = cloudVitals.lightSleepMinutes ?? 0;
          remSleepMinutes = cloudVitals.remSleepMinutes ?? 0;
          awakeMinutes = cloudVitals.awakeMinutes ?? 0;
          await repository.saveMetric(HealthMetric(
            id: 'synced_sleep_$dayKey',
            type: 'sleep',
            value: dashboardSleep,
            timestamp: now,
          ));
          if (deepSleepMinutes > 0) {
            await repository.saveMetric(HealthMetric(
              id: 'synced_deep_sleep_$dayKey',
              type: 'deep_sleep',
              value: deepSleepMinutes.toDouble(),
              timestamp: now,
            ));
          }
          if (lightSleepMinutes > 0) {
            await repository.saveMetric(HealthMetric(
              id: 'synced_light_sleep_$dayKey',
              type: 'light_sleep',
              value: lightSleepMinutes.toDouble(),
              timestamp: now,
            ));
          }
          if (remSleepMinutes > 0) {
            await repository.saveMetric(HealthMetric(
              id: 'synced_rem_sleep_$dayKey',
              type: 'rem_sleep',
              value: remSleepMinutes.toDouble(),
              timestamp: now,
            ));
          }
          if (awakeMinutes > 0) {
            await repository.saveMetric(HealthMetric(
              id: 'synced_awake_sleep_$dayKey',
              type: 'awake_sleep',
              value: awakeMinutes.toDouble(),
              timestamp: now,
            ));
          }
        }

        if (cloudVitals.steps != null && cloudVitals.steps! > 0) {
          dashboardSteps = cloudVitals.steps!;
          liveSteps = cloudVitals.steps!;
        }

        if (cloudVitals.caloriesKcal != null && cloudVitals.caloriesKcal! > 0) {
          dashboardCalories = cloudVitals.caloriesKcal!;
          await repository.saveMetric(HealthMetric(
            id: 'synced_cal_$dayKey',
            type: 'calories',
            value: dashboardCalories,
            timestamp: now,
          ));
        }

        if (cloudVitals.totalActiveMinutes != null) {
          dashboardActiveTimeMins = cloudVitals.totalActiveMinutes!;
          liveActiveMins = cloudVitals.totalActiveMinutes!;
          await repository.saveMetric(HealthMetric(
            id: 'synced_active_$dayKey',
            type: 'active_time',
            value: dashboardActiveTimeMins.toDouble(),
            timestamp: now,
          ));
        }

        if (cloudVitals.distanceMeters != null) {
          dashboardDistanceKm = cloudVitals.distanceMeters! / 1000.0;
          await repository.saveMetric(HealthMetric(
            id: 'synced_dist_$dayKey',
            type: 'distance',
            value: dashboardDistanceKm,
            timestamp: now,
          ));
        }

        if (cloudVitals.oxygenSaturation != null && cloudVitals.oxygenSaturation! > 0) {
          dashboardSpo2 = cloudVitals.oxygenSaturation!;
          await repository.saveMetric(HealthMetric(
            id: 'synced_spo2_$dayKey',
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
            id: 'synced_height_$dayKey',
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
            id: 'synced_weight_$dayKey',
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
            id: 'synced_hr_$dayKey',
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

        // Health Connect data changes slowly; don't upload an identical record
        // again (the service also caches reads for 30s).
        final payload = Map<String, dynamic>.from(mergedVitals.toJson())..remove('recorded_at');
        final signature = '$userId|${jsonEncode(payload)}';
        if (signature != _lastSubmittedVitalsSignature) {
          await vitalsRepository.submitVitals(mergedVitals, userId: userId, orgId: orgId);
          _lastSubmittedVitalsSignature = signature;
        }
        lastSyncOutcome = VitalsSyncOutcome.synced;
        await _saveLastSync(userId, DateTime.now());
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Open-Wearables sync error: $e');
      }
      // A failed sync must not keep showing "Synced".
      isOpenWearablesSynced = false;
      lastSyncOutcome = VitalsSyncOutcome.failed;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _stepsSub?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}

/// Result of the most recent Health Connect sync attempt.
enum VitalsSyncOutcome {
  /// No attempt yet in this session.
  none,

  /// Data was read and saved.
  synced,

  /// Health Connect had no data for today.
  noData,

  /// The attempt failed (permission, Health Connect or network error).
  failed,
}
