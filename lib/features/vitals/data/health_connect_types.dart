import 'package:health/health.dart';

/// The Health Connect data types this app reads.
///
/// Keep this list and the `android.permission.health.READ_*` entries in
/// AndroidManifest.xml in sync. Requesting a type whose permission is not
/// declared can never be granted, so `hasPermissions` stays false forever and
/// the app would keep re-prompting.
///
/// Mapping (health type -> manifest permission):
///   STEPS -> READ_STEPS
///   HEART_RATE -> READ_HEART_RATE
///   RESTING_HEART_RATE -> READ_RESTING_HEART_RATE
///   HEART_RATE_VARIABILITY_RMSSD -> READ_HEART_RATE_VARIABILITY
///   SLEEP_* -> READ_SLEEP
///   ACTIVE_ENERGY_BURNED -> READ_ACTIVE_CALORIES_BURNED
///   TOTAL_CALORIES_BURNED -> READ_TOTAL_CALORIES_BURNED
///   BASAL_ENERGY_BURNED -> READ_BASAL_METABOLIC_RATE
///   DISTANCE_DELTA -> READ_DISTANCE
///   BLOOD_OXYGEN -> READ_OXYGEN_SATURATION
///   WORKOUT -> READ_EXERCISE
///   HEIGHT -> READ_HEIGHT
///   WEIGHT -> READ_WEIGHT
const List<HealthDataType> kHealthConnectReadTypes = [
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,
  HealthDataType.SLEEP_AWAKE,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.TOTAL_CALORIES_BURNED,
  HealthDataType.BASAL_ENERGY_BURNED,
  HealthDataType.DISTANCE_DELTA,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.WORKOUT,
  HealthDataType.HEIGHT,
  HealthDataType.WEIGHT,
];

/// [kHealthConnectReadTypes] filtered to what this platform supports.
List<HealthDataType> availableHealthConnectTypes(Health health) =>
    kHealthConnectReadTypes.where(health.isDataTypeAvailable).toList();

/// Shows the Health Connect permission screen for all read types, then asks
/// for background read access (needed by the hourly background sync).
/// Must be called from a visible screen, in response to the user's context.
Future<bool> requestHealthConnectPermissions(Health health) async {
  final types = availableHealthConnectTypes(health);
  final granted = await health.requestAuthorization(types);
  try {
    if (await health.isHealthDataInBackgroundAvailable() &&
        !await health.isHealthDataInBackgroundAuthorized()) {
      await health.requestHealthDataInBackgroundAuthorization();
    }
  } catch (_) {
    // Background read is optional: foreground sync still works without it.
  }
  return granted;
}
