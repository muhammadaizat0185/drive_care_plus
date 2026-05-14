import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehicleInsights extends ChangeNotifier {
  // Singleton instance
  static final VehicleInsights instance = VehicleInsights._internal();

  VehicleInsights._internal();

  String _model = 'Perodua Axia';
  String _plate = 'ABC 1234';
  String _fuelType = 'Petrol';
  String _engine = '1.0L VVT-i (1KR-VE)';
  String _transmission = '4-Speed Automatic';
  double _fuelCapacityLiters = 36.0;
  double _recommendedTyrePressurePsi = 36.0;
  double _engineOilCapacityLiters = 3.0;

  double _currentMileageKm = 38200;
  final double _nextServiceMileageKm = 40000;
  final double _averageDailyDistanceKm = 50;
  double _recentTripDistanceKm = 24.6;
  double _recentTripFuelCostRm = 5.40;

  // Bookings, documents and multiple vehicles lists
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _vehicles = [];
  int _activeVehicleIndex = 0;

  // Getters
  String get model => _model;
  String get plate => _plate;
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

  List<Map<String, dynamic>> get bookings => _bookings;
  List<Map<String, dynamic>> get documents => _documents;
  List<Map<String, dynamic>> get vehicles => _vehicles;
  int get activeVehicleIndex => _activeVehicleIndex;

  // Active bookings list alias for Cockpit tab compatibility
  List<Map<String, dynamic>> get activeBookings => _bookings;

  List<MaintenanceItem> get watchlistItems {
    return [
      MaintenanceItem(name: 'Engine Oil', currentMileage: _currentMileageKm, interval: 10000),
      MaintenanceItem(name: 'Brake Pads', currentMileage: _currentMileageKm, interval: 40000),
      MaintenanceItem(name: 'Tyres', currentMileage: _currentMileageKm, interval: 50000),
      MaintenanceItem(name: 'Battery', currentMileage: _currentMileageKm, interval: 60000),
    ]..sort((a, b) => a.remainingKm.compareTo(b.remainingKm));
  }

  // Compatibility aliases for customized vehicle health gauges
  double get kmUntilServiceInstance => kmUntilService;
  int get predictedServiceDueDaysInstance => predictedServiceDueDays;

  double get kmUntilService {
    final difference = _nextServiceMileageKm - _currentMileageKm;
    return difference < 0 ? 0 : difference;
  }

  int get predictedServiceDueDays {
    if (_averageDailyDistanceKm <= 0) return 0;
    return (kmUntilService / _averageDailyDistanceKm).ceil();
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

    // Update inside _vehicles list
    if (_vehicles.isNotEmpty && _activeVehicleIndex >= 0 && _activeVehicleIndex < _vehicles.length) {
      _vehicles[_activeVehicleIndex] = {
        'model': _model,
        'plate': _plate,
        'fuelType': _fuelType,
        'currentMileageKm': _currentMileageKm,
        'engine': _engine,
        'transmission': _transmission,
        'fuelCapacityLiters': _fuelCapacityLiters,
        'recommendedTyrePressurePsi': _recommendedTyrePressurePsi,
        'engineOilCapacityLiters': _engineOilCapacityLiters,
      };
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
      await _saveVehiclesToPrefs();
    } catch (e) {
      debugPrint('SharedPreferences save error: $e');
    }
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
    _vehicles.add(vehicle);
    notifyListeners();
    await _saveVehiclesToPrefs();
  }

  Future<void> deleteVehicle(int index) async {
    if (index < 0 || index >= _vehicles.length) return;
    if (_vehicles.length <= 1) return; // Keep at least one
    _vehicles.removeAt(index);
    if (_activeVehicleIndex >= _vehicles.length) {
      _activeVehicleIndex = _vehicles.length - 1;
    }
    await setActiveVehicle(_activeVehicleIndex);
    await _saveVehiclesToPrefs();
  }

  Future<void> setActiveVehicle(int index) async {
    if (index < 0 || index >= _vehicles.length) return;
    _activeVehicleIndex = index;
    final v = _vehicles[index];
    _model = v['model'] ?? 'Perodua Axia';
    _plate = v['plate'] ?? '';
    _fuelType = v['fuelType'] ?? 'Petrol';
    _engine = v['engine'] ?? '1.0L VVT-i (1KR-VE)';
    _transmission = v['transmission'] ?? '4-Speed Automatic';
    _fuelCapacityLiters = (v['fuelCapacityLiters'] as num?)?.toDouble() ?? 36.0;
    _recommendedTyrePressurePsi = (v['recommendedTyrePressurePsi'] as num?)?.toDouble() ?? 36.0;
    _engineOilCapacityLiters = (v['engineOilCapacityLiters'] as num?)?.toDouble() ?? 3.0;
    _currentMileageKm = (v['currentMileageKm'] as num?)?.toDouble() ?? 38200;
    
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
      _model = prefs.getString('vehicle_model') ?? 'Perodua Axia';
      _plate = prefs.getString('vehicle_plate') ?? 'ABC 1234';
      _fuelType = prefs.getString('vehicle_fuelType') ?? 'Petrol';
      _currentMileageKm = prefs.getDouble('vehicle_currentMileageKm') ?? 38200;
      _recentTripDistanceKm = prefs.getDouble('vehicle_recentTripDistanceKm') ?? 24.6;
      _recentTripFuelCostRm = prefs.getDouble('vehicle_recentTripFuelCostRm') ?? 5.40;
      _engine = prefs.getString('vehicle_engine') ?? '1.0L VVT-i (1KR-VE)';
      _transmission = prefs.getString('vehicle_transmission') ?? '4-Speed Automatic';
      _fuelCapacityLiters = prefs.getDouble('vehicle_fuelCapacityLiters') ?? 36.0;
      _recommendedTyrePressurePsi = prefs.getDouble('vehicle_recommendedTyrePressurePsi') ?? 36.0;
      _engineOilCapacityLiters = prefs.getDouble('vehicle_engineOilCapacityLiters') ?? 3.0;

      // Load bookings
      final bookingsJsonList = prefs.getStringList('vehicle_bookings');
      if (bookingsJsonList != null) {
        _bookings = bookingsJsonList.map((str) => Map<String, dynamic>.from(jsonDecode(str))).toList();
      } else {
        // Seed a default upcoming premium booking
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        _bookings = [
          {
            'workshopId': 'w1',
            'workshopName': 'Perodua Auto Care Specialist',
            'serviceName': 'Major Service Package',
            'servicePrice': 180.0,
            'date': '${tomorrow.day}/${tomorrow.month}/${tomorrow.year}',
            'time': '10:00 AM',
            'status': 'Confirmed',
          }
        ];
        await _saveBookingsToPrefs();
      }

      // Load documents
      final docsJsonList = prefs.getStringList('vehicle_documents');
      if (docsJsonList != null) {
        _documents = docsJsonList.map((str) => Map<String, dynamic>.from(jsonDecode(str))).toList();
      } else {
        // Seed some sample documents
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
      }

      // Load vehicles list
      final vehiclesJsonList = prefs.getStringList('vehicle_list');
      if (vehiclesJsonList != null) {
        _vehicles = vehiclesJsonList.map((str) => Map<String, dynamic>.from(jsonDecode(str))).toList();
      } else {
        // Seed default vehicle
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
          }
        ];
        await _saveVehiclesToPrefs();
      }
      _activeVehicleIndex = prefs.getInt('vehicle_active_index') ?? 0;
      if (_activeVehicleIndex >= _vehicles.length) {
        _activeVehicleIndex = 0;
      }
      
      // Load selected vehicle properties
      if (_vehicles.isNotEmpty) {
        final v = _vehicles[_activeVehicleIndex];
        _model = v['model'] ?? 'Perodua Axia';
        _plate = v['plate'] ?? '';
        _fuelType = v['fuelType'] ?? 'Petrol';
        _engine = v['engine'] ?? '1.0L VVT-i (1KR-VE)';
        _transmission = v['transmission'] ?? '4-Speed Automatic';
        _fuelCapacityLiters = (v['fuelCapacityLiters'] as num?)?.toDouble() ?? 36.0;
        _recommendedTyrePressurePsi = (v['recommendedTyrePressurePsi'] as num?)?.toDouble() ?? 36.0;
        _engineOilCapacityLiters = (v['engineOilCapacityLiters'] as num?)?.toDouble() ?? 3.0;
        _currentMileageKm = (v['currentMileageKm'] as num?)?.toDouble() ?? 38200.0;
      }
    } catch (e) {
      debugPrint('SharedPreferences load error: $e');
    }
    notifyListeners();
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
  final double interval;

  MaintenanceItem({
    required this.name,
    required this.currentMileage,
    required this.interval,
  });

  double get nextChangeMileage => (currentMileage / interval).floor() * interval + interval;
  double get remainingKm => nextChangeMileage - currentMileage;
  
  String get status {
    if (remainingKm <= 1000) return 'Red';
    if (remainingKm <= 3000) return 'Yellow';
    return 'Green';
  }
}
