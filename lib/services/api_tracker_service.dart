import 'package:flutter/foundation.dart';

class ApiTracker extends ChangeNotifier {
  static final ApiTracker instance = ApiTracker._internal();
  ApiTracker._internal();

  final Map<String, int> _transactionCounts = {
    'Firebase Core': 0,
    'Cloud Firestore': 0,
    'Google Places API': 0,
    'ToyyibPay API': 0,
    'System Connectivity': 0,
  };

  Map<String, int> get transactionCounts => _transactionCounts;

  void trackCall(String apiName) {
    if (_transactionCounts.containsKey(apiName)) {
      _transactionCounts[apiName] = _transactionCounts[apiName]! + 1;
      notifyListeners();
    }
  }

  void reset() {
    _transactionCounts.updateAll((key, value) => 0);
    notifyListeners();
  }
}
