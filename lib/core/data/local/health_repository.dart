import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:phia_flutter/core/data/local/app_database.dart';
import 'package:phia_flutter/core/data/local/secure_storage_service.dart';
import 'package:phia_flutter/features/vitals/data/vitals_repository.dart';
import 'package:phia_flutter/features/vitals/domain/health_metrics.dart';
import 'package:phia_flutter/features/vitals/domain/vitals_payload.dart';
import 'package:sqflite/sqflite.dart';

// ponytail: concrete production repository; eliminated redundant single-implementation IHealthRepository interface
/// Default alert ranges, used until the user saves their own.
/// Single source of truth for both the settings screen and the alert checks.
const Map<String, Map<String, double>> kDefaultVitalsThresholds = {
  'steps': {'min': 0, 'max': 10000},
  'systolic': {'min': 90, 'max': 140},
  'diastolic': {'min': 60, 'max': 90},
  'heart_rate': {'min': 50, 'max': 100},
};

class HealthRepository {
  final AppDatabase _dbHelper = AppDatabase.instance;

  Future<void> saveMetric(HealthMetric metric) async {
    final db = await _dbHelper.database;
    
    final map = {
      'id': metric.id,
      'type': metric.type,
      'value': metric.value,
      'timestamp': metric.timestamp.toIso8601String(),
      'is_synced': metric.isSynced ? 1 : 0,
    };

    await db.insert(
      'health_metrics',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HealthMetric>> getRecentMetrics(String type) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'health_metrics',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'timestamp DESC',
      limit: 100,
    );

    return List.generate(maps.length, (i) {
      return HealthMetric(
        id: maps[i]['id'] as String,
        type: maps[i]['type'] as String,
        value: (maps[i]['value'] as num).toDouble(),
        timestamp: DateTime.parse(maps[i]['timestamp'] as String),
        isSynced: (maps[i]['is_synced'] as int) == 1,
      );
    });
  }

  Future<void> uploadPendingMetrics() async {
    final db = await _dbHelper.database;

    // Fetch all records where is_synced = 0
    final List<Map<String, dynamic>> unsynced = await db.query(
      'health_metrics',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    if (unsynced.isEmpty) {
      return;
    }

    final userId = await getSetting('iam_user_id') ?? '';
    final orgId = await getSetting('iam_org_id') ?? '';

    if (userId.isEmpty || orgId.isEmpty) {
      return; // Cannot sync without credentials
    }

    final vitalsRepository = VitalsRepository();
    final gender = await getProfileValue('gender');

    // Group unsynced metrics by date (YYYY-MM-DD)
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (final row in unsynced) {
      final timestampStr = row['timestamp'] as String;
      final dateStr = timestampStr.substring(0, 10);
      groupedByDate.putIfAbsent(dateStr, () => []).add(row);
    }

    for (final dateStr in groupedByDate.keys) {
      // Query all metrics (synced & unsynced) for this date to get a complete daily summary
      final List<Map<String, dynamic>> dailyMetrics = await db.query(
        'health_metrics',
        where: 'timestamp LIKE ?',
        whereArgs: ['$dateStr%'],
      );

      double? steps;
      double? calories;
      double? distance;
      double? activeMins;
      double? sleep;
      double? deepSleep;
      double? lightSleep;
      double? remSleep;
      double? awakeSleep;
      double? hr;
      double? hrv;
      double? weight;
      double? height;
      double? age;

      for (final m in dailyMetrics) {
        final type = m['type'] as String;
        final value = (m['value'] as num).toDouble();
        if (type == 'steps') {
          steps = value;
        } else if (type == 'calories') {
          calories = value;
        } else if (type == 'distance') {
          distance = value;
        } else if (type == 'active_time') {
          activeMins = value;
        } else if (type == 'sleep') {
          sleep = value;
        } else if (type == 'deep_sleep') {
          deepSleep = value;
        } else if (type == 'light_sleep') {
          lightSleep = value;
        } else if (type == 'rem_sleep') {
          remSleep = value;
        } else if (type == 'awake_sleep') {
          awakeSleep = value;
        } else if (type == 'heart_rate') {
          hr = value;
        } else if (type == 'hrv') {
          hrv = value;
        } else if (type == 'weight') {
          weight = value;
        } else if (type == 'height') {
          height = value;
        } else if (type == 'age') {
          age = value;
        }
      }

      // Fallback for biometrics from overall settings if not logged for this specific day
      if (weight == null) {
        final weightMetric = await getRecentMetrics('weight');
        if (weightMetric.isNotEmpty) weight = weightMetric.first.value;
      }
      if (height == null) {
        final heightMetric = await getRecentMetrics('height');
        if (heightMetric.isNotEmpty) height = heightMetric.first.value;
      }
      if (age == null) {
        final ageMetric = await getRecentMetrics('age');
        if (ageMetric.isNotEmpty) age = ageMetric.first.value;
      }

      // Compile consolidated daily vitals record with genuine sleep metrics (no synthetic multipliers)
      final record = VitalsRecord(
        steps: steps?.toInt(),
        caloriesKcal: calories,
        distanceMeters: (distance != null && distance > 0) ? distance * 1000.0 : null, // Pure recorded distance in meters, zero formulas
        totalActiveMinutes: activeMins?.toInt(),
        restingHeartRate: (hr != null && hr > 0) ? hr.toInt() : null,
        heartRate: (hr != null && hr > 0) ? hr.toInt() : null,
        heartRateVariability: (hrv != null && hrv > 0 && hrv != 45.5) ? hrv : null,
        sleepMinutes: sleep != null ? (sleep * 60).toInt() : null,
        remSleepMinutes: remSleep?.toInt(),
        deepSleepMinutes: deepSleep?.toInt(),
        lightSleepMinutes: lightSleep?.toInt(),
        awakeMinutes: awakeSleep?.toInt(),
        weightKg: weight,
        heightCm: height,
        age: age?.toInt(),
        gender: gender,
        date: dateStr,
      );

      try {
        await vitalsRepository.submitVitals(record, userId: userId, orgId: orgId);

        // Update local status to synced upon success
        await db.update(
          'health_metrics',
          {'is_synced': 1},
          where: 'timestamp LIKE ?',
          whereArgs: ['$dateStr%'],
        );
      } catch (e) {
        if (kDebugMode) {
          print('[HealthRepository] Failed to upload daily metrics sync for $dateStr: $e');
        }
      }
    }
  }

  /// Deletes locally cached readings older than [maxAge]. The server keeps
  /// the history; the device only needs recent data for the dashboard.
  /// Body measurements (weight, height, age) are kept because the latest one
  /// may be old and is still the current value.
  Future<int> pruneOldMetrics({Duration maxAge = const Duration(days: 90)}) async {
    final db = await _dbHelper.database;
    final cutoff = DateTime.now().subtract(maxAge).toIso8601String();
    return db.delete(
      'health_metrics',
      where: "timestamp < ? AND type NOT IN ('weight', 'height', 'age')",
      whereArgs: [cutoff],
    );
  }

  /// Removes recorded GPS workout routes (location data).
  Future<void> clearWorkoutRoutes() async {
    final db = await _dbHelper.database;
    await db.delete('workout_route_points');
  }

  Future<void> clearMetrics() async {
    final db = await _dbHelper.database;
    await db.delete('health_metrics');
  }

  Future<void> clearProfile() async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_profile (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.delete('local_profile');
  }

  Future<void> clearSyntheticHeartRate() async {
    final db = await _dbHelper.database;
    await db.delete(
      'health_metrics',
      where: 'type = ? AND (id LIKE "synthetic_%" OR id LIKE "mock_%")',
      whereArgs: ['heart_rate'],
    );
  }

  Future<void> saveProfileValue(String key, String value) async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_profile (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.insert(
      'local_profile',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getProfileValue(String key) async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_profile (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    final List<Map<String, dynamic>> maps = await db.query(
      'local_profile',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  /// Credentials. These live ONLY in encrypted secure storage, never in the
  /// plaintext SQLite `app_settings` table.
  static const Set<String> secureKeys = {
    'iam_session_token',
    'iam_jwt_token',
    'iam_refresh_token',
    'iam_id_token',
  };

  /// Moves any credentials left in plaintext SQLite by older app versions
  /// into secure storage and deletes the plaintext rows. Safe to call often.
  Future<void> purgeLegacyPlaintextCredentials() async {
    final db = await _dbHelper.database;
    for (final key in secureKeys) {
      final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
      if (rows.isEmpty) continue;
      final legacyVal = (rows.first['value'] as String?) ?? '';
      final secureVal = await SecureStorageService().readSecure(key);
      if ((secureVal == null || secureVal.isEmpty) && legacyVal.isNotEmpty) {
        await SecureStorageService().writeSecure(key, legacyVal);
      }
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    }
  }

  // --- Settings Table Helpers with Secure Storage Routing ---
  Future<String?> getSetting(String key) async {
    final db = await _dbHelper.database;

    if (secureKeys.contains(key)) {
      final secureVal = await SecureStorageService().readSecure(key);
      if (secureVal != null && secureVal.isNotEmpty) {
        return secureVal;
      }
      // One-time migration: older versions also wrote credentials to SQLite
      // in plaintext. Move them into secure storage and delete the row.
      final legacy = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
      if (legacy.isEmpty) return null;
      final legacyVal = (legacy.first['value'] as String?) ?? '';
      if (legacyVal.isNotEmpty) {
        await SecureStorageService().writeSecure(key, legacyVal);
      }
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
      return legacyVal.isEmpty ? null : legacyVal;
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      final val = maps.first['value'] as String;
      if (val.isNotEmpty) {
        return val;
      }
    }
    return null;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await _dbHelper.database;
    if (secureKeys.contains(key)) {
      // Always remove any legacy plaintext copy.
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
      if (value.isEmpty) {
        await SecureStorageService().deleteSecure(key);
      } else {
        await SecureStorageService().writeSecure(key, value);
      }
      return;
    }

    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Reminders CRUD Helpers ---
  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await _dbHelper.database;
    return db.query('reminders', orderBy: 'time ASC');
  }

  Future<void> saveReminder(Map<String, dynamic> reminder) async {
    final db = await _dbHelper.database;
    await db.insert(
      'reminders',
      reminder,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteReminder(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Removes every medication/vitals reminder (used on sign-out).
  Future<void> clearReminders() async {
    final db = await _dbHelper.database;
    await db.delete('reminders');
  }

  /// Removes custom alert thresholds (used on sign-out); defaults apply again.
  Future<void> clearVitalsThresholds() async {
    final db = await _dbHelper.database;
    await db.delete('vitals_thresholds');
  }

  // --- Vitals Thresholds Helpers ---
  Future<Map<String, Map<String, double>>> getVitalsThresholds() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('vitals_thresholds');
    // Start from the defaults so alerts work before the user has ever opened
    // the thresholds screen (the table starts empty). Saved values override.
    final Map<String, Map<String, double>> thresholds = {
      for (final e in kDefaultVitalsThresholds.entries) e.key: Map<String, double>.from(e.value),
    };
    for (final row in maps) {
      final metric = row['metric'] as String;
      thresholds[metric] = {
        'min': (row['min_value'] as num?)?.toDouble() ?? 0.0,
        'max': (row['max_value'] as num?)?.toDouble() ?? 0.0,
      };
    }
    return thresholds;
  }

  Future<void> saveVitalThreshold(String metric, double? minVal, double? maxVal) async {
    final db = await _dbHelper.database;
    await db.insert(
      'vitals_thresholds',
      {
        'metric': metric,
        'min_value': minVal,
        'max_value': maxVal,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Appointments Helpers ---
  Future<List<Map<String, dynamic>>> getAppointments() async {
    final db = await _dbHelper.database;
    return db.query('appointments', orderBy: 'start_time ASC');
  }

  Future<void> saveAppointment(Map<String, dynamic> appt) async {
    final db = await _dbHelper.database;
    await db.insert(
      'appointments',
      appt,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAppointment(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearLocalAppointments() async {
    final db = await _dbHelper.database;
    await db.delete('appointments');
  }

  // --- In-App Notifications Helpers ---
  Future<List<Map<String, dynamic>>> getInAppNotifications() async {
    final db = await _dbHelper.database;
    return db.query('in_app_notifications', orderBy: 'timestamp DESC');
  }

  Future<void> saveInAppNotification(Map<String, dynamic> notification) async {
    final db = await _dbHelper.database;
    await db.insert(
      'in_app_notifications',
      notification,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markNotificationAsRead(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'in_app_notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteInAppNotification(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'in_app_notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllInAppNotifications() async {
    final db = await _dbHelper.database;
    await db.delete('in_app_notifications');
  }
}
