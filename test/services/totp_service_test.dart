import 'package:flutter_test/flutter_test.dart';
import 'package:otp/otp.dart';
import 'package:drive_care_plus/services/totp_service.dart';

void main() {
  group('TOTPService Tests', () {
    test('generateSecret returns a valid 16-character uppercase Base32 secret', () {
      final String secret = TOTPService.instance.generateSecret();
      expect(secret.length, 16);
      expect(RegExp(r'^[A-Z2-7]+$').hasMatch(secret), isTrue);
    });

    test('getQrUri returns standard OTP Auth URI format', () {
      const String secret = 'JBSWY3DPEHPK3PXP';
      const String email = 'driver@example.com';
      final String uri = TOTPService.instance.getQrUri(email: email, secret: secret);

      expect(uri, contains('otpauth://totp/'));
      expect(uri, contains('secret=$secret'));
      expect(uri, contains('issuer=DriveCare%2B'));
      expect(uri, contains(Uri.encodeComponent(email)));
    });

    test('verifyCode validates valid codes and handles +/- 30s clock drift', () {
      const String secret = 'JBSWY3DPEHPK3PXP';
      final int now = DateTime.now().millisecondsSinceEpoch;

      // Current interval code
      final String currentCode = OTP.generateTOTPCodeString(
        secret,
        now,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      expect(TOTPService.instance.verifyCode(secret: secret, code: currentCode), isTrue);

      // Previous interval code (-30 seconds)
      final String prevCode = OTP.generateTOTPCodeString(
        secret,
        now - 30000,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      expect(TOTPService.instance.verifyCode(secret: secret, code: prevCode), isTrue);

      // Next interval code (+30 seconds)
      final String nextCode = OTP.generateTOTPCodeString(
        secret,
        now + 30000,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      expect(TOTPService.instance.verifyCode(secret: secret, code: nextCode), isTrue);

      // Far future code (+10 minutes) should be invalid
      final String futureCode = OTP.generateTOTPCodeString(
        secret,
        now + 600000,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      expect(TOTPService.instance.verifyCode(secret: secret, code: futureCode), isFalse);

      // Invalid length code
      expect(TOTPService.instance.verifyCode(secret: secret, code: '123'), isFalse);
    });
  });
}
