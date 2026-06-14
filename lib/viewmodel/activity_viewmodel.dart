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

class ActivityViewModel extends ChangeNotifier {
  final PedometerSensor pedometer;
  final GPSLocationSensor gps;
  final HealthRepository repository;
  final VitalsRepository vitalsRepository = VitalsRepository();

  // --- Live Steps State ---
  int liveSteps = 0;
  StreamSubscription<int>? _stepsSub;

  // --- Runtime Permission Handler Status ---
  bool hasActivityPermission = false;
  bool hasLocationPermission = false;

  // --- Sleep & Actigraphy State ---
  double liveSleep = 0.0;
  double dashboardSleep = 0.0;
  bool isStill = false;
  int _stillSeconds = 0;
  StreamSubscription<UserAccelerometerEvent>? _sleepAccSub;
  Timer? _actigraphyTimer;

  // --- Weekly Progress List ---
  List<int> weeklyCaloriesList = [350, 420, 390, 510, 480, 220, 150];

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
  double dashboardHrv = 0.0;
  double dashboardDistanceKm = 0.0;
  int dashboardActiveTimeMins = 0;
  double dashboardCalories = 0.0;

  // --- User Bio-Data State (Weight, Height, Age) ---
  double userWeight = 70.0;
  double userHeight = 175.0;
  int userAge = 25;

  // --- Real-time Step Tracking Baselines ---
  int _todayStepsBase = 0;
  int liveActiveMins = 0;
  DateTime _lastActiveCheckTime = DateTime.now();
  int _lastCheckSteps = 0;

  // --- Dynamic Getters for 24/7 Calculations ---
  int get currentSteps => liveSteps > 0 ? liveSteps : dashboardSteps;
  int get currentActiveMins => liveActiveMins > 0 ? liveActiveMins : (dashboardActiveTimeMins > 0 ? dashboardActiveTimeMins : 0);
  int get currentCalories => (currentSteps * userWeight * 0.0005 + currentActiveMins * 4.0 * (userWeight / 70.0)).toInt();
  double get currentSleep => liveSleep > 0.0 ? liveSleep : (dashboardSleep > 0.0 ? dashboardSleep : 0.0);
  bool get isStepSensorFallback => pedometer.isUsingAccelerometer;

  ActivityViewModel({
    required this.pedometer,
    required this.gps,
    required this.repository,
  }) {
    initDashboard();
  }

  Future<void> requestHardwarePermissions() async {
    if (kDebugMode) {
      print('[ActivityViewModel] Starting runtime hardware permission requests...');
    }

    // A. Request Activity Recognition (Pedometer)
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

    // B. Request Location (GPS)
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

    // C. Request Camera (Flash/BPM Vital Sensing)
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

    notifyListeners();

    // If activity recognition was granted, start native steps tracker immediately
    if (hasActivityPermission) {
      await startStepsTracking();
    }
    
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
    // A. Seed historical data if empty
    await _seedHistoricalDataIfEmpty();

    // 1. Fetch latest baseline logs from local database first (immediate load)
    try {
      // Load user bio data (Weight, Height, Age) first from SQLite
      final weightMetric = await repository.getRecentMetrics('weight');
      if (weightMetric.isNotEmpty) userWeight = weightMetric.first.value;
      
      final heightMetric = await repository.getRecentMetrics('height');
      if (heightMetric.isNotEmpty) userHeight = heightMetric.first.value;
      
      final ageMetric = await repository.getRecentMetrics('age');
      if (ageMetric.isNotEmpty) userAge = ageMetric.first.value.toInt();

      final steps = await repository.getRecentMetrics('steps');
      dashboardSteps = steps.isNotEmpty ? _getTodayMetricValue(steps).toInt() : 0;
      _todayStepsBase = dashboardSteps;
      _lastCheckSteps = dashboardSteps;
      
      final hr = await repository.getRecentMetrics('heart_rate');
      dashboardHr = hr.isNotEmpty ? _getTodayMetricValue(hr) : 0.0;
      
      final hrv = await repository.getRecentMetrics('hrv');
      dashboardHrv = hrv.isNotEmpty ? _getTodayMetricValue(hrv) : 0.0;

      final distance = await repository.getRecentMetrics('distance');
      dashboardDistanceKm = distance.isNotEmpty ? _getTodayMetricValue(distance) : 0.0;

      final activeTime = await repository.getRecentMetrics('active_time');
      dashboardActiveTimeMins = activeTime.isNotEmpty ? _getTodayMetricValue(activeTime).toInt() : 0;
      liveActiveMins = dashboardActiveTimeMins;

      final sleep = await repository.getRecentMetrics('sleep');
      dashboardSleep = sleep.isNotEmpty ? _getTodayMetricValue(sleep) : 0.0;

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
        if (latest.heartRate != null && latest.heartRate! > 0) {
          dashboardHr = latest.heartRate!.toDouble();
        }
        if (latest.heartRateVariability != null && latest.heartRateVariability! > 0.0) {
          dashboardHrv = latest.heartRateVariability!;
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to hydrate dashboard from FHIR vitals: $e');
      }
    }

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
    
    try {
      await pedometer.startSensor();
      int lastSteps = -1;
      _stepsSub = pedometer.dataStream.listen((sessionSteps) async {
        liveSteps = _todayStepsBase + sessionSteps;
        
        final now = DateTime.now();
        final todayStr = now.toIso8601String().substring(0, 10);
        
        // Save today's cumulative steps under a single unique ID for today!
        await repository.saveMetric(HealthMetric(
          id: 'steps_$todayStr',
          type: 'steps',
          value: liveSteps.toDouble(),
          timestamp: now,
        ));

        // 10,000 steps congratulatory notification check
        if (liveSteps >= 10000) {
          final milestoneStepsSentKey = 'milestone_steps_sent_$todayStr';
          final alreadySent = await repository.getSetting(milestoneStepsSentKey);
          if (alreadySent == null) {
            await repository.saveSetting(milestoneStepsSentKey, 'true');
            await NotificationService.instance.showImmediateNotification(
              id: 10000,
              title: 'Goal Achieved! 🎉',
              body: 'Congratulations! You have completed 10,000 steps today!',
              type: 'MILESTONE',
            );
          }
        }

        // Initialize active tracking controls on the first stream event
        if (lastSteps == -1) {
          _lastCheckSteps = liveSteps;
          _lastActiveCheckTime = now;
        }

        // 2. Active minutes: Check if steps incremented by >= 40 in a true 60-second window!
        final diffSeconds = now.difference(_lastActiveCheckTime).inSeconds;
        if (diffSeconds >= 60) {
          final difference = liveSteps - _lastCheckSteps;
          if (difference >= 40) {
            liveActiveMins += 1;
            dashboardActiveTimeMins = liveActiveMins;
            
            await repository.saveMetric(HealthMetric(
              id: 'active_time_$todayStr',
              type: 'active_time',
              value: liveActiveMins.toDouble(),
              timestamp: now,
            ));
          }
          _lastActiveCheckTime = now;
          _lastCheckSteps = liveSteps;
        }
        
        lastSteps = sessionSteps;
        
        // 3. Personalized Calorie Calculation & Remote FHIR Sync
        try {
          final int personalizedCal = (liveSteps * userWeight * 0.0005 + liveActiveMins * 4.0 * (userWeight / 70.0)).toInt();
          final int sleepMin = (dashboardSleep * 60).toInt() > 0 ? (dashboardSleep * 60).toInt() : 480;

          final cachedGender = await repository.getProfileValue('gender');
          final userId = await repository.getSetting('iam_user_id') ?? '';
          final orgId = await repository.getSetting('iam_org_id') ?? '';

          await vitalsRepository.submitVitals(VitalsRecord(
            steps: liveSteps,
            caloriesKcal: personalizedCal.toDouble(),
            distanceMeters: liveSteps * 0.8, // ~0.8m per step
            totalActiveMinutes: liveActiveMins,
            activityName: 'WALKING',
            exerciseDurationMinutes: liveActiveMins.toDouble(),
            activeZoneMinutes: liveActiveMins,
            fatburnActiveZoneMinutes: (liveActiveMins * 0.5).toInt(),
            cardioActiveZoneMinutes: (liveActiveMins * 0.3).toInt(),
            peakActiveZoneMinutes: (liveActiveMins * 0.2).toInt(),
            restingHeartRate: dashboardHr > 0 ? dashboardHr.toInt() : 72,
            heartRate: dashboardHr > 0 ? dashboardHr.toInt() : 72,
            heartRateVariability: dashboardHrv > 0 ? dashboardHrv : 45.5,
            stressManagementScore: null,
            bloodPressureSystolic: null,
            bloodPressureDiastolic: null,
            sleepMinutes: sleepMin,
            remSleepMinutes: (sleepMin * 0.1875).toInt(),
            deepSleepMinutes: (sleepMin * 0.125).toInt(),
            lightSleepMinutes: (sleepMin * 0.5208).toInt(),
            awakeMinutes: (sleepMin * 0.0417).toInt(),
            bedTime: '22:00',
            wakeUpTime: '06:00',
            deepSleepPercent: 14.2,
            remSleepPercent: 21.4,
            lightSleepPercent: 59.5,
            awakePercent: 4.7,
            weightKg: userWeight,
            heightCm: userHeight,
            age: userAge,
            gender: cachedGender,
            recordedAt: now.toIso8601String().substring(0, 19),
            date: todayStr,
          ), userId: userId, orgId: orgId);
        } catch (e) {
          if (kDebugMode) {
            print('[ActivityViewModel] Live steps FHIR sync failed: $e');
          }
        }
        
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to start native steps sensor: $e');
      }
    }
  }

  /// Persists height, weight, and age directly to the SQLite cache and triggers remote sync
  Future<void> saveBioData({required double weight, required double height, required double age}) async {
    userWeight = weight;
    userHeight = height;
    userAge = age.toInt();
    
    final now = DateTime.now();
    
    // Save to local database with unique baseline keys
    await repository.saveMetric(HealthMetric(
      id: 'bio_weight',
      type: 'weight',
      value: weight,
      timestamp: now,
    ));
    await repository.saveMetric(HealthMetric(
      id: 'bio_height',
      type: 'height',
      value: height,
      timestamp: now,
    ));
    await repository.saveMetric(HealthMetric(
      id: 'bio_age',
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
            restingHeartRate: dashboardHr > 0 ? dashboardHr.toInt() : 72,
            heartRate: dashboardHr > 0 ? dashboardHr.toInt() : 72,
            heartRateVariability: dashboardHrv > 0 ? dashboardHrv : 45.5,
            weightKg: weight,
            heightCm: height,
            age: age.toInt(),
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
    
    notifyListeners();
  }

  Future<void> startSleepTracking() async {
    await _sleepAccSub?.cancel();
    _actigraphyTimer?.cancel();
    
    _stillSeconds = 0;
    liveSleep = 0.0;
    isStill = false;
    
    // Read previous sleep from database if any
    final sleepRecords = await repository.getRecentMetrics('sleep');
    if (sleepRecords.isNotEmpty) {
      dashboardSleep = sleepRecords.first.value;
    } else {
      dashboardSleep = 7.3; // Faded/simulated baseline
    }
    
    try {
      _sleepAccSub = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
        double mag = event.x * event.x + event.y * event.y + event.z * event.z;
        // Phone is completely still if motion magnitude is extremely close to zero
        isStill = mag < 0.05;
      });
      
      // Periodically sample still state every second
      _actigraphyTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (isStill) {
          _stillSeconds++;
          if (_stillSeconds >= 5) {
            liveSleep += 0.05; // 0.05 hrs per second (rapid progression for testing)
            
            // Save sleep log to SQLite occasionally
            if (_stillSeconds % 10 == 0) {
              await repository.saveMetric(HealthMetric(
                id: 'sleep_${DateTime.now().millisecondsSinceEpoch}',
                type: 'sleep',
                value: liveSleep,
                timestamp: DateTime.now(),
              ));
            }
          }
        } else {
          // Device moved, reset actigraphy session stillness
          _stillSeconds = 0;
        }
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to start sleep actigraphy: $e');
      }
    }
  }

  Future<void> _seedHistoricalDataIfEmpty() async {
    try {
      final steps = await repository.getRecentMetrics('steps');
      if (steps.isEmpty) {
        final now = DateTime.now();
        // Seed 7 days of historical logs
        for (int i = 6; i >= 1; i--) {
          final date = now.subtract(Duration(days: i));
          final int mockSteps = 6000 + i * 500 + (i % 2 == 0 ? 800 : -400);
          final double mockActiveMins = 30.0 + i * 5 + (i % 2 == 0 ? 10 : -5);
          final double mockDistance = mockSteps * 0.0008; // ~0.8m per step
          final double mockSleep = 6.5 + (i % 3) * 0.5;
          final double mockCalories = mockSteps * 0.04 + mockActiveMins * 5.0;

          await repository.saveMetric(HealthMetric(
            id: 'seed_steps_${date.day}',
            type: 'steps',
            value: mockSteps.toDouble(),
            timestamp: date,
          ));
          await repository.saveMetric(HealthMetric(
            id: 'seed_active_time_${date.day}',
            type: 'active_time',
            value: mockActiveMins,
            timestamp: date,
          ));
          await repository.saveMetric(HealthMetric(
            id: 'seed_distance_${date.day}',
            type: 'distance',
            value: mockDistance,
            timestamp: date,
          ));
          await repository.saveMetric(HealthMetric(
            id: 'seed_sleep_${date.day}',
            type: 'sleep',
            value: mockSleep,
            timestamp: date,
          ));
          await repository.saveMetric(HealthMetric(
            id: 'seed_calories_${date.day}',
            type: 'calories',
            value: mockCalories,
            timestamp: date,
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityViewModel] Failed to seed historical data: $e');
      }
    }
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

  @override
  void dispose() {
    _stepsSub?.cancel();
    _gpsSub?.cancel();
    _stopwatchTimer?.cancel();
    _sleepAccSub?.cancel();
    _actigraphyTimer?.cancel();
    super.dispose();
  }
}
