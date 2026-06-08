import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:base32/base32.dart';
import 'package:otp/otp.dart';
import 'api_tracker_service.dart';

class TOTPService {
  static final TOTPService instance = TOTPService._internal();
  TOTPService._internal();

  @visibleForTesting
  static Future<void> Function(String uid, String secret)? enableTotpOverride;
  @visibleForTesting
  static Future<void> Function(String uid)? disableTotpOverride;
  @visibleForTesting
  static Future<bool> Function(String uid)? checkIsTotpEnabledOverride;
  @visibleForTesting
  static Future<String?> Function(String uid)? getTotpSecretOverride;

  /// Generates a secure random 16-character Base32 secret key.
  String generateSecret() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(10, (_) => random.nextInt(256));
    // Base32 secret string must be uppercase and typically 16 characters
    return base32.encode(Uint8List.fromList(bytes)).toUpperCase().replaceAll('=', '').substring(0, 16);
  }

  /// Builds a standard TOTP URI for Authenticator apps.
  String getQrUri({required String email, required String secret}) {
    final String cleanEmail = Uri.encodeComponent(email);
    final String cleanIssuer = Uri.encodeComponent('DriveCare+');
    return 'otpauth://totp/$cleanIssuer:$cleanEmail?secret=$secret&issuer=$cleanIssuer&algorithm=SHA1&digits=6&period=30';
  }

  /// Verifies a 6-digit TOTP code against the secret key, allowing for 30s clock drift (+/- 1 step).
  bool verifyCode({required String secret, required String code}) {
    if (code.length != 6) return false;
    final int now = DateTime.now().millisecondsSinceEpoch;
    
    // Check current, previous, and next intervals (each interval is 30 seconds)
    for (final int offsetMs in [-30000, 0, 30000]) {
      try {
        final String expected = OTP.generateTOTPCodeString(
          secret,
          now + offsetMs,
          algorithm: Algorithm.SHA1,
          isGoogle: true,
        );
        if (expected == code) return true;
      } catch (e) {
        debugPrint('TOTP generation failed for offset $offsetMs: $e');
      }
    }
    return false;
  }

  /// Checks if the user has TOTP enabled in their Firestore profile.
  Future<bool> checkIsTotpEnabled(String uid) async {
    if (checkIsTotpEnabledOverride != null) {
      return await checkIsTotpEnabledOverride!(uid);
    }
    try {
      ApiTracker.instance.trackCall('Cloud Firestore');
      final DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['totp_enabled'] ?? false;
      }
    } catch (e) {
      debugPrint('Error checking Firestore TOTP status: $e');
    }
    return false;
  }

  /// Retrieves the user's secret key from Firestore to complete login verification.
  Future<String?> getTotpSecret(String uid) async {
    if (getTotpSecretOverride != null) {
      return await getTotpSecretOverride!(uid);
    }
    try {
      ApiTracker.instance.trackCall('Cloud Firestore');
      final DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['totp_secret'] as String?;
      }
    } catch (e) {
      debugPrint('Error reading Firestore TOTP secret: $e');
    }
    return null;
  }

  /// Enrolls the user with TOTP, saving status and secret key in Firestore.
  Future<void> enableTotp(String uid, String secret) async {
    if (enableTotpOverride != null) {
      await enableTotpOverride!(uid, secret);
      return;
    }
    try {
      ApiTracker.instance.trackCall('Cloud Firestore');
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'totp_enabled': true,
        'totp_secret': secret,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error enabling Firestore TOTP: $e');
      throw Exception('Failed to save 2FA setup in database. Check connection.');
    }
  }

  /// Disables TOTP, removing credentials from Firestore.
  Future<void> disableTotp(String uid) async {
    if (disableTotpOverride != null) {
      await disableTotpOverride!(uid);
      return;
    }
    try {
      ApiTracker.instance.trackCall('Cloud Firestore');
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'totp_enabled': false,
        'totp_secret': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error disabling Firestore TOTP: $e');
      throw Exception('Failed to remove 2FA from database. Check connection.');
    }
  }
}
