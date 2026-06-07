import 'package:flutter_test/flutter_test.dart';
import 'package:drive_care_plus/services/api_tracker_service.dart';

void main() {
  group('ApiTracker Tests', () {
    setUp(() {
      ApiTracker.instance.reset();
    });

    test('initial transaction counts should be zero', () {
      final counts = ApiTracker.instance.transactionCounts;
      expect(counts['Firebase Core'], 0);
      expect(counts['Cloud Firestore'], 0);
      expect(counts['Google Places API'], 0);
      expect(counts['ToyyibPay API'], 0);
      expect(counts['System Connectivity'], 0);
    });

    test('trackCall should increment specific api count and notify listeners', () {
      int listenerCallCount = 0;
      void listener() {
        listenerCallCount++;
      }
      ApiTracker.instance.addListener(listener);

      ApiTracker.instance.trackCall('Firebase Core');
      expect(ApiTracker.instance.transactionCounts['Firebase Core'], 1);
      expect(listenerCallCount, 1);

      ApiTracker.instance.trackCall('Firebase Core');
      expect(ApiTracker.instance.transactionCounts['Firebase Core'], 2);
      expect(listenerCallCount, 2);

      // Verify other counters remain zero
      expect(ApiTracker.instance.transactionCounts['Cloud Firestore'], 0);
      
      ApiTracker.instance.removeListener(listener);
    });

    test('reset should clear all counts to zero', () {
      ApiTracker.instance.trackCall('Firebase Core');
      ApiTracker.instance.trackCall('Cloud Firestore');
      
      expect(ApiTracker.instance.transactionCounts['Firebase Core'], 1);
      expect(ApiTracker.instance.transactionCounts['Cloud Firestore'], 1);

      ApiTracker.instance.reset();

      expect(ApiTracker.instance.transactionCounts['Firebase Core'], 0);
      expect(ApiTracker.instance.transactionCounts['Cloud Firestore'], 0);
    });
  });
}
