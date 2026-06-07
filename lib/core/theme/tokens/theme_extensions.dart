import 'package:flutter/material.dart';

import '../color_utils.dart';
import 'app_colors.dart';
import 'app_motion.dart';
import 'app_radii.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// `ThemeExtension` adapters for the DriveCare+ design tokens.
///
/// Each adapter wraps a Token_Set (`AppColors`, `AppSpacing`, `AppRadii`,
/// `AppShadows`, `AppMotion`, `AppTypography`) and exposes the same surface
/// as instance fields so widgets can read tokens via
/// `Theme.of(context).extension<T>()` (Requirement 2.11).
///
/// Tokens are non-tweenable, so every adapter:
///   * implements `copyWith` as a no-op that returns `this`;
///   * implements `lerp` as a no-op that returns `this`.
///
/// `.light()` and `.dark()` named constructors are only provided where token
/// values differ between modes — that is `AppColorsExt` (neutrals) and
/// `AppShadowsExt` (opacity multiplier). The other four adapters expose a
/// single canonical constructor because their token values are identical
/// across light and dark themes.

// =============================================================================
// AppColorsExt
// =============================================================================

/// Theme-extension adapter for the `AppColors` Token_Set.
///
/// Exposes the brand palette, semantic colors, and neutrals as instance
/// fields. Light- and dark-mode neutrals are wired up via the `.light()` and
/// `.dark()` named constructors per the task specification:
///
///   * `.light()` → `lightBackground`, `lightForeground`, `lightCard`,
///     `lightMuted`, `lightBorder`.
///   * `.dark()`  → `darkBackground`, `darkForeground`, `darkCard`,
///     `darkPopover`, `darkBorder`.
///
/// The brand palette (`emerald500`, `emerald600`, `teal400`, `teal500`) and
/// the semantic colors (`success`, `warning`, `error`, `info`) are identical
/// between modes.
@immutable
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  // Neutrals.
  final Color background;
  final Color foreground;
  final Color card;
  final Color muted;
  final Color border;

  // Brand palette (Reference_Source gradient stops).
  final Color emerald500;
  final Color emerald600;
  final Color teal400;
  final Color teal500;
  final Color routeGlowOuter;
  final Color routeGlowInner;

  // Semantic colors.
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Surface overlay opacities (subtle / medium / prominent).
  final double surfaceSubtle;
  final double surfaceMedium;
  final double surfaceProminent;

  const AppColorsExt({
    required this.background,
    required this.foreground,
    required this.card,
    required this.muted,
    required this.border,
    required this.emerald500,
    required this.emerald600,
    required this.teal400,
    required this.teal500,
    required this.routeGlowOuter,
    required this.routeGlowInner,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.surfaceSubtle,
    required this.surfaceMedium,
    required this.surfaceProminent,
  });

  /// Light-mode neutrals + shared brand/semantic palette.
  const AppColorsExt.light()
      : background = AppColors.lightBackground,
        foreground = AppColors.lightForeground,
        card = AppColors.lightCard,
        muted = AppColors.lightMuted,
        border = AppColors.lightBorder,
        emerald500 = AppColors.emerald500,
        emerald600 = AppColors.emerald600,
        teal400 = AppColors.teal400,
        teal500 = AppColors.teal500,
        routeGlowOuter = AppColors.routeGlowOuter,
        routeGlowInner = AppColors.routeGlowInner,
        success = AppColors.success,
        warning = AppColors.warning,
        error = AppColors.error,
        info = AppColors.info,
        surfaceSubtle = AppColors.surfaceSubtle,
        surfaceMedium = AppColors.surfaceMedium,
        surfaceProminent = AppColors.surfaceProminent;

  /// Dark-mode neutrals + shared brand/semantic palette. The `muted` slot in
  /// dark mode resolves to `darkPopover` per the task specification.
  const AppColorsExt.dark()
      : background = AppColors.darkBackground,
        foreground = AppColors.darkForeground,
        card = AppColors.darkCard,
        muted = AppColors.darkPopover,
        border = AppColors.darkBorder,
        emerald500 = AppColors.emerald500,
        emerald600 = AppColors.emerald600,
        teal400 = AppColors.teal400,
        teal500 = AppColors.teal500,
        routeGlowOuter = AppColors.routeGlowOuter,
        routeGlowInner = AppColors.routeGlowInner,
        success = AppColors.success,
        warning = AppColors.warning,
        error = AppColors.error,
        info = AppColors.info,
        surfaceSubtle = AppColors.surfaceSubtle,
        surfaceMedium = AppColors.surfaceMedium,
        surfaceProminent = AppColors.surfaceProminent;

  @override
  AppColorsExt copyWith() => this;

  @override
  AppColorsExt lerp(ThemeExtension<AppColorsExt>? other, double t) => this;
}

// =============================================================================
// AppSpacingExt
// =============================================================================

/// Theme-extension adapter for the `AppSpacing` Token_Set. Values are
/// identical across light and dark themes.
@immutable
class AppSpacingExt extends ThemeExtension<AppSpacingExt> {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
  final double xxxxl;

  const AppSpacingExt()
      : xs = AppSpacing.xs,
        sm = AppSpacing.sm,
        md = AppSpacing.md,
        lg = AppSpacing.lg,
        xl = AppSpacing.xl,
        xxl = AppSpacing.xxl,
        xxxl = AppSpacing.xxxl,
        xxxxl = AppSpacing.xxxxl;

  @override
  AppSpacingExt copyWith() => this;

  @override
  AppSpacingExt lerp(ThemeExtension<AppSpacingExt>? other, double t) => this;
}

// =============================================================================
// AppRadiiExt
// =============================================================================

/// Theme-extension adapter for the `AppRadii` Token_Set. Values are identical
/// across light and dark themes.
@immutable
class AppRadiiExt extends ThemeExtension<AppRadiiExt> {
  final double small;
  final double medium;
  final double large;
  final double xLarge;

  const AppRadiiExt()
      : small = AppRadii.small,
        medium = AppRadii.medium,
        large = AppRadii.large,
        xLarge = AppRadii.xLarge;

  @override
  AppRadiiExt copyWith() => this;

  @override
  AppRadiiExt lerp(ThemeExtension<AppRadiiExt>? other, double t) => this;
}

// =============================================================================
// AppShadowsExt
// =============================================================================

/// Theme-extension adapter for the `AppShadows` Token_Set.
///
/// `.light()` exposes the authoritative Reference_Source values directly.
/// `.dark()` runs each list through `scaleShadowOpacity` with
/// `AppShadows.darkOpacityMultiplier` (= 2.5) so each shadow's color opacity
/// is `(originalOpacity * 2.5).clamp(0.0, 1.0)` while every other field
/// (`blurRadius`, `spreadRadius`, `offset`, `blurStyle`, color RGB) is
/// preserved.
///
/// `darkOpacityMultiplier` is exposed as an instance field for downstream
/// callers that need to recompute shadows for derived surfaces.
@immutable
class AppShadowsExt extends ThemeExtension<AppShadowsExt> {
  final List<BoxShadow> small;
  final List<BoxShadow> medium;
  final List<BoxShadow> large;
  final List<BoxShadow> xLarge;
  final double darkOpacityMultiplier;

  const AppShadowsExt({
    required this.small,
    required this.medium,
    required this.large,
    required this.xLarge,
    required this.darkOpacityMultiplier,
  });

  /// Light-mode shadows — pass-through of the canonical token lists.
  const AppShadowsExt.light()
      : small = AppShadows.small,
        medium = AppShadows.medium,
        large = AppShadows.large,
        xLarge = AppShadows.xLarge,
        darkOpacityMultiplier = AppShadows.darkOpacityMultiplier;

  /// Dark-mode shadows — opacities scaled by `AppShadows.darkOpacityMultiplier`
  /// and clamped to `[0.0, 1.0]` via `scaleShadowOpacity` (Requirement 1.8).
  AppShadowsExt.dark()
      : small = scaleShadowOpacity(
          AppShadows.small,
          AppShadows.darkOpacityMultiplier,
        ),
        medium = scaleShadowOpacity(
          AppShadows.medium,
          AppShadows.darkOpacityMultiplier,
        ),
        large = scaleShadowOpacity(
          AppShadows.large,
          AppShadows.darkOpacityMultiplier,
        ),
        xLarge = scaleShadowOpacity(
          AppShadows.xLarge,
          AppShadows.darkOpacityMultiplier,
        ),
        darkOpacityMultiplier = AppShadows.darkOpacityMultiplier;

  @override
  AppShadowsExt copyWith() => this;

  @override
  AppShadowsExt lerp(ThemeExtension<AppShadowsExt>? other, double t) => this;
}

// =============================================================================
// AppMotionExt
// =============================================================================

/// Theme-extension adapter for the `AppMotion` Token_Set. Values are
/// identical across light and dark themes.
@immutable
class AppMotionExt extends ThemeExtension<AppMotionExt> {
  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Curve standard;
  final Curve emphasized;

  const AppMotionExt()
      : fast = AppMotion.fast,
        normal = AppMotion.normal,
        slow = AppMotion.slow,
        standard = AppMotion.standard,
        emphasized = AppMotion.emphasized;

  @override
  AppMotionExt copyWith() => this;

  @override
  AppMotionExt lerp(ThemeExtension<AppMotionExt>? other, double t) => this;
}

// =============================================================================
// AppTypographyExt
// =============================================================================

/// Theme-extension adapter for the `AppTypography` Token_Set. Values are
/// identical across light and dark themes; color is applied at consumption
/// time so the underlying `TextStyle`s stay reusable.
@immutable
class AppTypographyExt extends ThemeExtension<AppTypographyExt> {
  final TextStyle display;
  final TextStyle headlineLarge;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle bodyLarge;
  final TextStyle body;
  final TextStyle label;

  const AppTypographyExt()
      : display = AppTypography.display,
        headlineLarge = AppTypography.headlineLarge,
        headline = AppTypography.headline,
        title = AppTypography.title,
        bodyLarge = AppTypography.bodyLarge,
        body = AppTypography.body,
        label = AppTypography.label;

  @override
  AppTypographyExt copyWith() => this;

  @override
  AppTypographyExt lerp(ThemeExtension<AppTypographyExt>? other, double t) =>
      this;
}
