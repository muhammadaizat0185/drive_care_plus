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

  // Bookings and documents lists
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _documents = [];

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

  // Setters with notifyListeners and SharedPreferences persistence
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

