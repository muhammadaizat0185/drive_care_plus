import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'profile_service.dart';

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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE journeys ADD COLUMN status TEXT DEFAULT 'planned'");
      await db.execute("ALTER TABLE journeys ADD COLUMN vehicle_type TEXT");
    }
    if (oldVersion < 3) {
      // Phase 1 additions: multi-vehicle attribution + planned-vs-actual tracking
      await db.execute(
          "ALTER TABLE journeys ADD COLUMN vehicle_id TEXT");
      await db.execute(
          "ALTER TABLE journeys ADD COLUMN transport_mode TEXT");
      await db.execute(
          "ALTER TABLE journeys ADD COLUMN attribution_source TEXT");
      await db.execute(
          "ALTER TABLE journeys ADD COLUMN planned_distance_km REAL");
      await db.execute(
          "ALTER TABLE journeys ADD COLUMN planned_duration_s INTEGER");
    }
    if (oldVersion < 4) {
      // Phase 5: deviation tracking (actual − planned distance)
      await db.execute(
          "ALTER TABLE journeys ADD COLUMN deviation_km REAL");
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE journeys (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time           TEXT NOT NULL,
  end_time             TEXT,
  distance_km          REAL,
  planned_distance_km  REAL,
  planned_duration_s   INTEGER,
  deviation_km         REAL,
  start_address        TEXT,
  destination_address  TEXT,
  status               TEXT DEFAULT 'planned',
  vehicle_type         TEXT,
  vehicle_id           TEXT,
  transport_mode       TEXT,
  attribution_source   TEXT
)
''');

    await db.execute('''
CREATE TABLE journey_points (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  journey_id INTEGER NOT NULL,
  latitude   REAL NOT NULL,
  longitude  REAL NOT NULL,
  timestamp  TEXT NOT NULL,
  FOREIGN KEY (journey_id) REFERENCES journeys (id) ON DELETE CASCADE
)
''');
  }

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /// Starts a new journey row. Optionally stores planned-route metadata so
  /// deviation can be computed when the journey ends.
  Future<int> startJourney({
    String status = 'planned',
    double? plannedDistanceKm,
    int? plannedDurationS,
  }) async {
    final db = await instance.database;
    final id = await db.insert('journeys', {
      'start_time': DateTime.now().toIso8601String(),
      'status': status,
      if (plannedDistanceKm != null) 'planned_distance_km': plannedDistanceKm,
      if (plannedDurationS != null) 'planned_duration_s': plannedDurationS,
    });
    return id;
  }

  /// Appends a GPS coordinate point to a journey.
  Future<void> insertPoint(int journeyId, double lat, double lng) async {
    final db = await instance.database;
    await db.insert('journey_points', {
      'journey_id': journeyId,
      'latitude': lat,
      'longitude': lng,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Closes a journey with its final distance and addresses. If planned metadata
  /// was stored, the deviation (actual − planned) is computed automatically.
  Future<void> endJourney(
    int journeyId,
    double totalDistanceKm,
    String? startAddr,
    String? destAddr,
  ) async {
    final db = await instance.database;

    // Phase 5: compute deviation = actual − planned (null if no plan was set).
    double? deviationKm;
    if (totalDistanceKm > 0) {
      final existing = await db.query(
        'journeys',
        columns: ['planned_distance_km'],
        where: 'id = ?',
        whereArgs: [journeyId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final planned =
            (existing.first['planned_distance_km'] as num?)?.toDouble();
        if (planned != null && planned > 0) {
          deviationKm = totalDistanceKm - planned;
        }
      }
    }

    await db.update(
      'journeys',
      {
        'end_time': DateTime.now().toIso8601String(),
        'distance_km': totalDistanceKm,
        'start_address': startAddr,
        'destination_address': destAddr,
        if (deviationKm != null) 'deviation_km': deviationKm,
      },
      where: 'id = ?',
      whereArgs: [journeyId],
    );
  }

  /// Legacy binary confirmation (my_car / other). Kept for backward-compat
  /// with [PendingJourneyCard] until Phase 2 UX redesign is complete.
  Future<void> updateJourneyStatus(
      int journeyId, String status, String vehicleType) async {
    final db = await instance.database;
    await db.update(
      'journeys',
      {
        'status': status,
        'vehicle_type': vehicleType,
        // When user says 'my_car' via the old card, treat as user_confirmed
        if (vehicleType == 'my_car') 'attribution_source': 'user_confirmed',
        if (vehicleType == 'other') 'transport_mode': 'other',
      },
      where: 'id = ?',
      whereArgs: [journeyId],
    );
  }

  /// Full attribution update (Phase 2+). Replaces the binary
  /// [updateJourneyStatus] with a rich tuple: specific vehicle ID,
  /// transport mode, and attribution source.
  ///
  /// [vehicleId]  — VehicleInsights vehicle list ID, or null if not user's car.
  /// [vehicleType] — 'my_car' | 'other' | 'public_transport' | 'passenger'
  /// [transportMode] — 'driving' | 'bus' | 'rail' | 'ride_hail' | 'other'
  /// [source] — 'user_confirmed' | 'bluetooth_auto' | 'heuristic'
  Future<void> updateJourneyAttribution(
    int journeyId, {
    String? vehicleId,
    String vehicleType = 'my_car',
    String transportMode = 'driving',
    String source = 'user_confirmed',
  }) async {
    final db = await instance.database;
    await db.update(
      'journeys',
      {
        'status': 'confirmed',
        'vehicle_type': vehicleType,
        'vehicle_id': vehicleId,
        'transport_mode': transportMode,
        'attribution_source': source,
      },
      where: 'id = ?',
      whereArgs: [journeyId],
    );
  }

  /// Updates the destination address on an existing journey (used by the
  /// background task after reverse-geocoding the final GPS point).
  Future<void> updateJourneyDestination(
      int journeyId, String? destAddr) async {
    if (destAddr == null) return;
    final db = await instance.database;
    await db.update(
      'journeys',
      {'destination_address': destAddr},
      where: 'id = ?',
      whereArgs: [journeyId],
    );
  }

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /// Returns all journeys ordered newest-first.
  ///
  /// [vehicleId] — if provided, only journeys attributed to that vehicle are
  /// returned. Useful for per-vehicle mileage breakdown.
  ///
  /// Free-plan gate: deletes journeys older than 30 days before returning.
  Future<List<Map<String, dynamic>>> getJourneys({String? vehicleId}) async {
    final db = await instance.database;
    if (!ProfileService.instance.isPro) {
      await db.delete(
        'journeys',
        where: "start_time < datetime('now', '-30 days')",
      );
    }
    if (vehicleId != null) {
      return await db.query(
        'journeys',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'start_time DESC',
      );
    }
    return await db.query('journeys', orderBy: 'start_time DESC');
  }

  /// Returns all GPS points for a specific journey, ordered by timestamp.
  Future<List<Map<String, dynamic>>> getPoints(int journeyId) async {
    final db = await instance.database;
    return await db.query(
      'journey_points',
      where: 'journey_id = ?',
      whereArgs: [journeyId],
      orderBy: 'timestamp ASC',
    );
  }

  /// Returns a daily summary for a given calendar date.
  ///
  /// Returns:
  ///   - [confirmedKm]: sum of distance_km for confirmed-my-car journeys
  ///   - [tripCount]: total journey count for the day
  ///   - [pendingCount]: journeys still in PENDING_CONFIRMATION state
  Future<Map<String, dynamic>> getDailyStats(DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10); // 'YYYY-MM-DD'

    final all = await db.query(
      'journeys',
      where: "date(start_time) = ?",
      whereArgs: [dateStr],
    );

    double confirmedKm = 0.0;
    int pendingCount = 0;

    for (final j in all) {
      final status = j['status'] as String? ?? '';
      final vt = j['vehicle_type'] as String? ?? '';
      if (status == 'confirmed' && vt == 'my_car') {
        confirmedKm += (j['distance_km'] as num?)?.toDouble() ?? 0.0;
      }
      if (status == 'PENDING_CONFIRMATION') pendingCount++;
    }

    return {
      'confirmedKm': confirmedKm,
      'tripCount': all.length,
      'pendingCount': pendingCount,
    };
  }
}
