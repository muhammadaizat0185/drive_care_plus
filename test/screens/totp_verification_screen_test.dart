import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otp/otp.dart';
import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/totp_verification_screen.dart';
import 'package:drive_care_plus/services/totp_service.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';

Widget _hostApp({required Widget child}) {
  final ThemeData theme = AppTheme.buildTheme(AppColors.emerald500, Brightness.light);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: child,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TOTPService.enableTotpOverride = null;
    TOTPService.disableTotpOverride = null;
    TOTPService.checkIsTotpEnabledOverride = null;
    TOTPService.getTotpSecretOverride = null;
  });

  group('TOTPVerificationScreen Widget Tests', () {
    testWidgets('entering invalid verification code displays error message', (tester) async {
      TOTPService.getTotpSecretOverride = (String uid) async => 'JBSWY3DPEHPK3PXP';

      await tester.pumpWidget(_hostApp(child: const TOTPVerificationScreen(uid: 'test_user_123')));
      await tester.pumpAndSettle();

      expect(find.text('Enter Verification Code'), findsOneWidget);

      final Finder codeField = find.byType(AppTextField);
      await tester.enterText(codeField, '111111');
      await tester.pump();

      await tester.tap(find.text('Verify Code'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid verification code. Please try again.'), findsOneWidget);
    });

    testWidgets('entering correct verification code pops back with true', (tester) async {
      const String secret = 'JBSWY3DPEHPK3PXP';
      TOTPService.getTotpSecretOverride = (String uid) async => secret;

      bool? result;

      await tester.pumpWidget(_hostApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => const TOTPVerificationScreen(uid: 'test_user_123'),
                  ),
                );
              },
              child: const Text('Launch'),
            );
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Launch screen
      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      // Generate a valid code
      final String validCode = OTP.generateTOTPCodeString(
        secret,
        DateTime.now().millisecondsSinceEpoch,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      final Finder codeField = find.byType(AppTextField);
      await tester.enterText(codeField, validCode);
      await tester.pump();

      await tester.tap(find.text('Verify Code'));
      await tester.pumpAndSettle();

      // Ensure verification screen popped and returned true
      expect(find.byType(TOTPVerificationScreen), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('tapping Cancel triggers signOut and pops back with false', (tester) async {
      TOTPService.getTotpSecretOverride = (String uid) async => 'JBSWY3DPEHPK3PXP';

      bool? result;

      await tester.pumpWidget(_hostApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => const TOTPVerificationScreen(uid: 'test_user_123'),
                  ),
                );
              },
              child: const Text('Launch'),
            );
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Launch screen
      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Ensure verification screen popped and returned false
      expect(find.byType(TOTPVerificationScreen), findsNothing);
      expect(result, isFalse);
    });
  });
}
