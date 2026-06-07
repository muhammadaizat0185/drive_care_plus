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

  double get averageKmPerDay {
    if (_mileageHistory.length < 2) return 50.0;
    final recent = _mileageHistory.last;
    final oldest = _mileageHistory.first;
    
    final recentDate = DateTime.tryParse(recent['timestamp']?.toString() ?? '');
    final oldestDate = DateTime.tryParse(oldest['timestamp']?.toString() ?? '');
    
    if (recentDate == null || oldestDate == null) return 50.0;
    
    final days = recentDate.difference(oldestDate).inDays;
    if (days <= 0) return 50.0;
    
    final recentMileage = (recent['mileage'] as num?)?.toDouble() ?? 0.0;
    final oldestMileage = (oldest['mileage'] as num?)?.toDouble() ?? 0.0;
    
    return (recentMileage - oldestMileage) / days;
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
  }

  Future<void> updateCurrentMileage(double mileage) async {
    if (mileage < _currentMileageKm) return; // Prevent reversing odometer
    
    _currentMileageKm = mileage;
    _mileageHistory.add({
      'mileage': mileage,
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
            'maintenanceData': <String, Map<String, dynamic>>{},
            'mileageHistory': <Map<String, dynamic>>[],
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
        _carType = v['carType'] ?? 'sedan';
        _carColor = v['carColor'] ?? '#3B82F6';
        
        // Fix: Load maintenance and history from the vehicle object
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
