// Feature: figma-ui-redesign, Property 2: atomic theme rebuild for presets
//
// Validates: Requirements 2.6
//
// For any `Color seed` in `ThemeService.presets.values`, the atomic
// `AppTheme.buildThemePair(seed)` wrapper (Task 2.5) must produce a
// `(light, dark)` pair where:
//
//   1. Both surfaces carry the same seed-derived brand palette
//      `(emerald500, emerald600, teal400, teal500)` in their `AppColorsExt`.
//      The expected palette is computed from the seed via
//      `derivePalette(seed)` (Task 2.2).
//   2. All other "non-color" token extensions — `AppSpacingExt`,
//      `AppRadiiExt`, `AppMotionExt`, `AppTypographyExt` — are present on
//      both surfaces and have field-identical values across light and dark
//      (these tokens are mode-invariant by design).
//   3. The semantic / surface slots of `AppColorsExt` (success, warning,
//      error, info, surfaceSubtle/Medium/Prominent) are identical across
//      light and dark; only the neutral slots (background, foreground, card,
//      muted, border) are mode-specific by design.
//   4. `AppShadowsExt` is present on both surfaces. Light/dark shadow
//      *opacity* may differ (the design intent: dark mode multiplies opacity
//      by `darkOpacityMultiplier = 2.5`), but every other shadow field
//      (`blurRadius`, `spreadRadius`, `offset`, `blurStyle`) and the list
//      length must match between light and dark.
//
// The generator picks an index into `ThemeService.presets.values.toList()`
// (7 presets at the time of writing) so every preset is exercised. Glados
// is configured for 200 runs to comfortably exceed the 100-iteration minimum
// required by the task.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/color_utils.dart';
import 'package:drive_care_plus/core/theme/tokens/theme_extensions.dart';
import 'package:drive_care_plus/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`.
import 'package:glados/glados.dart'
    hide
        expect,
        equals,
        closeTo,
        isFalse,
        isTrue,
        isNotNull,
        inInclusiveRange,
        test,
        group,
        setUp,
        tearDown,
        setUpAll,
        tearDownAll,
        addTearDown;

/// Snapshot of the preset list used by the generator. `ThemeService.presets`
/// is a `static const Map<String, Color>` so this list is stable across the
/// test run; capturing it here gives the generator a deterministic index
/// space and avoids re-evaluating `.toList()` on every iteration.
final List<Color> _presetColors = ThemeService.presets.values.toList();

void main() {
  // The generator picks an integer index into `_presetColors`. The property
  // body looks up the corresponding `Color` so Glados can shrink toward
  // smaller indices when a preset triggers a counterexample.
  Glados<int>(
    any.intInRange(0, _presetColors.length),
    ExploreConfig(numRuns: 200),
  ).test(
    'AppTheme.buildThemePair(presetSeed): light and dark carry the same '
    'seed-derived brand palette in AppColorsExt; non-color tokens are '
    'identical across modes; shadow lists match in shape (opacity may differ)',
    (presetIndex) {
      final Color seed = _presetColors[presetIndex];

      // Atomic theme pair (Task 2.5 / Requirement 2.6, 2.8).
      final pair = AppTheme.buildThemePair(seed);
      final ThemeData light = pair.light;
      final ThemeData dark = pair.dark;

      // Expected brand palette derived from the preset seed.
      final expectedPalette = derivePalette(seed);

      // ---------------------------------------------------------------------
      // AppColorsExt — must be present on both surfaces and carry the same
      // seed-derived brand palette.
      // ---------------------------------------------------------------------
      final AppColorsExt? lightColors = light.extension<AppColorsExt>();
      final AppColorsExt? darkColors = dark.extension<AppColorsExt>();
      expect(lightColors, isNotNull, reason: 'AppColorsExt on light theme');
      expect(darkColors, isNotNull, reason: 'AppColorsExt on dark theme');

      // Brand palette parity: lightExt.<stop> == darkExt.<stop> == expected.
      expect(lightColors!.emerald500, equals(expectedPalette.emerald500),
          reason: 'light.emerald500 == derivePalette(seed).emerald500');
      expect(darkColors!.emerald500, equals(expectedPalette.emerald500),
          reason: 'dark.emerald500 == derivePalette(seed).emerald500');
      expect(lightColors.emerald500, equals(darkColors.emerald500),
          reason: 'light.emerald500 == dark.emerald500');

      expect(lightColors.emerald600, equals(expectedPalette.emerald600),
          reason: 'light.emerald600 == derivePalette(seed).emerald600');
      expect(darkColors.emerald600, equals(expectedPalette.emerald600),
          reason: 'dark.emerald600 == derivePalette(seed).emerald600');
      expect(lightColors.emerald600, equals(darkColors.emerald600),
          reason: 'light.emerald600 == dark.emerald600');

      expect(lightColors.teal400, equals(expectedPalette.teal400),
          reason: 'light.teal400 == derivePalette(seed).teal400');
      expect(darkColors.teal400, equals(expectedPalette.teal400),
          reason: 'dark.teal400 == derivePalette(seed).teal400');
      expect(lightColors.teal400, equals(darkColors.teal400),
          reason: 'light.teal400 == dark.teal400');

      expect(lightColors.teal500, equals(expectedPalette.teal500),
          reason: 'light.teal500 == derivePalette(seed).teal500');
      expect(darkColors.teal500, equals(expectedPalette.teal500),
          reason: 'dark.teal500 == derivePalette(seed).teal500');
      expect(lightColors.teal500, equals(darkColors.teal500),
          reason: 'light.teal500 == dark.teal500');

      // Semantic colors and surface opacities are mode-invariant: identical
      // between light and dark. Neutrals (background/foreground/card/
      // muted/border) are mode-specific by design (Requirements 2.1, 2.2)
      // so they are not compared here.
      expect(lightColors.success, equals(darkColors.success),
          reason: 'AppColorsExt.success unchanged across modes');
      expect(lightColors.warning, equals(darkColors.warning),
          reason: 'AppColorsExt.warning unchanged across modes');
      expect(lightColors.error, equals(darkColors.error),
          reason: 'AppColorsExt.error unchanged across modes');
      expect(lightColors.info, equals(darkColors.info),
          reason: 'AppColorsExt.info unchanged across modes');
      expect(lightColors.surfaceSubtle, equals(darkColors.surfaceSubtle),
          reason: 'AppColorsExt.surfaceSubtle unchanged across modes');
      expect(lightColors.surfaceMedium, equals(darkColors.surfaceMedium),
          reason: 'AppColorsExt.surfaceMedium unchanged across modes');
      expect(lightColors.surfaceProminent, equals(darkColors.surfaceProminent),
          reason: 'AppColorsExt.surfaceProminent unchanged across modes');

      // ---------------------------------------------------------------------
      // AppSpacingExt — present on both, every field identical.
      // ---------------------------------------------------------------------
      final AppSpacingExt? lightSpacing = light.extension<AppSpacingExt>();
      final AppSpacingExt? darkSpacing = dark.extension<AppSpacingExt>();
      expect(lightSpacing, isNotNull, reason: 'AppSpacingExt on light');
      expect(darkSpacing, isNotNull, reason: 'AppSpacingExt on dark');
      expect(lightSpacing!.xs, equals(darkSpacing!.xs), reason: 'spacing.xs');
      expect(lightSpacing.sm, equals(darkSpacing.sm), reason: 'spacing.sm');
      expect(lightSpacing.md, equals(darkSpacing.md), reason: 'spacing.md');
      expect(lightSpacing.lg, equals(darkSpacing.lg), reason: 'spacing.lg');
      expect(lightSpacing.xl, equals(darkSpacing.xl), reason: 'spacing.xl');
      expect(lightSpacing.xxl, equals(darkSpacing.xxl), reason: 'spacing.xxl');
      expect(lightSpacing.xxxl, equals(darkSpacing.xxxl),
          reason: 'spacing.xxxl');
      expect(lightSpacing.xxxxl, equals(darkSpacing.xxxxl),
          reason: 'spacing.xxxxl');

      // ---------------------------------------------------------------------
      // AppRadiiExt — present on both, every field identical.
      // ---------------------------------------------------------------------
      final AppRadiiExt? lightRadii = light.extension<AppRadiiExt>();
      final AppRadiiExt? darkRadii = dark.extension<AppRadiiExt>();
      expect(lightRadii, isNotNull, reason: 'AppRadiiExt on light');
      expect(darkRadii, isNotNull, reason: 'AppRadiiExt on dark');
      expect(lightRadii!.small, equals(darkRadii!.small), reason: 'radii.small');
      expect(lightRadii.medium, equals(darkRadii.medium),
          reason: 'radii.medium');
      expect(lightRadii.large, equals(darkRadii.large), reason: 'radii.large');
      expect(lightRadii.xLarge, equals(darkRadii.xLarge),
          reason: 'radii.xLarge');

      // ---------------------------------------------------------------------
      // AppMotionExt — present on both, every field identical.
      // ---------------------------------------------------------------------
      final AppMotionExt? lightMotion = light.extension<AppMotionExt>();
      final AppMotionExt? darkMotion = dark.extension<AppMotionExt>();
      expect(lightMotion, isNotNull, reason: 'AppMotionExt on light');
      expect(darkMotion, isNotNull, reason: 'AppMotionExt on dark');
      expect(lightMotion!.fast, equals(darkMotion!.fast),
          reason: 'motion.fast');
      expect(lightMotion.normal, equals(darkMotion.normal),
          reason: 'motion.normal');
      expect(lightMotion.slow, equals(darkMotion.slow),
          reason: 'motion.slow');
      expect(lightMotion.standard, equals(darkMotion.standard),
          reason: 'motion.standard');
      expect(lightMotion.emphasized, equals(darkMotion.emphasized),
          reason: 'motion.emphasized');

      // ---------------------------------------------------------------------
      // AppTypographyExt — present on both, every field identical. The token
      // `TextStyle`s do not bake in a foreground color (color is applied at
      // theme-build time on the `TextTheme`), so the underlying styles must
      // be identical between light and dark.
      // ---------------------------------------------------------------------
      final AppTypographyExt? lightTypo = light.extension<AppTypographyExt>();
      final AppTypographyExt? darkTypo = dark.extension<AppTypographyExt>();
      expect(lightTypo, isNotNull, reason: 'AppTypographyExt on light');
      expect(darkTypo, isNotNull, reason: 'AppTypographyExt on dark');
      expect(lightTypo!.display, equals(darkTypo!.display),
          reason: 'typography.display');
      expect(lightTypo.headlineLarge, equals(darkTypo.headlineLarge),
          reason: 'typography.headlineLarge');
      expect(lightTypo.headline, equals(darkTypo.headline),
          reason: 'typography.headline');
      expect(lightTypo.title, equals(darkTypo.title),
          reason: 'typography.title');
      expect(lightTypo.bodyLarge, equals(darkTypo.bodyLarge),
          reason: 'typography.bodyLarge');
      expect(lightTypo.body, equals(darkTypo.body),
          reason: 'typography.body');
      expect(lightTypo.label, equals(darkTypo.label),
          reason: 'typography.label');

      // ---------------------------------------------------------------------
      // AppShadowsExt — present on both surfaces. Per the design intent
      // (Requirement 1.8), dark-mode shadows have their *opacity* multiplied
      // by `darkOpacityMultiplier = 2.5` and clamped to `[0.0, 1.0]`. Every
      // other field — list length, RGB channels, blurRadius, spreadRadius,
      // offset, blurStyle — must match light/dark within each list.
      // ---------------------------------------------------------------------
      final AppShadowsExt? lightShadows = light.extension<AppShadowsExt>();
      final AppShadowsExt? darkShadows = dark.extension<AppShadowsExt>();
      expect(lightShadows, isNotNull, reason: 'AppShadowsExt on light');
      expect(darkShadows, isNotNull, reason: 'AppShadowsExt on dark');
      expect(lightShadows!.darkOpacityMultiplier,
          equals(darkShadows!.darkOpacityMultiplier),
          reason: 'shadows.darkOpacityMultiplier');

      _expectShadowListShapeMatches(
        lightShadows.small,
        darkShadows.small,
        listName: 'small',
      );
      _expectShadowListShapeMatches(
        lightShadows.medium,
        darkShadows.medium,
        listName: 'medium',
      );
      _expectShadowListShapeMatches(
        lightShadows.large,
        darkShadows.large,
        listName: 'large',
      );
      _expectShadowListShapeMatches(
        lightShadows.xLarge,
        darkShadows.xLarge,
        listName: 'xLarge',
      );
    },
  );
}

/// Asserts two `List<BoxShadow>`s have the same length and that every paired
/// shadow shares the same shape — RGB channels, blurRadius, spreadRadius,
/// offset, and blurStyle. Alpha is allowed to differ (light/dark opacity
/// multiplier).
void _expectShadowListShapeMatches(
  List<BoxShadow> lightList,
  List<BoxShadow> darkList, {
  required String listName,
}) {
  expect(lightList.length, equals(darkList.length),
      reason: 'shadows.$listName list length matches');
  for (int i = 0; i < lightList.length; i++) {
    final BoxShadow l = lightList[i];
    final BoxShadow d = darkList[i];
    expect(l.color.r, equals(d.color.r),
        reason: 'shadows.$listName[$i].color.r preserved');
    expect(l.color.g, equals(d.color.g),
        reason: 'shadows.$listName[$i].color.g preserved');
    expect(l.color.b, equals(d.color.b),
        reason: 'shadows.$listName[$i].color.b preserved');
    expect(l.blurRadius, equals(d.blurRadius),
        reason: 'shadows.$listName[$i].blurRadius preserved');
    expect(l.spreadRadius, equals(d.spreadRadius),
        reason: 'shadows.$listName[$i].spreadRadius preserved');
    expect(l.offset, equals(d.offset),
        reason: 'shadows.$listName[$i].offset preserved');
    expect(l.blurStyle, equals(d.blurStyle),
        reason: 'shadows.$listName[$i].blurStyle preserved');
  }
}
