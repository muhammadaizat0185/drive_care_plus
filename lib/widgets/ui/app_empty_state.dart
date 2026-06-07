import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Standardized empty-state layout for the DriveCare+ Component_Library.
///
/// Used by screens to communicate "no results" or "no data yet" branches in
/// a consistent way (workshops empty search, vault empty filter, refuel
/// history, vehicle maintenance/upcoming-tasks empty, wallet history empty,
/// etc.). Renders a centered column with:
///
///   * a large muted [icon];
///   * a [title] in `AppTypography.headline`;
///   * an optional [message] in `AppTypography.body`;
///   * an optional [action] CTA below the copy (typically a Component_Library
///     button such as `AppGradientButton` or `AppSecondaryButton`).
///
/// All children are separated by `AppSpacing.md` gaps so the vertical rhythm
/// matches the rest of the redesigned screens.
///
/// Every visual constant — icon size, copy color, spacing, typography —
/// flows from the design-token extensions on `Theme.of(context)`; no hex
/// colors, spacing, radii, or typography literals from the Token_Sets are
/// inlined (Requirement 3.11).
///
/// Example:
/// ```dart
/// AppEmptyState(
///   icon: Icons.search_off,
///   title: 'No workshops found',
///   message: 'Try a different search term or category.',
///   action: AppSecondaryButton(
///     label: 'Clear filters',
///     onPressed: _clearFilters,
///   ),
/// );
/// ```
class AppEmptyState extends StatelessWidget {
  /// Leading icon rendered in muted-foreground tone above the copy.
  final IconData icon;

  /// Headline text rendered in `AppTypography.headline`.
  final String title;

  /// Optional supporting copy rendered in `AppTypography.body` below the
  /// title.
  final String? message;

  /// Optional CTA widget rendered below the copy.
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  // Visual size of the leading icon. Empty-state glyphs read clearly above
  // the headline at this size; not a Token_Set value, so encoded locally.
  static const double _iconSize = 64.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    // Muted foreground: foreground softened via the `surfaceProminent`
    // overlay so the empty state recedes from primary content. Same
    // muted-foreground language used by `AppSectionHeader` and the
    // disabled-foreground rules in `AppPrimaryButton` / `AppIconButton`.
    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent);

    final TextStyle titleStyle =
        typography.headline.copyWith(color: colors.foreground);
    final TextStyle messageStyle =
        typography.body.copyWith(color: mutedForeground);

    final List<Widget> children = <Widget>[
      Icon(icon, size: _iconSize, color: mutedForeground),
      SizedBox(height: spacing.md),
      Text(title, style: titleStyle, textAlign: TextAlign.center),
    ];

    if (message != null) {
      children.add(SizedBox(height: spacing.md));
      children.add(
        Text(message!, style: messageStyle, textAlign: TextAlign.center),
      );
    }

    if (action != null) {
      children.add(SizedBox(height: spacing.md));
      children.add(action!);
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }
}
