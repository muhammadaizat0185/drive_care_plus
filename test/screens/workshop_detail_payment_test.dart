import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:cloud_firestore_platform_interface/src/pigeon/messages.pigeon.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:drive_care_plus/services/profile_service.dart';
import 'package:drive_care_plus/services/biometric_service.dart';
import 'package:drive_care_plus/services/notification_service.dart';
import 'package:drive_care_plus/services/notification_preferences.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:drive_care_plus/models/workshop.dart';
import 'package:drive_care_plus/screens/workshop_detail_screen.dart';
import 'package:drive_care_plus/screens/workshops/_booking_details_sheet.dart';
import '../widgets/ui/_test_host.dart';

// Fake implementations for Firebase Core test environment
class FakeFirebaseAuthPlatform extends FirebaseAuthPlatform {
  UserPlatform? mockUser;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;
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

  FakeUserPlatform({required this.uid});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class FakeFirebaseFirestorePlatform extends FirebaseFirestorePlatform {
  final Map<String, List<Map<String, dynamic>>> collections = {};

  @override
  FirebaseFirestorePlatform delegateFor({required FirebaseApp app, required String databaseId}) => this;
  @override
  CollectionReferencePlatform collection(String collectionPath) => FakeCollectionReference(this, collectionPath);
  @override
  DocumentReferencePlatform doc(String documentPath) => FakeDocumentReference(this, documentPath);
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
  Stream<QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) {
    final dataList = _platform.collections[_path] ?? [];
    final docs = dataList.map((d) {
      final id = d['id'] ?? 'dummy_id';
      return FakeDocumentSnapshot(_platform, '$_path/$id', d);
    }).toList();
    return Stream.value(FakeQuerySnapshot(docs));
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

  @override
  Future<DocumentReferencePlatform> add(Map<String, dynamic> data) {
    final docId = 'doc_${DateTime.now().millisecondsSinceEpoch}';
    final docRef = FakeDocumentReference(_platform, '$_path/$docId');
    docRef.set(data);
    return Future.value(docRef);
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
    final segments = _path.split('/');
    final collPath = segments.sublist(0, segments.length - 1).join('/');
    final list = _platform.collections[collPath] ?? [];
    list.removeWhere((item) => item['id'] == data['id']);
    list.add(data);
    _platform.collections[collPath] = list;
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

const Workshop _workshop = Workshop(
  id: 'detail-test-w1',
  name: 'Test Workshop',
  address: '123 Test Street',
  rating: 4.8,
  reviewCount: 15,
  distance: '1.2 km',
  types: <String>['car_repair'],
  isOpenNow: true,
);

final FakeFirebaseAuthPlatform globalFakeAuth = FakeFirebaseAuthPlatform();
final FakeFirebaseFirestorePlatform globalFakeFirestore = FakeFirebaseFirestorePlatform();

class FakeFlutterLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #initialize) {
      return Future<bool>.value(true);
    }
    if (name == #zonedSchedule || name == #cancel || name == #show) {
      return Future<void>.value();
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  const MethodChannel localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    
    // Reset global fakes to prevent test-to-test cross pollution
    globalFakeAuth.mockUser = null;
    globalFakeFirestore.collections.clear();

    FirebaseAuthPlatform.instance = globalFakeAuth;
    FirebaseFirestorePlatform.instance = globalFakeFirestore;
    FlutterLocalNotificationsPlatform.instance = FakeFlutterLocalNotificationsPlatform();
    
    try {
      await Firebase.app().delete();
    } catch (_) {}
    await Firebase.initializeApp();

    // Initialize notification preferences and service
    await NotificationPreferences.instance.init();
    await NotificationService.instance.init();

    await ProfileService.instance.clearProfile();
    await BiometricService.instance.setTransactionAuthEnabled(false);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      localAuthChannel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'canCheckBiometrics':
            return true;
          case 'isDeviceSupported':
            return true;
          case 'authenticate':
            return true;
          case 'getAvailableBiometrics':
            return <String>['fingerprint'];
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(localAuthChannel, null);
  });

  group('WorkshopDetailScreen Booking Payment Tests', () {
    testWidgets('renders booking setup options and payment chips', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        hostApp(child: const WorkshopDetailScreen(workshop: _workshop)),
      );
      await tester.pumpAndSettle();

      // Tap Book Appointment to reveal booking options
      final bookBtnFinder = find.text('Book Appointment');
      expect(bookBtnFinder, findsOneWidget);
      await tester.tap(bookBtnFinder);
      await tester.pumpAndSettle();

      // Check for payment selector title
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Pay at Workshop'), findsOneWidget);
      expect(find.text('Pay via Wallet'), findsOneWidget);
    });

    testWidgets('wallet payment shows insufficient warning if balance < cost', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        hostApp(child: const WorkshopDetailScreen(workshop: _workshop)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Appointment'));
      await tester.pumpAndSettle();

      // Initially starts as at_workshop. Tap Pay via Wallet.
      await tester.tap(find.text('Pay via Wallet'));
      await tester.pumpAndSettle();

      // Should show Insufficient Balance since profile wallet balance is 0.0
      expect(find.textContaining('Insufficient Balance'), findsOneWidget);
    });

    testWidgets('wallet payment shows sufficient balance if balance >= cost', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed wallet balance
      await ProfileService.instance.addWalletTransaction(200.0, 'top_up', 'Seed topup');
      
      await tester.pumpWidget(
        hostApp(child: const WorkshopDetailScreen(workshop: _workshop)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Appointment'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay via Wallet'));
      await tester.pumpAndSettle();

      // Should show Sufficient Balance since profile wallet balance is 200.0 (cost is 150.0)
      expect(find.textContaining('Sufficient Balance'), findsOneWidget);
    });

    testWidgets('booking with Pay at Workshop schedules with status Pending and does not deduct balance', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Authenticate user using global fake
      globalFakeAuth.mockUser = FakeUserPlatform(uid: 'user-123');

      // Seed wallet balance
      await ProfileService.instance.addWalletTransaction(100.0, 'top_up', 'Initial Balance');

      await tester.pumpWidget(
        hostApp(child: const WorkshopDetailScreen(workshop: _workshop)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Appointment'));
      await tester.pumpAndSettle();

      // Ensure Pay at Workshop is selected
      await tester.tap(find.text('Pay at Workshop'));
      await tester.pumpAndSettle();

      // Pick Date
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Pick Time
      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Schedule
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      // Close successful booking dialog
      expect(find.text('Booking Successful!'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify booking added to firestore collection via global fake
      final bookings = globalFakeFirestore.collections['bookings'] ?? [];
      expect(bookings.length, 1);
      expect(bookings.first['status'], 'Pending');
      expect(bookings.first['totalCost'], 150.0);

      // Verify wallet balance is unchanged
      expect(ProfileService.instance.walletBalance, 100.0);
    });

    testWidgets('booking with sufficient wallet balance deducts price and schedules with status Paid', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Authenticate user using global fake
      globalFakeAuth.mockUser = FakeUserPlatform(uid: 'user-123');

      // Seed sufficient wallet balance (150.0 is booking cost)
      await ProfileService.instance.addWalletTransaction(200.0, 'top_up', 'Initial Balance');

      await tester.pumpWidget(
        hostApp(child: const WorkshopDetailScreen(workshop: _workshop)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Appointment'));
      await tester.pumpAndSettle();

      // Select Pay via Wallet
      await tester.tap(find.text('Pay via Wallet'));
      await tester.pumpAndSettle();

      // Pick Date
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Pick Time
      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Schedule
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      // Approve transaction on modal
      expect(find.text('Confirm Money Transfer'), findsOneWidget);
      await tester.tap(find.text('Approve Transfer'));
      await tester.pumpAndSettle();

      // Skip biometrics suggest modal
      expect(find.text('Enable Biometric Payments?'), findsOneWidget);
      await tester.tap(find.text('Skip for Now'));
      await tester.pumpAndSettle();

      // Confirm success dialog
      expect(find.text('Booking Successful!'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify booking added to firestore collection via global fake
      final bookings = globalFakeFirestore.collections['bookings'] ?? [];
      expect(bookings.length, 1);
      expect(bookings.first['status'], 'Paid');
      expect(bookings.first['totalCost'], 150.0);

      // Verify wallet balance is deducted (200.0 - 150.0 = 50.0)
      expect(ProfileService.instance.walletBalance, 50.0);
    });

    testWidgets('booking with sufficient wallet balance and biometrics enabled prompts local auth and schedules with status Paid', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      globalFakeAuth.mockUser = FakeUserPlatform(uid: 'user-123');
      await ProfileService.instance.addWalletTransaction(200.0, 'top_up', 'Initial Balance');
      await BiometricService.instance.setTransactionAuthEnabled(true);

      await tester.pumpWidget(
        hostApp(child: const WorkshopDetailScreen(workshop: _workshop)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Appointment'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay via Wallet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      // Approve transaction
      expect(find.text('Confirm Money Transfer'), findsOneWidget);
      await tester.tap(find.text('Approve Transfer'));
      await tester.pumpAndSettle();

      // Direct success (local auth succeeds under the hood automatically due to mocked channel)
      expect(find.text('Booking Successful!'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final bookings = globalFakeFirestore.collections['bookings'] ?? [];
      expect(bookings.length, 1);
      expect(bookings.first['status'], 'Paid');
      expect(ProfileService.instance.walletBalance, 50.0);
    });

    testWidgets('rejecting the confirmation modal schedules booking as Pending with wallet paymentMethod', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      globalFakeAuth.mockUser = FakeUserPlatform(uid: 'user-123');
      await ProfileService.instance.addWalletTransaction(200.0, 'top_up', 'Initial Balance');

      await tester.pumpWidget(
        hostApp(child: const WorkshopDetailScreen(workshop: _workshop)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Appointment'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay via Wallet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      // Reject/Cancel transaction
      expect(find.text('Confirm Money Transfer'), findsOneWidget);
      await tester.tap(find.text('Reject / Cancel'));
      await tester.pumpAndSettle();

      // Verify success dialog scheduled booking as unpaid
      expect(find.text('Booking Successful!'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final bookings = globalFakeFirestore.collections['bookings'] ?? [];
      expect(bookings.length, 1);
      expect(bookings.first['status'], 'Pending');
      expect(bookings.first['paymentMethod'], 'wallet');
      expect(ProfileService.instance.walletBalance, 200.0); // balance untouched
    });

    testWidgets('BookingDetailsBottomSheet allows paying pending wallet booking and invokes onSave with status Paid', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await ProfileService.instance.addWalletTransaction(100.0, 'top_up', 'Seed');

      final pendingBooking = <String, dynamic>{
        'id': 'booking-details-pending',
        'workshopName': 'Legacy Auto Shop',
        'serviceName': 'Oil Change',
        'date': '2030-06-08T10:00:00.000',
        'time': '10:00',
        'status': 'Pending',
        'paymentMethod': 'wallet',
        'totalCost': 50.0,
      };

      Map<String, dynamic>? savedUpdates;

      await tester.pumpWidget(
        hostApp(
          child: Scaffold(
            body: BookingDetailsBottomSheet(
              booking: pendingBooking,
              onSave: (updates) {
                savedUpdates = updates;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment Pending (Wallet)'), findsOneWidget);

      await tester.tap(find.text('Pay via Wallet (RM 50.00)'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Money Transfer'), findsOneWidget);
      await tester.tap(find.text('Approve Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('Enable Biometric Payments?'), findsOneWidget);
      await tester.tap(find.text('Skip for Now'));
      await tester.pumpAndSettle();

      expect(savedUpdates, isNotNull);
      expect(savedUpdates?['status'], 'Paid');
      expect(savedUpdates?['paymentMethod'], 'wallet');
      expect(ProfileService.instance.walletBalance, 50.0);
    });

    testWidgets('BookingDetailsBottomSheet allows changing payment method to at_workshop', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pendingBooking = <String, dynamic>{
        'id': 'booking-details-pending',
        'workshopName': 'Legacy Auto Shop',
        'serviceName': 'Oil Change',
        'date': '2030-06-08T10:00:00.000',
        'time': '10:00',
        'status': 'Pending',
        'paymentMethod': 'wallet',
        'totalCost': 50.0,
      };

      Map<String, dynamic>? savedUpdates;

      await tester.pumpWidget(
        hostApp(
          child: Scaffold(
            body: BookingDetailsBottomSheet(
              booking: pendingBooking,
              onSave: (updates) {
                savedUpdates = updates;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay at Workshop'));
      await tester.pumpAndSettle();

      expect(savedUpdates, isNotNull);
      expect(savedUpdates?['status'], 'Pending');
      expect(savedUpdates?['paymentMethod'], 'at_workshop');
    });
  });
}
