import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Token-driven replacement for Material's [ListTile] used across the
/// DriveCare+ Component_Library.
///
/// Lays out an optional [leading] widget, a required [title], an optional
/// [subtitle], and an optional [trailing] widget in a single row. Spacing
/// between leading/title and title/trailing is `AppSpacing.md`; the row's
/// outer padding is
/// `EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md)`
/// (Requirement 3.11).
///
/// When [onTap] is provided, the tile becomes interactive: taps are routed
/// through an `InkWell` so the Material ripple is contained by the row, and
/// the tile enforces a minimum hit area of 48x48 logical pixels via a
/// [ConstrainedBox] floor matching the `Touch_Target_Floor` from
/// Requirements 3.10 / 13.3. When [onTap] is `null`, the tile is a static
/// row and emits no gesture or splash.
///
/// Every visual constant — spacing, padding — flows from the design-token
/// extensions on `Theme.of(context)`; no hex colors, spacing, radii, or
/// typography literals from the Token_Sets are inlined (Requirement 3.11).
/// Title and subtitle styling is owned by the caller so the same tile can
/// host varied text roles (settings labels, transaction descriptions,
/// maintenance entries).
///
/// Example:
/// ```dart
/// AppListTile(
///   leading: Icon(Icons.lock_outline),
///   title: Text('Change password', style: typography.bodyLarge),
///   subtitle: Text('Last updated 30 days ago', style: typography.body),
///   trailing: Icon(Icons.chevron_right),
///   onTap: () => Navigator.of(context).pushNamed('/security/password'),
/// );
/// ```
class AppListTile extends StatelessWidget {
  /// Optional leading widget rendered to the left of [title]. Typically an
  /// icon or avatar.
  final Widget? leading;

  /// Required title widget. Caller owns the text styling.
  final Widget title;

  /// Optional subtitle rendered below [title]. Caller owns the text
  /// styling.
  final Widget? subtitle;

  /// Optional trailing widget rendered to the right of the title column.
  /// Typically a chevron, badge, or icon button.
  final Widget? trailing;

  /// Optional tap callback. When non-null, the tile becomes interactive
  /// and an `InkWell` ripple is rendered on press. When `null`, the tile
  /// is a static row.
  final VoidCallback? onTap;

  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  // `Touch_Target_Floor` from Requirements 3.10 / 13.3. Held as a local
  // constant because it's an accessibility floor, not a layout token.
  static const double _minHitArea = 48.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    final EdgeInsetsGeometry rowPadding = EdgeInsets.symmetric(
      horizontal: spacing.lg,
      vertical: spacing.md,
    );

    // Title column: title plus optional subtitle stacked with a small gap.
    final Widget titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        title,
        if (subtitle != null) ...<Widget>[
          SizedBox(height: spacing.xs),
          subtitle!,
        ],
      ],
    );

    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading!,
          SizedBox(width: spacing.md),
        ],
        Expanded(child: titleColumn),
        if (trailing != null) ...<Widget>[
          SizedBox(width: spacing.md),
          trailing!,
        ],
      ],
    );

    // Static row: no gesture, no splash.
    if (onTap == null) {
      return Padding(padding: rowPadding, child: row);
    }

    // Interactive row: `Material` + `InkWell` so the ripple is contained,
    // and a `ConstrainedBox` floor enforces the 48x48 hit-area minimum.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minHitArea,
            minHeight: _minHitArea,
          ),
          child: Padding(padding: rowPadding, child: row),
        ),
      ),
    );
  }
}
