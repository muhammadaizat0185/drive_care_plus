import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drive_care_plus/services/biometric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const MethodChannel localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');

  final Map<String, String> secureStorageMock = {};

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'write':
            final Map<dynamic, dynamic> args = methodCall.arguments as Map<dynamic, dynamic>;
            final String key = args['key'] as String;
            final String value = args['value'] as String;
            secureStorageMock[key] = value;
            return null;
          case 'read':
            final Map<dynamic, dynamic> args = methodCall.arguments as Map<dynamic, dynamic>;
            final String key = args['key'] as String;
            return secureStorageMock[key];
          case 'delete':
            final Map<dynamic, dynamic> args = methodCall.arguments as Map<dynamic, dynamic>;
            final String key = args['key'] as String;
            secureStorageMock.remove(key);
            return null;
          case 'clear':
            secureStorageMock.clear();
            return null;
          default:
            return null;
        }
      },
    );

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

    // Re-initialize singleton state
    await BiometricService.instance.clearStoredCredentials();
    await BiometricService.instance.setTransactionAuthEnabled(false);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(localAuthChannel, null);
    secureStorageMock.clear();
  });

  group('BiometricService Tests', () {
    test('canAuthenticate returns true when platform supports biometrics', () async {
      final bool canAuth = await BiometricService.instance.canAuthenticate();
      expect(canAuth, isTrue);
    });

    test('authenticateLocal returns true when verification succeeds', () async {
      final bool result = await BiometricService.instance.authenticateLocal();
      expect(result, isTrue);
    });

    test('transaction biometric settings default to false, can be toggled', () async {
      expect(BiometricService.instance.isTransactionAuthEnabled, isFalse);

      await BiometricService.instance.setTransactionAuthEnabled(true);
      expect(BiometricService.instance.isTransactionAuthEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('biometrics_transactions_enabled'), isTrue);

      await BiometricService.instance.setTransactionAuthEnabled(false);
      expect(BiometricService.instance.isTransactionAuthEnabled, isFalse);
      expect(prefs.getBool('biometrics_transactions_enabled'), isFalse);
    });

    test('setBiometricsEnabled saves credentials securely and toggles local state', () async {
      expect(BiometricService.instance.isBiometricsEnabled, isFalse);

      final bool success = await BiometricService.instance.setBiometricsEnabled(
        true,
        email: 'test@example.com',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(BiometricService.instance.isBiometricsEnabled, isTrue);
      expect(secureStorageMock['secure_login_email'], 'test@example.com');
      expect(secureStorageMock['secure_login_password'], 'password123');

      // Check retrieving credentials
      final Map<String, String>? credentials = await BiometricService.instance.getStoredCredentials();
      expect(credentials, isNotNull);
      expect(credentials?['email'], 'test@example.com');
      expect(credentials?['password'], 'password123');
    });

    test('setBiometricsEnabled false clears credentials and disables local state', () async {
      // Enable first
      await BiometricService.instance.setBiometricsEnabled(
        true,
        email: 'test@example.com',
        password: 'password123',
      );
      expect(BiometricService.instance.isBiometricsEnabled, isTrue);

      // Disable
      final bool success = await BiometricService.instance.setBiometricsEnabled(false);
      expect(success, isTrue);
      expect(BiometricService.instance.isBiometricsEnabled, isFalse);
      expect(secureStorageMock.containsKey('secure_login_email'), isFalse);
      expect(secureStorageMock.containsKey('secure_login_password'), isFalse);

      final Map<String, String>? credentials = await BiometricService.instance.getStoredCredentials();
      expect(credentials, isNull);
    });

    test('clearStoredCredentials clears secure storage and disables state', () async {
      await BiometricService.instance.setBiometricsEnabled(
        true,
        email: 'test@example.com',
        password: 'password123',
      );
      expect(BiometricService.instance.isBiometricsEnabled, isTrue);

      await BiometricService.instance.clearStoredCredentials();
      expect(BiometricService.instance.isBiometricsEnabled, isFalse);
      expect(secureStorageMock.isEmpty, isTrue);
    });
  });
}
