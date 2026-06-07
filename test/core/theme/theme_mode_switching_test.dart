// Feature: figma-ui-redesign — Widget tests for `themeMode` switching
//
// Validates: Requirements 2.3, 2.4, 2.5
//
// These widget tests exercise the wiring between `ThemeService.themeMode`
// and `MaterialApp` so that:
//
//   * `ThemeMode.light` renders the `light` `ThemeData` on the next frame
//     (Requirement 2.3).
//   * `ThemeMode.dark` renders the `dark` `ThemeData` on the next frame
//     (Requirement 2.4).
//   * `ThemeMode.system` selects light or dark from
//     `MediaQuery.platformBrightnessOf(context)` and re-evaluates that
//     selection when the framework reports a platform brightness change
//     (Requirement 2.5).
//
// The tests build a minimal `MaterialApp` that listens to `ThemeService`
// using the same pattern as `lib/app.dart` (atomic light+dark pair via
// `AppTheme.buildThemePair`). The real `DriveCarePlusApp` is intentionally
// avoided because its route table boots Firebase, sqflite, and other
// platform services on first frame; the redesign of theme wiring does not
// require any of that machinery to exercise theme mode switching.
//
// `ThemeService` is a singleton that persists changes through
// `SharedPreferences`. `SharedPreferences.setMockInitialValues({})` in
// `setUp` provides an in-memory store so the persistence calls inside
// `setThemeMode` complete cleanly without touching the host filesystem.
// `tearDown` restores the singleton to a known baseline (`ThemeMode.light`
// and the canonical brand seed) so a failing test can never bleed state
// into subsequent tests in this file or elsewhere in the suite.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/app_colors.dart';
import 'package:drive_care_plus/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a minimal `MaterialApp` whose `theme`, `darkTheme`, and
/// `themeMode` are driven by [service]. Mirrors the listening pattern used
/// in `lib/app.dart` so the test surface behaves identically to the real
/// app for theme purposes.
///
/// The body of each route renders a `Text` whose value is the resolved
/// `Theme.of(context).brightness.name` (`"light"` or `"dark"`). Tests use
/// that string to assert which `ThemeData` Flutter actually applied to the
/// subtree on the current frame.
Widget _buildTestApp({required ThemeService service}) {
  return ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final pair = AppTheme.buildThemePair(service.primaryColor);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: pair.light,
        darkTheme: pair.dark,
        themeMode: service.themeMode,
        // `MaterialApp` wraps its `theme`/`darkTheme` in an `AnimatedTheme`
        // that interpolates over `kThemeAnimationDuration` (≈200 ms by
        // default). For the purposes of these tests we care about the
        // *target* `ThemeData` selected for a given `themeMode +
        // platformBrightness` combination, not the animation curve, so the
        // animation duration is zeroed to make the resolved
        // `Theme.of(context).brightness` flip on the very next frame.
        themeAnimationDuration: Duration.zero,
        home: Builder(
          builder: (innerContext) {
            // Read brightness from the inner context so the resolved
            // `ThemeData` reflects the `themeMode + platformBrightness`
            // selection performed by `MaterialApp` itself.
            final Brightness b = Theme.of(innerContext).brightness;
            return Scaffold(
              body: Center(
                child: Text(
                  'mode-${b.name}',
                  // Avoid pulling in any localization plumbing.
                  textDirection: TextDirection.ltr,
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

void main() {
  // ---------------------------------------------------------------------
  // Test fixture — provide an in-memory SharedPreferences store and reset
  // the `ThemeService` singleton so each test starts from the canonical
  // (`ThemeMode.light`, `AppColors.emerald500`) baseline.
  // ---------------------------------------------------------------------
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Drive the singleton back to a known baseline before each test. This
    // is necessary because `ThemeService.instance` is a process-global
    // and any prior test (or its tearDown) could have shifted `themeMode`
    // or `primaryColor` away from their defaults.
    await ThemeService.instance.setThemeMode(ThemeMode.light);
    await ThemeService.instance.setPrimaryColor(AppColors.emerald500);
  });

  tearDown(() async {
    // Restore the canonical baseline so a failing test cannot bleed into
    // other test files that share the same singleton.
    await ThemeService.instance.setThemeMode(ThemeMode.light);
    await ThemeService.instance.setPrimaryColor(AppColors.emerald500);
  });

  testWidgets(
    'ThemeMode.light renders the light ThemeData',
    (WidgetTester tester) async {
      await ThemeService.instance.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(_buildTestApp(service: ThemeService.instance));
      await tester.pump();

      // Resolved brightness on the inner subtree must be light.
      expect(find.text('mode-light'), findsOneWidget);
      expect(find.text('mode-dark'), findsNothing);

      // `MaterialApp.themeMode` reflects the service value.
      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, equals(ThemeMode.light));
    },
  );

  testWidgets(
    'Switching ThemeMode.light → ThemeMode.dark flips the resolved '
    'brightness on the next frame (Requirement 2.4)',
    (WidgetTester tester) async {
      // Start in light mode so the switch produces an observable diff.
      await ThemeService.instance.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(_buildTestApp(service: ThemeService.instance));
      await tester.pump();
      expect(find.text('mode-light'), findsOneWidget);

      // Mutate the singleton; `ListenableBuilder` rebuilds `MaterialApp`
      // with the new pair on the next frame.
      await ThemeService.instance.setThemeMode(ThemeMode.dark);
      await tester.pump();

      expect(find.text('mode-dark'), findsOneWidget);
      expect(find.text('mode-light'), findsNothing);

      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, equals(ThemeMode.dark));
    },
  );

  testWidgets(
    'ThemeMode.system tracks MediaQuery.platformBrightness changes '
    '(Requirement 2.5)',
    (WidgetTester tester) async {
      // Pin platform brightness to `dark` *before* mounting so the first
      // frame already resolves through the `system` path with a known
      // platform value.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await ThemeService.instance.setThemeMode(ThemeMode.system);

      await tester.pumpWidget(_buildTestApp(service: ThemeService.instance));
      await tester.pump();

      // `system` + `platformBrightness=dark` must resolve to dark.
      expect(find.text('mode-dark'), findsOneWidget,
          reason: 'system + platformBrightness=dark → dark theme');
      expect(find.text('mode-light'), findsNothing);

      // Flip the platform brightness; `MaterialApp` re-evaluates the
      // selection on the next frame without any `ThemeService` mutation.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();

      expect(find.text('mode-light'), findsOneWidget,
          reason: 'system + platformBrightness=light → light theme');
      expect(find.text('mode-dark'), findsNothing);

      // `themeMode` itself never changed.
      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, equals(ThemeMode.system));
    },
  );
}
