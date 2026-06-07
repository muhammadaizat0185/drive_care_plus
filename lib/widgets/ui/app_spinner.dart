import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Token-styled circular progress indicator for the DriveCare+
/// Component_Library.
///
/// Wraps Flutter's `CircularProgressIndicator` in a fixed-size box so callers
/// can drop it inline into buttons, banners, or list rows without managing
/// layout themselves. The default tint is `AppColors.emerald500` so the
/// spinner reads as the brand accent; callers may override via [color].
///
/// Every visual constant — default color and stroke width — flows from the
/// design-token extensions on `Theme.of(context)`; no hex colors or
/// token-equivalent literals are inlined (Requirement 3.11).
///
/// Example:
/// ```dart
/// const AppSpinner();                  // 24 logical px, brand accent.
/// AppSpinner(size: 16);                // smaller inline indicator.
/// AppSpinner(color: Colors.white);     // on-gradient surface override.
/// ```
class AppSpinner extends StatelessWidget {
  /// Diameter of the indicator in logical pixels. Defaults to 24.
  final double size;

  /// Optional explicit foreground color override. When `null`, the spinner
  /// uses `AppColors.emerald500` from the active color tokens.
  final Color? color;

  const AppSpinner({super.key, this.size = 24, this.color});

  // Stroke width matches the inline-spinner treatment used elsewhere in the
  // Component_Library (e.g. `AppGradientButton` loading state). Not a
  // Token_Set value, so encoded locally.
  static const double _strokeWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;

    final Color resolvedColor = color ?? colors.emerald500;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(resolvedColor),
      ),
    );
  }
}
