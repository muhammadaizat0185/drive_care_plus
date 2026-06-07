// Validates: Requirements 1.1, 1.9, 1.12
//
// Structural smoke test: importing only the Design_Tokens_Module barrel
// (`lib/core/theme/tokens/tokens.dart`) makes every documented Token_Set
// member reachable. The references below cover every `static const` field
// declared by `AppColors`, `AppSpacing`, `AppRadii`, `AppTypography`,
// `AppShadows`, and `AppMotion`.
//
// The list is mirror-checked against the lint guard's per-class field
// counts: if a member is added to a Token_Set without also being added
// here, the smoke test would still compile, so the lint guard
// (`lint_guard_test.dart`) carries the structural completeness contract
// while this test carries the reachability contract via the barrel.

import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppColors members are reachable via the barrel export', () {
    // Every reference below resolves through `package:.../tokens/tokens.dart`,
    // so a regression that drops a member from the barrel re-export breaks
    // compilation here.
    final List<Object> members = <Object>[
      AppColors.emerald500,
      AppColors.emerald600,
      AppColors.teal400,
      AppColors.teal500,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.info,
      AppColors.lightBackground,
      AppColors.lightForeground,
      AppColors.lightCard,
      AppColors.lightMuted,
      AppColors.lightBorder,
      AppColors.darkBackground,
      AppColors.darkForeground,
      AppColors.darkCard,
      AppColors.darkPopover,
      AppColors.darkBorder,
      AppColors.surfaceSubtle,
      AppColors.surfaceMedium,
      AppColors.surfaceProminent,
    ];
    expect(members, hasLength(21));
    for (final Object m in members) {
      expect(m, isNotNull);
    }
    // Spot-check that the ARGB-typed members really resolve to `Color` and
    // the opacity-typed members resolve to `double`.
    expect(AppColors.emerald500, isA<Color>());
    expect(AppColors.surfaceSubtle, isA<double>());
  });

  test('AppSpacing members are reachable via the barrel export', () {
    final List<double> members = <double>[
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
      AppSpacing.xxxl,
      AppSpacing.xxxxl,
    ];
    expect(members, hasLength(8));
    for (final double m in members) {
      expect(m, greaterThan(0.0));
    }
  });

  test('AppRadii members are reachable via the barrel export', () {
    final List<double> members = <double>[
      AppRadii.small,
      AppRadii.medium,
      AppRadii.large,
      AppRadii.xLarge,
    ];
    expect(members, hasLength(4));
    for (final double m in members) {
      expect(m, greaterThan(0.0));
    }
  });

  test('AppTypography members are reachable via the barrel export', () {
    final List<TextStyle> members = <TextStyle>[
      AppTypography.display,
      AppTypography.headlineLarge,
      AppTypography.headline,
      AppTypography.title,
      AppTypography.bodyLarge,
      AppTypography.body,
      AppTypography.label,
    ];
    expect(members, hasLength(7));
    for (final TextStyle m in members) {
      expect(m.fontSize, isNotNull);
      expect(m.fontWeight, isNotNull);
    }
  });

  test('AppShadows members are reachable via the barrel export', () {
    // The four shadow scales plus the dark-mode multiplier double.
    final List<List<BoxShadow>> shadowLists = <List<BoxShadow>>[
      AppShadows.small,
      AppShadows.medium,
      AppShadows.large,
      AppShadows.xLarge,
    ];
    expect(shadowLists, hasLength(4));
    for (final List<BoxShadow> l in shadowLists) {
      expect(l, isNotEmpty);
    }
    expect(AppShadows.darkOpacityMultiplier, isA<double>());
    expect(AppShadows.darkOpacityMultiplier, greaterThan(0.0));
  });

  test('AppMotion members are reachable via the barrel export', () {
    final List<Object> members = <Object>[
      AppMotion.fast,
      AppMotion.normal,
      AppMotion.slow,
      AppMotion.standard,
      AppMotion.emphasized,
    ];
    expect(members, hasLength(5));
    expect(AppMotion.fast, isA<Duration>());
    expect(AppMotion.normal, isA<Duration>());
    expect(AppMotion.slow, isA<Duration>());
    expect(AppMotion.standard, isA<Curve>());
    expect(AppMotion.emphasized, isA<Curve>());
  });
}
