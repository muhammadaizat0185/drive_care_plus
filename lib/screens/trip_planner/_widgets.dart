// Trip planner extracted helpers (Group 14, Task 14.7).
//
// Hosts the route info chip and cost tile widgets used by the redesigned
// `TripPlannerScreen`. Keeps the screen file under the ~600-line ceiling
// stipulated by the Group 14 sweep playbook.

import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Pill-shaped info chip used to render the route distance/duration above
/// the trip planner action panel.
class TripInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const TripInfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.emerald500.withValues(alpha: colors.surfaceMedium),
        borderRadius: BorderRadius.circular(radii.large),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: typography.bodyLarge.fontSize,
              color: colors.emerald500),
          SizedBox(width: spacing.sm),
          Text(
            label,
            style: typography.bodyLarge.copyWith(color: colors.emerald500),
          ),
        ],
      ),
    );
  }
}

/// Cost tile used to render fuel consumption and estimated cost rows in
/// the trip planner action panel.
class TripCostTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? highlightColor;

  const TripCostTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(radii.medium),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: typography.title.fontSize, color: mutedForeground),
              SizedBox(width: spacing.md),
              Text(
                title,
                style:
                    typography.body.copyWith(color: mutedForeground),
              ),
            ],
          ),
          Text(
            value,
            style: typography.bodyLarge.copyWith(
              color: highlightColor ?? colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Blinking REC indicator used while a journey is being recorded.
class TripBlinkingRecordingIndicator extends StatefulWidget {
  const TripBlinkingRecordingIndicator({super.key});

  @override
  State<TripBlinkingRecordingIndicator> createState() =>
      _TripBlinkingRecordingIndicatorState();
}

class _TripBlinkingRecordingIndicatorState
    extends State<TripBlinkingRecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: colors.surfaceMedium),
          borderRadius: BorderRadius.circular(radii.large),
          border: Border.all(color: colors.error),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: spacing.sm,
              height: spacing.sm,
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: spacing.xs),
            Text(
              'REC',
              style: typography.label.copyWith(color: colors.error),
            ),
          ],
        ),
      ),
    );
  }
}
