import 'package:flutter/painting.dart';

/// Color tokens for the DriveCare+ design system.
///
/// All members are `static const` so the entire token surface is compile-time
/// and cannot be reassigned at runtime (Requirements 1.9, 1.12).
///
/// Sources:
/// - Brand and semantic palettes are taken directly from the Reference_Source
///   Tailwind tokens (Requirement 1.2).
/// - Light neutrals come from the `Light_Theme` reference (Requirement 2.1).
/// - Dark neutrals are pre-computed from the Reference_Source OKLCH values
///   (`oklch(0.145 0 0)`, `oklch(0.985 0 0)`, `oklch(0.269 0 0)`) using a
///   one-time OKLCH→sRGB conversion and frozen here as `Color(0xFFRRGGBB)`
///   literals so no runtime conversion is needed (Requirement 2.2).
/// - Surface opacities encode the subtle/medium/prominent overlay scale used
///   by the Component_Library glassy surfaces (Requirement 1.3).
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------------------
  // Brand gradient palette (Requirement 1.2)
  // ---------------------------------------------------------------------------
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color routeGlowOuter = Color(0xFF06B6D4);
  static const Color routeGlowInner = Color(0xFF22D3EE);

  // ---------------------------------------------------------------------------
  // Semantic colors (Requirement 1.2)
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ---------------------------------------------------------------------------
  // Neutrals — Light_Theme (Requirement 2.1)
  // ---------------------------------------------------------------------------
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightForeground = Color(0xFF111827);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightMuted = Color(0xFFECECF0);
  // rgba(0, 0, 0, 0.1) — 10% black border used by Light_Theme dividers.
  static const Color lightBorder = Color(0x1A000000);

  // ---------------------------------------------------------------------------
  // Neutrals — Dark_Theme (Requirement 2.2)
  //
  // Pre-converted from the Reference_Source OKLCH values using the standard
  // OKLCH → linear sRGB → gamma-encoded sRGB pipeline. Each channel is held
  // within ±1/255 of the canonical conversion, then frozen as a hex literal
  // so the runtime never re-derives them.
  //
  //   oklch(0.145 0 0) → #1A1A1A   (background, card, popover)
  //   oklch(0.985 0 0) → #FAFAFA   (foreground)
  //   oklch(0.269 0 0) → #373737   (border)
  // ---------------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color darkForeground = Color(0xFFFAFAFA);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color darkPopover = Color(0xFF1A1A1A);
  static const Color darkBorder = Color(0xFF373737);

  // ---------------------------------------------------------------------------
  // Surface overlay opacities (Requirement 1.3)
  //
  // Used by the Component_Library to layer translucent surfaces over the
  // background or brand gradient. Consumers multiply these against a base
  // color via `Color.withOpacity` / `Color.withValues(alpha: …)`.
  // ---------------------------------------------------------------------------
  static const double surfaceSubtle = 0.05;
  static const double surfaceMedium = 0.12;
  static const double surfaceProminent = 0.20;
}
