/// Spacing tokens for the DriveCare+ design system.
///
/// All members are `static const` so the entire token surface is compile-time
/// and cannot be reassigned at runtime (Requirements 1.9, 1.12).
///
/// Values are expressed in logical pixels and follow the geometric scale
/// defined in the Reference_Source spacing tokens (Requirement 1.4):
///
///   xs = 4,  sm = 8,  md = 12, lg = 16,
///   xl = 24, xxl = 32, xxxl = 40, xxxxl = 48
class AppSpacing {
  const AppSpacing._();

  // ---------------------------------------------------------------------------
  // Spacing scale (Requirement 1.4) — all in logical pixels.
  // ---------------------------------------------------------------------------
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double xxxxl = 48.0;
}
