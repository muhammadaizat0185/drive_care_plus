import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drive_care_plus/firebase_options.dart';

void main() {
  test('Firestore Diagnostic Test', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('Firebase initialized successfully.');
      final snapshot = await FirebaseFirestore.instance
          .collection('health_check')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));
      print('Firestore query succeeded. Document count: ${snapshot.docs.length}');
    } catch (e, stackTrace) {
      print('Firestore diagnostic failed with exception: $e');
      print('StackTrace: $stackTrace');
    }
  });
}
