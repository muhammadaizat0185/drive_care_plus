import 'package:flutter/painting.dart';

/// Typography tokens for the DriveCare+ design system.
///
/// All members are `static const` so the entire token surface is compile-time
/// and cannot be reassigned at runtime (Requirements 1.9, 1.12).
///
/// The seven roles below cover every text slot used by the redesign and map
/// onto Material `TextTheme` slots in `AppTheme.buildTheme` (Requirement 2.10):
///
///   display       → 32 / w900
///   headlineLarge → 24 / w900
///   headline      → 20 / w800
///   title         → 16 / w700
///   bodyLarge     → 14 / w400
///   body          → 12 / w400  (accessibility floor — Requirement 13.1)
///   label         → 10 / w700  (accessibility floor — Requirement 13.2)
///
/// Only `fontSize` and `fontWeight` are encoded here; color, height, and
/// letter spacing are applied by the theme/text widgets at consumption time
/// so the tokens stay reusable across light and dark surfaces.
///
/// Requirements: 1.6, 13.1, 13.2.
class AppTypography {
  const AppTypography._();

  // ---------------------------------------------------------------------------
  // Type ramp (Requirement 1.6).
  // ---------------------------------------------------------------------------
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// Smallest body text in the design system.
  ///
  /// `fontSize == 12` is enforced as the accessibility floor for body copy
  /// (Requirement 13.1) and is asserted by the token unit tests.
  static const TextStyle body = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Smallest label text in the design system.
  ///
  /// `fontSize == 10` is enforced as the accessibility floor for label copy
  /// (Requirement 13.2) and is asserted by the token unit tests.
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );
}
