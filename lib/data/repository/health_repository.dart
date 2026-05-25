import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../domain/model/health_metrics.dart';
import '../../domain/repository/i_health_repository.dart';
import '../database/sqflite_database.dart';

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

    // Simulate batch uploading of payloads (Phase 7 API binding point)
    for (var row in unsynced) {
      // Mock upload progress
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Update is_synced to 1 in local database upon success
      await db.update(
        'health_metrics',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
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
}
