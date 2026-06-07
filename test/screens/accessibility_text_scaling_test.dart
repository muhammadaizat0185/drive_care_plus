import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/screens/splash_screen.dart';
import 'package:drive_care_plus/screens/login_screen.dart';
import 'package:drive_care_plus/screens/register_screen.dart';
import 'package:drive_care_plus/screens/notifications_screen.dart';
import 'package:drive_care_plus/screens/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget hostAppWithScaler({
  required Widget child,
  required TextScaler textScaler,
  Brightness brightness = Brightness.light,
}) {
  final ThemeData theme =
      AppTheme.buildTheme(AppColors.emerald500, brightness);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    builder: (context, widget) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: widget!,
      );
    },
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Accessibility Text Scaling Reflow (Task 16.5)', () {
    final List<double> scalingFactors = [1.0, 1.25, 1.5, 1.75, 2.0];

    for (final double scale in scalingFactors) {
      testWidgets('SplashScreen reflows at scale $scale', (tester) async {
        await tester.pumpWidget(
          hostAppWithScaler(
            textScaler: TextScaler.linear(scale),
            child: const SplashScreen(
              homeScreenOverride: SizedBox(),
              loginScreenOverride: SizedBox(),
            ),
          ),
        );

        // Verify splash details are rendered
        expect(find.text('DriveCare+'), findsOneWidget);
        
        // Clean up transition timer
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('LoginScreen reflows at scale $scale', (tester) async {
        await tester.pumpWidget(
          hostAppWithScaler(
            textScaler: TextScaler.linear(scale),
            child: const LoginScreen(),
          ),
        );

        expect(find.byType(LoginScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('RegisterScreen reflows at scale $scale', (tester) async {
        await tester.pumpWidget(
          hostAppWithScaler(
            textScaler: TextScaler.linear(scale),
            child: const RegisterScreen(),
          ),
        );

        expect(find.byType(RegisterScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('NotificationsScreen reflows at scale $scale', (tester) async {
        await tester.pumpWidget(
          hostAppWithScaler(
            textScaler: TextScaler.linear(scale),
            child: const NotificationsScreen(),
          ),
        );

        expect(find.byType(NotificationsScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('MaintenanceScreen reflows at scale $scale', (tester) async {
        await tester.pumpWidget(
          hostAppWithScaler(
            textScaler: TextScaler.linear(scale),
            child: const MaintenanceScreen(),
          ),
        );

        expect(find.byType(MaintenanceScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
      });
    }
  });
}
