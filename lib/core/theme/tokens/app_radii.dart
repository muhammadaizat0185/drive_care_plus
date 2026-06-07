/// Border-radius tokens for the DriveCare+ design system.
///
/// All members are `static const` so the entire token surface is compile-time
/// and cannot be reassigned at runtime (Requirements 1.9, 1.12).
///
/// Values are expressed in logical pixels and match the Reference_Source
/// corner-radius scale (Requirement 1.5):
///
///   small = 12, medium = 16, large = 24, xLarge = 32
class AppRadii {
  const AppRadii._();

  // ---------------------------------------------------------------------------
  // Corner-radius scale (Requirement 1.5) — all in logical pixels.
  // ---------------------------------------------------------------------------
  static const double small = 12.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double xLarge = 32.0;
}
