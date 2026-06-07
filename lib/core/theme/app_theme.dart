import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'color_utils.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_radii.dart';
import 'tokens/app_shadows.dart';
import 'tokens/app_typography.dart';
import 'tokens/theme_extensions.dart';

/// Token-driven `ThemeData` builder for the DriveCare+ design system.
///
/// `AppTheme.buildTheme(seed, brightness)` is the single entry point used by
/// `lib/app.dart` to wire `MaterialApp.theme` and `MaterialApp.darkTheme`.
/// It reads every visual constant from the Design_Tokens_Module
/// (`AppColors`, `AppRadii`, `AppShadows`, `AppTypography`) and registers
/// the six `ThemeExtension` adapters from
/// `lib/core/theme/tokens/theme_extensions.dart` on `ThemeData.extensions`
/// so widgets can read tokens via `Theme.of(context).extension<...>()`
/// (Requirement 2.11).
///
/// The atomic `buildThemePair` wrapper (Task 2.5) returns both the light and
/// dark `ThemeData` instances from a single seed in one pure function so
/// callers that listen to theme changes can swap both surfaces in the same
/// frame and never observe a half-applied theme (Requirement 2.6, 2.8).
class AppTheme {
  const AppTheme._();

  /// Builds a `ThemeData` for the given `seed` color and `brightness`.
  ///
  /// - The brand gradient palette is derived from `seed` via
  ///   `derivePalette(seed)`. For the canonical `#10B981` seed this returns
  ///   the literal `AppColors.{emerald500, emerald600, teal400, teal500}`;
  ///   for any other preset the derivation produces a coherent four-stop
  ///   gradient palette (Requirement 2.6 / Task 2.2).
  /// - Light mode uses `AppColors.light*` neutrals and `AppShadows.{small,
  ///   medium, large, xLarge}` directly.
  /// - Dark mode uses `AppColors.dark*` neutrals and pipes each shadow list
  ///   through `scaleShadowOpacity(list, AppShadows.darkOpacityMultiplier)`
  ///   so the per-shadow opacity becomes
  ///   `(originalOpacity * 2.5).clamp(0.0, 1.0)` (Requirement 1.8).
  /// - The `TextTheme` slots are wired to `AppTypography` per Requirement
  ///   2.10:
  ///     * `displayLarge`     ← `AppTypography.display`
  ///     * `headlineLarge`    ← `AppTypography.headlineLarge`
  ///     * `headlineMedium`   ← `AppTypography.headline`
  ///     * `titleLarge`       ← `AppTypography.title`
  ///     * `bodyLarge`        ← `AppTypography.bodyLarge`
  ///     * `bodyMedium`       ← `AppTypography.body`
  ///     * `labelSmall`       ← `AppTypography.label`
  ///   `fontSize` and `fontWeight` are preserved exactly; foreground color
  ///   is applied at theme-build time so light/dark surfaces stay legible.
  /// - All six `ThemeExtension` adapters
  ///   (`AppColorsExt`, `AppSpacingExt`, `AppRadiiExt`, `AppShadowsExt`,
  ///   `AppMotionExt`, `AppTypographyExt`) are registered on
  ///   `ThemeData.extensions` so consumers can read tokens through
  ///   `Theme.of(context).extension<...>()` (Requirement 2.11).
  static ThemeData buildTheme(Color seed, Brightness brightness) {
    final bool isLight = brightness == Brightness.light;

    // Derive the brand gradient palette from the seed (Task 2.2 / Req 2.6).
    final palette = derivePalette(seed);

    // Mode-specific neutrals (Requirements 2.1, 2.2).
    final Color background =
        isLight ? AppColors.lightBackground : AppColors.darkBackground;
    final Color foreground =
        isLight ? AppColors.lightForeground : AppColors.darkForeground;
    final Color card = isLight ? AppColors.lightCard : AppColors.darkCard;
    final Color muted =
        isLight ? AppColors.lightMuted : AppColors.darkPopover;
    final Color border =
        isLight ? AppColors.lightBorder : AppColors.darkBorder;

    // Mode-specific shadow set (Requirement 1.8). Light mode uses the
    // authoritative `AppShadows.*` lists directly; dark mode multiplies each
    // shadow's color opacity by `darkOpacityMultiplier` and clamps to
    // `[0.0, 1.0]` via `scaleShadowOpacity`.
    final List<BoxShadow> shadowSmall = isLight
        ? AppShadows.small
        : scaleShadowOpacity(
            AppShadows.small,
            AppShadows.darkOpacityMultiplier,
          );

    // ColorScheme: seeded for Material 3 harmonisation, then overridden so
    // the primary/onPrimary slots track the derived brand palette and the
    // surface slots track the neutral tokens.
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      primary: palette.emerald500,
      onPrimary: Colors.white,
      secondary: palette.teal500,
      onSecondary: Colors.white,
      surface: background,
      onSurface: foreground,
      error: AppColors.error,
      onError: Colors.white,
    );

    // TextTheme — Requirement 2.10. Foreground colour is applied here so
    // the underlying token `TextStyle`s remain reusable across modes.
    final TextTheme textTheme = TextTheme(
      displayLarge: AppTypography.display.copyWith(color: foreground),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: foreground),
      headlineMedium: AppTypography.headline.copyWith(color: foreground),
      titleLarge: AppTypography.title.copyWith(color: foreground),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: foreground),
      bodyMedium: AppTypography.body.copyWith(color: foreground),
      labelSmall: AppTypography.label.copyWith(color: foreground),
    );

    // Build the AppColorsExt via its regular constructor so the derived
    // brand palette flows into the four brand slots while the neutral and
    // semantic slots track the mode-specific tokens.
    final AppColorsExt colorsExt = AppColorsExt(
      background: background,
      foreground: foreground,
      card: card,
      muted: muted,
      border: border,
      emerald500: palette.emerald500,
      emerald600: palette.emerald600,
      teal400: palette.teal400,
      teal500: palette.teal500,
      routeGlowOuter: AppColors.routeGlowOuter,
      routeGlowInner: AppColors.routeGlowInner,
      success: AppColors.success,
      warning: AppColors.warning,
      error: AppColors.error,
      info: AppColors.info,
      surfaceSubtle: AppColors.surfaceSubtle,
      surfaceMedium: AppColors.surfaceMedium,
      surfaceProminent: AppColors.surfaceProminent,
    );

    final AppShadowsExt shadowsExt =
        isLight ? const AppShadowsExt.light() : AppShadowsExt.dark();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      // ----------------------------------------------------------------------
      // AppBar — transparent surface, foreground from neutral tokens.
      // ----------------------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.title.copyWith(color: foreground),
        iconTheme: IconThemeData(color: foreground),
      ),
      // ----------------------------------------------------------------------
      // Input decoration — 2-pixel border, focused emerald500, error red,
      // fill = card surface (Requirements 3.3, 3.4, 3.5).
      // ----------------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.emerald500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: border, width: 2),
        ),
        labelStyle: AppTypography.bodyLarge.copyWith(color: foreground),
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: foreground.withValues(alpha: 0.6),
        ),
        errorStyle: AppTypography.body.copyWith(color: AppColors.error),
      ),
      // ----------------------------------------------------------------------
      // Elevated button — Touch_Target_Floor min height 48, large radius,
      // primary fill, white foreground.
      // ----------------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: palette.emerald500,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          textStyle: AppTypography.title,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      // ----------------------------------------------------------------------
      // Card — surface = card token, large radius, 1-pixel border, small
      // shadow at rest.
      // ----------------------------------------------------------------------
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadowSmall.isNotEmpty
            ? shadowSmall.first.color
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      // ----------------------------------------------------------------------
      // BottomSheet — top-rounded with AppRadii.large.
      // ----------------------------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: card,
        modalBarrierColor: Colors.black54,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadii.large),
            topRight: Radius.circular(AppRadii.large),
          ),
        ),
      ),
      // ----------------------------------------------------------------------
      // SnackBar — token-driven background and content color.
      // ----------------------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: AppTypography.bodyLarge.copyWith(color: foreground),
        actionTextColor: palette.emerald500,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      // ----------------------------------------------------------------------
      // Dialog — token-driven background, large radius.
      // ----------------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        titleTextStyle: AppTypography.headline.copyWith(color: foreground),
        contentTextStyle: AppTypography.bodyLarge.copyWith(color: foreground),
      ),
      iconTheme: IconThemeData(color: foreground),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      // ----------------------------------------------------------------------
      // Page transitions — emphasized curve at the standard duration.
      // ----------------------------------------------------------------------
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      // ----------------------------------------------------------------------
      // Register all six ThemeExtensions (Requirement 2.11).
      // ----------------------------------------------------------------------
      extensions: <ThemeExtension<dynamic>>[
        colorsExt,
        const AppSpacingExt(),
        const AppRadiiExt(),
        shadowsExt,
        const AppMotionExt(),
        const AppTypographyExt(),
      ],
    );
  }

  /// Atomic theme pair builder (Task 2.5).
  ///
  /// Returns the light and dark `ThemeData` instances derived from the same
  /// `seed` color. Callers (e.g. `DriveCarePlusApp`) compute the pair in one
  /// step and only hand it to `MaterialApp` after both surfaces succeed so
  /// observers never see one mode updated without the other (Requirement
  /// 2.6, 2.8).
  ///
  /// This is a pure function: no side effects, no I/O. If either underlying
  /// `buildTheme` call throws, the exception propagates so the caller can
  /// fall back to a previously cached pair without partial updates
  /// (Requirement 2.8 — atomicity preserved by re-using the cached pair).
  static ({ThemeData light, ThemeData dark}) buildThemePair(Color seed) {
    final ThemeData light = buildTheme(seed, Brightness.light);
    final ThemeData dark = buildTheme(seed, Brightness.dark);
    return (light: light, dark: dark);
  }
}
