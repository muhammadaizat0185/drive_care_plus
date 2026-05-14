import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class JourneyDatabase {
  static final JourneyDatabase instance = JourneyDatabase._init();
  static Database? _database;

  JourneyDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('journeys.db');
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
    await db.execute('''
CREATE TABLE journeys (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time TEXT NOT NULL,
  end_time TEXT,
  distance_km REAL,
  start_address TEXT,
  destination_address TEXT
)
''');

    await db.execute('''
CREATE TABLE journey_points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  journey_id INTEGER NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  timestamp TEXT NOT NULL,
  FOREIGN KEY (journey_id) REFERENCES journeys (id) ON DELETE CASCADE
)
''');
  }

  // Insert Journey
  Future<int> startJourney() async {
    final db = await instance.database;
    final id = await db.insert('journeys', {
      'start_time': DateTime.now().toIso8601String(),
    });
    return id;
  }

  // Insert Point
  Future<void> insertPoint(int journeyId, double lat, double lng) async {
    final db = await instance.database;
    await db.insert('journey_points', {
      'journey_id': journeyId,
      'latitude': lat,
      'longitude': lng,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // End Journey
  Future<void> endJourney(int journeyId, double totalDistanceKm, String? startAddr, String? destAddr) async {
    final db = await instance.database;
    await db.update(
      'journeys',
      {
        'end_time': DateTime.now().toIso8601String(),
        'distance_km': totalDistanceKm,
        'start_address': startAddr,
        'destination_address': destAddr,
      },
      where: 'id = ?',
      whereArgs: [journeyId],
    );
  }

  Future<List<Map<String, dynamic>>> getJourneys() async {
    final db = await instance.database;
    return await db.query('journeys', orderBy: 'start_time DESC');
  }

  Future<List<Map<String, dynamic>>> getPoints(int journeyId) async {
    final db = await instance.database;
    return await db.query('journey_points', where: 'journey_id = ?', whereArgs: [journeyId], orderBy: 'timestamp ASC');
  }
}
