// Feature: figma-ui-redesign — Unit tests for `AppTheme.buildTheme`
//
// Validates: Requirements 2.1, 2.2, 2.10, 2.11
//
// These unit tests exercise `AppTheme.buildTheme(seed, brightness)` end-to-
// end and assert that the produced `ThemeData` carries the canonical
// design-token values on every slot the redesign relies on:
//
//   * Requirement 2.1 — Light neutrals on `scaffoldBackgroundColor`,
//     `colorScheme.onSurface`, and the `AppColorsExt` `foreground`/`card`/
//     `muted`/`border` slots match the exact hex literals
//     (#FFFFFF, #111827, #FFFFFF, #ECECF0, 0x1A000000).
//
//   * Requirement 2.2 — Dark neutrals on `scaffoldBackgroundColor`,
//     `colorScheme.onSurface`, and the `AppColorsExt` `foreground`/`card`/
//     `muted`/`border` slots match the canonical OKLCH→sRGB conversions
//     (#1A1A1A, #FAFAFA, #1A1A1A, #373737). The `AppColors` literals are
//     pre-frozen at exactly the canonical values so the ±1-per-channel
//     tolerance from the requirement collapses to a strict equality check.
//
//   * Requirement 2.10 — Every Material `TextTheme` slot wired by the
//     theme builder carries the `fontSize` and `fontWeight` mandated by
//     `AppTypography`:
//       displayLarge   → 32 / w900
//       headlineLarge  → 24 / w900
//       headlineMedium → 20 / w800
//       titleLarge     → 16 / w700
//       bodyLarge      → 14 / w400
//       bodyMedium     → 12 / w400
//       labelSmall     → 10 / w700
//
//   * Requirement 2.11 — All six `ThemeExtension` adapters
//     (`AppColorsExt`, `AppSpacingExt`, `AppRadiiExt`, `AppShadowsExt`,
//     `AppMotionExt`, `AppTypographyExt`) are registered and non-null on
//     both the light and dark themes returned by the builder.
//
// The themes are built once at the top of `main()` using the canonical
// brand seed `AppColors.emerald500` so each test reads from the same
// `ThemeData` instance — keeps the tests cheap to run and guarantees the
// assertions describe a single coherent build of the design system.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/app_colors.dart';
import 'package:drive_care_plus/core/theme/tokens/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Build the canonical light + dark themes once per `main()` invocation so
  // every test below reads from the same `ThemeData` instance. The brand
  // seed is `AppColors.emerald500` — for that seed `derivePalette` returns
  // the literal brand palette, which keeps any palette-related assertions
  // in this file byte-perfect.
  // ---------------------------------------------------------------------------
  final ThemeData light =
      AppTheme.buildTheme(AppColors.emerald500, Brightness.light);
  final ThemeData dark =
      AppTheme.buildTheme(AppColors.emerald500, Brightness.dark);

  // =========================================================================
  // Requirement 2.1 — Light neutrals
  // =========================================================================
  group('AppTheme.buildTheme(light) — neutrals (Requirement 2.1)', () {
    test('scaffoldBackgroundColor == #FFFFFF', () {
      expect(
        light.scaffoldBackgroundColor,
        equals(const Color(0xFFFFFFFF)),
        reason: 'Light_Theme background must equal AppColors.lightBackground',
      );
    });

    test('colorScheme.onSurface == #111827', () {
      // `onSurface` is the foreground slot wired by `buildTheme` so widgets
      // that read `Theme.of(context).colorScheme.onSurface` resolve to the
      // canonical Light_Theme foreground.
      expect(
        light.colorScheme.onSurface,
        equals(const Color(0xFF111827)),
        reason: 'Light_Theme foreground must equal AppColors.lightForeground',
      );
    });

    test('AppColorsExt.foreground == #111827', () {
      final AppColorsExt? ext = light.extension<AppColorsExt>();
      expect(ext, isNotNull);
      expect(ext!.foreground, equals(const Color(0xFF111827)));
    });

    test('AppColorsExt.card == #FFFFFF', () {
      final AppColorsExt ext = light.extension<AppColorsExt>()!;
      expect(ext.card, equals(const Color(0xFFFFFFFF)));
    });

    test('AppColorsExt.muted == #ECECF0', () {
      final AppColorsExt ext = light.extension<AppColorsExt>()!;
      expect(ext.muted, equals(const Color(0xFFECECF0)));
    });

    test('AppColorsExt.border == rgba(0, 0, 0, 0.1) → 0x1A000000', () {
      final AppColorsExt ext = light.extension<AppColorsExt>()!;
      expect(ext.border, equals(const Color(0x1A000000)));
    });

    test('AppColorsExt.background == #FFFFFF', () {
      final AppColorsExt ext = light.extension<AppColorsExt>()!;
      expect(ext.background, equals(const Color(0xFFFFFFFF)));
    });
  });

  // =========================================================================
  // Requirement 2.2 — Dark neutrals
  //
  // The `AppColors` dark-mode literals are pre-frozen at exactly the
  // canonical OKLCH→sRGB conversion targets, so the ±1-per-channel
  // tolerance described in Requirement 2.2 collapses to a strict equality
  // check against the literal values.
  // =========================================================================
  group('AppTheme.buildTheme(dark) — neutrals (Requirement 2.2)', () {
    test('scaffoldBackgroundColor == #1A1A1A (oklch(0.145 0 0))', () {
      expect(
        dark.scaffoldBackgroundColor,
        equals(const Color(0xFF1A1A1A)),
        reason: 'Dark_Theme background must equal AppColors.darkBackground',
      );
    });

    test('colorScheme.onSurface == #FAFAFA (oklch(0.985 0 0))', () {
      expect(
        dark.colorScheme.onSurface,
        equals(const Color(0xFFFAFAFA)),
        reason: 'Dark_Theme foreground must equal AppColors.darkForeground',
      );
    });

    test('AppColorsExt.background == #1A1A1A', () {
      final AppColorsExt ext = dark.extension<AppColorsExt>()!;
      expect(ext.background, equals(const Color(0xFF1A1A1A)));
    });

    test('AppColorsExt.foreground == #FAFAFA', () {
      final AppColorsExt ext = dark.extension<AppColorsExt>()!;
      expect(ext.foreground, equals(const Color(0xFFFAFAFA)));
    });

    test('AppColorsExt.card == #1A1A1A', () {
      final AppColorsExt ext = dark.extension<AppColorsExt>()!;
      expect(ext.card, equals(const Color(0xFF1A1A1A)));
    });

    test('AppColorsExt.border == #373737 (oklch(0.269 0 0))', () {
      final AppColorsExt ext = dark.extension<AppColorsExt>()!;
      expect(ext.border, equals(const Color(0xFF373737)));
    });

    test('AppColorsExt dark neutrals lie within ±1 per channel of the '
        'canonical OKLCH→sRGB conversion targets', () {
      // Reference targets from the Reference_Source OKLCH values:
      //   oklch(0.145 0 0) → #1A1A1A
      //   oklch(0.985 0 0) → #FAFAFA
      //   oklch(0.269 0 0) → #373737
      //
      // Asserting per-channel deltas is a stronger statement than the
      // strict equality checks above: it documents the tolerance window
      // mandated by Requirement 2.2 and would still pass if the literals
      // were ever re-derived to within that window.
      const Color bgRef = Color(0xFF1A1A1A);
      const Color fgRef = Color(0xFFFAFAFA);
      const Color borderRef = Color(0xFF373737);

      final AppColorsExt ext = dark.extension<AppColorsExt>()!;
      _expectChannelsWithin(ext.background, bgRef, tolerance: 1);
      _expectChannelsWithin(ext.card, bgRef, tolerance: 1);
      _expectChannelsWithin(ext.foreground, fgRef, tolerance: 1);
      _expectChannelsWithin(ext.border, borderRef, tolerance: 1);
    });
  });

  // =========================================================================
  // Requirement 2.10 — TextTheme slot wiring
  // =========================================================================
  group('AppTheme.buildTheme — textTheme slots (Requirement 2.10)', () {
    test('displayLarge has fontSize=32 and fontWeight=w900', () {
      _expectFontSizeAndWeight(
        light.textTheme.displayLarge,
        size: 32,
        weight: FontWeight.w900,
        slotName: 'displayLarge',
      );
      _expectFontSizeAndWeight(
        dark.textTheme.displayLarge,
        size: 32,
        weight: FontWeight.w900,
        slotName: 'displayLarge',
      );
    });

    test('headlineLarge has fontSize=24 and fontWeight=w900', () {
      _expectFontSizeAndWeight(
        light.textTheme.headlineLarge,
        size: 24,
        weight: FontWeight.w900,
        slotName: 'headlineLarge',
      );
      _expectFontSizeAndWeight(
        dark.textTheme.headlineLarge,
        size: 24,
        weight: FontWeight.w900,
        slotName: 'headlineLarge',
      );
    });

    test('headlineMedium has fontSize=20 and fontWeight=w800', () {
      _expectFontSizeAndWeight(
        light.textTheme.headlineMedium,
        size: 20,
        weight: FontWeight.w800,
        slotName: 'headlineMedium',
      );
      _expectFontSizeAndWeight(
        dark.textTheme.headlineMedium,
        size: 20,
        weight: FontWeight.w800,
        slotName: 'headlineMedium',
      );
    });

    test('titleLarge has fontSize=16 and fontWeight=w700', () {
      _expectFontSizeAndWeight(
        light.textTheme.titleLarge,
        size: 16,
        weight: FontWeight.w700,
        slotName: 'titleLarge',
      );
      _expectFontSizeAndWeight(
        dark.textTheme.titleLarge,
        size: 16,
        weight: FontWeight.w700,
        slotName: 'titleLarge',
      );
    });

    test('bodyLarge has fontSize=14 and fontWeight=w400', () {
      _expectFontSizeAndWeight(
        light.textTheme.bodyLarge,
        size: 14,
        weight: FontWeight.w400,
        slotName: 'bodyLarge',
      );
      _expectFontSizeAndWeight(
        dark.textTheme.bodyLarge,
        size: 14,
        weight: FontWeight.w400,
        slotName: 'bodyLarge',
      );
    });

    test('bodyMedium has fontSize=12 and fontWeight=w400', () {
      _expectFontSizeAndWeight(
        light.textTheme.bodyMedium,
        size: 12,
        weight: FontWeight.w400,
        slotName: 'bodyMedium',
      );
      _expectFontSizeAndWeight(
        dark.textTheme.bodyMedium,
        size: 12,
        weight: FontWeight.w400,
        slotName: 'bodyMedium',
      );
    });

    test('labelSmall has fontSize=10 and fontWeight=w700', () {
      _expectFontSizeAndWeight(
        light.textTheme.labelSmall,
        size: 10,
        weight: FontWeight.w700,
        slotName: 'labelSmall',
      );
      _expectFontSizeAndWeight(
        dark.textTheme.labelSmall,
        size: 10,
        weight: FontWeight.w700,
        slotName: 'labelSmall',
      );
    });
  });

  // =========================================================================
  // Requirement 2.11 — All six ThemeExtensions registered
  // =========================================================================
  group('AppTheme.buildTheme — registered ThemeExtensions '
      '(Requirement 2.11)', () {
    test('Light_Theme registers AppColorsExt', () {
      expect(light.extension<AppColorsExt>(), isNotNull);
    });

    test('Light_Theme registers AppSpacingExt', () {
      expect(light.extension<AppSpacingExt>(), isNotNull);
    });

    test('Light_Theme registers AppRadiiExt', () {
      expect(light.extension<AppRadiiExt>(), isNotNull);
    });

    test('Light_Theme registers AppShadowsExt', () {
      expect(light.extension<AppShadowsExt>(), isNotNull);
    });

    test('Light_Theme registers AppMotionExt', () {
      expect(light.extension<AppMotionExt>(), isNotNull);
    });

    test('Light_Theme registers AppTypographyExt', () {
      expect(light.extension<AppTypographyExt>(), isNotNull);
    });

    test('Dark_Theme registers AppColorsExt', () {
      expect(dark.extension<AppColorsExt>(), isNotNull);
    });

    test('Dark_Theme registers AppSpacingExt', () {
      expect(dark.extension<AppSpacingExt>(), isNotNull);
    });

    test('Dark_Theme registers AppRadiiExt', () {
      expect(dark.extension<AppRadiiExt>(), isNotNull);
    });

    test('Dark_Theme registers AppShadowsExt', () {
      expect(dark.extension<AppShadowsExt>(), isNotNull);
    });

    test('Dark_Theme registers AppMotionExt', () {
      expect(dark.extension<AppMotionExt>(), isNotNull);
    });

    test('Dark_Theme registers AppTypographyExt', () {
      expect(dark.extension<AppTypographyExt>(), isNotNull);
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

/// Asserts that [actual] has the expected `fontSize` and `fontWeight`. The
/// theme builder applies a foreground color via `copyWith`, so the
/// underlying `TextStyle` is non-null and only the size + weight are
/// pinned by the design tokens.
void _expectFontSizeAndWeight(
  TextStyle? actual, {
  required double size,
  required FontWeight weight,
  required String slotName,
}) {
  expect(
    actual,
    isNotNull,
    reason: 'TextTheme.$slotName must be wired by AppTheme.buildTheme',
  );
  expect(
    actual!.fontSize,
    equals(size),
    reason: 'TextTheme.$slotName.fontSize',
  );
  expect(
    actual.fontWeight,
    equals(weight),
    reason: 'TextTheme.$slotName.fontWeight',
  );
}

/// Asserts that each of the R/G/B/A 8-bit channels of [actual] is within
/// [tolerance] of the corresponding channel of [reference].
///
/// `Color` exposes channels as doubles in `[0.0, 1.0]`. We multiply by 255
/// and round to compare against the canonical OKLCH→sRGB targets in the
/// 8-bit space mandated by Requirement 2.2.
void _expectChannelsWithin(
  Color actual,
  Color reference, {
  required int tolerance,
}) {
  int to8bit(double v) => (v * 255.0).round();

  final int aActual = to8bit(actual.a);
  final int rActual = to8bit(actual.r);
  final int gActual = to8bit(actual.g);
  final int bActual = to8bit(actual.b);

  final int aRef = to8bit(reference.a);
  final int rRef = to8bit(reference.r);
  final int gRef = to8bit(reference.g);
  final int bRef = to8bit(reference.b);

  expect(
    (aActual - aRef).abs(),
    lessThanOrEqualTo(tolerance),
    reason: 'alpha channel out of tolerance: actual=$aActual ref=$aRef',
  );
  expect(
    (rActual - rRef).abs(),
    lessThanOrEqualTo(tolerance),
    reason: 'red channel out of tolerance: actual=$rActual ref=$rRef',
  );
  expect(
    (gActual - gRef).abs(),
    lessThanOrEqualTo(tolerance),
    reason: 'green channel out of tolerance: actual=$gActual ref=$gRef',
  );
  expect(
    (bActual - bRef).abs(),
    lessThanOrEqualTo(tolerance),
    reason: 'blue channel out of tolerance: actual=$bActual ref=$bRef',
  );
}
