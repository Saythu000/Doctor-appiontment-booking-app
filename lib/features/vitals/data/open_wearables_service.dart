import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:phia_flutter/features/vitals/data/health_connect_types.dart';
import 'package:phia_flutter/features/vitals/domain/vitals_payload.dart';

/// Reads wearable data that watch companion apps write to Android Health
/// Connect, and normalises it into a [VitalsRecord].
///
/// There is no cloud wearable integration (Garmin/WHOOP/Oura/Fitbit): those
/// "Link" buttons were simulated and have been removed.
class OpenWearablesService {
  // Singleton pattern
  static final OpenWearablesService _instance = OpenWearablesService._internal();
  factory OpenWearablesService() => _instance;
  OpenWearablesService._internal();

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

      final types = availableHealthConnectTypes(health);

      bool? hasPerm;
      try {
        hasPerm = await health.hasPermissions(types);
      } catch (permError) {
        if (kDebugMode) {
          print('[OpenWearablesService] Health Connect permission check throttled/error: $permError');
        }
      }

      // Never show the permission screen from here: this runs on timers, on
      // app resume and in the background. Permissions are requested once, in
      // context (dashboard / device manager). Without them we simply read
      // whichever types were granted (per-type fallback below).
      if (hasPerm != true) {
        debugPrint('[OpenWearablesService] Not all Health Connect read permissions are granted; reading granted types only.');
      }

      // Query past 48 hours for general activity and sleep
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

      // If BLOOD_OXYGEN was not found in 48h (since smartwatches like boAt measure SpO2 on-demand),
      // query 7 days back to get the latest baseline reading
      final hasSpo2InBatch = dataPoints.any((dp) => dp.type == HealthDataType.BLOOD_OXYGEN);
      if (!hasSpo2InBatch && health.isDataTypeAvailable(HealthDataType.BLOOD_OXYGEN)) {
        try {
          final spo2History = await health.getHealthDataFromTypes(
            types: [HealthDataType.BLOOD_OXYGEN],
            startTime: now.subtract(const Duration(days: 7)),
            endTime: now,
          );
          if (spo2History.isNotEmpty) {
            dataPoints.addAll(spo2History);
          }
        } catch (_) {}
      }

      lastDataPointsCount = dataPoints.length;
      if (kDebugMode) {
        print('[OpenWearablesService] Health Connect queried ${types.length} types, received ${dataPoints.length} data points');
      }

      if (dataPoints.isNotEmpty) {
        final breakdown = <String, int>{};
        for (final dp in dataPoints) {
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
        double? realHeight;
        double? realWeight;
        int realSteps = 0;
        int googleFitSteps = 0;
        int wearableSteps = 0;
        double googleFitDistance = 0.0;
        double wearableDistance = 0.0;
        double realTotalCalories = 0.0;
        double realActiveCalories = 0.0;
        double realBasalCalories = 0.0;
        double realDistance = 0.0;
        int realSleepMinutes = 0;
        int sleepAsleepMinutes = 0;
        int sleepSessionMinutes = 0;
        int realDeepSleepMinutes = 0;
        int realLightSleepMinutes = 0;
        int realRemSleepMinutes = 0;
        int realAwakeMinutes = 0;
        int realWorkoutMinutes = 0;
        int recordedActiveMinutes = 0;
        int googleFitActiveMinutes = 0;
        int wearableActiveMinutes = 0;
        int totalActiveSeconds = 0;
        int googleFitActiveSeconds = 0;
        final minuteStepCounts = <String, int>{};
        final googleFitMinuteStepCounts = <String, int>{};
        final workoutIntervals = <Map<String, dynamic>>[];
        String detectedAppSource = 'Android Health Connect';

        DateTime? latestRestingHrDate;
        DateTime? latestLiveHrDate;

        for (final dp in dataPoints) {
          if (dp.sourceName.isNotEmpty && dp.sourceName != 'unknown') {
            detectedAppSource = dp.sourceName;
          }

          if (dp.type == HealthDataType.RESTING_HEART_RATE) {
            if (dp.value is NumericHealthValue && dp.dateTo.isAfter(todayStart)) {
              final val = (dp.value as NumericHealthValue).numericValue.toInt();
              if (latestRestingHrDate == null || dp.dateTo.isAfter(latestRestingHrDate)) {
                latestRestingHrDate = dp.dateTo;
                realRestingHr = val;
              }
            }
          } else if (dp.type == HealthDataType.HEART_RATE) {
            if (dp.value is NumericHealthValue && dp.dateTo.isAfter(todayStart)) {
              final val = (dp.value as NumericHealthValue).numericValue.toInt();
              if (latestLiveHrDate == null || dp.dateTo.isAfter(latestLiveHrDate)) {
                latestLiveHrDate = dp.dateTo;
                realLiveHr = val;
              }
              if (realMinHr == null || val < realMinHr) realMinHr = val;
              if (realMaxHr == null || val > realMaxHr) realMaxHr = val;
            }
          } else if ((dp.type == HealthDataType.HEART_RATE_VARIABILITY_RMSSD ||
                      dp.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) &&
                     realHrv == null &&
                     dp.dateTo.isAfter(todayStart)) {
            if (dp.value is NumericHealthValue) {
              realHrv = (dp.value as NumericHealthValue).numericValue.toDouble();
            }
          } else if (dp.type == HealthDataType.BLOOD_OXYGEN && realSpo2 == null) {
            if (dp.value is NumericHealthValue) {
              double val = (dp.value as NumericHealthValue).numericValue.toDouble();
              if (val <= 1.0) val = val * 100.0;
              realSpo2 = val;
            }
          } else if (dp.type == HealthDataType.HEIGHT && realHeight == null) {
            if (dp.value is NumericHealthValue) {
              double val = (dp.value as NumericHealthValue).numericValue.toDouble();
              if (val < 3.0) val = val * 100.0; // convert meters to cm
              if (val > 0) realHeight = val;
            }
          } else if (dp.type == HealthDataType.WEIGHT && realWeight == null) {
            if (dp.value is NumericHealthValue) {
              final double val = (dp.value as NumericHealthValue).numericValue.toDouble();
              if (val > 0) realWeight = val;
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
          } else if (dp.type == HealthDataType.DISTANCE_WALKING_RUNNING ||
                     dp.type == HealthDataType.DISTANCE_DELTA) {
            if (dp.value is NumericHealthValue && !dp.dateTo.isBefore(todayStart)) {
              final distVal = (dp.value as NumericHealthValue).numericValue.toDouble();
              final src = dp.sourceName.toLowerCase();
              final isFit = src.contains('fitness') || src.contains('fit') || src.contains('google');
              if (isFit) {
                googleFitDistance += distVal;
              } else {
                wearableDistance += distVal;
              }
              realDistance += distVal;
            }
          } else if (dp.type == HealthDataType.ACTIVITY_INTENSITY || dp.type == HealthDataType.EXERCISE_TIME) {
            if (!dp.dateTo.isBefore(todayStart)) {
              int mins = 0;
              if (dp.value is NumericHealthValue) {
                mins = (dp.value as NumericHealthValue).numericValue.toInt();
              }
              if (mins <= 0) {
                mins = dp.dateTo.difference(dp.dateFrom).inMinutes;
              }
              final isFit = dp.sourceName.toLowerCase().contains('fit') || dp.sourceName.toLowerCase().contains('google');
              if (isFit) {
                googleFitActiveMinutes += mins;
              } else {
                wearableActiveMinutes += mins;
              }
              recordedActiveMinutes += mins;
            }
          } else if (dp.type == HealthDataType.WORKOUT) {
            if (!dp.dateTo.isBefore(todayStart)) {
              final workoutDur = dp.dateTo.difference(dp.dateFrom).inMinutes;
              final isFit = dp.sourceName.toLowerCase().contains('fit') || dp.sourceName.toLowerCase().contains('google');
              if (isFit) {
                googleFitActiveMinutes += workoutDur;
              } else {
                wearableActiveMinutes += workoutDur;
              }
              realWorkoutMinutes += workoutDur;

              final wStart = dp.dateFrom.isBefore(todayStart) ? todayStart : dp.dateFrom;
              final wEnd = dp.dateTo.isAfter(now) ? now : dp.dateTo;
              workoutIntervals.add({
                'start': wStart,
                'end': wEnd,
                'isFit': isFit,
                'source': dp.sourceName,
              });
            }
          } else if (dp.type == HealthDataType.STEPS) {
            if (!dp.dateTo.isBefore(todayStart)) {
              final count = (dp.value is NumericHealthValue)
                  ? (dp.value as NumericHealthValue).numericValue.toInt()
                  : 0;
              final durSec = dp.dateTo.difference(dp.dateFrom).inSeconds;
              final cadence = durSec > 0 ? (count / (durSec / 60.0)) : count.toDouble();
              final isFit = dp.sourceName.toLowerCase().contains('fit') || dp.sourceName.toLowerCase().contains('google');
              if (isFit) {
                googleFitSteps += count;
              } else {
                wearableSteps += count;
              }
              // Google Fit awards 1 Move Minute for each minute with at least 30 steps.
              // Distribute steps across all minute buckets covered by the interval [dp.dateFrom, dp.dateTo]:
              if (durSec > 0) {
                DateTime cur = DateTime(dp.dateFrom.year, dp.dateFrom.month, dp.dateFrom.day, dp.dateFrom.hour, dp.dateFrom.minute);
                final end = dp.dateTo;
                while (!cur.isAfter(end)) {
                  final nextMin = cur.add(const Duration(minutes: 1));
                  final segStart = cur.isBefore(dp.dateFrom) ? dp.dateFrom : cur;
                  final segEnd = nextMin.isAfter(end) ? end : nextMin;
                  final segSec = segEnd.difference(segStart).inSeconds;
                  if (segSec > 0 && !cur.isBefore(todayStart)) {
                    final segSteps = (count * (segSec / durSec)).round();
                    final bucketKey = '${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')} ${cur.hour.toString().padLeft(2, '0')}:${cur.minute.toString().padLeft(2, '0')}';
                    minuteStepCounts[bucketKey] = (minuteStepCounts[bucketKey] ?? 0) + segSteps;
                    if (isFit) {
                      googleFitMinuteStepCounts[bucketKey] = (googleFitMinuteStepCounts[bucketKey] ?? 0) + segSteps;
                    }
                  }
                  cur = nextMin;
                }
              } else if (!dp.dateFrom.isBefore(todayStart)) {
                final bucketKey = '${dp.dateFrom.year}-${dp.dateFrom.month.toString().padLeft(2, '0')}-${dp.dateFrom.day.toString().padLeft(2, '0')} ${dp.dateFrom.hour.toString().padLeft(2, '0')}:${dp.dateFrom.minute.toString().padLeft(2, '0')}';
                minuteStepCounts[bucketKey] = (minuteStepCounts[bucketKey] ?? 0) + count;
                if (isFit) {
                  googleFitMinuteStepCounts[bucketKey] = (googleFitMinuteStepCounts[bucketKey] ?? 0) + count;
                }
              }
              if (cadence >= 30.0) {
                if (isFit) {
                  googleFitActiveSeconds += durSec;
                } else {
                  totalActiveSeconds += durSec;
                }
              }
            }
          } else if (dp.type == HealthDataType.SLEEP_SESSION ||
                     dp.type == HealthDataType.SLEEP_ASLEEP ||
                     dp.type == HealthDataType.SLEEP_LIGHT ||
                     dp.type == HealthDataType.SLEEP_DEEP ||
                     dp.type == HealthDataType.SLEEP_REM ||
                     dp.type == HealthDataType.SLEEP_AWAKE) {
            // Only aggregate sleep ending today or after last night (18:00 yesterday)
            final lastEvening = todayStart.subtract(const Duration(hours: 6));
            if (dp.dateTo.isAfter(lastEvening)) {
              final dur = dp.dateTo.difference(dp.dateFrom).inMinutes;
              if (dp.type == HealthDataType.SLEEP_ASLEEP) {
                sleepAsleepMinutes += dur;
              } else if (dp.type == HealthDataType.SLEEP_LIGHT) {
                realLightSleepMinutes += dur;
              } else if (dp.type == HealthDataType.SLEEP_DEEP) {
                realDeepSleepMinutes += dur;
              } else if (dp.type == HealthDataType.SLEEP_REM) {
                realRemSleepMinutes += dur;
              } else if (dp.type == HealthDataType.SLEEP_AWAKE) {
                realAwakeMinutes += dur;
              } else if (dp.type == HealthDataType.SLEEP_SESSION) {
                sleepSessionMinutes += dur;
              }
            }
          }
        }

        // Calculate true sleep duration (Time Asleep):
        // 1. Sum of distinct sleep stages (Deep + Light + REM) if available
        // 2. Or explicit SLEEP_ASLEEP duration
        // 3. Or SLEEP_SESSION minus Awake time if available
        // 4. Fallback to SLEEP_SESSION if only raw session was recorded
        final totalStagesAsleep = realDeepSleepMinutes + realLightSleepMinutes + realRemSleepMinutes;
        if (totalStagesAsleep > 0) {
          realSleepMinutes = totalStagesAsleep;
        } else if (sleepAsleepMinutes > 0) {
          realSleepMinutes = sleepAsleepMinutes;
        } else if (sleepSessionMinutes > 0) {
          if (realAwakeMinutes > 0 && sleepSessionMinutes > realAwakeMinutes) {
            realSleepMinutes = sleepSessionMinutes - realAwakeMinutes;
          } else {
            realSleepMinutes = sleepSessionMinutes;
          }
        }

        final double realCalories = realTotalCalories > 0
            ? realTotalCalories
            : (realActiveCalories + realBasalCalories);

        if (kDebugMode) {
          print('[OpenWearablesService] Aggregated calories for today calculated');
        }

        realSleepMinutes = realSleepMinutes.clamp(0, 1440);

        // Align steps: If Google Fit data points were recorded today, use Google Fit's exact count
        // to avoid double-counting overlapping wearable (boAt/Alien) intervals!
        if (googleFitSteps > 0) {
          realSteps = googleFitSteps;
        } else if (wearableSteps > 0) {
          realSteps = wearableSteps;
        } else {
          try {
            final midnight = DateTime(now.year, now.month, now.day);
            final stepCount = await health.getTotalStepsInInterval(midnight, now);
            if (stepCount != null && stepCount > 0) {
              realSteps = stepCount;
            }
          } catch (_) {}
        }

        // Align distance: Pure extracted distance directly from Google Fit (or wearable).
        // Zero synthetic formulas or stride estimations.
        if (googleFitDistance > 0) {
          realDistance = googleFitDistance;
        } else if (wearableDistance > 0) {
          realDistance = wearableDistance;
        }

        // Calculate real active minutes directly matching Google Fit's Move Minutes:
        // 1. Primary standard: Google Fit Move Minutes calculated from 1-minute step buckets (>= 30 steps/min).
        //    Google Fit awards exactly 1 Move Minute for every minute with at least 30 steps.
        // 2. Non-step workout sessions (e.g., cycling, rowing, weight training) where steps were not tracked (< 50 steps in interval).
        //    For walking/running workouts, step buckets already accurately reflect active vs paused minutes.
        // 3. Robust fallbacks for sensors/wearables where granular minute step intervals are not exported.
        final fitBuckets = googleFitMinuteStepCounts.isNotEmpty ? googleFitMinuteStepCounts : minuteStepCounts;
        final Set<String> activeMinutesSet = {};

        // Add all minutes meeting Google Fit's Move Minute threshold (>= 30 steps/min)
        fitBuckets.forEach((bucketKey, stepsInMin) {
          if (stepsInMin >= 30) {
            activeMinutesSet.add(bucketKey);
          }
        });

        // Add non-step workout minutes (e.g., stationary bike, yoga) that didn't generate steps
        for (final w in workoutIntervals) {
          final start = w['start'] as DateTime;
          final end = w['end'] as DateTime;
          DateTime cur = DateTime(start.year, start.month, start.day, start.hour, start.minute);
          final sessionKeys = <String>[];
          int stepsInSession = 0;
          while (!cur.isAfter(end)) {
            final key = '${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')} ${cur.hour.toString().padLeft(2, '0')}:${cur.minute.toString().padLeft(2, '0')}';
            sessionKeys.add(key);
            stepsInSession += (fitBuckets[key] ?? 0);
            cur = cur.add(const Duration(minutes: 1));
          }
          // Only add workout minutes if it was a non-step workout (< 50 steps across the whole session).
          // For walking/running workouts, active minutes are already precisely determined by the >= 30 steps rule.
          if (stepsInSession < 50) {
            activeMinutesSet.addAll(sessionKeys);
          }
        }

        // Multi-source reconciliation: ensure low-step workouts (e.g. cycling, swimming, yoga)
        // are never overshadowed by a small bucket count from brief walks.
        final int candidateFromBuckets = activeMinutesSet.length;
        int candidateFromRecorded = recordedActiveMinutes;
        if (googleFitActiveMinutes > candidateFromRecorded) {
          candidateFromRecorded = googleFitActiveMinutes;
        }
        if (wearableActiveMinutes > candidateFromRecorded) {
          candidateFromRecorded = wearableActiveMinutes;
        }
        if (realWorkoutMinutes > candidateFromRecorded) {
          candidateFromRecorded = realWorkoutMinutes;
        }

        int candidateFromSeconds = 0;
        if (googleFitActiveSeconds >= 60) {
          candidateFromSeconds = (googleFitActiveSeconds / 60.0).round();
        } else if (totalActiveSeconds >= 60) {
          candidateFromSeconds = (totalActiveSeconds / 60.0).round();
        }

        final int realActiveMinutes = math.max(
          candidateFromBuckets,
          math.max(candidateFromRecorded, candidateFromSeconds),
        );

        if (kDebugMode) {
          print('[OpenWearablesService] Active minutes for today: $realActiveMinutes (from ${activeMinutesSet.length} Move Min buckets, fitActiveMins=$googleFitActiveMinutes, recActiveMins=$recordedActiveMinutes, workoutMins=$realWorkoutMinutes)');
        }

        lastSyncSource = detectedAppSource;
        isLastSyncReal = true;
        latestSpo2 = realSpo2;

        if (realRestingHr != null || realLiveHr != null || realSteps > 0 || realCalories > 0 || realSleepMinutes > 0 || realSpo2 != null || realActiveMinutes > 0) {
          final record = VitalsRecord(
            steps: realSteps > 0 ? realSteps : null,
            caloriesKcal: realCalories > 0 ? realCalories : null,
            totalActiveMinutes: realActiveMinutes,
            distanceMeters: realDistance,
            restingHeartRate: realRestingHr ?? realLiveHr,
            heartRate: realLiveHr ?? realRestingHr,
            minHeartRate: realMinHr,
            maxHeartRate: realMaxHr,
            heartRateVariability: realHrv,
            oxygenSaturation: realSpo2,
            sleepMinutes: realSleepMinutes > 0 ? realSleepMinutes : null,
            deepSleepMinutes: realDeepSleepMinutes > 0 ? realDeepSleepMinutes : null,
            lightSleepMinutes: realLightSleepMinutes > 0 ? realLightSleepMinutes : null,
            remSleepMinutes: realRemSleepMinutes > 0 ? realRemSleepMinutes : null,
            awakeMinutes: realAwakeMinutes > 0 ? realAwakeMinutes : null,
            weightKg: realWeight,
            heightCm: realHeight,
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
}
