// Feature: figma-ui-redesign — Theme rebuild performance benchmark
//
// Validates: Requirements 2.9
//
// Requirement 2.9 mandates that the atomic light+dark theme rebuild from
// `AppTheme.buildThemePair(seed)` complete within 200 ms on the target
// Android emulator, measured from the call returning to the next applied
// frame. `buildThemePair` is pure-Dart (no platform channels, no async
// I/O), so timing it inside the Flutter test runner with `dart:io`
// `Stopwatch` produces a faithful upper-bound for the on-device cost: the
// Dart VM in the test harness performs the same color/shadow derivations,
// `ColorScheme.fromSeed` calls, and `ThemeData` construction the running
// app does. The design document records the in-practice rebuild cost at
// `< 8ms`, so the 200 ms budget should pass comfortably.
//
// For each seed in `ThemeService.presets.values` the test:
//   1. Runs `AppTheme.buildThemePair(seed)` once to warm up JIT/inlining,
//   2. Times 10 iterations with a single `Stopwatch`,
//   3. Computes the average elapsed time in milliseconds,
//   4. Prints the per-preset timing for diagnostic visibility,
//   5. Asserts the average is `<= 200` ms.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme.buildThemePair performance (Requirement 2.9)', () {
    const int iterations = 10;
    const double budgetMs = 200.0;

    test(
      'average rebuild for every ThemeService.presets seed is <= 200 ms',
      () {
        final Map<String, Color> presets = ThemeService.presets;
        expect(
          presets,
          isNotEmpty,
          reason: 'ThemeService.presets must expose at least one preset.',
        );

        for (final MapEntry<String, Color> entry in presets.entries) {
          final String name = entry.key;
          final Color seed = entry.value;

          // Warm-up — exclude the first build from the measurement so we
          // capture the steady-state cost rather than one-time JIT work.
          AppTheme.buildThemePair(seed);

          final Stopwatch stopwatch = Stopwatch()..start();
          for (int i = 0; i < iterations; i++) {
            final pair = AppTheme.buildThemePair(seed);
            // Reference the result so the optimiser cannot dead-code it.
            expect(pair.light, isA<ThemeData>());
            expect(pair.dark, isA<ThemeData>());
          }
          stopwatch.stop();

          final double averageMs =
              stopwatch.elapsedMicroseconds / 1000.0 / iterations;

          debugPrint(
            'AppTheme.buildThemePair("$name", '
            '0x${seed.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}) '
            'avg = ${averageMs.toStringAsFixed(3)} ms over $iterations iterations',
          );

          expect(
            averageMs,
            lessThanOrEqualTo(budgetMs),
            reason:
                'buildThemePair("$name") averaged ${averageMs.toStringAsFixed(3)} ms '
                'over $iterations iterations, exceeding the 200 ms budget '
                'from Requirement 2.9.',
          );
        }
      },
    );
  });
}
