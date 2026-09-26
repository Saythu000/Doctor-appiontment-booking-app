import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../../domain/model/vitals_payload.dart';

/// Supported Open-Wearables ecosystem providers
enum WearableProviderType {
  garmin,
  whoop,
  oura,
  fitbit,
  healthConnect,
  appleHealth,
}

extension WearableProviderTypeExtension on WearableProviderType {
  String get id {
    switch (this) {
      case WearableProviderType.garmin:
        return 'garmin';
      case WearableProviderType.whoop:
        return 'whoop';
      case WearableProviderType.oura:
        return 'oura';
      case WearableProviderType.fitbit:
        return 'fitbit';
      case WearableProviderType.healthConnect:
        return 'health_connect';
      case WearableProviderType.appleHealth:
        return 'apple';
    }
  }

  String get displayName {
    switch (this) {
      case WearableProviderType.garmin:
        return 'Garmin Connect';
      case WearableProviderType.whoop:
        return 'WHOOP 4.0';
      case WearableProviderType.oura:
        return 'Oura Ring';
      case WearableProviderType.fitbit:
        return 'Fitbit';
      case WearableProviderType.healthConnect:
        return 'Android Health Connect';
      case WearableProviderType.appleHealth:
        return 'Apple Health';
    }
  }

  String get category {
    switch (this) {
      case WearableProviderType.garmin:
      case WearableProviderType.whoop:
      case WearableProviderType.oura:
      case WearableProviderType.fitbit:
        return 'Cloud Sync (OAuth 2.0)';
      case WearableProviderType.healthConnect:
      case WearableProviderType.appleHealth:
        return 'On-Device Platform SDK';
    }
  }
}

class ProviderConnectionInfo {
  final WearableProviderType provider;
  final bool isConnected;
  final DateTime? lastSyncTime;
  final String? accountEmail;

  ProviderConnectionInfo({
    required this.provider,
    required this.isConnected,
    this.lastSyncTime,
    this.accountEmail,
  });
}

class OpenWearablesService {
  // Singleton pattern
  static final OpenWearablesService _instance = OpenWearablesService._internal();
  factory OpenWearablesService() => _instance;
  OpenWearablesService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));
  }

  late final Dio _dio;
  String _host = 'https://api.openwearables.io'; // Configurable Open-Wearables host
  String? _accessToken;
  String? _userId;
  String? get currentUserId => _userId;

  // Active connected providers cache
  final Map<WearableProviderType, ProviderConnectionInfo> _connections = {
    WearableProviderType.garmin: ProviderConnectionInfo(
      provider: WearableProviderType.garmin,
      isConnected: false,
    ),
    WearableProviderType.whoop: ProviderConnectionInfo(
      provider: WearableProviderType.whoop,
      isConnected: false,
    ),
    WearableProviderType.oura: ProviderConnectionInfo(
      provider: WearableProviderType.oura,
      isConnected: false,
    ),
    WearableProviderType.healthConnect: ProviderConnectionInfo(
      provider: WearableProviderType.healthConnect,
      isConnected: true, // Native Health Connect enabled via Android Manifest
      lastSyncTime: DateTime.now(),
    ),
  };

  Map<WearableProviderType, ProviderConnectionInfo> get connections => Map.unmodifiable(_connections);

  final _syncStatusController = StreamController<bool>.broadcast();
  Stream<bool> get syncStatusStream => _syncStatusController.stream;

  /// Configure host and user credentials
  void configure({required String host, String? userId, String? accessToken}) {
    _host = host.replaceAll(RegExp(r'/$'), '');
    _userId = userId;
    _accessToken = accessToken;
    _dio.options.baseUrl = _host;
    if (_accessToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    }
  }

  /// Toggle connection status for a cloud provider (OAuth simulation / link)
  Future<bool> connectProvider(WearableProviderType provider) async {
    _syncStatusController.add(true);
    try {
      // In production, opens provider OAuth webview or calls /api/v1/connections/oauth/{provider}
      await Future.delayed(const Duration(milliseconds: 600));
      _connections[provider] = ProviderConnectionInfo(
        provider: provider,
        isConnected: true,
        lastSyncTime: DateTime.now(),
        accountEmail: 'patient.auth@drgodly.com',
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[OpenWearables] Error connecting ${provider.displayName}: $e');
      }
      return false;
    } finally {
      _syncStatusController.add(false);
    }
  }

  /// Disconnect a linked provider
  Future<void> disconnectProvider(WearableProviderType provider) async {
    _connections[provider] = ProviderConnectionInfo(
      provider: provider,
      isConnected: false,
    );
  }

  bool isLastSyncReal = false;
  String lastSyncSource = 'Android Health Connect';
  int lastDataPointsCount = 0;
  double? latestSpo2;

  DateTime? _lastFetchTime;
  VitalsRecord? _cachedVitals;

  /// Pull recent normalized vitals from connected Open-Wearables / Health Connect providers
  /// and convert them into PHIA's VitalsRecord model
  Future<VitalsRecord?> fetchLatestVitals({required String userId, required String orgId}) async {
    final now = DateTime.now();
    if (_lastFetchTime != null && now.difference(_lastFetchTime!).inSeconds < 30) {
      return _cachedVitals;
    }
    final todayStr = now.toIso8601String().split('T')[0];
    final todayStart = DateTime(now.year, now.month, now.day);

    // Query REAL on-device data from Android Health Connect
    try {
      final health = Health();
      await health.configure();

      final candidateTypes = [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        HealthDataType.STEPS,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.WORKOUT,
      ];
      final types = candidateTypes.where((t) => health.isDataTypeAvailable(t)).toList();

      bool? hasPerm;
      try {
        hasPerm = await health.hasPermissions(types);
      } catch (permError) {
        if (kDebugMode) {
          print('[OpenWearablesService] Health Connect permission check throttled/error: $permError');
        }
      }

      if (hasPerm != true) {
        try {
          await health.requestAuthorization(types);
        } catch (_) {}
      }

      final startTime = now.subtract(const Duration(hours: 48));
      List<HealthDataPoint> dataPoints = [];
      try {
        dataPoints = await health.getHealthDataFromTypes(
          types: types,
          startTime: startTime,
          endTime: now,
        );
      } catch (queryError) {
        if (kDebugMode) {
          print('[OpenWearablesService] Batch query failed, attempting per-type query: $queryError');
        }
      }

      // If batch query returned empty or failed, query critical types individually
      if (dataPoints.isEmpty) {
        for (final t in types) {
          try {
            final pts = await health.getHealthDataFromTypes(
              types: [t],
              startTime: startTime,
              endTime: now,
            );
            dataPoints.addAll(pts);
          } catch (_) {}
        }
      }

      lastDataPointsCount = dataPoints.length;
      if (kDebugMode) {
        print('[OpenWearablesService] Health Connect queried ${types.length} types, received ${dataPoints.length} data points');
      }

      if (dataPoints.isNotEmpty) {
        final breakdown = <String, int>{};
        for (var dp in dataPoints) {
          breakdown[dp.type.name] = (breakdown[dp.type.name] ?? 0) + 1;
        }
        if (kDebugMode) {
          print('[OpenWearablesService] Live points breakdown: $breakdown');
        }

        // Sort newest first
        dataPoints.sort((a, b) => b.dateTo.compareTo(a.dateTo));

        int? realRestingHr;
        int? realLiveHr;
        int? realMinHr;
        int? realMaxHr;
        double? realHrv;
        double? realSpo2;
        int realSteps = 0;
        double realTotalCalories = 0.0;
        double realActiveCalories = 0.0;
        double realBasalCalories = 0.0;
        double realDistance = 0.0;
        int realSleepMinutes = 0;
        int realWorkoutMinutes = 0;
        int totalActiveSeconds = 0;
        final minuteStepCounts = <String, int>{};
        String detectedAppSource = 'Android Health Connect';

        for (final dp in dataPoints) {
          if (dp.sourceName.isNotEmpty && dp.sourceName != 'unknown') {
            detectedAppSource = dp.sourceName;
          }

          if (dp.type == HealthDataType.RESTING_HEART_RATE && realRestingHr == null) {
            if (dp.value is NumericHealthValue) {
              realRestingHr = (dp.value as NumericHealthValue).numericValue.toInt();
            }
          } else if (dp.type == HealthDataType.HEART_RATE) {
            if (dp.value is NumericHealthValue) {
              final val = (dp.value as NumericHealthValue).numericValue.toInt();
              realLiveHr ??= val;
              if (realMinHr == null || val < realMinHr) realMinHr = val;
              if (realMaxHr == null || val > realMaxHr) realMaxHr = val;
            }
          } else if ((dp.type == HealthDataType.HEART_RATE_VARIABILITY_RMSSD ||
                      dp.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) &&
                     realHrv == null) {
            if (dp.value is NumericHealthValue) {
              realHrv = (dp.value as NumericHealthValue).numericValue.toDouble();
            }
          } else if (dp.type == HealthDataType.BLOOD_OXYGEN && realSpo2 == null) {
            if (dp.value is NumericHealthValue) {
              double val = (dp.value as NumericHealthValue).numericValue.toDouble();
              if (val <= 1.0) val = val * 100.0;
              realSpo2 = val;
            }
          } else if (dp.type == HealthDataType.TOTAL_CALORIES_BURNED) {
            if (dp.value is NumericHealthValue) {
              double val = (dp.value as NumericHealthValue).numericValue.toDouble();
              if (!dp.dateFrom.isBefore(todayStart)) {
                if (dp.dateTo.isAfter(now) && dp.dateTo.isAfter(dp.dateFrom)) {
                  final totalSec = dp.dateTo.difference(dp.dateFrom).inSeconds;
                  final elapsedSec = now.difference(dp.dateFrom).inSeconds;
                  if (totalSec > 0 && elapsedSec > 0) {
                    val = val * (elapsedSec / totalSec).clamp(0.0, 1.0);
                  }
                }
                realTotalCalories += val;
              }
            }
          } else if (dp.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
            if (dp.value is NumericHealthValue) {
              double val = (dp.value as NumericHealthValue).numericValue.toDouble();
              if (!dp.dateFrom.isBefore(todayStart)) {
                if (dp.dateTo.isAfter(now) && dp.dateTo.isAfter(dp.dateFrom)) {
                  final totalSec = dp.dateTo.difference(dp.dateFrom).inSeconds;
                  final elapsedSec = now.difference(dp.dateFrom).inSeconds;
                  if (totalSec > 0 && elapsedSec > 0) {
                    val = val * (elapsedSec / totalSec).clamp(0.0, 1.0);
                  }
                }
                realActiveCalories += val;
              }
            }
          } else if (dp.type == HealthDataType.BASAL_ENERGY_BURNED) {
            if (dp.value is NumericHealthValue) {
              double val = (dp.value as NumericHealthValue).numericValue.toDouble();
              if (!dp.dateFrom.isBefore(todayStart)) {
                if (dp.dateTo.isAfter(now) && dp.dateTo.isAfter(dp.dateFrom)) {
                  final totalSec = dp.dateTo.difference(dp.dateFrom).inSeconds;
                  final elapsedSec = now.difference(dp.dateFrom).inSeconds;
                  if (totalSec > 0 && elapsedSec > 0) {
                    val = val * (elapsedSec / totalSec).clamp(0.0, 1.0);
                  }
                }
                realBasalCalories += val;
              }
            }
          } else if (dp.type == HealthDataType.DISTANCE_WALKING_RUNNING) {
            if (dp.value is NumericHealthValue && !dp.dateTo.isBefore(todayStart)) {
              realDistance += (dp.value as NumericHealthValue).numericValue.toDouble();
            }
          } else if (dp.type == HealthDataType.WORKOUT) {
            if (!dp.dateTo.isBefore(todayStart)) {
              realWorkoutMinutes += dp.dateTo.difference(dp.dateFrom).inMinutes;
            }
          } else if (dp.type == HealthDataType.STEPS) {
            if (!dp.dateFrom.isBefore(todayStart)) {
              final count = (dp.value is NumericHealthValue)
                  ? (dp.value as NumericHealthValue).numericValue.toInt()
                  : 0;
              final durSec = dp.dateTo.difference(dp.dateFrom).inSeconds;
              final cadence = durSec > 0 ? (count / (durSec / 60.0)) : count.toDouble();
              // Track minute bucket for Google Fit Move Minutes calculation
              // Google Fit awards 1 Move Minute for each minute with brisk movement / step count >= 28
              final bucketKey = '${dp.dateFrom.year}-${dp.dateFrom.month}-${dp.dateFrom.day} ${dp.dateFrom.hour}:${dp.dateFrom.minute}';
              minuteStepCounts[bucketKey] = (minuteStepCounts[bucketKey] ?? 0) + count;
              if (cadence >= 30.0) {
                totalActiveSeconds += durSec;
              }
            }
          } else if (dp.type == HealthDataType.SLEEP_SESSION || dp.type == HealthDataType.SLEEP_ASLEEP) {
            // Only aggregate sleep ending today or after last night (18:00 yesterday)
            final lastEvening = todayStart.subtract(const Duration(hours: 6));
            if (dp.dateTo.isAfter(lastEvening)) {
              realSleepMinutes += dp.dateTo.difference(dp.dateFrom).inMinutes;
            }
          }
        }

        final double realCalories = realTotalCalories > 0
            ? realTotalCalories
            : (realActiveCalories + realBasalCalories);

        if (kDebugMode) {
          print('[OpenWearablesService] Aggregated calories for today: total=$realTotalCalories, active=$realActiveCalories, basal=$realBasalCalories => finalCalories=$realCalories');
        }

        realSleepMinutes = realSleepMinutes.clamp(0, 1440);

        try {
          final midnight = DateTime(now.year, now.month, now.day);
          final stepCount = await health.getTotalStepsInInterval(midnight, now);
          if (stepCount != null && stepCount > 0) {
            realSteps = stepCount;
          }
        } catch (_) {}

        // Calculate real active minutes matching Google Fit's Move Minutes exactly
        // Google Fit calculates Move Minutes as each minute where steps >= 28 or structured workout duration
        final moveMinutesFromBuckets = minuteStepCounts.values.where((c) => c >= 28).length;
        int realActiveMinutes = realWorkoutMinutes > 0
            ? realWorkoutMinutes
            : (moveMinutesFromBuckets > 0
                ? moveMinutesFromBuckets
                : (totalActiveSeconds / 60.0).round());
        if (realActiveMinutes == 0 && realSteps > 0) {
          realActiveMinutes = (realSteps / 70.0).round().clamp(1, 1440);
        }

        if (kDebugMode) {
          print('[OpenWearablesService] Active minutes for today: workout=$realWorkoutMinutes, buckets=$moveMinutesFromBuckets, totalActiveSec=$totalActiveSeconds => finalActiveMinutes=$realActiveMinutes');
        }

        lastSyncSource = detectedAppSource;
        isLastSyncReal = true;
        latestSpo2 = realSpo2;

        if (realRestingHr != null || realLiveHr != null || realSteps > 0 || realCalories > 0 || realSleepMinutes > 0 || realSpo2 != null || realActiveMinutes > 0) {
          final record = VitalsRecord(
            steps: realSteps > 0 ? realSteps : null,
            caloriesKcal: realCalories > 0 ? realCalories : null,
            totalActiveMinutes: realActiveMinutes > 0 ? realActiveMinutes : null,
            distanceMeters: realDistance > 0 ? realDistance : null,
            restingHeartRate: realRestingHr ?? realLiveHr,
            heartRate: realLiveHr ?? realRestingHr,
            minHeartRate: realMinHr,
            maxHeartRate: realMaxHr,
            heartRateVariability: realHrv,
            oxygenSaturation: realSpo2,
            sleepMinutes: realSleepMinutes > 0 ? realSleepMinutes : null,
            activityName: 'HEALTH_CONNECT_LIVE',
            recordedAt: now.toIso8601String().substring(0, 19),
            date: todayStr,
          );
          _lastFetchTime = now;
          _cachedVitals = record;
          return record;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OpenWearablesService] Live Health Connect query error: $e');
      }
      _lastFetchTime = now;
      return _cachedVitals;
    }

    // If no real records exist yet in Health Connect, return null to avoid displaying mock data
    _lastFetchTime = now;
    _cachedVitals = null;
    isLastSyncReal = false;
    return null;
  }

  void dispose() {
    _syncStatusController.close();
  }
}
