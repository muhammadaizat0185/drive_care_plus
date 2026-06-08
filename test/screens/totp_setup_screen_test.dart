import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otp/otp.dart';
import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/totp_setup_screen.dart';
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

void _configureViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TOTPSetupScreen.skipAuthCheck = true;
    TOTPService.enableTotpOverride = null;
    TOTPService.disableTotpOverride = null;
    TOTPService.checkIsTotpEnabledOverride = null;
    TOTPService.getTotpSecretOverride = null;
  });

  group('TOTPSetupScreen Widget Tests', () {
    testWidgets('entering invalid verification code displays error message', (tester) async {
      _configureViewport(tester);

      await tester.pumpWidget(_hostApp(child: const TOTPSetupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Step 1: Link your Authenticator App'), findsOneWidget);
      expect(find.text('Step 2: Enter Verification Code'), findsOneWidget);

      // Scroll into view if needed
      await tester.ensureVisible(find.text('Verify & Enable'));
      await tester.pumpAndSettle();

      // Enter an invalid code (Step 2 field is the second AppTextField)
      final Finder codeField = find.byType(AppTextField).at(1);
      
      await tester.enterText(codeField, '111111');
      await tester.pump();

      await tester.tap(find.text('Verify & Enable'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid validation code. Please check your authenticator app.'), findsOneWidget);
    });

    testWidgets('entering correct verification code triggers enableTotp and pops page', (tester) async {
      _configureViewport(tester);

      String? savedUid;
      String? savedSecret;

      // Mock database write
      TOTPService.enableTotpOverride = (String uid, String secret) async {
        savedUid = uid;
        savedSecret = secret;
      };

      await tester.pumpWidget(_hostApp(child: const TOTPSetupScreen()));
      await tester.pumpAndSettle();

      // Scroll into view if needed
      await tester.ensureVisible(find.text('Verify & Enable'));
      await tester.pumpAndSettle();

      // Retrieve the generated secret from the UI text field (first AppTextField)
      final Finder secretFieldFinder = find.byType(AppTextField).at(0);
      final AppTextField secretField = tester.widget<AppTextField>(secretFieldFinder);
      final String secret = secretField.controller!.text;

      // Generate a valid OTP code from that secret
      final String validCode = OTP.generateTOTPCodeString(
        secret,
        DateTime.now().millisecondsSinceEpoch,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      // Enter the valid OTP code
      final Finder codeField = find.byType(AppTextField).at(1);
      await tester.enterText(codeField, validCode);
      await tester.pump();

      await tester.tap(find.text('Verify & Enable'));
      await tester.pumpAndSettle();

      // Ensure Firestore write was triggered
      expect(savedSecret, secret);
      expect(savedUid, isNotNull);

      // Ensure setup page popped
      expect(find.byType(TOTPSetupScreen), findsNothing);
    });
  });
}
