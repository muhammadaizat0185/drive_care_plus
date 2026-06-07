import 'package:flutter/animation.dart';

/// Motion tokens (durations + curves) for the DriveCare+ design system.
///
/// All members are `static const` so the entire token surface is compile-time
/// and cannot be reassigned at runtime (Requirements 1.9, 1.12).
///
/// The Reference_Source motion scale (Requirement 1.11) defines:
///
///   fast       = 150 ms
///   normal     = 300 ms
///   slow       = 500 ms
///   standard   = Curves.easeInOut    (default ease for token-driven motion)
///   emphasized = Curves.easeOutCubic (used for entrance/emphasis transitions)
class AppMotion {
  const AppMotion._();

  // ---------------------------------------------------------------------------
  // Durations (Requirement 1.11)
  // ---------------------------------------------------------------------------
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // ---------------------------------------------------------------------------
  // Curves (Requirement 1.11)
  // ---------------------------------------------------------------------------
  static const Curve standard = Curves.easeInOut;
  static const Curve emphasized = Curves.easeOutCubic;
}
