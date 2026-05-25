import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class SqfliteDatabaseHelper {
  static final SqfliteDatabaseHelper instance = SqfliteDatabaseHelper._init();
  static Database? _database;

  SqfliteDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('phia_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Table for flat health metrics (Steps, Heart Rate, HRV)
    await db.execute('''
      CREATE TABLE health_metrics (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        timestamp TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Table for structured workout trail route coordinates
    await db.execute('''
      CREATE TABLE workout_route_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        speed REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Index optimizations for lightning-fast queries
    await db.execute('CREATE INDEX idx_metrics_type_time ON health_metrics (type, timestamp DESC)');
    await db.execute('CREATE INDEX idx_route_points_workout ON workout_route_points (workout_id)');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
