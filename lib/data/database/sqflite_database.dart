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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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

    // 3. Table for general app settings (units, language, start week)
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 4. Table for vitals & medication reminders
    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        time TEXT NOT NULL,
        days TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 5. Table for vitals warning thresholds
    await db.execute('''
      CREATE TABLE vitals_thresholds (
        metric TEXT PRIMARY KEY,
        min_value REAL,
        max_value REAL
      )
    ''');

    // 6. Table for scheduled patient appointments (upcoming & history)
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        practitioner_name TEXT NOT NULL,
        practitioner_role TEXT NOT NULL,
        practitioner_image TEXT NOT NULL,
        start_time TEXT NOT NULL,
        type TEXT NOT NULL,
        is_virtual INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 7. Table for in-app notification logs
    await db.execute('''
      CREATE TABLE in_app_notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Index optimizations for lightning-fast queries
    await db.execute('CREATE INDEX idx_metrics_type_time ON health_metrics (type, timestamp DESC)');
    await db.execute('CREATE INDEX idx_route_points_workout ON workout_route_points (workout_id)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE reminders (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          type TEXT NOT NULL,
          time TEXT NOT NULL,
          days TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE vitals_thresholds (
          metric TEXT PRIMARY KEY,
          min_value REAL,
          max_value REAL
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE appointments (
          id TEXT PRIMARY KEY,
          practitioner_name TEXT NOT NULL,
          practitioner_role TEXT NOT NULL,
          practitioner_image TEXT NOT NULL,
          start_time TEXT NOT NULL,
          type TEXT NOT NULL,
          is_virtual INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE in_app_notifications (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          type TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          is_read INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
