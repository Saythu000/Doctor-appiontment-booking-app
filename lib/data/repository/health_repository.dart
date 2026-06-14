import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/model/health_metrics.dart';
import '../../domain/repository/i_health_repository.dart';
import '../database/sqflite_database.dart';
import 'vitals_repository.dart';
import '../../domain/model/vitals_payload.dart';

class HealthRepository implements IHealthRepository {
  final SqfliteDatabaseHelper _dbHelper = SqfliteDatabaseHelper.instance;

  @override
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

  @override
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

  @override
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
    for (var row in unsynced) {
      final timestampStr = row['timestamp'] as String;
      final dateStr = timestampStr.substring(0, 10);
      groupedByDate.putIfAbsent(dateStr, () => []).add(row);
    }

    for (var dateStr in groupedByDate.keys) {
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
      double? hr;
      double? hrv;
      double? weight;
      double? height;
      double? age;

      for (var m in dailyMetrics) {
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

      // Compile consolidated daily vitals record
      final record = VitalsRecord(
        steps: steps?.toInt(),
        caloriesKcal: calories,
        distanceMeters: distance != null ? distance * 1000.0 : (steps != null ? steps * 0.8 : null), // SQLite stores KM, API expects Meters
        totalActiveMinutes: activeMins?.toInt(),
        restingHeartRate: hr?.toInt() ?? 72,
        heartRate: hr?.toInt() ?? 72,
        heartRateVariability: hrv ?? 45.5,
        sleepMinutes: sleep != null ? (sleep * 60).toInt() : null,
        remSleepMinutes: sleep != null ? (sleep * 60 * 0.1875).toInt() : null,
        deepSleepMinutes: sleep != null ? (sleep * 60 * 0.125).toInt() : null,
        lightSleepMinutes: sleep != null ? (sleep * 60 * 0.5208).toInt() : null,
        awakeMinutes: sleep != null ? (sleep * 60 * 0.0417).toInt() : null,
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

  // --- GPS Workout Route Helper Queries ---

  Future<void> saveRoutePoint({
    required String workoutId,
    required double latitude,
    required double longitude,
    required double speed,
  }) async {
    final db = await _dbHelper.database;

    final map = {
      'workout_id': workoutId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await db.insert(
      'workout_route_points',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getRoutePoints(String workoutId) async {
    final db = await _dbHelper.database;

    return await db.query(
      'workout_route_points',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'timestamp ASC',
    );
  }

  @override
  Future<void> clearMetrics() async {
    final db = await _dbHelper.database;
    await db.delete('health_metrics');
    await db.delete('workout_route_points');
  }

  @override
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

  @override
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

  // --- Settings Table Helpers ---
  Future<String?> getSetting(String key) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Reminders CRUD Helpers ---
  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await _dbHelper.database;
    return await db.query('reminders', orderBy: 'time ASC');
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

  // --- Vitals Thresholds Helpers ---
  Future<Map<String, Map<String, double>>> getVitalsThresholds() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('vitals_thresholds');
    final Map<String, Map<String, double>> thresholds = {};
    for (var row in maps) {
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
    return await db.query('appointments', orderBy: 'start_time ASC');
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
    return await db.query('in_app_notifications', orderBy: 'timestamp DESC');
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
