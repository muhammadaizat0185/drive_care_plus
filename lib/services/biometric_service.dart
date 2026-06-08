import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService extends ChangeNotifier {
  static final BiometricService instance = BiometricService._internal();

  BiometricService._internal() {
    _init();
  }

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isBiometricsEnabled = false;

  bool get isBiometricsEnabled => _isBiometricsEnabled;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isBiometricsEnabled = prefs.getBool('biometrics_login_enabled') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing BiometricService: $e');
    }
  }

  /// Checks if the device supports biometrics and has enrolled templates.
  Future<bool> canAuthenticate() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      debugPrint('Error checking biometric support: $e');
      return false;
    }
  }

  /// Triggers the native biometric verification dialog.
  Future<bool> authenticateLocal() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Verify your identity to log in securely.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  /// Toggles biometric enrollment. Stashes/clears credentials from secure hardware storage.
  Future<bool> setBiometricsEnabled(bool enabled, {String? email, String? password}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (enabled) {
        if (email == null || password == null || email.isEmpty || password.isEmpty) {
          throw Exception('Valid credentials required to enroll biometrics.');
        }

        final bool canAuth = await canAuthenticate();
        if (!canAuth) {
          throw Exception('Biometrics not supported or enrolled on this device.');
        }

        // Store credentials securely
        await _secureStorage.write(key: 'secure_login_email', value: email);
        await _secureStorage.write(key: 'secure_login_password', value: password);
        await prefs.setBool('biometrics_login_enabled', true);
        _isBiometricsEnabled = true;
      } else {
        // Clear secure credentials
        await _secureStorage.delete(key: 'secure_login_email');
        await _secureStorage.delete(key: 'secure_login_password');
        await prefs.setBool('biometrics_login_enabled', false);
        _isBiometricsEnabled = false;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to set biometrics state: $e');
      rethrow;
    }
  }

  /// Retrieves stored login credentials if biometrics is verified and active.
  Future<Map<String, String>?> getStoredCredentials() async {
    try {
      if (!_isBiometricsEnabled) return null;

      final String? email = await _secureStorage.read(key: 'secure_login_email');
      final String? password = await _secureStorage.read(key: 'secure_login_password');

      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }
    } catch (e) {
      debugPrint('Error reading stored credentials: $e');
    }
    return null;
  }

  /// Clears secure credentials on sign out or when account data is wiped.
  Future<void> clearStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _secureStorage.delete(key: 'secure_login_email');
      await _secureStorage.delete(key: 'secure_login_password');
      await prefs.setBool('biometrics_login_enabled', false);
      _isBiometricsEnabled = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing secure storage: $e');
    }
  }
}
