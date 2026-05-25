import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/model/health_metrics.dart';
import '../../data/service/camera_ppg_sensor.dart';
import '../../data/service/pedometer_sensor.dart';
import '../../data/service/gps_location_sensor.dart';
import '../../data/repository/health_repository.dart';

class HealthViewModel extends ChangeNotifier {
  final PedometerSensor pedometer;
  final GPSLocationSensor gps;
  final CameraPPGSensor ppg;
  final HealthRepository repository;

  HealthViewModel({
    required this.pedometer,
    required this.gps,
    required this.ppg,
    required this.repository,
  });

  // --- Live Steps State ---
  int liveSteps = 0;
  StreamSubscription<int>? _stepsSub;

  // --- Live PPG Heart Rate State ---
  bool isPpgScanning = false;
  bool fingerDetected = false;
  double liveBpm = 0.0;
  double liveHrv = 0.0;
  final List<double> wavePoints = [];
  StreamSubscription<PPGData>? _ppgSub;

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

  // --- Initialization ---
  
  Future<void> initDashboard() async {
    try {
      final steps = await repository.getRecentMetrics('steps');
      if (steps.isNotEmpty) dashboardSteps = steps.first.value.toInt();
      
      final hr = await repository.getRecentMetrics('heart_rate');
      if (hr.isNotEmpty) dashboardHr = hr.first.value;
      
      final hrv = await repository.getRecentMetrics('hrv');
      if (hrv.isNotEmpty) dashboardHrv = hrv.first.value;

      final distance = await repository.getRecentMetrics('distance');
      if (distance.isNotEmpty) dashboardDistanceKm = distance.first.value;

      final activeTime = await repository.getRecentMetrics('active_time');
      if (activeTime.isNotEmpty) dashboardActiveTimeMins = activeTime.first.value.toInt();

      notifyListeners();
    } catch (e) {
      // Swallowed safely
    }
  }

  // --- Steps Controller ---

  Future<void> startStepsTracking() async {
    await _stepsSub?.cancel();
    
    try {
      await pedometer.startSensor();
      _stepsSub = pedometer.dataStream.listen((steps) {
        liveSteps = steps;
        
        // Save current steps to SQLite database
        repository.saveMetric(HealthMetric(
          id: 'steps_${DateTime.now().millisecondsSinceEpoch}',
          type: 'steps',
          value: steps.toDouble(),
          timestamp: DateTime.now(),
        ));
        
        notifyListeners();
      });
    } catch (e) {
      // Swallowed safely
    }
  }

  // --- PPG Scanner Controller ---

  Future<void> startPpgScan() async {
    isPpgScanning = true;
    fingerDetected = false;
    liveBpm = 0.0;
    liveHrv = 0.0;
    wavePoints.clear();
    notifyListeners();

    try {
      await ppg.startSensor();
      _ppgSub = ppg.dataStream.listen((data) {
        fingerDetected = data.isFingerDetected;
        liveBpm = data.bpm;
        liveHrv = data.hrv;
        
        if (data.isFingerDetected) {
          wavePoints.add(data.signal);
          if (wavePoints.length > 60) {
            wavePoints.removeAt(0);
          }
        } else {
          wavePoints.clear();
        }
        notifyListeners();
      });
    } catch (e) {
      await stopPpgScan();
    }
  }

  Future<void> stopPpgScan() async {
    isPpgScanning = false;
    await _ppgSub?.cancel();
    _ppgSub = null;
    
    try {
      await ppg.stopSensor();
      
      // Save heart rate and HRV only if we got clean calculations
      if (liveBpm > 0) {
        final timestamp = DateTime.now();
        await repository.saveMetric(HealthMetric(
          id: 'hr_${timestamp.millisecondsSinceEpoch}',
          type: 'heart_rate',
          value: liveBpm,
          timestamp: timestamp,
        ));
        await repository.saveMetric(HealthMetric(
          id: 'hrv_${timestamp.millisecondsSinceEpoch}',
          type: 'hrv',
          value: liveHrv,
          timestamp: timestamp,
        ));

        // Update dashboard view instantly
        dashboardHr = liveBpm;
        dashboardHrv = liveHrv;
      }
    } catch (e) {
      // Safe swallow
    }

    wavePoints.clear();
    notifyListeners();

    // Trigger local SQLite sync simulation in background
    repository.uploadPendingMetrics();
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
            
            // Filter coordinates with safe accuracy boundaries
            if (position.accuracy < 15) {
              totalDistanceKm += distance / 1000.0;
              routeCoordinates.add(position);
              
              // Relational write coordinate to SQLite points table
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
        
        // Save distance
        await repository.saveMetric(HealthMetric(
          id: '${_currentWorkoutId}_dist',
          type: 'distance',
          value: totalDistanceKm,
          timestamp: timestamp,
        ));
        
        // Save active elapsed time in minutes
        double activeMins = elapsedSeconds / 60.0;
        await repository.saveMetric(HealthMetric(
          id: '${_currentWorkoutId}_time',
          type: 'active_time',
          value: activeMins,
          timestamp: timestamp,
        ));

        // Update dashboard view instantly
        dashboardDistanceKm = totalDistanceKm;
        dashboardActiveTimeMins = activeMins.toInt();
      }
    } catch (e) {
      // Safe swallow
    }

    _lastGpsPosition = null;
    _currentWorkoutId = null;
    notifyListeners();

    // Trigger local SQLite sync simulation
    repository.uploadPendingMetrics();
  }

  @override
  void dispose() {
    _stepsSub?.cancel();
    _ppgSub?.cancel();
    _gpsSub?.cancel();
    _stopwatchTimer?.cancel();
    super.dispose();
  }
}
