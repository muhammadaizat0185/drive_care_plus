import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '_focus_indicator.dart';
import '_press_scale.dart';

/// Outlined secondary call-to-action button for the DriveCare+
/// Component_Library.
///
/// Visually a transparent pill with a 2-logical-pixel border and foreground
/// text in `AppColors.emerald500`. Shares the press-scale animation contract
/// with `AppPrimaryButton` (0.98x ↔ 1.0x in 100 ms, within the 80–200 ms
/// inclusive window from Requirement 3.2) and the same disabled rules from
/// Requirement 3.12: when `onPressed == null`, the button renders with the
/// muted disabled treatment and ignores tap, press, and long-press gestures.
///
/// Every visual constant — border width is the only spec-imposed literal
/// outside the Token_Sets — comes from the design-token extensions on
/// `Theme.of(context)`; no hex colors, spacing, radii, typography, or
/// duration literals from the Token_Sets are inlined (Requirement 3.11).
///
/// The minimum height of 48 logical pixels enforces the `Touch_Target_Floor`
/// from Requirement 3.10 even when the button's intrinsic content is
/// smaller.
class AppSecondaryButton extends StatelessWidget {
  /// Visible label rendered with `AppTypography.title` styling.
  final String label;

  /// Tap callback. `null` → disabled state per Requirement 3.12.
  final VoidCallback? onPressed;

  /// Optional leading icon rendered to the left of [label].
  final IconData? icon;

  /// When `true`, the button stretches to its parent's full width.
  final bool fullWidth;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
  });

  // `Touch_Target_Floor` from Requirement 3.10. Held as a local constant
  // because it's an accessibility floor, not a layout token.
  static const double _minHitArea = 48.0;

  // The 2-logical-pixel border width is part of the secondary-button visual
  // contract. There is no border-width token in the Token_Sets, so encoding
  // it as a private constant here does not violate Requirement 3.11.
  static const double _borderWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final bool disabled = onPressed == null;

    final BorderRadius borderRadius = BorderRadius.circular(radii.large);

    // Active vs disabled treatment. Active: emerald500 border + emerald500
    // foreground on a transparent background. Disabled: muted border +
    // muted foreground (Requirement 3.12).
    final Color borderColor =
        disabled ? colors.muted : colors.emerald500;
    final Color contentColor = disabled
        ? colors.foreground.withValues(alpha: colors.surfaceProminent)
        : colors.emerald500;

    final TextStyle labelStyle = typography.title.copyWith(color: contentColor);

    final Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, color: contentColor, size: typography.title.fontSize),
          SizedBox(width: spacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: labelStyle,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final Widget visual = Container(
      constraints: const BoxConstraints(
        minWidth: _minHitArea,
        minHeight: _minHitArea,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xl,
        vertical: spacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: _borderWidth),
      ),
      alignment: Alignment.center,
      child: content,
    );

    final Widget interactive = Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: AppFocusIndicator(
        enabled: !disabled,
        borderRadius: borderRadius,
        child: PressScale(
          enabled: !disabled,
          onTap: onPressed,
          child: visual,
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: interactive);
    }
    return interactive;
  }
}
