import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import 'app_icon_button.dart';
import 'types.dart';

/// Status banner used to surface success, error, warning, or informational
/// messages above the affected screen content in the DriveCare+
/// Component_Library.
///
/// The banner accepts a `kind` of [FeedbackKind.success], [FeedbackKind.error],
/// [FeedbackKind.warning], or [FeedbackKind.info] and applies the matching
/// semantic background, border, and icon colors from the color Token_Set
/// (Requirement 3.7). The same semantic color is used at full saturation for
/// the leading icon and border, and as a low-saturation tint
/// (`AppColors.surfaceMedium = 0.12` alpha) for the background, so the banner
/// reads as the correct semantic kind at a glance without overwhelming the
/// surrounding content.
///
/// `kind` → leading icon mapping:
///
///   * `success` → `Icons.check_circle`
///   * `error`   → `Icons.error`
///   * `warning` → `Icons.warning`
///   * `info`    → `Icons.info`
///
/// When [onDismiss] is non-null, a trailing `AppIconButton` with semantics
/// label `"Dismiss"` is rendered; tapping it invokes [onDismiss]. When
/// [onDismiss] is `null`, no dismiss affordance is rendered and the banner
/// is purely informational.
///
/// Every visual constant — colors, padding, radius, typography, border
/// width — flows from the design-token extensions on `Theme.of(context)`;
/// no hex colors, spacing, radii, typography, or duration literals from the
/// Token_Sets are inlined (Requirement 3.11).
///
/// Example:
/// ```dart
/// AppFeedbackBanner(
///   kind: FeedbackKind.error,
///   message: 'Could not save profile. Please try again.',
///   onDismiss: () => setState(() => _saveError = null),
/// );
/// ```
class AppFeedbackBanner extends StatelessWidget {
  /// Banner copy rendered with `AppTypography.bodyLarge` styling.
  final String message;

  /// Semantic kind driving background, border, and icon colors.
  final FeedbackKind kind;

  /// Optional dismiss callback. When non-null, a trailing dismiss button is
  /// rendered with semantics label `"Dismiss"`.
  final VoidCallback? onDismiss;

  const AppFeedbackBanner({
    super.key,
    required this.message,
    required this.kind,
    this.onDismiss,
  });

  // The 1-logical-pixel border width is part of the banner visual contract
  // and matches the default `Border.all` width. There is no border-width
  // token in the Token_Sets, so encoding it as a private constant here does
  // not violate Requirement 3.11.
  static const double _borderWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Color accent = _accentFor(kind, colors);
    final IconData iconData = _iconFor(kind);

    final BorderRadius borderRadius = BorderRadius.circular(radii.medium);

    // Low-saturation tinted background using the `surfaceMedium` overlay
    // (0.12 alpha) so the banner reads as the correct semantic kind without
    // overwhelming surrounding content. Border is the same accent at full
    // saturation for clarity at the surface edge.
    final Decoration decoration = BoxDecoration(
      color: accent.withValues(alpha: colors.surfaceMedium),
      borderRadius: borderRadius,
      border: Border.all(color: accent, width: _borderWidth),
    );

    final TextStyle messageStyle =
        typography.bodyLarge.copyWith(color: colors.foreground);

    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.md,
        ),
        decoration: decoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(
              iconData,
              color: accent,
              size: typography.title.fontSize,
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Text(message, style: messageStyle),
            ),
            if (onDismiss != null) ...<Widget>[
              SizedBox(width: spacing.sm),
              AppIconButton(
                icon: Icons.close,
                onPressed: onDismiss,
                semanticsLabel: 'Dismiss',
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Maps a [FeedbackKind] to its full-saturation accent color from the
  /// active color tokens.
  static Color _accentFor(FeedbackKind kind, AppColorsExt colors) {
    switch (kind) {
      case FeedbackKind.success:
        return colors.success;
      case FeedbackKind.error:
        return colors.error;
      case FeedbackKind.warning:
        return colors.warning;
      case FeedbackKind.info:
        return colors.info;
    }
  }

  /// Maps a [FeedbackKind] to its leading Material icon.
  static IconData _iconFor(FeedbackKind kind) {
    switch (kind) {
      case FeedbackKind.success:
        return Icons.check_circle;
      case FeedbackKind.error:
        return Icons.error;
      case FeedbackKind.warning:
        return Icons.warning;
      case FeedbackKind.info:
        return Icons.info;
    }
  }
}
