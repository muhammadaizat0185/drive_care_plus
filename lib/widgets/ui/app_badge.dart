import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import 'types.dart';

/// Compact pill badge used to surface status, category, or count chips
/// across the DriveCare+ Component_Library.
///
/// Renders [text] with `AppTypography.label` styling inside a rounded
/// pill whose background and foreground colors are driven by the
/// [BadgeKind] variant:
///
///   * `neutral` → muted surface background, default foreground.
///   * `success` → `AppColors.success` background, white foreground.
///   * `warning` → `AppColors.warning` background, white foreground.
///   * `error`   → `AppColors.error`   background, white foreground.
///   * `info`    → `AppColors.info`    background, white foreground.
///   * `brand`   → `emerald500 → teal400` gradient, white foreground.
///
/// Every visual constant — colors, padding, radius, typography — flows
/// from the design-token extensions on `Theme.of(context)`; no hex
/// colors, spacing, radii, typography, or duration literals from the
/// Token_Sets are inlined (Requirement 3.11).
///
/// `AppBadge` is a static, non-interactive surface; it does not accept
/// gestures and is sized to its intrinsic content.
///
/// Example:
/// ```dart
/// AppBadge(text: 'NEW', kind: BadgeKind.brand);
/// AppBadge(text: 'High', kind: BadgeKind.error);
/// ```
class AppBadge extends StatelessWidget {
  /// Visible label rendered with `AppTypography.label` styling.
  final String text;

  /// Visual variant; defaults to [BadgeKind.neutral].
  final BadgeKind kind;

  const AppBadge({
    super.key,
    required this.text,
    this.kind = BadgeKind.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final _BadgePalette palette = _paletteFor(kind, colors);

    final BorderRadius borderRadius = BorderRadius.circular(radii.small);

    final Decoration decoration = palette.gradient != null
        ? BoxDecoration(
            gradient: palette.gradient,
            borderRadius: borderRadius,
          )
        : BoxDecoration(
            color: palette.background,
            borderRadius: borderRadius,
          );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      decoration: decoration,
      child: Text(
        text,
        style: typography.label.copyWith(color: palette.foreground),
      ),
    );
  }

  /// Resolves the per-variant background, foreground, and optional
  /// gradient palette from the active color tokens.
  static _BadgePalette _paletteFor(BadgeKind kind, AppColorsExt colors) {
    switch (kind) {
      case BadgeKind.neutral:
        return _BadgePalette(
          background: colors.muted,
          foreground: colors.foreground,
        );
      case BadgeKind.success:
        return _BadgePalette(
          background: colors.success,
          foreground: Colors.white,
        );
      case BadgeKind.warning:
        return _BadgePalette(
          background: colors.warning,
          foreground: Colors.white,
        );
      case BadgeKind.error:
        return _BadgePalette(
          background: colors.error,
          foreground: Colors.white,
        );
      case BadgeKind.info:
        return _BadgePalette(
          background: colors.info,
          foreground: Colors.white,
        );
      case BadgeKind.brand:
        return _BadgePalette(
          background: Colors.transparent,
          foreground: Colors.white,
          gradient: LinearGradient(
            colors: <Color>[colors.emerald500, colors.teal400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
    }
  }
}

/// Resolved color triplet used to render a single [AppBadge] variant.
@immutable
class _BadgePalette {
  final Color background;
  final Color foreground;
  final Gradient? gradient;

  const _BadgePalette({
    required this.background,
    required this.foreground,
    this.gradient,
  });
}
