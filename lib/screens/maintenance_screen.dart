// Token + Component_Library sweep (Group 14, Task 14.3).
//
// Sweep summary:
//   * Cards swapped to `AppCard`.
//   * Primary CTA ('Play Maintenance Alert') rendered as
//     `AppGradientButton` (Requirement 12.4).
//   * Section trailing summary tiles use `AppListTile`.
//   * Spacing/typography routed through token extensions.
//
// PRESERVED:
//   * `VehicleInsights.instance` listener via `ListenableBuilder`.
//   * `_playMaintenanceAlert` invokes `SystemSound.play(SystemSoundType.alert)`
//     and shows a `SnackBar` with the same copy — transient confirmation
//     stays as `SnackBar` per the sweep rules.
//   * `CarHealthDiagram(onPartSelected: ...)` callback contract preserved.
//   * Lottie animation asset path unchanged.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../core/theme/tokens/tokens.dart';
import '../services/vehicle_insights.dart';
import '../widgets/car_health_diagram.dart';
import '../widgets/ui/ui.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  static const routeName = '/maintenance';

  // Lottie hero height. Not a Token_Set value.
  static const double _lottieHeight = 180;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: ListenableBuilder(
        listenable: VehicleInsights.instance,
        builder: (context, child) {
          final insights = VehicleInsights.instance;
          return ListView(
            padding: EdgeInsets.all(spacing.lg),
            children: [
              AppCard(
                child: Column(
                  children: [
                    SizedBox(
                      height: _lottieHeight,
                      child: Lottie.asset(
                        'assets/animations/maintenance_service.json',
                        repeat: true,
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      'Maintenance check in progress',
                      style: typography.title
                          .copyWith(color: colors.foreground),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      'Animated service status helps users understand vehicle condition quickly.',
                      textAlign: TextAlign.center,
                      style: typography.bodyLarge
                          .copyWith(color: mutedForeground),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oil change due in ${insights.kmUntilService.toStringAsFixed(0)} km',
                      style: typography.headline
                          .copyWith(color: colors.foreground),
                    ),
                    SizedBox(height: spacing.sm),
                    LinearProgressIndicator(
                      value: 0.82,
                      color: colors.emerald500,
                      backgroundColor: colors.muted,
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      'Based on ${insights.averageDailyDistanceKm.toStringAsFixed(0)} km/day, service is due in approximately ${insights.predictedServiceDueDays} days.',
                      style: typography.bodyLarge
                          .copyWith(color: colors.foreground),
                    ),
                    SizedBox(height: spacing.lg),
                    AppGradientButton(
                      label: 'Play Maintenance Alert',
                      icon: Icons.volume_up_outlined,
                      onPressed: () => _playMaintenanceAlert(
                        context,
                        insights.predictedServiceDueDays,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap Vehicle Part',
                      style: typography.title
                          .copyWith(color: colors.foreground),
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      'Check engine, tyres, brakes, and battery status.',
                      style: typography.bodyLarge
                          .copyWith(color: mutedForeground),
                    ),
                    SizedBox(height: spacing.md),
                    CarHealthDiagram(
                      onPartSelected: (message) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: AppListTile(
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: colors.success,
                  ),
                  title: Text(
                    'Last service',
                    style: typography.bodyLarge
                        .copyWith(color: colors.foreground),
                  ),
                  subtitle: Text(
                    'Oil filter and engine oil changed at 30,000 km',
                    style: typography.body.copyWith(color: mutedForeground),
                  ),
                ),
              ),
              SizedBox(height: spacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: AppListTile(
                  leading: Icon(
                    Icons.warning_amber_outlined,
                    color: colors.warning,
                  ),
                  title: Text(
                    'Upcoming inspection',
                    style: typography.bodyLarge
                        .copyWith(color: colors.foreground),
                  ),
                  subtitle: Text(
                    'Tyre rotation and brake check recommended',
                    style: typography.body.copyWith(color: mutedForeground),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _playMaintenanceAlert(
    BuildContext context,
    int daysDue,
  ) async {
    await SystemSound.play(SystemSoundType.alert);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Audio alert: Oil change due in $daysDue days.',
        ),
      ),
    );
  }
}
