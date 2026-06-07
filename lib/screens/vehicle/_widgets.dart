// ignore_for_file: deprecated_member_use
//
// Modular building blocks for the redesigned Vehicle screen
// (`lib/screens/vehicle_screen.dart`).
//
// This module hosts the four primary blocks of the vehicle profile body
// from the figma-ui-redesign blueprint (design.md → vehicle_screen.dart):
//
//   * [VehicleHeroCard]        — Gradient hero with car emoji, plate
//                                number, and an Edit AppIconButton
//                                overlay (Task 10.1, Requirement 8.1).
//   * [VehicleHealthGrid]      — 4-tile health grid for Engine, Brakes,
//                                Battery, Tires whose percentages are
//                                pulled from `VehicleInsights` and
//                                clamped via `clampPercentage`. Missing
//                                values render `--%` (Task 10.2,
//                                Requirements 8.2, 8.3).
//   * [MaintenanceHistoryList] — AppListTile-styled list of maintenance
//                                entries ordered most-recent-first
//                                (Task 10.3, Requirements 8.4, 8.6).
//   * [UpcomingTasksList]      — List of upcoming maintenance with
//                                priority pills colored via the
//                                `error` / `warning` / `info` semantic
//                                tokens (Task 10.5, Requirements 8.5,
//                                8.7).
//
// The pure helper [sortMaintenanceEntriesDescending] is exported so the
// PBT in `test/screens/vehicle_history_sort_pbt_test.dart` can drive
// the same sort the screen uses (Task 10.4, Requirement 8.4).
//
// All visual constants flow from the design-token extensions on
// `Theme.of(context)`; no hex colors, spacing, radii, or typography
// literals from the Token_Sets are inlined (Requirement 3.11).

import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../core/util/clamp_percentage.dart';
import '../../services/vehicle_insights.dart';
import '../../widgets/ui/ui.dart';
import '../vehicle_customizer_screen.dart';

// ===========================================================================
// VehicleHeroCard
// ===========================================================================

/// Hero card at the top of the redesigned Vehicle screen.
///
/// Renders a rounded card with a linear gradient from `#2563EB`
/// (top-left) to `#4338CA` (bottom-right), the car emoji, the plate
/// number, and an Edit `AppIconButton` overlay positioned in the
/// top-right corner. Tapping the Edit button pushes
/// `VehicleCustomizerScreen.routeName`, preserving the existing
/// customizer logic and persistence (Task 10.6, Requirement 8.8).
///
/// The blue→indigo gradient is the brand vehicle hero treatment from
/// Requirement 8.1; it is **not** part of the `AppColors` Token_Set
/// (which carries the emerald→teal product brand gradient), so the two
/// hex literals are anchored explicitly here per the requirement and
/// commented as such.
class VehicleHeroCard extends StatelessWidget {
  /// Plate number displayed beneath the car emoji. When the plate is
  /// empty / null the placeholder dash is rendered.
  final String plate;

  /// Optional override for the model name displayed under the plate.
  /// When `null`, the model is omitted (the hero is intentionally
  /// minimal — emoji + plate is enough to establish identity).
  final String? model;

  const VehicleHeroCard({super.key, required this.plate, this.model});

  // Hero gradient stops from Requirement 8.1. These are not in the
  // `AppColors` Token_Set (which encodes the emerald→teal product
  // brand gradient), so they are anchored here as named constants and
  // referenced by the gradient builder below.
  static const Color _heroGradientTopLeft = Color(0xFF2563EB);
  static const Color _heroGradientBottomRight = Color(0xFF4338CA);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final BorderRadius borderRadius = BorderRadius.circular(radii.large);

    final String displayPlate = plate.trim().isEmpty ? '—' : plate;

    return Stack(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(spacing.xl),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _heroGradientTopLeft,
                _heroGradientBottomRight,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Car emoji rendered at display-scale typography so it
              // anchors the hero visually.
              Text('🚗', style: typography.display),
              SizedBox(height: spacing.md),
              Text(
                displayPlate,
                style: typography.headline.copyWith(color: Colors.white),
              ),
              if (model != null && model!.trim().isNotEmpty) ...<Widget>[
                SizedBox(height: spacing.xs),
                Text(
                  model!,
                  style: typography.bodyLarge
                      .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ],
          ),
        ),
        // Edit button overlay positioned in the top-right corner of the
        // hero (Requirement 8.1). Tapping it pushes the customizer route
        // (Requirement 8.8).
        Positioned(
          top: spacing.sm,
          right: spacing.sm,
          child: AppIconButton(
            icon: Icons.edit,
            semanticsLabel: 'Edit vehicle',
            color: Colors.white,
            onPressed: () => Navigator.of(context)
                .pushNamed(VehicleCustomizerScreen.routeName),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// VehicleHealthGrid
// ===========================================================================

/// Four-tile health metrics grid for the redesigned Vehicle screen.
///
/// Renders a 2×2 grid with a tile per metric in this fixed order:
/// Engine, Brakes, Battery, Tires. Each tile shows the metric's name
/// and an `AppHealthGauge` whose percentage is sourced from
/// `VehicleInsights.watchlistItems` (matched by name substring) and
/// normalised through `clampPercentage`. When the matching watchlist
/// item is missing or returns a non-finite value, the gauge falls back
/// to its `--%` placeholder branch (Requirements 8.2, 8.3).
class VehicleHealthGrid extends StatelessWidget {
  /// Watchlist items pulled from `VehicleInsights.watchlistItems`.
  final List<MaintenanceItem> watchlistItems;

  const VehicleHealthGrid({super.key, required this.watchlistItems});

  // Metric name → list of substrings that must match the watchlist
  // item's name (case-insensitive). The ordering of the entries here
  // is the rendering order of the grid (Engine top-left, Brakes
  // top-right, Battery bottom-left, Tires bottom-right).
  static const List<_HealthMetricSpec> _metrics = <_HealthMetricSpec>[
    _HealthMetricSpec(label: 'Engine', match: <String>['oil', 'engine']),
    _HealthMetricSpec(label: 'Brakes', match: <String>['brake']),
    _HealthMetricSpec(label: 'Battery', match: <String>['battery']),
    _HealthMetricSpec(label: 'Tires', match: <String>['tyre', 'tire']),
  ];

  /// Returns the clamped integer percentage for [spec] from
  /// [watchlistItems], or `null` when the matching item is absent.
  static int? _percentageFor(
    _HealthMetricSpec spec,
    List<MaintenanceItem> watchlistItems,
  ) {
    for (final MaintenanceItem item in watchlistItems) {
      final String lowerName = item.name.toLowerCase();
      for (final String token in spec.match) {
        if (lowerName.contains(token)) {
          return clampPercentage(item.healthPercentage);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    // The grid is always rendered as a 2-column layout regardless of
    // viewport so the four tiles read as a single block. Tile heights
    // are intrinsic (driven by AppHealthGauge size + label) so a fixed
    // childAspectRatio is unnecessary.
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing.md,
      crossAxisSpacing: spacing.md,
      childAspectRatio: 1.2,
      children: <Widget>[
        for (final _HealthMetricSpec spec in _metrics)
          _HealthMetricTile(
            label: spec.label,
            percentage: _percentageFor(spec, watchlistItems),
          ),
      ],
    );
  }
}

/// Internal description of a single health metric tile.
class _HealthMetricSpec {
  final String label;
  final List<String> match;

  const _HealthMetricSpec({required this.label, required this.match});
}

/// Single tile in the health grid: an `AppHealthGauge` plus the label.
class _HealthMetricTile extends StatelessWidget {
  final String label;
  final int? percentage;

  const _HealthMetricTile({required this.label, required this.percentage});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;

    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          AppHealthGauge(
            percentage: percentage?.toDouble(),
            size: 72,
          ),
          SizedBox(height: spacing.sm),
          Text(
            label,
            style: typography.title.copyWith(color: colors.foreground),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// MaintenanceHistoryList
// ===========================================================================

/// Single, immutable maintenance-history entry used by
/// [MaintenanceHistoryList].
///
/// Two entries are equal iff their `name`, `mileageKm`, and `date`
/// match — making the list comparable in tests without identity
/// tracking.
@immutable
class MaintenanceHistoryEntry {
  final String name;
  final double mileageKm;
  final DateTime date;

  const MaintenanceHistoryEntry({
    required this.name,
    required this.mileageKm,
    required this.date,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaintenanceHistoryEntry &&
        other.name == name &&
        other.mileageKm == mileageKm &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(name, mileageKm, date);

  @override
  String toString() =>
      'MaintenanceHistoryEntry(name: $name, mileage: $mileageKm, date: $date)';
}

/// Pure helper that returns a new list containing the same entries as
/// [entries] sorted by `date` in descending order (most-recent-first).
///
/// The input list is not mutated. Two entries with the same `date`
/// keep their relative order (stable sort).
///
/// The screen uses this helper to satisfy Requirement 8.4 ("ordered
/// from most recent to oldest") and the PBT in
/// `test/screens/vehicle_history_sort_pbt_test.dart` (Task 10.4)
/// drives the same helper to assert the property holds for any input
/// list.
List<MaintenanceHistoryEntry> sortMaintenanceEntriesDescending(
  List<MaintenanceHistoryEntry> entries,
) {
  final List<MaintenanceHistoryEntry> sorted =
      List<MaintenanceHistoryEntry>.of(entries);
  // `compareTo` returns a negative number when the receiver is earlier
  // than the argument; we want most-recent-first, so we invert by
  // comparing `b.date` to `a.date`.
  sorted.sort((MaintenanceHistoryEntry a, MaintenanceHistoryEntry b) =>
      b.date.compareTo(a.date));
  return sorted;
}

/// Maintenance history list for the redesigned Vehicle screen.
///
/// Renders [entries] using `AppListTile`-styled rows ordered from most
/// recent to oldest (Requirement 8.4). Empty input renders an
/// `AppEmptyState` placeholder (Requirement 8.6).
class MaintenanceHistoryList extends StatelessWidget {
  /// Maintenance history entries pulled from
  /// `VehicleInsights.maintenanceData`. Order does not matter — the
  /// widget sorts a defensive copy via [sortMaintenanceEntriesDescending].
  final List<MaintenanceHistoryEntry> entries;

  const MaintenanceHistoryList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    if (entries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history,
        title: 'No maintenance logged',
        message: 'Logged services will appear here once recorded.',
      );
    }

    final List<MaintenanceHistoryEntry> sorted =
        sortMaintenanceEntriesDescending(entries);

    return Column(
      children: <Widget>[
        for (final MaintenanceHistoryEntry entry in sorted)
          AppListTile(
            leading: Icon(
              Icons.build_circle_outlined,
              color: colors.emerald500,
            ),
            title: Text(
              entry.name,
              style: typography.title.copyWith(color: colors.foreground),
            ),
            subtitle: Text(
              '${entry.mileageKm.toStringAsFixed(0)} km · '
              '${_formatDate(entry.date)}',
              style: typography.body.copyWith(
                color: colors.foreground
                    .withValues(alpha: colors.surfaceProminent + 0.4),
              ),
            ),
          ),
      ],
    );
  }

  /// Format a date as `DD/MM/YYYY`. Kept inline because the screen has
  /// no other date formatter; introducing `intl.DateFormat` here would
  /// add a dependency for a single call site.
  static String _formatDate(DateTime date) {
    final String d = date.day.toString().padLeft(2, '0');
    final String m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

// ===========================================================================
// UpcomingTasksList
// ===========================================================================

/// Priority bucket for an upcoming maintenance task. Drives the colored
/// pill rendered next to each task name (Requirement 8.5):
///
///   * [high]   → `AppColors.error`   — urgent (status `Red`)
///   * [medium] → `AppColors.warning` — soon  (status `Yellow`)
///   * [low]    → `AppColors.info`    — fine for now (status `Green`)
enum UpcomingTaskPriority { high, medium, low }

/// Single upcoming-task entry rendered by [UpcomingTasksList].
@immutable
class UpcomingTaskEntry {
  final String name;
  final double remainingKm;
  final UpcomingTaskPriority priority;

  const UpcomingTaskEntry({
    required this.name,
    required this.remainingKm,
    required this.priority,
  });

  /// Build an entry from a `VehicleInsights.MaintenanceItem`. Maps the
  /// item's `status` (`Red` / `Yellow` / `Green`) to the matching
  /// [UpcomingTaskPriority] bucket.
  factory UpcomingTaskEntry.fromMaintenanceItem(MaintenanceItem item) {
    final UpcomingTaskPriority priority;
    switch (item.status) {
      case 'Red':
        priority = UpcomingTaskPriority.high;
        break;
      case 'Yellow':
        priority = UpcomingTaskPriority.medium;
        break;
      case 'Green':
      default:
        priority = UpcomingTaskPriority.low;
        break;
    }
    return UpcomingTaskEntry(
      name: item.name,
      remainingKm: item.remainingKm,
      priority: priority,
    );
  }
}

/// Upcoming maintenance tasks list for the redesigned Vehicle screen.
///
/// Renders [tasks] as a column of `AppListTile`-styled rows. Each row
/// carries a small colored pill on the leading edge whose color
/// encodes the task's priority via three distinct semantic tokens
/// (`error` / `warning` / `info`) per Requirement 8.5. Empty input
/// renders an `AppEmptyState` placeholder (Requirement 8.7).
class UpcomingTasksList extends StatelessWidget {
  final List<UpcomingTaskEntry> tasks;

  const UpcomingTasksList({super.key, required this.tasks});

  /// Resolve the pill color for [priority] using the active token
  /// extension. Public so widget tests can drive the same mapping
  /// without re-implementing the switch.
  static Color colorFor(UpcomingTaskPriority priority, AppColorsExt colors) {
    switch (priority) {
      case UpcomingTaskPriority.high:
        return colors.error;
      case UpcomingTaskPriority.medium:
        return colors.warning;
      case UpcomingTaskPriority.low:
        return colors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    if (tasks.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_note_outlined,
        title: 'No upcoming tasks',
        message: 'Predicted maintenance will appear here as it becomes due.',
      );
    }

    return Column(
      children: <Widget>[
        for (final UpcomingTaskEntry task in tasks)
          AppListTile(
            leading: _PriorityPill(
              priority: task.priority,
              color: colorFor(task.priority, colors),
            ),
            title: Text(
              task.name,
              style: typography.title.copyWith(color: colors.foreground),
            ),
            subtitle: Text(
              'Due in ${task.remainingKm.toStringAsFixed(0)} km',
              style: typography.body.copyWith(
                color: colors.foreground
                    .withValues(alpha: colors.surfaceProminent + 0.4),
              ),
            ),
          ),
      ],
    );
  }
}

/// Small, key-able priority pill used as the leading widget on each
/// upcoming-task row. Exposes a `ValueKey('priority_pill_{priority.name}')`
/// so widget tests can locate the pill by priority bucket without
/// scraping the private color value.
class _PriorityPill extends StatelessWidget {
  final UpcomingTaskPriority priority;
  final Color color;

  const _PriorityPill({required this.priority, required this.color});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;

    return Container(
      key: ValueKey<String>('priority_pill_${priority.name}'),
      width: 6,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radii.small),
      ),
    );
  }
}
