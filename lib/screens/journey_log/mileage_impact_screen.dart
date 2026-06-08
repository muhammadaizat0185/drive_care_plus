// Phase 2 — Mileage Impact screen.
//
// Shown after the user taps "Confirm All Trips" in [TripConfirmationSheet].
// Surfaces:
//   • Animated odometer flip (old → new km)
//   • Updated maintenance watchlist items
//   • 7-day confirmed km/day bar chart
//
// Navigated to via [MileageImpactScreen.routeName] with a [MileageImpactArgs]
// argument.

import 'package:flutter/material.dart';

import '../../core/theme/color_utils.dart';
import '../../core/theme/tokens/tokens.dart';
import '../../services/vehicle_insights.dart';
import '../../widgets/ui/ui.dart';

/// Arguments passed to [MileageImpactScreen] via [Navigator.pushNamed].
class MileageImpactArgs {
  final double previousMileageKm;
  final double addedKm;
  final String vehicleModel;
  final String vehiclePlate;

  const MileageImpactArgs({
    required this.previousMileageKm,
    required this.addedKm,
    required this.vehicleModel,
    required this.vehiclePlate,
  });
}

class MileageImpactScreen extends StatefulWidget {
  static const routeName = '/mileage-impact';

  final MileageImpactArgs args;

  const MileageImpactScreen({super.key, required this.args});

  @override
  State<MileageImpactScreen> createState() => _MileageImpactScreenState();
}

class _MileageImpactScreenState extends State<MileageImpactScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _odometerController;
  late Animation<double> _odometerAnim;

  @override
  void initState() {
    super.initState();
    _odometerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _odometerAnim = CurvedAnimation(
      parent: _odometerController,
      curve: Curves.easeOutCubic,
    );
    // Start animation after first frame
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _odometerController.forward());
  }

  @override
  void dispose() {
    _odometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final insights = VehicleInsights.instance;
    final Color mutedFg =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    final double newKm =
        widget.args.previousMileageKm + widget.args.addedKm;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(spacing.xl),
            children: [
              // ── Success header ──────────────────────────────────────────
              Container(
                padding: EdgeInsets.all(spacing.xl),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.emerald500.withValues(alpha: 0.25),
                      colors.emerald500.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(radii.large),
                  border: Border.all(
                      color:
                          colors.emerald500.withValues(alpha: colors.surfaceMedium)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(spacing.md),
                      decoration: BoxDecoration(
                        color:
                            colors.emerald500.withValues(alpha: colors.surfaceMedium),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_outline,
                          color: colors.emerald500, size: 28),
                    ),
                    SizedBox(width: spacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Odometer Updated',
                            style: typography.title
                                .copyWith(color: colors.emerald500)),
                        Text(widget.args.vehicleModel,
                            style:
                                typography.body.copyWith(color: mutedFg)),
                        Text(widget.args.vehiclePlate,
                            style:
                                typography.label.copyWith(color: mutedFg)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.xl),

              // ── Animated odometer flip ──────────────────────────────────
              AppCard(
                child: Column(
                  children: [
                    Text('Distance Added Today',
                        style: typography.label.copyWith(color: mutedFg)),
                    SizedBox(height: spacing.md),
                    AnimatedBuilder(
                      animation: _odometerAnim,
                      builder: (_, __) {
                        final displayed = widget.args.previousMileageKm +
                            (widget.args.addedKm * _odometerAnim.value);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              displayed.toStringAsFixed(0),
                              style: typography.display.copyWith(
                                color: colors.foreground,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            SizedBox(width: spacing.xs),
                            Text('km',
                                style: typography.title
                                    .copyWith(color: mutedFg)),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      '+${widget.args.addedKm.toStringAsFixed(1)} km today',
                      style: typography.bodyLarge
                          .copyWith(color: colors.emerald500),
                    ),
                    SizedBox(height: spacing.md),
                    // Old → New pill
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: spacing.lg, vertical: spacing.xs),
                      decoration: BoxDecoration(
                        color: colors.muted,
                        borderRadius: BorderRadius.circular(radii.large),
                      ),
                      child: Text(
                        '${widget.args.previousMileageKm.toStringAsFixed(0)} km  →  ${newKm.toStringAsFixed(0)} km',
                        style: typography.label.copyWith(color: mutedFg),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.xl),

              // ── Maintenance impact ──────────────────────────────────────
              Text('Maintenance Impact',
                  style: typography.title.copyWith(color: colors.foreground)),
              SizedBox(height: spacing.md),
              ...insights.watchlistItems.map((item) {
                final statusColor = item.status == 'Red'
                    ? colors.error
                    : item.status == 'Yellow'
                        ? colors.warning
                        : colors.emerald500;
                return Padding(
                  padding: EdgeInsets.only(bottom: spacing.sm),
                  child: AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: spacing.md),
                            Text(item.name,
                                style: typography.body
                                    .copyWith(color: colors.foreground)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.remainingKm.toStringAsFixed(0)} km left',
                              style: typography.bodyLarge
                                  .copyWith(color: statusColor),
                            ),
                            Text(
                              'Due ~${item.predictedDateStr}',
                              style: typography.label
                                  .copyWith(color: mutedFg),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(height: spacing.xl),

              // ── 7-day bar chart ─────────────────────────────────────────
              Text('This Week',
                  style: typography.title.copyWith(color: colors.foreground)),
              SizedBox(height: spacing.md),
              _WeeklyBarChart(colors: colors, spacing: spacing, radii: radii,
                  typography: typography, mutedFg: mutedFg),
              SizedBox(height: spacing.xl),

              // ── Actions ─────────────────────────────────────────────────
              AppSecondaryButton(
                label: 'View Full Journey History',
                icon: Icons.timeline_outlined,
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly bar chart
// ---------------------------------------------------------------------------

class _WeeklyBarChart extends StatelessWidget {
  final AppColorsExt colors;
  final AppSpacingExt spacing;
  final AppRadiiExt radii;
  final AppTypographyExt typography;
  final Color mutedFg;

  const _WeeklyBarChart({
    required this.colors,
    required this.spacing,
    required this.radii,
    required this.typography,
    required this.mutedFg,
  });

  @override
  Widget build(BuildContext context) {
    // Build last 7 days of km data from mileage history.
    final history = VehicleInsights.instance.mileageHistory;
    final today = DateTime.now();
    final Map<String, double> kmByDay = {};

    // Seed 7 days with 0
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      kmByDay[key] = 0.0;
    }

    // Accumulate addedKm from history entries
    for (final entry in history) {
      final added = (entry['addedKm'] as num?)?.toDouble() ?? 0.0;
      if (added <= 0) continue;
      final ts = DateTime.tryParse(entry['timestamp']?.toString() ?? '');
      if (ts == null) continue;
      final key =
          '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
      if (kmByDay.containsKey(key)) {
        kmByDay[key] = (kmByDay[key] ?? 0.0) + added;
      }
    }

    final days = kmByDay.entries.toList();
    final maxKm = days.fold(1.0, (m, e) => e.value > m ? e.value : m);

    return Container(
      height: 120,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(radii.medium),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((entry) {
          final fraction = (entry.value / maxKm).clamp(0.04, 1.0);
          final dayLabel = entry.key.substring(8); // day number
          final isToday = entry.key == days.last.key;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xs / 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 80 * fraction,
                    decoration: BoxDecoration(
                      color: isToday
                          ? colors.emerald500
                          : colors.emerald500
                              .withValues(alpha: colors.surfaceMedium + 0.2),
                      borderRadius: BorderRadius.circular(radii.small),
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    dayLabel,
                    style: typography.label.copyWith(
                      color: isToday ? colors.emerald500 : mutedFg,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
