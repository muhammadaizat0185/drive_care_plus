import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_tracker_service.dart';

class VehicleInsights extends ChangeNotifier {
  // Singleton instance
  static final VehicleInsights instance = VehicleInsights._internal();

  VehicleInsights._internal();

  String _model = '';
  String _plate = '';
  String _fuelType = 'Petrol';
  String _engine = '';
  String _transmission = '';
  double _fuelCapacityLiters = 0.0;
  double _recommendedTyrePressurePsi = 0.0;
  double _engineOilCapacityLiters = 0.0;

  double _currentMileageKm = 0.0;
  final double _nextServiceMileageKm = 40000;
  final double _averageDailyDistanceKm = 50;
  double _recentTripDistanceKm = 0.0;
  double _recentTripFuelCostRm = 0.0;
  String _carType = 'sedan';
  String _carColor = '#3B82F6'; // Default Blue

  // Maintenance & History
  Map<String, Map<String, dynamic>> _maintenanceData = {};
  List<Map<String, dynamic>> _mileageHistory = [];

  // Bookings, documents and multiple vehicles lists
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _vehicles = [];
  int _activeVehicleIndex = 0;

  // Getters
  String get model => _model.isEmpty ? 'No Active Vehicle' : _model;
  String get plate => _plate.isEmpty ? 'N/A' : _plate;
  String get fuelType => _fuelType;
  String get engine => _engine;
  String get transmission => _transmission;
  double get fuelCapacityLiters => _fuelCapacityLiters;
  double get recommendedTyrePressurePsi => _recommendedTyrePressurePsi;
  double get engineOilCapacityLiters => _engineOilCapacityLiters;
  double get currentMileageKm => _currentMileageKm;
  double get nextServiceMileageKm => _nextServiceMileageKm;
  double get averageDailyDistanceKm => _averageDailyDistanceKm;
  double get recentTripDistanceKm => _recentTripDistanceKm;
  double get recentTripFuelCostRm => _recentTripFuelCostRm;
  String get carType => _carType;
  String get carColor => _carColor;
  Map<String, Map<String, dynamic>> get maintenanceData => _maintenanceData;
  List<Map<String, dynamic>> get mileageHistory => _mileageHistory;

  List<Map<String, dynamic>> get bookings => _bookings;
  List<Map<String, dynamic>> get documents => _documents;
  List<Map<String, dynamic>> get vehicles => _vehicles;
  int get activeVehicleIndex => _activeVehicleIndex;

  // Active bookings list alias for Cockpit tab compatibility
  List<Map<String, dynamic>> get activeBookings => _bookings;

  List<MaintenanceItem> get watchlistItems {
    return [
      _createItem('Engine Oil', 10000),
      _createItem('Brake Pads', 40000),
      _createItem('Tyres', 50000),
      _createItem('Battery', 60000),
    ]..sort((a, b) => a.remainingKm.compareTo(b.remainingKm));
  }

  MaintenanceItem _createItem(String name, double interval) {
    // If no data exists, we use a fixed starting point (e.g., 0 or a large offset from current)
    // to ensure health changes as current mileage increases.
    final data = _maintenanceData[name] ?? {
      'mileage': 0.0, // Assume new/fresh if never logged
      'date': DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
    };
    
    return MaintenanceItem(
      name: name,
      currentMileage: _currentMileageKm,
      lastServiceMileage: (data['mileage'] as num).toDouble(),
      lastServiceDate: DateTime.parse(data['date'] as String),
      interval: interval,
    );
  }

  /// Average km driven on days the user actually drove (ignores zero-driving days).
  /// Uses a rolling 30-entry window from [_mileageHistory].
  /// Each history entry is expected to carry an 'addedKm' field (added by
  /// [updateCurrentMileage] and [updateCurrentMileageForVehicle]).
  double get averageKmPerDay {
    if (_mileageHistory.isEmpty) return 50.0;

    // Count unique calendar days that have at least 1 km of confirmed driving.
    final Map<String, double> kmPerDay = {};
    for (final entry in _mileageHistory) {
      final added = (entry['addedKm'] as num?)?.toDouble() ?? 0.0;
      if (added <= 0) continue;
      final ts = DateTime.tryParse(entry['timestamp']?.toString() ?? '');
      if (ts == null) continue;
      final dayKey = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
      kmPerDay[dayKey] = (kmPerDay[dayKey] ?? 0.0) + added;
    }

    if (kmPerDay.isEmpty) return 50.0;
    final totalKm = kmPerDay.values.fold(0.0, (sum, km) => sum + km);
    return totalKm / kmPerDay.length;
  }

  // Compatibility aliases for customized vehicle health gauges
  double get kmUntilServiceInstance => kmUntilService;
  int get predictedServiceDueDaysInstance => predictedServiceDueDays;

  double get kmUntilService {
    final items = watchlistItems;
    if (items.isEmpty) return 10000.0;
    // Return the lowest remaining distance among all monitored components
    return items.map((e) => e.remainingKm).reduce((a, b) => a < b ? a : b).clamp(0.0, double.infinity);
  }

  int get predictedServiceDueDays {
    final dailyAvg = averageKmPerDay;
    if (dailyAvg <= 0) return 30;
    return (kmUntilService / dailyAvg).ceil().clamp(0, 365);
  }

  double get recentTripCostPerKm {
    if (_recentTripDistanceKm <= 0) return 0;
    return _recentTripFuelCostRm / _recentTripDistanceKm;
  }

  Future<void> updateVehicle({
    required String model,
    required String plate,
    required String fuelType,
    required double currentMileageKm,
    String? engine,
    String? transmission,
    double? fuelCapacityLiters,
    double? recommendedTyrePressurePsi,
    double? engineOilCapacityLiters,
    String? carType,
    String? carColor,
  }) async {
    _model = model;
    _plate = plate;
    _fuelType = fuelType;
    _currentMileageKm = currentMileageKm;
    if (engine != null) _engine = engine;
    if (transmission != null) _transmission = transmission;
    if (fuelCapacityLiters != null) _fuelCapacityLiters = fuelCapacityLiters;
    if (recommendedTyrePressurePsi != null) _recommendedTyrePressurePsi = recommendedTyrePressurePsi;
    if (engineOilCapacityLiters != null) _engineOilCapacityLiters = engineOilCapacityLiters;
    if (carType != null) _carType = carType;
    if (carColor != null) _carColor = carColor;

    // Update inside _vehicles list
    if (_vehicles.isNotEmpty && _activeVehicleIndex >= 0 && _activeVehicleIndex < _vehicles.length) {
      _vehicles[_activeVehicleIndex]['model'] = _model;
      _vehicles[_activeVehicleIndex]['plate'] = _plate;
      _vehicles[_activeVehicleIndex]['fuelType'] = _fuelType;
      _vehicles[_activeVehicleIndex]['currentMileageKm'] = _currentMileageKm;
      _vehicles[_activeVehicleIndex]['engine'] = _engine;
      _vehicles[_activeVehicleIndex]['transmission'] = _transmission;
      _vehicles[_activeVehicleIndex]['fuelCapacityLiters'] = _fuelCapacityLiters;
      _vehicles[_activeVehicleIndex]['recommendedTyrePressurePsi'] = _recommendedTyrePressurePsi;
      _vehicles[_activeVehicleIndex]['engineOilCapacityLiters'] = _engineOilCapacityLiters;
      _vehicles[_activeVehicleIndex]['carType'] = _carType;
      _vehicles[_activeVehicleIndex]['carColor'] = _carColor;
      _vehicles[_activeVehicleIndex]['maintenanceData'] = _maintenanceData;
      _vehicles[_activeVehicleIndex]['mileageHistory'] = _mileageHistory;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vehicle_model', model);
      await prefs.setString('vehicle_plate', plate);
      await prefs.setString('vehicle_fuelType', fuelType);
      await prefs.setDouble('vehicle_currentMileageKm', currentMileageKm);
      await prefs.setString('vehicle_engine', _engine);
      await prefs.setString('vehicle_transmission', _transmission);
      await prefs.setDouble('vehicle_fuelCapacityLiters', _fuelCapacityLiters);
      await prefs.setDouble('vehicle_recommendedTyrePressurePsi', _recommendedTyrePressurePsi);
      await prefs.setDouble('vehicle_engineOilCapacityLiters', _engineOilCapacityLiters);
      await prefs.setString('vehicle_carType', _carType);
      await prefs.setString('vehicle_carColor', _carColor);
      await _saveVehiclesToPrefs();
    } catch (e) {
      debugPrint('SharedPreferences save error: $e');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _vehicles.isNotEmpty && _activeVehicleIndex >= 0 && _activeVehicleIndex < _vehicles.length) {
      final Map<String, dynamic> activeVehicle = _vehicles[_activeVehicleIndex];
      String docId = activeVehicle['id'] ?? '';
      if (docId.isEmpty) {
        docId = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('vehicles').doc().id;
        activeVehicle['id'] = docId;
      }
      try {
        ApiTracker.instance.trackCall('Cloud Firestore');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicles')
            .doc(docId)
            .set(activeVehicle);
      } catch (e) {
        debugPrint('Error updating vehicle in Firestore: $e');
      }
    }
  }

  Future<void> updateCurrentMileage(double mileage) async {
    if (mileage < _currentMileageKm) return; // Prevent reversing odometer
    final added = mileage - _currentMileageKm;
    _currentMileageKm = mileage;
    _mileageHistory.add({
      'mileage': mileage,
      'addedKm': added,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Keep only last 30 entries to save space/pref size
    if (_mileageHistory.length > 30) _mileageHistory.removeAt(0);

    notifyListeners();
    await updateVehicle(
      model: _model,
      plate: _plate,
      fuelType: _fuelType,
      currentMileageKm: _currentMileageKm,
    );
  }

  /// Increments the odometer of a specific registered vehicle by [additionalKm].
  ///
  /// Called by [LocationTaskHandler.onDestroy] after a confirmed-my-car journey
  /// ends. If [vehicleId] matches the active vehicle, the in-memory state is
  /// also updated so the dashboard reflects the change immediately.
  Future<void> updateCurrentMileageForVehicle({
    required String vehicleId,
    required double additionalKm,
  }) async {
    if (additionalKm <= 0) return;

    final idx = _vehicles.indexWhere((v) => v['id']?.toString() == vehicleId);
    if (idx == -1) {
      debugPrint('updateCurrentMileageForVehicle: vehicle $vehicleId not found');
      return;
    }

    final current =
        (_vehicles[idx]['currentMileageKm'] as num?)?.toDouble() ?? 0.0;
    final updated = current + additionalKm;

    // Patch the in-memory vehicle map
    _vehicles[idx] = Map<String, dynamic>.from(_vehicles[idx])
      ..['currentMileageKm'] = updated;

    // Keep mileage history on the vehicle entry itself
    final history = List<Map<String, dynamic>>.from(
        _vehicles[idx]['mileageHistory'] as List? ?? []);
    history.add({
      'mileage': updated,
      'addedKm': additionalKm,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (history.length > 30) history.removeAt(0);
    _vehicles[idx]['mileageHistory'] = history;

    // If this is the active vehicle, sync in-memory scalar fields too
    if (idx == _activeVehicleIndex) {
      _currentMileageKm = updated;
      _mileageHistory = history;
    }

    notifyListeners();

    // Persist locally
    await _saveVehiclesToPrefs();
    if (idx == _activeVehicleIndex) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('vehicle_currentMileageKm', updated);
      } catch (e) {
        debugPrint('SharedPreferences mileage update error: $e');
      }
    }

    // Persist to Firestore
    final user = FirebaseAuth.instance.currentUser;
    final docId = _vehicles[idx]['id']?.toString() ?? '';
    if (user != null && docId.isNotEmpty) {
      try {
        ApiTracker.instance.trackCall('Cloud Firestore');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicles')
            .doc(docId)
            .update({
          'currentMileageKm': updated,
          'mileageHistory': history,
        });
      } catch (e) {
        debugPrint('Firestore mileage update error: $e');
      }
    }
  }

  Future<void> logMaintenance(List<String> itemNames, double mileage) async {
    final now = DateTime.now().toIso8601String();
    for (final name in itemNames) {
      _maintenanceData[name] = {
        'mileage': mileage,
        'date': now,
      };
    }
    
    notifyListeners();
    await updateVehicle(
      model: _model,
      plate: _plate,
      fuelType: _fuelType,
      currentMileageKm: _currentMileageKm,
    );
    
    // TODO: Implement Atomic Firestore Sync here if cloud is enabled
  }

  Future<void> updateRecentTrip({
    required double distanceKm,
    required double fuelCostRm,
  }) async {
    _recentTripDistanceKm = distanceKm;
    _recentTripFuelCostRm = fuelCostRm;
    _currentMileageKm += distanceKm; // update local mileage too
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('vehicle_recentTripDistanceKm', distanceKm);
      await prefs.setDouble('vehicle_recentTripFuelCostRm', fuelCostRm);
      await prefs.setDouble('vehicle_currentMileageKm', _currentMileageKm);
    } catch (e) {
      debugPrint('SharedPreferences save error: $e');
    }
  }

  // Bookings setters
  Future<void> addBooking(Map<String, dynamic> booking) async {
    _bookings.insert(0, booking);
    notifyListeners();
    await _saveBookingsToPrefs();
  }

  Future<void> updateBooking(String bookingId, Map<String, dynamic> updates) async {
    final int index = _bookings.indexWhere((b) => b['id'] == bookingId || b['workshopId'] == bookingId);
    if (index != -1) {
      _bookings[index] = <String, dynamic>{
        ..._bookings[index],
        ...updates,
      };
      notifyListeners();
      await _saveBookingsToPrefs();
    }
  }

  Future<void> _saveBookingsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _bookings.map((b) => jsonEncode(b)).toList();
      await prefs.setStringList('vehicle_bookings', jsonList);
    } catch (e) {
      debugPrint('SharedPreferences save bookings error: $e');
    }
  }

  // Documents setters
  Future<void> addDocument(Map<String, dynamic> doc) async {
    _documents.insert(0, doc);
    notifyListeners();
    await _saveDocumentsToPrefs();
  }

  Future<void> _saveDocumentsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _documents.map((d) => jsonEncode(d)).toList();
      await prefs.setStringList('vehicle_documents', jsonList);
    } catch (e) {
      debugPrint('SharedPreferences save documents error: $e');
    }
  }

  // Document Edit & Delete CRUD
  Future<void> updateDocument(int index, Map<String, dynamic> updatedDoc) async {
    if (index < 0 || index >= _documents.length) return;
    _documents[index] = updatedDoc;
    notifyListeners();
    await _saveDocumentsToPrefs();
  }

  Future<void> deleteDocument(int index) async {
    if (index < 0 || index >= _documents.length) return;
    _documents.removeAt(index);
    notifyListeners();
    await _saveDocumentsToPrefs();
  }

  // Multi-Vehicle CRUD & State Switcher
  Future<void> addVehicle(Map<String, dynamic> vehicle) async {
    final user = FirebaseAuth.instance.currentUser;
    String docId = vehicle['id'] ?? '';
    if (docId.isEmpty) {
      if (user != null) {
        docId = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('vehicles').doc().id;
      } else {
        docId = DateTime.now().millisecondsSinceEpoch.toString();
      }
      final Map<String, dynamic> mutableVehicle = Map<String, dynamic>.from(vehicle);
      mutableVehicle['id'] = docId;
      vehicle = mutableVehicle;
    }

    _vehicles.add(vehicle);
    if (_vehicles.length == 1) {
      _activeVehicleIndex = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('vehicle_active_index', 0);
      _model = vehicle['model'] ?? '';
      _plate = vehicle['plate'] ?? '';
      _fuelType = vehicle['fuelType'] ?? 'Petrol';
      _engine = vehicle['engine'] ?? '';
      _transmission = vehicle['transmission'] ?? '';
      _fuelCapacityLiters = (vehicle['fuelCapacityLiters'] as num?)?.toDouble() ?? 0.0;
      _recommendedTyrePressurePsi = (vehicle['recommendedTyrePressurePsi'] as num?)?.toDouble() ?? 0.0;
      _engineOilCapacityLiters = (vehicle['engineOilCapacityLiters'] as num?)?.toDouble() ?? 0.0;
      _currentMileageKm = (vehicle['currentMileageKm'] as num?)?.toDouble() ?? 0.0;
      _carType = vehicle['carType'] ?? 'sedan';
      _carColor = vehicle['carColor'] ?? '#3B82F6';
      _maintenanceData = Map<String, Map<String, dynamic>>.from(vehicle['maintenanceData'] ?? {});
      _mileageHistory = List<Map<String, dynamic>>.from(vehicle['mileageHistory'] ?? []);
      
      await prefs.setString('vehicle_model', _model);
      await prefs.setString('vehicle_plate', _plate);
      await prefs.setString('vehicle_fuelType', _fuelType);
      await prefs.setDouble('vehicle_currentMileageKm', _currentMileageKm);
      await prefs.setString('vehicle_engine', _engine);
      await prefs.setString('vehicle_transmission', _transmission);
      await prefs.setDouble('vehicle_fuelCapacityLiters', _fuelCapacityLiters);
      await prefs.setDouble('vehicle_recommendedTyrePressurePsi', _recommendedTyrePressurePsi);
      await prefs.setDouble('vehicle_engineOilCapacityLiters', _engineOilCapacityLiters);
      await prefs.setString('vehicle_carType', _carType);
      await prefs.setString('vehicle_carColor', _carColor);
    }
    
    notifyListeners();
    await _saveVehiclesToPrefs();

    if (user != null) {
      try {
        ApiTracker.instance.trackCall('Cloud Firestore');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicles')
            .doc(docId)
            .set(vehicle);
      } catch (e) {
        debugPrint('Error writing vehicle to Firestore: $e');
      }
    }
  }

  Future<void> deleteVehicle(int index) async {
    if (index < 0 || index >= _vehicles.length) return;
    final deletedVehicle = _vehicles[index];

    if (_vehicles.length <= 1) {
      _vehicles.removeAt(index);
      _activeVehicleIndex = 0;
      _model = '';
      _plate = '';
      _fuelType = 'Petrol';
      _engine = '';
      _transmission = '';
      _fuelCapacityLiters = 0.0;
      _recommendedTyrePressurePsi = 0.0;
      _engineOilCapacityLiters = 0.0;
      _currentMileageKm = 0.0;
      _carType = 'sedan';
      _carColor = '#3B82F6';
      _maintenanceData = {};
      _mileageHistory = [];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('vehicle_active_index', 0);
      await prefs.remove('vehicle_model');
      await prefs.remove('vehicle_plate');
      await prefs.remove('vehicle_fuelType');
      await prefs.remove('vehicle_currentMileageKm');
      await prefs.remove('vehicle_engine');
      await prefs.remove('vehicle_transmission');
      await prefs.remove('vehicle_fuelCapacityLiters');
      await prefs.remove('vehicle_recommendedTyrePressurePsi');
      await prefs.remove('vehicle_engineOilCapacityLiters');
      await prefs.remove('vehicle_carType');
      await prefs.remove('vehicle_carColor');
      
      await _saveVehiclesToPrefs();
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;
      final String docId = deletedVehicle['id'] ?? '';
      if (user != null && docId.isNotEmpty) {
        try {
          ApiTracker.instance.trackCall('Cloud Firestore');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('vehicles')
              .doc(docId)
              .delete();
        } catch (e) {
          debugPrint('Error deleting vehicle from Firestore: $e');
        }
      }
      return;
    }
    
    _vehicles.removeAt(index);
    if (_activeVehicleIndex >= _vehicles.length) {
      _activeVehicleIndex = _vehicles.length - 1;
    }
    await setActiveVehicle(_activeVehicleIndex);
    await _saveVehiclesToPrefs();

    final user = FirebaseAuth.instance.currentUser;
    final String docId = deletedVehicle['id'] ?? '';
    if (user != null && docId.isNotEmpty) {
      try {
        ApiTracker.instance.trackCall('Cloud Firestore');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicles')
            .doc(docId)
            .delete();
      } catch (e) {
        debugPrint('Error deleting vehicle from Firestore: $e');
      }
    }
  }

  Future<void> setActiveVehicle(int index) async {
    if (index < 0 || index >= _vehicles.length) return;
    _activeVehicleIndex = index;
    final v = _vehicles[index];
    _model = v['model'] ?? '';
    _plate = v['plate'] ?? '';
    _fuelType = v['fuelType'] ?? 'Petrol';
    _engine = v['engine'] ?? '';
    _transmission = v['transmission'] ?? '';
    _fuelCapacityLiters = (v['fuelCapacityLiters'] as num?)?.toDouble() ?? 0.0;
    _recommendedTyrePressurePsi = (v['recommendedTyrePressurePsi'] as num?)?.toDouble() ?? 0.0;
    _engineOilCapacityLiters = (v['engineOilCapacityLiters'] as num?)?.toDouble() ?? 0.0;
    _currentMileageKm = (v['currentMileageKm'] as num?)?.toDouble() ?? 0.0;
    _carType = v['carType'] ?? 'sedan';
    _carColor = v['carColor'] ?? '#3B82F6';
    _maintenanceData = Map<String, Map<String, dynamic>>.from(v['maintenanceData'] ?? {});
    _mileageHistory = List<Map<String, dynamic>>.from(v['mileageHistory'] ?? []);
    
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('vehicle_active_index', index);
    } catch (_) {}
  }

  Future<void> _saveVehiclesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _vehicles.map((v) => jsonEncode(v)).toList();
      await prefs.setStringList('vehicle_list', jsonList);
    } catch (e) {
      debugPrint('SharedPreferences save vehicles error: $e');
    }
  }

  // Local caching load
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _model = prefs.getString('vehicle_model') ?? '';
      _plate = prefs.getString('vehicle_plate') ?? '';
      _fuelType = prefs.getString('vehicle_fuelType') ?? 'Petrol';
      _currentMileageKm = prefs.getDouble('vehicle_currentMileageKm') ?? 0.0;
      _recentTripDistanceKm = prefs.getDouble('vehicle_recentTripDistanceKm') ?? 0.0;
      _recentTripFuelCostRm = prefs.getDouble('vehicle_recentTripFuelCostRm') ?? 0.0;
      _engine = prefs.getString('vehicle_engine') ?? '';
      _transmission = prefs.getString('vehicle_transmission') ?? '';
      _fuelCapacityLiters = prefs.getDouble('vehicle_fuelCapacityLiters') ?? 0.0;
      _recommendedTyrePressurePsi = prefs.getDouble('vehicle_recommendedTyrePressurePsi') ?? 0.0;
      _engineOilCapacityLiters = prefs.getDouble('vehicle_engineOilCapacityLiters') ?? 0.0;
      _carType = prefs.getString('vehicle_carType') ?? 'sedan';
      _carColor = prefs.getString('vehicle_carColor') ?? '#3B82F6';

      // Load bookings
      final bookingsJsonList = prefs.getStringList('vehicle_bookings');
      if (bookingsJsonList != null) {
        _bookings = bookingsJsonList.map((str) => Map<String, dynamic>.from(jsonDecode(str))).toList();
      } else {
        _bookings = [];
        await _saveBookingsToPrefs();
      }

      // Load documents
      final docsJsonList = prefs.getStringList('vehicle_documents');
      if (docsJsonList != null) {
        _documents = docsJsonList.map((str) => Map<String, dynamic>.from(jsonDecode(str))).toList();
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          // Seed some sample documents ONLY for guests
          _documents = [
            {
              'title': 'Insurance Policy Cover Note',
              'category': 'Insurance',
              'note': 'Renewed via Etiqa Takaful',
              'expiryDate': '18/12/2026',
            },
            {
              'title': '30,000 km Oil Service Invoice',
              'category': 'Receipt',
              'note': 'Fully Synthetic Engine Oil change',
              'expiryDate': '',
            }
          ];
          await _saveDocumentsToPrefs();
        } else {
          _documents = [];
        }
      }

      // Load vehicles list
      final vehiclesJsonList = prefs.getStringList('vehicle_list');
      if (vehiclesJsonList != null) {
        _vehicles = vehiclesJsonList.map((str) => Map<String, dynamic>.from(jsonDecode(str))).toList();
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          // Seed default vehicle ONLY for guests
          _vehicles = [
            {
              'model': 'Perodua Axia',
              'plate': 'ABC 1234',
              'fuelType': 'Petrol',
              'engine': '1.0L VVT-i (1KR-VE)',
              'transmission': '4-Speed Automatic',
              'fuelCapacityLiters': 36.0,
              'recommendedTyrePressurePsi': 36.0,
              'engineOilCapacityLiters': 3.0,
              'currentMileageKm': 38200.0,
              'maintenanceData': <String, Map<String, dynamic>>{},
              'mileageHistory': <Map<String, dynamic>>[],
            }
          ];
          await _saveVehiclesToPrefs();
        } else {
          _vehicles = [];
        }
      }
      _activeVehicleIndex = prefs.getInt('vehicle_active_index') ?? 0;
      if (_activeVehicleIndex >= _vehicles.length) {
        _activeVehicleIndex = 0;
      }
      
      // Load selected vehicle properties
      if (_vehicles.isNotEmpty) {
        final v = _vehicles[_activeVehicleIndex];
        _model = v['model'] ?? '';
        _plate = v['plate'] ?? '';
        _fuelType = v['fuelType'] ?? 'Petrol';
        _engine = v['engine'] ?? '';
        _transmission = v['transmission'] ?? '';
        _fuelCapacityLiters = (v['fuelCapacityLiters'] as num?)?.toDouble() ?? 0.0;
        _recommendedTyrePressurePsi = (v['recommendedTyrePressurePsi'] as num?)?.toDouble() ?? 0.0;
        _engineOilCapacityLiters = (v['engineOilCapacityLiters'] as num?)?.toDouble() ?? 0.0;
        _currentMileageKm = (v['currentMileageKm'] as num?)?.toDouble() ?? 0.0;
        _carType = v['carType'] ?? 'sedan';
        _carColor = v['carColor'] ?? '#3B82F6';
        
        if (v['maintenanceData'] != null) {
          _maintenanceData = (v['maintenanceData'] as Map).map(
            (key, value) => MapEntry(key.toString(), Map<String, dynamic>.from(value as Map))
          );
        } else {
          _maintenanceData = {};
        }
        
        if (v['mileageHistory'] != null) {
          _mileageHistory = List<Map<String, dynamic>>.from(v['mileageHistory']);
        } else {
          _mileageHistory = [];
        }
      } else {
        _model = '';
        _plate = '';
        _fuelType = 'Petrol';
        _engine = '';
        _transmission = '';
        _fuelCapacityLiters = 0.0;
        _recommendedTyrePressurePsi = 0.0;
        _engineOilCapacityLiters = 0.0;
        _currentMileageKm = 0.0;
        _carType = 'sedan';
        _carColor = '#3B82F6';
        _maintenanceData = {};
        _mileageHistory = [];
      }
    } catch (e) {
      debugPrint('SharedPreferences load error: $e');
    }
    notifyListeners();
  }

  Future<void> clear() async {
    _model = '';
    _plate = '';
    _fuelType = 'Petrol';
    _engine = '';
    _transmission = '';
    _fuelCapacityLiters = 0.0;
    _recommendedTyrePressurePsi = 0.0;
    _engineOilCapacityLiters = 0.0;

    _currentMileageKm = 0.0;
    _recentTripDistanceKm = 0.0;
    _recentTripFuelCostRm = 0.0;
    _carType = 'sedan';
    _carColor = '#3B82F6';

    _maintenanceData = {};
    _mileageHistory = [];
    _bookings = [];
    _documents = [];
    _vehicles = [];
    _activeVehicleIndex = 0;

    notifyListeners();
  }

  Future<void> syncFromFirestore(String uid) async {
    try {
      // 1. Sync vehicles
      ApiTracker.instance.trackCall('Cloud Firestore');
      final vehiclesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('vehicles')
          .get();

      final List<Map<String, dynamic>> remoteVehicles = vehiclesSnap.docs
          .map((doc) => Map<String, dynamic>.from(doc.data()))
          .toList();

      // 2. Sync documents
      ApiTracker.instance.trackCall('Cloud Firestore');
      final docsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('documents')
          .get();

      final List<Map<String, dynamic>> remoteDocs = docsSnap.docs
          .map((doc) => Map<String, dynamic>.from(doc.data()))
          .toList();

      // 3. Sync bookings
      ApiTracker.instance.trackCall('Cloud Firestore');
      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .get();

      final List<Map<String, dynamic>> remoteBookings = bookingsSnap.docs
          .map((doc) => <String, dynamic>{
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      // 4. Update memory state
      _vehicles = remoteVehicles;
      _documents = remoteDocs;
      _bookings = remoteBookings;

      final prefs = await SharedPreferences.getInstance();
      _activeVehicleIndex = prefs.getInt('vehicle_active_index') ?? 0;
      if (_activeVehicleIndex >= _vehicles.length) {
        _activeVehicleIndex = 0;
      }

      if (_vehicles.isNotEmpty) {
        final v = _vehicles[_activeVehicleIndex];
        _model = v['model'] ?? '';
        _plate = v['plate'] ?? '';
        _fuelType = v['fuelType'] ?? 'Petrol';
        _engine = v['engine'] ?? '';
        _transmission = v['transmission'] ?? '';
        _fuelCapacityLiters = (v['fuelCapacityLiters'] as num?)?.toDouble() ?? 0.0;
        _recommendedTyrePressurePsi = (v['recommendedTyrePressurePsi'] as num?)?.toDouble() ?? 0.0;
        _engineOilCapacityLiters = (v['engineOilCapacityLiters'] as num?)?.toDouble() ?? 0.0;
        _currentMileageKm = (v['currentMileageKm'] as num?)?.toDouble() ?? 0.0;
        _carType = v['carType'] ?? 'sedan';
        _carColor = v['carColor'] ?? '#3B82F6';
        
        if (v['maintenanceData'] != null) {
          _maintenanceData = (v['maintenanceData'] as Map).map(
            (key, value) => MapEntry(key.toString(), Map<String, dynamic>.from(value as Map))
          );
        } else {
          _maintenanceData = {};
        }
        
        if (v['mileageHistory'] != null) {
          _mileageHistory = List<Map<String, dynamic>>.from(v['mileageHistory']);
        } else {
          _mileageHistory = [];
        }
      } else {
        _model = '';
        _plate = '';
        _fuelType = 'Petrol';
        _engine = '';
        _transmission = '';
        _fuelCapacityLiters = 0.0;
        _recommendedTyrePressurePsi = 0.0;
        _engineOilCapacityLiters = 0.0;
        _currentMileageKm = 0.0;
        _carType = 'sedan';
        _carColor = '#3B82F6';
        _maintenanceData = {};
        _mileageHistory = [];
      }

      // 5. Save everything to SharedPreferences to populate cache
      await _saveVehiclesToPrefs();
      await _saveBookingsToPrefs();
      await _saveDocumentsToPrefs();
      await prefs.setInt('vehicle_active_index', _activeVehicleIndex);
      
      if (_vehicles.isNotEmpty) {
        await prefs.setString('vehicle_model', _model);
        await prefs.setString('vehicle_plate', _plate);
        await prefs.setString('vehicle_fuelType', _fuelType);
        await prefs.setDouble('vehicle_currentMileageKm', _currentMileageKm);
        await prefs.setString('vehicle_engine', _engine);
        await prefs.setString('vehicle_transmission', _transmission);
        await prefs.setDouble('vehicle_fuelCapacityLiters', _fuelCapacityLiters);
        await prefs.setDouble('vehicle_recommendedTyrePressurePsi', _recommendedTyrePressurePsi);
        await prefs.setDouble('vehicle_engineOilCapacityLiters', _engineOilCapacityLiters);
        await prefs.setString('vehicle_carType', _carType);
        await prefs.setString('vehicle_carColor', _carColor);
      } else {
        await prefs.remove('vehicle_model');
        await prefs.remove('vehicle_plate');
        await prefs.remove('vehicle_fuelType');
        await prefs.remove('vehicle_currentMileageKm');
        await prefs.remove('vehicle_engine');
        await prefs.remove('vehicle_transmission');
        await prefs.remove('vehicle_fuelCapacityLiters');
        await prefs.remove('vehicle_recommendedTyrePressurePsi');
        await prefs.remove('vehicle_engineOilCapacityLiters');
        await prefs.remove('vehicle_carType');
        await prefs.remove('vehicle_carColor');
      }

      notifyListeners();
    } catch (e, stack) {
      debugPrint('Error syncing vehicle insights from Firestore: $e\n$stack');
    }
  }

  // Static pure utility functions
  static double kmPerLiter({
    required double distanceKm,
    required double liters,
  }) {
    if (liters <= 0) {
      return 0;
    }
    return distanceKm / liters;
  }

  static double litersPer100Km({
    required double distanceKm,
    required double liters,
  }) {
    if (distanceKm <= 0) {
      return 0;
    }
    return (liters / distanceKm) * 100;
  }

  static double refuelCost({
    required double liters,
    required double pricePerLiter,
  }) {
    return liters * pricePerLiter;
  }
}

class MaintenanceItem {
  final String name;
  final double currentMileage;
  final double lastServiceMileage;
  final DateTime lastServiceDate;
  final double interval;

  MaintenanceItem({
    required this.name,
    required this.currentMileage,
    required this.lastServiceMileage,
    required this.lastServiceDate,
    required this.interval,
  });

  double get remainingKm => (lastServiceMileage + interval) - currentMileage;
  
  double get healthPercentage {
    return (remainingKm / interval).clamp(0.0, 1.0) * 100;
  }

  double get nextChangeMileage => lastServiceMileage + interval;

  int get monthsSinceService {
    final now = DateTime.now();
    return (now.year - lastServiceDate.year) * 12 + now.month - lastServiceDate.month;
  }
  
  String get status {
    if (remainingKm <= 500 || monthsSinceService >= 12) return 'Red';
    if (remainingKm <= 2000 || monthsSinceService >= 10) return 'Yellow';
    return 'Green';
  }

  String get predictedDateStr {
    final dailyAvg = VehicleInsights.instance.averageKmPerDay;
    if (dailyAvg <= 0) return 'TBD';
    final daysLeft = (remainingKm / dailyAvg).ceil();
    if (daysLeft < 0) return 'Overdue';
    final date = DateTime.now().add(Duration(days: daysLeft));
    return '${date.day}/${date.month}/${date.year}';
  }
}
