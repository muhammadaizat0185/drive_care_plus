import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '_focus_indicator.dart';
import '_press_scale.dart';
import 'app_spinner.dart';

/// Wider gradient pill used as a primary CTA across the DriveCare+
/// Component_Library (Sign In, Save Profile, Top Up, etc.).
///
/// Renders a full-width gradient pill from `AppColors.emerald500` to
/// `AppColors.teal400`. Shares the press-scale animation contract with
/// `AppPrimaryButton` (0.98x ↔ 1.0x in 100 ms, within the 80–200 ms
/// inclusive window from Requirement 3.2) and the same disabled rules
/// from Requirement 3.12.
///
/// When [isLoading] is `true`, the button shows an inline spinner in
/// place of the label and **rejects all gestures** so a single user
/// gesture maps to a single in-flight action (Requirements 5.7, 11.5).
///
/// Every visual constant comes from the design-token extensions on
/// `Theme.of(context)`; no hex colors, spacing, radii, typography, or
/// duration literals from the Token_Sets are inlined (Requirement 3.11).
///
/// The minimum height of 48 logical pixels enforces the
/// `Touch_Target_Floor` from Requirement 3.10.
class AppGradientButton extends StatelessWidget {
  /// Visible label rendered with `AppTypography.title` styling.
  final String label;

  /// Tap callback. `null` → disabled state per Requirement 3.12.
  final VoidCallback? onPressed;

  /// Optional leading icon rendered to the left of [label].
  final IconData? icon;

  /// When `true`, an inline spinner replaces the label and all gestures
  /// are detached so additional taps cannot trigger a second invocation
  /// (Requirements 5.7, 11.5).
  final bool isLoading;

  /// When `true`, the button stretches to its parent's full width.
  /// Defaults to `true` because the gradient pill is the primary CTA
  /// pattern and is laid out edge-to-edge in the redesigned screens.
  final bool fullWidth;

  const AppGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  // `Touch_Target_Floor` from Requirement 3.10. Held as a local constant
  // because it's an accessibility floor, not a layout token.
  static const double _minHitArea = 48.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final bool disabled = onPressed == null;
    // Loading also short-circuits gestures (Requirements 5.7, 11.5).
    final bool gesturesEnabled = !disabled && !isLoading;

    final BorderRadius borderRadius = BorderRadius.circular(radii.large);

    // Active vs disabled treatment. Active: brand gradient. Disabled:
    // flat muted surface (Requirement 3.12).
    final Decoration decoration = disabled
        ? BoxDecoration(
            color: colors.muted,
            borderRadius: borderRadius,
          )
        : BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[colors.emerald500, colors.teal400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: borderRadius,
          );

    final Color contentColor = disabled
        ? colors.foreground.withValues(alpha: colors.surfaceProminent)
        : Colors.white;

    final TextStyle labelStyle = typography.title.copyWith(color: contentColor);

    final Widget content;
    if (isLoading) {
      // Inline spinner replaces the label while the button is in flight.
      // Sized to the title type scale so it occupies the same vertical
      // space as the label it stands in for, and tinted white so it reads
      // against the active brand-gradient surface.
      content = AppSpinner(
        size: typography.title.fontSize ?? 16,
        color: Colors.white,
      );
    } else {
      content = Row(
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
    }

    final Widget visual = Container(
      constraints: const BoxConstraints(
        minWidth: _minHitArea,
        minHeight: _minHitArea,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xl,
        vertical: spacing.md,
      ),
      decoration: decoration,
      alignment: Alignment.center,
      child: content,
    );

    final Widget interactive = Semantics(
      button: true,
      enabled: gesturesEnabled,
      label: label,
      child: AppFocusIndicator(
        enabled: gesturesEnabled,
        borderRadius: borderRadius,
        child: PressScale(
          enabled: gesturesEnabled,
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
