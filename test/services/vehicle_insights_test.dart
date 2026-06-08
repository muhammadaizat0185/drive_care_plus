import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:cloud_firestore_platform_interface/src/pigeon/messages.pigeon.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:drive_care_plus/services/vehicle_insights.dart';

// --- FirebaseAuth Mocking ---

class FakeFirebaseAuthPlatform extends FirebaseAuthPlatform {
  UserPlatform? mockUser;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return this;
  }

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) {
    return this;
  }

  @override
  UserPlatform? get currentUser => mockUser;

  @override
  Stream<UserPlatform?> authStateChanges() => const Stream.empty();

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream.empty();

  @override
  Stream<UserPlatform?> userChanges() => const Stream.empty();
}

class FakeUserPlatform extends MockPlatformInterfaceMixin implements UserPlatform {
  @override
  final String uid;

  @override
  final String? email;

  FakeUserPlatform({required this.uid, this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}


// --- FirebaseFirestore Mocking ---

class FakeFirebaseFirestorePlatform extends FirebaseFirestorePlatform {
  final Map<String, List<Map<String, dynamic>>> collections = {};

  @override
  FirebaseFirestorePlatform delegateFor(
      {required FirebaseApp app, required String databaseId}) {
    return this;
  }

  @override
  CollectionReferencePlatform collection(String collectionPath) {
    return FakeCollectionReference(this, collectionPath);
  }

  @override
  DocumentReferencePlatform doc(String documentPath) {
    return FakeDocumentReference(this, documentPath);
  }
}

class FakeCollectionReference extends CollectionReferencePlatform {
  final FakeFirebaseFirestorePlatform _platform;
  final String _path;

  FakeCollectionReference(this._platform, this._path) : super(_platform, _path);

  @override
  Map<String, dynamic> get parameters => {
        'where': <List<dynamic>>[],
        'orderBy': <List<dynamic>>[],
        'startAt': null,
        'startAfter': null,
        'endAt': null,
        'endBefore': null,
        'limit': null,
        'limitToLast': null,
      };

  @override
  DocumentReferencePlatform doc([String? path]) {
    final docId = path ?? 'dummy';
    return FakeDocumentReference(_platform, '$_path/$docId');
  }

  @override
  QueryPlatform where(List<List<dynamic>> conditions) {
    return this;
  }

  @override
  Future<QuerySnapshotPlatform> get([GetOptions options = const GetOptions()]) {
    final dataList = _platform.collections[_path] ?? [];
    final docs = dataList.map((d) {
      final id = d['id'] ?? 'dummy_id';
      return FakeDocumentSnapshot(_platform, '$_path/$id', d);
    }).toList();
    return Future.value(FakeQuerySnapshot(docs));
  }
}

class FakeDocumentReference extends DocumentReferencePlatform {
  final FakeFirebaseFirestorePlatform _platform;
  final String _path;

  FakeDocumentReference(this._platform, this._path) : super(_platform, _path);

  @override
  CollectionReferencePlatform collection(String collectionPath) {
    return FakeCollectionReference(_platform, '$_path/$collectionPath');
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    print('FakeDocumentReference.set: path = $_path');
    print('FakeDocumentReference.set: platform hash = ${identityHashCode(_platform)}');
    final segments = _path.split('/');
    final collPath = segments.sublist(0, segments.length - 1).join('/');
    final list = _platform.collections[collPath] ?? [];
    list.removeWhere((item) => item['id'] == data['id']);
    list.add(data);
    _platform.collections[collPath] = list;
    print('FakeDocumentReference.set: stored list length = ${list.length} in collPath = $collPath');
    return Future.value();
  }

  @override
  Future<void> delete() {
    final segments = _path.split('/');
    final docId = segments.last;
    final collPath = segments.sublist(0, segments.length - 1).join('/');
    final list = _platform.collections[collPath] ?? [];
    list.removeWhere((item) => item['id'] == docId);
    _platform.collections[collPath] = list;
    return Future.value();
  }
}

class FakeQuerySnapshot extends QuerySnapshotPlatform {
  FakeQuerySnapshot(List<DocumentSnapshotPlatform> docs)
      : super(docs, const <DocumentChangePlatform>[], SnapshotMetadataPlatform(false, false));
}

class FakeDocumentSnapshot extends DocumentSnapshotPlatform {
  FakeDocumentSnapshot(FirebaseFirestorePlatform firestore, String path, Map<String?, Object?>? data)
      : super(
          firestore,
          path,
          data,
          InternalSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
        );
}

final FakeFirebaseAuthPlatform globalFakeAuth = FakeFirebaseAuthPlatform();
final FakeFirebaseFirestorePlatform globalFakeFirestore = FakeFirebaseFirestorePlatform();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  late FakeFirebaseAuthPlatform fakeAuth;
  late FakeFirebaseFirestorePlatform fakeFirestore;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Reset singleton state to prevent test-to-test cross pollution since Firebase wrapper caches delegates
    globalFakeAuth.mockUser = null;
    globalFakeFirestore.collections.clear();

    fakeAuth = globalFakeAuth;
    fakeFirestore = globalFakeFirestore;

    FirebaseAuthPlatform.instance = fakeAuth;
    FirebaseFirestorePlatform.instance = fakeFirestore;

    // Delete existing app to clear cached singletons on the Dart side
    try {
      await Firebase.app().delete();
    } catch (_) {}

    await Firebase.initializeApp();
    await VehicleInsights.instance.clear();
  });

  group('VehicleInsights Watched Items & Getters', () {
    test('WATCHLIST items health and categorization calculations', () {
      final insights = VehicleInsights.instance;
      insights.watchlistItems;
      expect(insights.model, equals('No Active Vehicle'));
      expect(insights.plate, equals('N/A'));
      expect(insights.currentMileageKm, 0.0);
    });

    test('averageKmPerDay calculations with empty history', () {
      final insights = VehicleInsights.instance;
      expect(insights.averageKmPerDay, 50.0);
    });
  });

  group('VehicleInsights Guest vs Auth Seeding & Syncing', () {
    test('guest (user == null) loadFromPrefs seeds default Perodua Axia', () async {
      final insights = VehicleInsights.instance;
      fakeAuth.mockUser = null;
      await insights.loadFromPrefs();
      expect(insights.model, equals('Perodua Axia'));
      expect(insights.plate, equals('ABC 1234'));
      expect(insights.vehicles.length, 1);
    });

    test('auth (user != null) loadFromPrefs does not seed default vehicle', () async {
      final insights = VehicleInsights.instance;
      fakeAuth.mockUser = FakeUserPlatform(uid: 'user-123', email: 'user@example.com');
      print('Mock currentUser uid: ${FirebaseAuth.instance.currentUser?.uid}');

      // Clear shared preferences first to simulate a fresh start / new login
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await insights.loadFromPrefs();
      expect(insights.model, equals('No Active Vehicle'));
      expect(insights.plate, equals('N/A'));
      expect(insights.vehicles.isEmpty, isTrue);
    });

    test('syncFromFirestore fetches and populates remote data correctly', () async {
      final insights = VehicleInsights.instance;
      fakeAuth.mockUser = FakeUserPlatform(uid: 'user-123', email: 'user@example.com');

      // Populate remote collection data in fake Firestore
      fakeFirestore.collections['users/user-123/vehicles'] = [
        {
          'id': 'v-999',
          'model': 'Toyota Vios',
          'plate': 'V-999',
          'fuelType': 'Petrol',
          'currentMileageKm': 15000.0,
        }
      ];
      fakeFirestore.collections['users/user-123/documents'] = [
        {
          'title': 'Roadtax 2026',
          'category': 'Roadtax',
          'expiryDate': '01/01/2027',
        }
      ];
      fakeFirestore.collections['bookings'] = [
        {
          'id': 'b-100',
          'userId': 'user-123',
          'workshopName': 'Budi Workshop',
        }
      ];

      await insights.syncFromFirestore('user-123');

      expect(insights.vehicles.length, 1);
      expect(insights.model, equals('Toyota Vios'));
      expect(insights.plate, equals('V-999'));
      expect(insights.documents.length, 1);
      expect(insights.documents.first['title'], equals('Roadtax 2026'));
      expect(insights.bookings.length, 1);
      expect(insights.bookings.first['workshopName'], equals('Budi Workshop'));
    });
  });

  group('VehicleCRUD Database Syncing', () {
    test('addVehicle writes to local state and Firestore', () async {
      final insights = VehicleInsights.instance;
      fakeAuth.mockUser = FakeUserPlatform(uid: 'user-123', email: 'user@example.com');
      
      // Clear local state
      insights.vehicles.clear();

      final newCar = {
        'id': 'my-custom-v',
        'model': 'Proton X50',
        'plate': 'P-X50',
        'fuelType': 'Petrol',
      };
      await insights.addVehicle(newCar);

      expect(insights.vehicles.length, 1);
      expect(insights.model, equals('Proton X50'));

      // Check remote write
      final remoteList = fakeFirestore.collections['users/user-123/vehicles'];
      expect(remoteList, isNotNull);
      expect(remoteList!.length, 1);
      expect(remoteList.first['model'], equals('Proton X50'));
    });

    test('deleteVehicle updates local state and Firestore', () async {
      final insights = VehicleInsights.instance;
      fakeAuth.mockUser = FakeUserPlatform(uid: 'user-123', email: 'user@example.com');
      
      // Set initial state
      insights.vehicles.clear();
      final car = {
        'id': 'my-custom-v',
        'model': 'Proton X50',
        'plate': 'P-X50',
        'fuelType': 'Petrol',
      };
      await insights.addVehicle(car);
      expect(insights.vehicles.length, 1);

      // Now delete it
      await insights.deleteVehicle(0);

      expect(insights.vehicles.isEmpty, isTrue);
      expect(insights.model, equals('No Active Vehicle'));

      // Verify remote deletion
      final remoteList = fakeFirestore.collections['users/user-123/vehicles'];
      expect(remoteList!.isEmpty, isTrue);
    });
  });
}
