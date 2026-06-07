import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '_focus_indicator.dart';

/// Single-select pill chip used in workshops, vault, and refuel category
/// rows of the DriveCare+ Component_Library.
///
/// Renders [label] inside a rounded pill. When [selected] is `true` the
/// pill background is the brand gradient
/// (`AppColors.emerald500 → AppColors.teal400`) with white foreground;
/// when `false` the background is the muted surface token and the
/// foreground falls back to `AppColors.foreground` so the chip recedes
/// into the row.
///
/// An optional [trailingPriceText] is rendered below [label] using the
/// `AppTypography.label` style and is used by the refuel screen to
/// surface preset fuel prices (e.g. `RM 2.05/L`) directly inside the
/// fuel-type chip.
///
/// The widget guarantees a `48 x 48` logical-pixel hit area per the
/// `Touch_Target_Floor` from Requirement 3.10 / 13.3, even when the
/// chip's visual height is smaller.
///
/// Every visual constant — gradient stops, padding, corner radius,
/// label typography — comes from the design-token extensions on
/// `Theme.of(context)`; no hex color, spacing, radius, typography, or
/// duration literals from the Token_Sets are inlined (Requirement 3.11).
class AppCategoryChip extends StatelessWidget {
  /// Visible label rendered with `AppTypography.title` styling.
  final String label;

  /// Whether the chip is the currently-selected option in its row.
  final bool selected;

  /// Tap callback. The chip is always interactive — single-select rows
  /// are expected to handle the case where the same chip is tapped
  /// twice in a row at the controller level.
  final VoidCallback onTap;

  /// Optional secondary line rendered beneath [label]. When `null`,
  /// the chip renders the label only.
  final String? trailingPriceText;

  const AppCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingPriceText,
  });

  // `Touch_Target_Floor` from Requirement 3.10 / 13.3. Held as a local
  // constant because it's an accessibility floor, not a layout token.
  static const double _minHitArea = 48.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final BorderRadius borderRadius = BorderRadius.circular(radii.medium);

    final Decoration decoration = selected
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[colors.emerald500, colors.teal400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: borderRadius,
          )
        : BoxDecoration(
            color: colors.muted,
            borderRadius: borderRadius,
          );

    final Color foreground =
        selected ? Colors.white : colors.foreground;

    final TextStyle labelStyle =
        typography.title.copyWith(color: foreground);

    final TextStyle priceStyle = typography.label.copyWith(
      color: selected
          ? Colors.white
          : colors.foreground.withValues(alpha: colors.surfaceProminent),
    );

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          style: labelStyle,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        if (trailingPriceText != null) ...<Widget>[
          SizedBox(height: spacing.xs),
          Text(
            trailingPriceText!,
            style: priceStyle,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    final Widget visual = Container(
      constraints: const BoxConstraints(
        minWidth: _minHitArea,
        minHeight: _minHitArea,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.sm,
      ),
      decoration: decoration,
      alignment: Alignment.center,
      child: content,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AppFocusIndicator(
        enabled: true,
        borderRadius: borderRadius,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: visual,
        ),
      ),
    );
  }
}
