import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Token-driven card surface for the DriveCare+ Component_Library.
///
/// Renders [child] on top of a `colors.card` surface with a 1-logical-pixel
/// `colors.border` outline, a subtle `shadows.small` elevation, and
/// `AppRadii.large` corners (Requirement 3.11). Default content padding is
/// `AppSpacing.lg` on all sides; callers may override via [padding].
///
/// When [onTap] is provided, the card becomes interactive: taps are routed
/// through `InkWell` so Material ripples honor the rounded corners, and the
/// card enforces a minimum hit area of 48x48 logical pixels via a
/// [ConstrainedBox] floor matching the `Touch_Target_Floor` from
/// Requirements 3.10 / 13.3. When [onTap] is `null`, the card is a static
/// surface and emits no gesture or splash.
///
/// Every visual constant — surface color, border color, shadow, radius,
/// padding — flows from the design-token extensions on `Theme.of(context)`;
/// no hex colors, spacing, radii, or typography literals from the
/// Token_Sets are inlined (Requirement 3.11).
///
/// Example:
/// ```dart
/// AppCard(
///   onTap: () => Navigator.of(context).pushNamed('/details'),
///   child: Column(
///     crossAxisAlignment: CrossAxisAlignment.start,
///     children: const <Widget>[
///       Text('Toyota Vios'),
///       Text('WMK 1234'),
///     ],
///   ),
/// );
/// ```
class AppCard extends StatelessWidget {
  /// Visible content rendered inside the card's padded interior.
  final Widget child;

  /// Optional content padding override. When `null`, defaults to
  /// `AppSpacing.lg` on all sides (read from the active theme tokens).
  final EdgeInsetsGeometry? padding;

  /// Optional tap callback. When non-null, the card becomes interactive
  /// and an `InkWell` ripple is rendered on press. When `null`, the card
  /// is a static surface.
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  // 1-logical-pixel border width matches the default `Border.all` width and
  // mirrors the contract shared with `AppFeedbackBanner`. There is no
  // border-width token in the Token_Sets, so encoding it as a private
  // constant here does not violate Requirement 3.11.
  static const double _borderWidth = 1.0;

  // `Touch_Target_Floor` from Requirements 3.10 / 13.3. Held as a local
  // constant because it's an accessibility floor, not a layout token.
  static const double _minHitArea = 48.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppShadowsExt shadows = theme.extension<AppShadowsExt>()!;

    final BorderRadius borderRadius = BorderRadius.circular(radii.large);
    final EdgeInsetsGeometry resolvedPadding =
        padding ?? EdgeInsets.all(spacing.lg);

    final Decoration decoration = BoxDecoration(
      color: colors.card,
      borderRadius: borderRadius,
      border: Border.all(color: colors.border, width: _borderWidth),
      boxShadow: shadows.small,
    );

    // Static surface: no gesture, no splash. The surface itself owns the
    // shadow + decoration.
    if (onTap == null) {
      return Container(
        decoration: decoration,
        child: Padding(padding: resolvedPadding, child: child),
      );
    }

    // Interactive surface: the decoration container owns the shadow and
    // border; an inner `Material` + `InkWell` clips the ripple to the
    // rounded corners and enforces the 48x48 hit-area floor via
    // `ConstrainedBox`.
    return Container(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minHitArea,
              minHeight: _minHitArea,
            ),
            child: Padding(padding: resolvedPadding, child: child),
          ),
        ),
      ),
    );
  }
}
