// ignore_for_file: deprecated_member_use
//
// Redesigned Vehicle screen for the figma-ui-redesign
// (Tasks 10.1 – 10.6 — Requirements 8.1 – 8.8).
//
// The body is composed from the modular widgets in
// `lib/screens/vehicle/_widgets.dart`:
//
//   * VehicleHeroCard         — Gradient hero with car emoji, plate
//                               number, and Edit overlay (Task 10.1).
//   * VehicleHealthGrid       — 4-tile health metrics from
//                               `VehicleInsights` (Task 10.2).
//   * MaintenanceHistoryList  — AppListTile entries, descending date
//                               (Task 10.3).
//   * UpcomingTasksList       — Priority-coded list (Task 10.5).
//
// The screen reads data from the existing `VehicleInsights` singleton
// and re-uses the persistence already wired up there. `Edit` →
// `Navigator.pushNamed(VehicleCustomizerScreen.routeName)` (Task 10.6).

import 'package:flutter/material.dart';

import '../core/theme/tokens/tokens.dart';
import '../services/vehicle_insights.dart';
import '../widgets/ui/ui.dart';
import 'vehicle/_widgets.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  static const String routeName = '/vehicle';

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  /// Map the maintenance log persisted on `VehicleInsights` into a list
  /// of typed [MaintenanceHistoryEntry]s. The helper accepts the
  /// service map verbatim so the screen does not have to mutate the
  /// shared service state.
  ///
  /// The service's `maintenanceData` is keyed by item name (e.g. `Engine
  /// Oil`) and each value carries the `mileage` (num) and `date` (ISO
  /// 8601 string) of the most-recent service. Entries with malformed
  /// values are skipped silently — the screen surfaces only the
  /// successfully-parsed history rather than blocking on malformed
  /// fixtures from old prefs.
  List<MaintenanceHistoryEntry> _historyEntries(VehicleInsights insights) {
    final List<MaintenanceHistoryEntry> entries = <MaintenanceHistoryEntry>[];
    insights.maintenanceData.forEach((String name, Map<String, dynamic> data) {
      final num? rawMileage = data['mileage'] as num?;
      final String? rawDate = data['date'] as String?;
      if (rawMileage == null || rawDate == null) return;
      final DateTime? parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate == null) return;
      entries.add(
        MaintenanceHistoryEntry(
          name: name,
          mileageKm: rawMileage.toDouble(),
          date: parsedDate,
        ),
      );
    });
    return entries;
  }

  /// Bucket the watchlist into upcoming-task priorities. The service
  /// already maps each item to a `Red` / `Yellow` / `Green` status, so
  /// the screen only translates that string into the typed
  /// `UpcomingTaskPriority` bucket via the
  /// `UpcomingTaskEntry.fromMaintenanceItem` factory.
  List<UpcomingTaskEntry> _upcomingTasks(VehicleInsights insights) {
    return insights.watchlistItems
        .map(UpcomingTaskEntry.fromMaintenanceItem)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Vehicle profile',
          style: typography.headline.copyWith(color: colors.foreground),
        ),
      ),
      body: ListenableBuilder(
        listenable: VehicleInsights.instance,
        builder: (BuildContext context, Widget? _) {
          final VehicleInsights insights = VehicleInsights.instance;
          final List<MaintenanceHistoryEntry> history =
              _historyEntries(insights);
          final List<UpcomingTaskEntry> upcoming = _upcomingTasks(insights);

          return ListView(
            padding: EdgeInsets.all(spacing.lg),
            children: <Widget>[
              // Hero card — Task 10.1.
              VehicleHeroCard(
                plate: insights.plate,
                model: insights.model,
              ),

              SizedBox(height: spacing.lg),

              // Health grid — Task 10.2.
              VehicleHealthGrid(watchlistItems: insights.watchlistItems),

              SizedBox(height: spacing.xl),

              // Maintenance history — Task 10.3.
              const AppSectionHeader(label: 'Maintenance history'),
              SizedBox(height: spacing.sm),
              MaintenanceHistoryList(entries: history),

              SizedBox(height: spacing.xl),

              // Upcoming tasks — Task 10.5.
              const AppSectionHeader(label: 'Upcoming tasks'),
              SizedBox(height: spacing.sm),
              UpcomingTasksList(tasks: upcoming),
            ],
          );
        },
      ),
    );
  }
}
