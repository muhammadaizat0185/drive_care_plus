import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Thin status-bar accent used at the top of full-bleed scenes in the
/// DriveCare+ Component_Library.
///
/// Renders a `24` logical-pixel tall, full-width band that mirrors the
/// device's status bar visual but is painted by the app so full-bleed
/// scenes (login hero, splash, onboarding) can sit underneath the
/// system status bar with a subtle, brightness-aware overlay.
///
/// The band is painted with the foreground token at the
/// `surfaceSubtle` opacity so the accent reads consistently against
/// both light and dark backgrounds. The [brightness] parameter is
/// honoured by inverting the foreground source: `Brightness.light`
/// (light surface beneath) uses the dark foreground; `Brightness.dark`
/// (dark surface beneath) uses the light foreground.
///
/// Every visual constant comes from the design-token extensions on
/// `Theme.of(context)`; no hex color, spacing, radius, typography, or
/// duration literals from the Token_Sets are inlined (Requirement 3.11).
///
/// `AppPhoneStatusBar` is a static, non-interactive overlay; it does
/// not accept gestures.
class AppPhoneStatusBar extends StatelessWidget {
  /// Brightness of the surface this status bar is painted over. Used
  /// to pick the foreground tint so the accent stays legible in both
  /// `Light_Theme` and `Dark_Theme`.
  final Brightness brightness;

  const AppPhoneStatusBar({
    super.key,
    required this.brightness,
  });

  // Status-bar band height. This is a component-local sizing constant
  // (not part of the spacing token scale) and lives here so the
  // contract is explicit at the call site.
  static const double _height = 24.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;

    // Pick the foreground source so the band reads against the
    // surface beneath it: a light surface needs the dark foreground
    // tint, a dark surface needs the light foreground tint.
    final Color tintSource = brightness == Brightness.light
        ? colors.foreground
        : Colors.white;

    final Color tint =
        tintSource.withValues(alpha: colors.surfaceSubtle);

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: ColoredBox(color: tint),
    );
  }
}
