// Feature: figma-ui-redesign, Property 3: non-preset rejection preserves themes
//
// Validates: Requirements 2.7, 2.8
//
// For any random `Color` that is *not* a member of `ThemeService.presets`,
// the preset validator (`setPrimaryColorValidated` from
// `lib/core/theme/preset_validator.dart`) must:
//
//   1. Reject the call by throwing `NonPresetColorError` (a subclass of
//      `ArgumentError`) so the caller is notified and can surface an error
//      to the user (Requirement 2.7 — "surface an error indication to the
//      caller").
//   2. Leave the previously applied `(theme, darkTheme)` pair byte-identical.
//      Because the validator is a pure-validation guard that throws *before*
//      delegating to `ThemeService.setPrimaryColor`, no `ThemeService` state
//      is mutated and the themes derived from
//      `ThemeService.instance.primaryColor` therefore remain unchanged
//      (Requirement 2.7 — "retain the previously applied Light_Theme and
//      Dark_Theme without modification" — and Requirement 2.8 — atomicity
//      preserved by leaving the cached pair untouched on failure).
//
// The generator produces a random ARGB `Color` from four independent
// `intInRange(0, 256)` channel axes, then the test body skips any iteration
// where the generated color happens to coincide with one of the (very few)
// preset colors so the property body only exercises non-preset inputs. With
// 7 presets distributed across the 2^32 ARGB space, this filter virtually
// never fires — but skipping is the correct behavior when it does, because
// the property is scoped to non-preset inputs only.
//
// The "byte-identical themes" check rebuilds the `(light, dark)` pair from
// `ThemeService.instance.primaryColor` *before* and *after* the rejected
// validator call and compares the relevant `ThemeExtension` fields and
// `ColorScheme` slots field-by-field. Because `AppTheme.buildThemePair` is
// pure and deterministic, two builds from the same seed must produce
// equivalent themes; any divergence would prove that `ThemeService` had
// been mutated by the rejected call, which Requirement 2.7 forbids.
//
// Glados is configured for 200 runs to comfortably exceed the 100-iteration
// minimum required by the task.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/preset_validator.dart';
import 'package:drive_care_plus/core/theme/tokens/theme_extensions.dart';
import 'package:drive_care_plus/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`.
import 'package:glados/glados.dart'
    hide
        expect,
        expectLater,
        equals,
        closeTo,
        isFalse,
        isTrue,
        isNotNull,
        isA,
        inInclusiveRange,
        throwsA,
        test,
        group,
        setUp,
        tearDown,
        setUpAll,
        tearDownAll,
        addTearDown;

/// Holder for an ARGB color with each channel as an independently shrinkable
/// integer axis in `[0, 255]`. Using four small axes (rather than a single
/// 32-bit value) keeps shrinking precise: when a counterexample is found,
/// Glados can pinpoint which channel triggered the failure.
class _ColorSpec {
  const _ColorSpec({
    required this.a,
    required this.r,
    required this.g,
    required this.b,
  });

  final int a;
  final int r;
  final int g;
  final int b;

  Color toColor() => Color.fromARGB(a, r, g, b);
}

Generator<_ColorSpec> _colorSpecGenerator() {
  // `intInRange(0, 256)` yields ints in `[0, 255]` inclusive (the upper
  // bound is exclusive in Glados' `intInRange`). Each channel is an
  // independent axis so Glados can shrink any counterexample to a minimal
  // ARGB tuple.
  return any.combine4<int, int, int, int, _ColorSpec>(
    any.intInRange(0, 256),
    any.intInRange(0, 256),
    any.intInRange(0, 256),
    any.intInRange(0, 256),
    (a, r, g, b) => _ColorSpec(a: a, r: r, g: g, b: b),
  );
}

void main() {
  Glados<_ColorSpec>(
    _colorSpecGenerator(),
    ExploreConfig(numRuns: 200),
  ).test(
    'setPrimaryColorValidated(nonPreset) throws NonPresetColorError and '
    'leaves the ThemeService primaryColor and the derived (light, dark) '
    'theme pair byte-identical',
    (spec) async {
      final Color generatedColor = spec.toColor();

      // Scope the property to non-preset inputs. The preset list is tiny
      // (7 entries) compared to the 2^32 ARGB space, so this filter
      // virtually never fires; when it does, skipping is the correct
      // behavior because Property 3 is defined only over non-preset colors.
      if (isPresetColor(generatedColor)) {
        return;
      }

      // -----------------------------------------------------------------
      // Capture the pre-call ThemeService state and the (light, dark) pair
      // derived from it. The pair is computed via `AppTheme.buildThemePair`
      // directly (no `ThemeService` mutation), so this snapshot is purely
      // observational.
      // -----------------------------------------------------------------
      final Color primaryBefore = ThemeService.instance.primaryColor;
      final pairBefore = AppTheme.buildThemePair(primaryBefore);

      // -----------------------------------------------------------------
      // Property part 1: the validator rejects the call by throwing
      // `NonPresetColorError` (a subclass of `ArgumentError`). The error
      // is the "error indication to the caller" mandated by Req 2.7.
      // -----------------------------------------------------------------
      await expectLater(
        () => setPrimaryColorValidated(generatedColor),
        throwsA(isA<NonPresetColorError>()),
      );

      // -----------------------------------------------------------------
      // Property part 2: `ThemeService.instance.primaryColor` is byte-
      // identical to its pre-call value. The validator throws *before*
      // delegating to `ThemeService.setPrimaryColor`, so the singleton's
      // state must not have shifted (Req 2.7).
      // -----------------------------------------------------------------
      final Color primaryAfter = ThemeService.instance.primaryColor;
      expect(primaryAfter, equals(primaryBefore),
          reason: 'ThemeService.primaryColor unchanged after rejected call');

      // -----------------------------------------------------------------
      // Property part 3: the (light, dark) theme pair derived from
      // `ThemeService.primaryColor` is byte-identical to the pre-call pair.
      // `AppTheme.buildThemePair` is pure and deterministic, so any
      // divergence would prove the ThemeService was mutated by the
      // rejected call — which Req 2.7 forbids.
      // -----------------------------------------------------------------
      final pairAfter = AppTheme.buildThemePair(primaryAfter);
      _expectThemePairsByteIdentical(pairBefore, pairAfter);
    },
  );
}

/// Asserts the light and dark `ThemeData` instances in `before` and `after`
/// are byte-identical with respect to every design-system surface the
/// redesign relies on: the `ColorScheme` slots, the scaffold background, the
/// brightness, and every `ThemeExtension` registered by
/// `AppTheme.buildTheme` (Requirement 2.11).
void _expectThemePairsByteIdentical(
  ({ThemeData light, ThemeData dark}) before,
  ({ThemeData light, ThemeData dark}) after,
) {
  _expectThemeDataByteIdentical(before.light, after.light, surface: 'light');
  _expectThemeDataByteIdentical(before.dark, after.dark, surface: 'dark');
}

/// Asserts two `ThemeData` instances produced by `AppTheme.buildTheme` carry
/// identical values for every design-system surface. Field-level rather than
/// reference equality is used so the property catches any future regression
/// where `ThemeService` mutation would change the seed even though the
/// `ThemeData` reference stayed the same.
void _expectThemeDataByteIdentical(
  ThemeData a,
  ThemeData b, {
  required String surface,
}) {
  // Brightness and the seeded `ColorScheme` slots — the brand palette flows
  // into `primary` and `secondary`, the neutrals flow into `surface` and
  // `onSurface`, and the semantic error token flows into `error`.
  expect(a.brightness, equals(b.brightness),
      reason: '$surface.brightness preserved');
  expect(a.colorScheme.primary, equals(b.colorScheme.primary),
      reason: '$surface.colorScheme.primary preserved');
  expect(a.colorScheme.secondary, equals(b.colorScheme.secondary),
      reason: '$surface.colorScheme.secondary preserved');
  expect(a.colorScheme.surface, equals(b.colorScheme.surface),
      reason: '$surface.colorScheme.surface preserved');
  expect(a.colorScheme.onSurface, equals(b.colorScheme.onSurface),
      reason: '$surface.colorScheme.onSurface preserved');
  expect(a.colorScheme.error, equals(b.colorScheme.error),
      reason: '$surface.colorScheme.error preserved');
  expect(a.scaffoldBackgroundColor, equals(b.scaffoldBackgroundColor),
      reason: '$surface.scaffoldBackgroundColor preserved');

  // AppColorsExt — brand palette, semantic colors, neutrals, and surface
  // overlay opacities. This is the most substantive byte-identity check
  // because `setPrimaryColor` mutation (the very thing Req 2.7 forbids)
  // would manifest here as a changed brand palette.
  final AppColorsExt? aColors = a.extension<AppColorsExt>();
  final AppColorsExt? bColors = b.extension<AppColorsExt>();
  expect(aColors, isNotNull, reason: '$surface.AppColorsExt present (before)');
  expect(bColors, isNotNull, reason: '$surface.AppColorsExt present (after)');
  expect(aColors!.background, equals(bColors!.background),
      reason: '$surface.AppColorsExt.background preserved');
  expect(aColors.foreground, equals(bColors.foreground),
      reason: '$surface.AppColorsExt.foreground preserved');
  expect(aColors.card, equals(bColors.card),
      reason: '$surface.AppColorsExt.card preserved');
  expect(aColors.muted, equals(bColors.muted),
      reason: '$surface.AppColorsExt.muted preserved');
  expect(aColors.border, equals(bColors.border),
      reason: '$surface.AppColorsExt.border preserved');
  expect(aColors.emerald500, equals(bColors.emerald500),
      reason: '$surface.AppColorsExt.emerald500 preserved');
  expect(aColors.emerald600, equals(bColors.emerald600),
      reason: '$surface.AppColorsExt.emerald600 preserved');
  expect(aColors.teal400, equals(bColors.teal400),
      reason: '$surface.AppColorsExt.teal400 preserved');
  expect(aColors.teal500, equals(bColors.teal500),
      reason: '$surface.AppColorsExt.teal500 preserved');
  expect(aColors.success, equals(bColors.success),
      reason: '$surface.AppColorsExt.success preserved');
  expect(aColors.warning, equals(bColors.warning),
      reason: '$surface.AppColorsExt.warning preserved');
  expect(aColors.error, equals(bColors.error),
      reason: '$surface.AppColorsExt.error preserved');
  expect(aColors.info, equals(bColors.info),
      reason: '$surface.AppColorsExt.info preserved');
  expect(aColors.surfaceSubtle, equals(bColors.surfaceSubtle),
      reason: '$surface.AppColorsExt.surfaceSubtle preserved');
  expect(aColors.surfaceMedium, equals(bColors.surfaceMedium),
      reason: '$surface.AppColorsExt.surfaceMedium preserved');
  expect(aColors.surfaceProminent, equals(bColors.surfaceProminent),
      reason: '$surface.AppColorsExt.surfaceProminent preserved');

  // AppSpacingExt, AppRadiiExt, AppMotionExt, AppTypographyExt — these
  // adapters are mode-invariant and stateless, so a byte-identity check is
  // a guard against any future regression where one of these adapters
  // gains state derived from the seed.
  final AppSpacingExt? aSpacing = a.extension<AppSpacingExt>();
  final AppSpacingExt? bSpacing = b.extension<AppSpacingExt>();
  expect(aSpacing, isNotNull, reason: '$surface.AppSpacingExt present (before)');
  expect(bSpacing, isNotNull, reason: '$surface.AppSpacingExt present (after)');
  expect(aSpacing!.xs, equals(bSpacing!.xs),
      reason: '$surface.AppSpacingExt.xs preserved');
  expect(aSpacing.sm, equals(bSpacing.sm),
      reason: '$surface.AppSpacingExt.sm preserved');
  expect(aSpacing.md, equals(bSpacing.md),
      reason: '$surface.AppSpacingExt.md preserved');
  expect(aSpacing.lg, equals(bSpacing.lg),
      reason: '$surface.AppSpacingExt.lg preserved');
  expect(aSpacing.xl, equals(bSpacing.xl),
      reason: '$surface.AppSpacingExt.xl preserved');
  expect(aSpacing.xxl, equals(bSpacing.xxl),
      reason: '$surface.AppSpacingExt.xxl preserved');
  expect(aSpacing.xxxl, equals(bSpacing.xxxl),
      reason: '$surface.AppSpacingExt.xxxl preserved');
  expect(aSpacing.xxxxl, equals(bSpacing.xxxxl),
      reason: '$surface.AppSpacingExt.xxxxl preserved');

  final AppRadiiExt? aRadii = a.extension<AppRadiiExt>();
  final AppRadiiExt? bRadii = b.extension<AppRadiiExt>();
  expect(aRadii, isNotNull, reason: '$surface.AppRadiiExt present (before)');
  expect(bRadii, isNotNull, reason: '$surface.AppRadiiExt present (after)');
  expect(aRadii!.small, equals(bRadii!.small),
      reason: '$surface.AppRadiiExt.small preserved');
  expect(aRadii.medium, equals(bRadii.medium),
      reason: '$surface.AppRadiiExt.medium preserved');
  expect(aRadii.large, equals(bRadii.large),
      reason: '$surface.AppRadiiExt.large preserved');
  expect(aRadii.xLarge, equals(bRadii.xLarge),
      reason: '$surface.AppRadiiExt.xLarge preserved');

  final AppMotionExt? aMotion = a.extension<AppMotionExt>();
  final AppMotionExt? bMotion = b.extension<AppMotionExt>();
  expect(aMotion, isNotNull, reason: '$surface.AppMotionExt present (before)');
  expect(bMotion, isNotNull, reason: '$surface.AppMotionExt present (after)');
  expect(aMotion!.fast, equals(bMotion!.fast),
      reason: '$surface.AppMotionExt.fast preserved');
  expect(aMotion.normal, equals(bMotion.normal),
      reason: '$surface.AppMotionExt.normal preserved');
  expect(aMotion.slow, equals(bMotion.slow),
      reason: '$surface.AppMotionExt.slow preserved');
  expect(aMotion.standard, equals(bMotion.standard),
      reason: '$surface.AppMotionExt.standard preserved');
  expect(aMotion.emphasized, equals(bMotion.emphasized),
      reason: '$surface.AppMotionExt.emphasized preserved');

  final AppTypographyExt? aTypo = a.extension<AppTypographyExt>();
  final AppTypographyExt? bTypo = b.extension<AppTypographyExt>();
  expect(aTypo, isNotNull,
      reason: '$surface.AppTypographyExt present (before)');
  expect(bTypo, isNotNull,
      reason: '$surface.AppTypographyExt present (after)');
  expect(aTypo!.display, equals(bTypo!.display),
      reason: '$surface.AppTypographyExt.display preserved');
  expect(aTypo.headlineLarge, equals(bTypo.headlineLarge),
      reason: '$surface.AppTypographyExt.headlineLarge preserved');
  expect(aTypo.headline, equals(bTypo.headline),
      reason: '$surface.AppTypographyExt.headline preserved');
  expect(aTypo.title, equals(bTypo.title),
      reason: '$surface.AppTypographyExt.title preserved');
  expect(aTypo.bodyLarge, equals(bTypo.bodyLarge),
      reason: '$surface.AppTypographyExt.bodyLarge preserved');
  expect(aTypo.body, equals(bTypo.body),
      reason: '$surface.AppTypographyExt.body preserved');
  expect(aTypo.label, equals(bTypo.label),
      reason: '$surface.AppTypographyExt.label preserved');

  // AppShadowsExt — the dark variant scales opacity by
  // `darkOpacityMultiplier`, but for a fixed seed the resulting list must
  // be deterministic. Compare list shape and per-entry fields.
  final AppShadowsExt? aShadows = a.extension<AppShadowsExt>();
  final AppShadowsExt? bShadows = b.extension<AppShadowsExt>();
  expect(aShadows, isNotNull,
      reason: '$surface.AppShadowsExt present (before)');
  expect(bShadows, isNotNull,
      reason: '$surface.AppShadowsExt present (after)');
  expect(aShadows!.darkOpacityMultiplier,
      equals(bShadows!.darkOpacityMultiplier),
      reason: '$surface.AppShadowsExt.darkOpacityMultiplier preserved');
  _expectShadowListByteIdentical(aShadows.small, bShadows.small,
      surface: surface, listName: 'small');
  _expectShadowListByteIdentical(aShadows.medium, bShadows.medium,
      surface: surface, listName: 'medium');
  _expectShadowListByteIdentical(aShadows.large, bShadows.large,
      surface: surface, listName: 'large');
  _expectShadowListByteIdentical(aShadows.xLarge, bShadows.xLarge,
      surface: surface, listName: 'xLarge');
}

/// Asserts two `List<BoxShadow>`s have the same length and that every paired
/// shadow shares every field — color (alpha + RGB), blurRadius, spreadRadius,
/// offset, and blurStyle. Used to verify the dark-mode shadow lists rebuild
/// to the same values when the seed has not changed.
void _expectShadowListByteIdentical(
  List<BoxShadow> a,
  List<BoxShadow> b, {
  required String surface,
  required String listName,
}) {
  expect(a.length, equals(b.length),
      reason: '$surface.AppShadowsExt.$listName list length preserved');
  for (int i = 0; i < a.length; i++) {
    final BoxShadow l = a[i];
    final BoxShadow r = b[i];
    expect(l.color.a, equals(r.color.a),
        reason: '$surface.AppShadowsExt.$listName[$i].color.a preserved');
    expect(l.color.r, equals(r.color.r),
        reason: '$surface.AppShadowsExt.$listName[$i].color.r preserved');
    expect(l.color.g, equals(r.color.g),
        reason: '$surface.AppShadowsExt.$listName[$i].color.g preserved');
    expect(l.color.b, equals(r.color.b),
        reason: '$surface.AppShadowsExt.$listName[$i].color.b preserved');
    expect(l.blurRadius, equals(r.blurRadius),
        reason: '$surface.AppShadowsExt.$listName[$i].blurRadius preserved');
    expect(l.spreadRadius, equals(r.spreadRadius),
        reason:
            '$surface.AppShadowsExt.$listName[$i].spreadRadius preserved');
    expect(l.offset, equals(r.offset),
        reason: '$surface.AppShadowsExt.$listName[$i].offset preserved');
    expect(l.blurStyle, equals(r.blurStyle),
        reason: '$surface.AppShadowsExt.$listName[$i].blurStyle preserved');
  }
}
