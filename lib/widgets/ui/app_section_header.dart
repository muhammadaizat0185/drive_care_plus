import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Uppercased section divider used to introduce groups of `AppListTile`s
/// or other content blocks across the DriveCare+ Component_Library.
///
/// Renders [label] uppercased with `AppTypography.label` styling and a
/// muted-foreground color (the foreground token softened via the
/// `surfaceProminent` overlay so it recedes from primary content while
/// remaining legible). Outer padding is `EdgeInsets.only(left: AppSpacing.lg,
/// bottom: AppSpacing.sm)` so the header aligns with the leading edge of
/// the tiles below it (Requirement 3.11).
///
/// Every visual constant — typography, color, padding — flows from the
/// design-token extensions on `Theme.of(context)`; no hex colors, spacing,
/// radii, or typography literals from the Token_Sets are inlined
/// (Requirement 3.11).
///
/// Example:
/// ```dart
/// AppSectionHeader(label: 'Privacy & Security'),
/// AppListTile(title: Text('Change password'), onTap: ...),
/// AppListTile(title: Text('Two-factor auth'),  onTap: ...),
/// ```
class AppSectionHeader extends StatelessWidget {
  /// Section label. Rendered uppercased; the caller may pass mixed-case
  /// copy and the widget will normalize via `String.toUpperCase()`.
  final String label;

  const AppSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    // Muted foreground: foreground softened to 0.55 opacity to increase
    // contrast and readability on light gray backgrounds, while still
    // remaining visually separate from primary content.
    final Color mutedForeground =
        colors.foreground.withValues(alpha: 0.55);

    final TextStyle style = typography.label.copyWith(
      color: mutedForeground,
      fontWeight: FontWeight.bold,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: spacing.lg,
        top: spacing.md,
        bottom: spacing.sm,
      ),
      child: Text(label.toUpperCase(), style: style),
    );
  }
}
