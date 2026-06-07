import 'package:flutter/painting.dart';

/// Shadow tokens for the DriveCare+ design system.
///
/// All members are `static const` so the entire token surface is compile-time
/// and cannot be reassigned at runtime (Requirements 1.9, 1.12).
///
/// The four shadow scales (`small`, `medium`, `large`, `xLarge`) match the
/// Reference_Source values exactly (Requirement 1.7):
///
///   small  → rgba(0, 0, 0, 0.05) blur=2  offset=(0, 1)
///   medium → rgba(0, 0, 0, 0.10) blur=6  offset=(0, 4)
///   large  → rgba(0, 0, 0, 0.10) blur=15 offset=(0, 10)
///   xLarge → rgba(0, 0, 0, 0.15) blur=25 offset=(0, 20)
///
/// The light-mode opacity bytes are encoded directly in the ARGB literals:
///   0x0D ≈ 13/255  ≈ 0.05
///   0x1A ≈ 26/255  ≈ 0.10
///   0x26 ≈ 38/255  ≈ 0.15
///
/// Dark mode is not represented as a separate `static const` list because
/// `BoxShadow.color` is the only field that varies between modes. Instead,
/// `AppTheme.buildTheme` produces the dark variant at theme-build time by
/// running each list through `color_utils.scaleShadowOpacity(list, factor)`
/// with `factor = AppShadows.darkOpacityMultiplier` (Requirement 1.8). The
/// per-shadow opacity becomes `(originalOpacity * 2.5).clamp(0.0, 1.0)` and
/// every other field (blur, offset, spread, color RGB) is preserved.
class AppShadows {
  const AppShadows._();

  // ---------------------------------------------------------------------------
  // Light-mode shadow scale (Requirement 1.7) — authoritative source.
  // ---------------------------------------------------------------------------

  /// Subtle elevation for resting cards and small surfaces.
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// Standard elevation for raised cards, dropdowns, and popovers.
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 6,
      offset: Offset(0, 4),
    ),
  ];

  /// Pronounced elevation for floating bottom navigation and sheets.
  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 15,
      offset: Offset(0, 10),
    ),
  ];

  /// Maximum elevation for modals, dialogs, and full-screen overlays.
  static const List<BoxShadow> xLarge = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 25,
      offset: Offset(0, 20),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Dark-mode opacity multiplier (Requirement 1.8) — applied at theme build
  // time via `color_utils.scaleShadowOpacity`, not at compile time.
  // ---------------------------------------------------------------------------

  /// Factor applied to each light-mode shadow's color opacity to derive its
  /// dark-mode counterpart. Resulting opacity is clamped to `[0.0, 1.0]`.
  static const double darkOpacityMultiplier = 2.5;
}
