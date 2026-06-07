import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens/app_colors.dart';

/// Color and shadow utility functions for the DriveCare+ design system.
///
/// This file is a home for top-level pure functions used by the Design Tokens
/// Module and the theme builder. Members are deliberately top-level (not
/// grouped in a class) so callers can import them as plain functions and so
/// later tasks (`derivePalette`, `contrastRatio`) can be appended here without
/// disturbing existing call sites.
///
/// ---------------------------------------------------------------------------

/// Returns a new `List<BoxShadow>` whose every shadow has its color opacity
/// scaled by `factor` and clamped to the inclusive range `[0.0, 1.0]`. All
/// other fields of each shadow (`blurRadius`, `spreadRadius`, `offset`,
/// `blurStyle`, and the color's RGB channels) are preserved exactly.
///
/// This is a pure function: the input list and its `BoxShadow` instances are
/// not mutated. The returned list is a freshly allocated `List<BoxShadow>`
/// that is independent of the input.
///
/// Used by `AppTheme.buildTheme` to derive dark-mode shadow variants from the
/// light-mode authoritative `AppShadows.{small, medium, large, xLarge}`
/// tokens at theme-build time, satisfying Requirement 1.8:
///
/// > WHEN the active theme brightness is `Brightness.dark`, THE
/// > Design_Tokens_Module SHALL return shadow opacities computed by
/// > multiplying the light-mode shadow opacities by `2.5` and clamping the
/// > result to the inclusive range `[0.0, 1.0]`.
///
/// Examples:
///
/// ```dart
/// final scaled = scaleShadowOpacity(AppShadows.small, 2.5);
/// // shadow at 0.05 → 0.125; all other fields preserved.
///
/// final pinned = scaleShadowOpacity(AppShadows.xLarge, 100.0);
/// // every shadow color clamped to opacity 1.0.
/// ```
List<BoxShadow> scaleShadowOpacity(List<BoxShadow> input, double factor) {
  return List<BoxShadow>.generate(
    input.length,
    (i) {
      final BoxShadow shadow = input[i];
      final Color color = shadow.color;
      // `Color.a` returns the alpha component as a double in [0.0, 1.0].
      final double scaledAlpha = (color.a * factor).clamp(0.0, 1.0);
      return BoxShadow(
        color: color.withValues(alpha: scaledAlpha),
        blurRadius: shadow.blurRadius,
        spreadRadius: shadow.spreadRadius,
        offset: shadow.offset,
        blurStyle: shadow.blurStyle,
      );
    },
    growable: false,
  );
}

/// Derives a coherent four-stop gradient brand palette from a single seed
/// `Color`. The returned record exposes the same field names as the canonical
/// `AppColors.{emerald500, emerald600, teal400, teal500}` palette so callers
/// (the theme builder, gradient widgets) can plug a derived palette into the
/// same slots.
///
/// **Canonical seed.** When `seed` equals the canonical brand seed
/// `#10B981`, the function returns the literal `AppColors.{emerald500,
/// emerald600, teal400, teal500}` values directly so that the canonical case
/// round-trips byte-perfect.
///
/// **Other seeds.** For any other preset seed, the derivation is computed in
/// HSL space relative to the seed:
///
/// - `emerald500` = the seed itself (preserve hue, saturation, and lightness).
/// - `emerald600` = the seed with lightness reduced by `0.075`, clamped to
///   `[0.0, 1.0]` — the darker step in the brand gradient.
/// - `teal400`    = the seed hue-shifted by `+13°` toward cyan, with
///   lightness raised by `0.107` (clamped) — the lighter, more teal end of
///   the gradient.
/// - `teal500`    = the seed hue-shifted by `+13°` toward cyan, with
///   lightness raised by `0.006` (clamped) — the mid teal stop.
///
/// The hue shift and lightness deltas are calibrated against the canonical
/// `#10B981 → (#10B981, #059669, #2DD4BF, #14B8A6)` mapping so the formula
/// produces approximately matching relative shifts on any other input seed.
/// The non-canonical output is not required to match any specific hex
/// literal — it only needs to remain a coherent four-stop gradient palette
/// (Requirement 2.6).
///
/// This is a pure function: it performs no I/O and allocates only the four
/// returned `Color` values.
({Color emerald500, Color emerald600, Color teal400, Color teal500})
    derivePalette(Color seed) {
  // Canonical brand seed → return the literal AppColors palette byte-perfect.
  if (seed == AppColors.emerald500) {
    return (
      emerald500: AppColors.emerald500,
      emerald600: AppColors.emerald600,
      teal400: AppColors.teal400,
      teal500: AppColors.teal500,
    );
  }

  // Derive a coherent 4-stop gradient palette from any other seed.
  final HSLColor base = HSLColor.fromColor(seed);
  final double shiftedHue = (base.hue + 13.0) % 360.0;

  final HSLColor darker = base.withLightness(
    (base.lightness - 0.075).clamp(0.0, 1.0),
  );
  final HSLColor tealLighter = base
      .withHue(shiftedHue)
      .withLightness((base.lightness + 0.107).clamp(0.0, 1.0));
  final HSLColor tealMid = base
      .withHue(shiftedHue)
      .withLightness((base.lightness + 0.006).clamp(0.0, 1.0));

  return (
    emerald500: base.toColor(),
    emerald600: darker.toColor(),
    teal400: tealLighter.toColor(),
    teal500: tealMid.toColor(),
  );
}

/// Returns the WCAG 2.1 contrast ratio between a foreground and background
/// `Color`. The result is a `double` in the inclusive range `[1.0, 21.0]`,
/// where `1.0` is no contrast (identical luminance) and `21.0` is maximum
/// contrast (pure black on pure white, or vice versa).
///
/// The computation follows the WCAG 2.1 specification verbatim:
///
/// 1. For each sRGB channel `c` of each color, expressed as a double in
///    `[0.0, 1.0]`, convert to linear-light:
///    `c_lin = (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4`.
/// 2. Compute the relative luminance:
///    `L = 0.2126 * R_lin + 0.7152 * G_lin + 0.0722 * B_lin`.
/// 3. Return `(max(L_fg, L_bg) + 0.05) / (min(L_fg, L_bg) + 0.05)`.
///
/// The alpha channel is ignored — WCAG contrast is defined for opaque
/// foreground/background pairs. Callers that need to evaluate contrast for
/// translucent overlays must composite the foreground over an explicit
/// background first and pass the resulting opaque color in.
///
/// This is a pure function: it performs no I/O and allocates only the
/// intermediate `double` values implied by the formula.
///
/// Used by accessibility checks (Property 24, task 4.15) and the
/// reference-source contrast-ratio audit to validate that documented token
/// foreground/background pairings meet the WCAG AA thresholds (Requirements
/// 13.5, 13.6).
double contrastRatio(Color fg, Color bg) {
  final double lFg = _relativeLuminance(fg);
  final double lBg = _relativeLuminance(bg);
  final double lighter = lFg > lBg ? lFg : lBg;
  final double darker = lFg > lBg ? lBg : lFg;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Computes the WCAG 2.1 relative luminance of an sRGB `Color`. The alpha
/// channel is ignored. Returns a `double` in the inclusive range `[0.0, 1.0]`.
double _relativeLuminance(Color color) {
  final double r = _channelToLinear(color.r);
  final double g = _channelToLinear(color.g);
  final double b = _channelToLinear(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Converts a single sRGB channel value in `[0.0, 1.0]` to its linear-light
/// equivalent using the WCAG 2.1 piecewise transfer function.
double _channelToLinear(double c) {
  if (c <= 0.03928) {
    return c / 12.92;
  }
  return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// Returns the dynamic dark mode gradient bottom color matching the user's active
/// primary theme preset.
///
/// Mappings:
/// - Emerald Green (0xFF1B8A5A) -> Color(0xFF022C22)
/// - Mint Fresh (0xFF10B981) -> Color(0xFF022C1B)
/// - Teal Ocean (0xFF0F766E) -> Color(0xFF042F2E)
/// - Classic Blue (0xFF1E40AF) -> Color(0xFF0A1931)
/// - Dark Charcoal (0xFF1F2937) -> Color(0xFF111827)
/// - Berry Red (0xFFBE123C) -> Color(0xFF3B0712)
/// - Nordic Steel (0xFF475569) -> Color(0xFF1E293B)
///
/// Returns Color(0xFF022C22) as fallback when a custom or undefined color is passed.
Color darkGradientBottomColor(Color primary) {
  switch (primary.value) {
    case 0xFF1B8A5A: // Emerald Green
      return const Color(0xFF022C22);
    case 0xFF10B981: // Mint Fresh
      return const Color(0xFF022C1B);
    case 0xFF0F766E: // Teal Ocean
      return const Color(0xFF042F2E);
    case 0xFF1E40AF: // Classic Blue
      return const Color(0xFF0A1931);
    case 0xFF1F2937: // Dark Charcoal
      return const Color(0xFF111827);
    case 0xFFBE123C: // Berry Red
      return const Color(0xFF3B0712);
    case 0xFF475569: // Nordic Steel
      return const Color(0xFF1E293B);
    default:
      return const Color(0xFF022C22);
  }
}

/// A widget that wraps screens with the dynamic brand gradient background.
///
/// Under dark mode, the gradient smoothly transitions from Deep Slate Dark
/// (#0F172A) at the top to a dynamic bottom color selected to match the user's
/// active primary theme color preset.
/// Under light mode, the gradient transitions from soft pastel mint (#EFFDF5)
/// to soft premium grey (#F9FAFB).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Prevent duplicate backgrounds when screens are nested (e.g. inside HomeScreen tabs)
    final hasAncestor = context.findAncestorWidgetOfExactType<AppBackground>() != null;
    if (hasAncestor) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F172A), // Deep Slate Dark
                  darkGradientBottomColor(primaryColor), // Curated Obsidian tone
                ]
              : [
                  const Color(0xFFEFFDF5), // Soft pastel mint
                  const Color(0xFFF9FAFB), // Soft premium grey
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
