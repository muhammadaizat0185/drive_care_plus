import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Token-driven circular health gauge for the DriveCare+ Component_Library.
///
/// Renders a circular arc whose sweep is `percentage / 100 * 2π`, layered
/// over a muted track ring, with a centered percentage label. The arc
/// rendering replicates the `_HealthGaugePainter` logic from the existing
/// `vehicle_health_gauge.dart` for visual continuity (track ring + glow
/// underlay + crisp foreground arc), but the colors and motion durations
/// are sourced exclusively from the design-token extensions on
/// `Theme.of(context)`; no hex colors, durations, or token-equivalent
/// literals are inlined (Requirement 3.11).
///
/// Behaviour:
///
/// * `percentage == null` → renders the placeholder branch with the muted
///   track ring only (no active arc, no glow) and a centered `--%` text
///   (Requirements 4.4, 8.3).
/// * `percentage != null` → assumed already clamped by the caller via
///   `clampPercentage` (Requirements 4.3, 8.2). Values outside `[0, 100]`
///   are clamped defensively here as well so the painter is never asked
///   to sweep past a full circle.
/// * When [percentage] crosses the [criticalThreshold] (default `25`), the
///   active arc and centered numeric text adopt the `error` color from
///   the active token palette so the gauge reads as "needs attention" at
///   a glance.
/// * Percentage transitions are interpolated with `AppMotion.normal`
///   (300 ms) via [TweenAnimationBuilder] so the sweep eases between
///   states instead of snapping.
///
/// Example:
/// ```dart
/// // Live percentage from VehicleInsights.
/// AppHealthGauge(percentage: clampPercentage(rawValue)?.toDouble());
///
/// // Loading / error branch.
/// const AppHealthGauge(percentage: null);
///
/// // Custom size + label.
/// AppHealthGauge(percentage: 84, label: 'STATUS', size: 96);
/// ```
class AppHealthGauge extends StatelessWidget {
  /// Current gauge value in `[0, 100]`. `null` triggers the `--%`
  /// placeholder branch (Requirements 4.4, 8.3).
  final double? percentage;

  /// Optional uppercased caption rendered under the percentage value.
  /// When `null`, only the numeric/placeholder label is rendered.
  final String? label;

  /// Visual diameter of the gauge in logical pixels. Defaults to 80 to
  /// match the existing cockpit treatment.
  final double size;

  /// Threshold (inclusive lower bound) below which the active arc and
  /// centered numeric text adopt the `error` token color. Defaults to
  /// `25` so values in `[0, 25)` read as critical.
  final double criticalThreshold;

  const AppHealthGauge({
    super.key,
    this.percentage,
    this.label,
    this.size = 80,
    this.criticalThreshold = 25,
  });

  // Stroke widths for the gauge ring. These are component-local sizing
  // constants (not part of the spacing token scale) and live here so the
  // painter contract is explicit at the call site. Values mirror the
  // existing `_HealthGaugePainter` so the visual remains continuous with
  // the unmigrated `vehicle_health_gauge.dart`.
  static const double _trackStrokeWidth = 10.0;
  static const double _glowStrokeWidth = 14.0;
  static const double _activeStrokeWidth = 10.0;

  // Inset of the arc rectangle from the gauge bounds; matches the
  // existing painter's `radius - 6` margin so the stroke does not clip
  // the bounding box.
  static const double _arcInset = 6.0;

  // Glow underlay opacity from the existing painter.
  static const double _glowOpacity = 0.3;

  // Track opacity from the existing painter (a softened muted token so
  // the placeholder ring stays visible without dominating the surface).
  static const double _trackOpacity = 0.25;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppMotionExt motion = theme.extension<AppMotionExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final double? clamped = percentage?.clamp(0.0, 100.0).toDouble();

    final bool isPlaceholder = clamped == null;
    final bool isCritical =
        !isPlaceholder && clamped < criticalThreshold;

    final Color trackColor = colors.muted.withValues(alpha: _trackOpacity);
    final Color activeColor =
        isCritical ? colors.error : colors.emerald500;
    final Color foregroundTextColor =
        isCritical ? colors.error : colors.foreground;

    // Percentage shown in the centered numeric text. Rounded to the
    // nearest integer for display; the painter uses the unrounded
    // tween value below so the sweep remains smooth.
    final String numericText =
        isPlaceholder ? '--%' : '${clamped.round()}%';

    final Widget gaugeStack = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Painter: animates the sweep between consecutive percentage
          // values over `AppMotion.normal`. In the placeholder branch
          // the tween end is `0` so only the muted track is drawn.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0.0,
              end: isPlaceholder ? 0.0 : clamped / 100.0,
            ),
            duration: motion.normal,
            curve: motion.standard,
            builder: (BuildContext context, double t, Widget? _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _AppHealthGaugePainter(
                  // In the placeholder branch, force `progress = 0` so
                  // the active and glow arcs are skipped entirely.
                  progress: isPlaceholder ? 0.0 : t,
                  drawActiveArc: !isPlaceholder,
                  activeColor: activeColor,
                  trackColor: trackColor,
                  trackStrokeWidth: _trackStrokeWidth,
                  glowStrokeWidth: _glowStrokeWidth,
                  activeStrokeWidth: _activeStrokeWidth,
                  arcInset: _arcInset,
                  glowOpacity: _glowOpacity,
                ),
              );
            },
          ),
          // Centered text: numeric percentage (or `--%` placeholder) on
          // top, optional uppercased caption underneath.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                numericText,
                style: typography.title.copyWith(color: foregroundTextColor),
              ),
              if (label != null)
                Text(
                  label!,
                  style: typography.label.copyWith(color: colors.muted),
                ),
            ],
          ),
        ],
      ),
    );

    // Wrap in Semantics so assistive tech announces the value (or the
    // placeholder state) without needing to read the painter visuals.
    return Semantics(
      container: true,
      label: isPlaceholder
          ? 'Vehicle health unavailable'
          : 'Vehicle health ${clamped.round()} percent',
      child: gaugeStack,
    );
  }
}

/// Internal painter for [AppHealthGauge].
///
/// Replicates the `_HealthGaugePainter` arc-rendering logic from
/// `lib/widgets/vehicle_health_gauge.dart`:
///   1. Draws the muted track circle.
///   2. Draws a soft glow underlay arc behind the active sweep.
///   3. Draws the crisp foreground active arc on top.
///
/// All colors and stroke widths flow in from [AppHealthGauge] so the
/// painter itself contains no hard-coded visual constants.
class _AppHealthGaugePainter extends CustomPainter {
  final double progress; // 0.0 .. 1.0, sweep fraction of full circle.
  final bool drawActiveArc;
  final Color activeColor;
  final Color trackColor;
  final double trackStrokeWidth;
  final double glowStrokeWidth;
  final double activeStrokeWidth;
  final double arcInset;
  final double glowOpacity;

  _AppHealthGaugePainter({
    required this.progress,
    required this.drawActiveArc,
    required this.activeColor,
    required this.trackColor,
    required this.trackStrokeWidth,
    required this.glowStrokeWidth,
    required this.activeStrokeWidth,
    required this.arcInset,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius =
        math.min(size.width / 2, size.height / 2) - arcInset;

    // Track ring — always drawn, even in the placeholder branch.
    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStrokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (!drawActiveArc || progress <= 0.0) {
      return;
    }

    // Glow underlay — soft halo behind the active arc.
    final Paint glowPaint = Paint()
      ..color = activeColor.withValues(alpha: glowOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowStrokeWidth
      ..strokeCap = StrokeCap.round;

    // Active arc — crisp foreground sweep.
    final Paint activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = activeStrokeWidth
      ..strokeCap = StrokeCap.round;

    const double startAngle = -math.pi / 2; // 12 o'clock origin.
    final double sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _AppHealthGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.drawActiveArc != drawActiveArc ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.trackStrokeWidth != trackStrokeWidth ||
        oldDelegate.glowStrokeWidth != glowStrokeWidth ||
        oldDelegate.activeStrokeWidth != activeStrokeWidth ||
        oldDelegate.arcInset != arcInset ||
        oldDelegate.glowOpacity != glowOpacity;
  }
}
