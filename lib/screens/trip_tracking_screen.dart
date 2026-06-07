// Token + Component_Library sweep (Group 14, Task 14.8).
//
// Sweep summary:
//   * Tokens applied to all spacing, typography, radius, and color literals.
//   * Hero status surface routed through `AppCard` styling via token
//     extensions.
//   * Trip metric rows rendered via `AppListTile`.
//   * Primary CTA ('Start Trip' / 'Stop Trip') rendered as
//     `AppGradientButton` (Requirement 12.4).
//   * Secondary CTAs (Open Refuel Log / Open Workshop Map) rendered via
//     `AppSecondaryButton`.
//   * Loading indicator rendered via `AppSpinner`.
//
// PRESERVED (Requirement 12.6, 14.5):
//   * `Timer.periodic(Duration(seconds: 1), ...)` increments untouched.
//   * `VehicleInsights.instance.updateRecentTrip(distanceKm:..., fuelCostRm:...)`
//     call signature preserved.
//   * Firestore writes preserve full collection paths and field shapes:
//       - `users/{uid}/trips`.add({distanceKm, durationSeconds, fuelCostRm,
//         timestamp: FieldValue.serverTimestamp()})
//       - `users/{uid}/vehicle/primary`.update({currentMileageKm: ...})
//   * `Navigator.pushNamed(context, RefuelLogScreen.routeName)` / `WorkshopMapScreen.routeName`.
//   * Trip summary `AlertDialog` flow.
//   * The screen does not currently mount a GoogleMap (the placeholder
//     Container has always stood in for the live map preview); this
//     sweep does not re-introduce GoogleMap so there is no marker, camera,
//     or polyline contract to preserve at this time.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/color_utils.dart';

import '../core/theme/tokens/tokens.dart';
import '../services/vehicle_insights.dart';
import '../widgets/ui/ui.dart';
import 'refuel_log_screen.dart';
import 'workshop_map_screen.dart';

class TripTrackingScreen extends StatefulWidget {
  const TripTrackingScreen({super.key});

  static const routeName = '/trip-tracking';

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  Timer? _tripTimer;
  bool _isTracking = false;
  int _secondsElapsed = 0;
  double _distanceKm = 0.0;
  double _fuelCostRm = 0.0;

  // Hero status surface height. Not a Token_Set value.
  static const double _heroHeight = 260;
  static const double _heroIconSize = 56;

  @override
  void dispose() {
    _tripTimer?.cancel();
    super.dispose();
  }

  void _toggleTrip() {
    if (_isTracking) {
      _stopTrip();
    } else {
      _startTrip();
    }
  }

  void _startTrip() {
    setState(() {
      _isTracking = true;
      _secondsElapsed = 0;
      _distanceKm = 0.0;
      _fuelCostRm = 0.0;
    });

    // Simulating driving speed of approx 60 km/h (0.016 km/sec)
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
        _distanceKm += 0.017; // Increments by 0.017 km every second (~61 km/h)
        _fuelCostRm = _distanceKm * 0.22; // Estimate RM 0.22 fuel cost per km
      });
    });
  }

  Future<void> _stopTrip() async {
    _tripTimer?.cancel();
    setState(() => _isTracking = false);

    final finalDistance = _distanceKm;
    final finalSeconds = _secondsElapsed;
    final finalCost = _fuelCostRm;

    // Save locally, update cache and notify listeners reactively!
    await VehicleInsights.instance.updateRecentTrip(
      distanceKm: finalDistance,
      fuelCostRm: finalCost,
    );

    // Show Trip Summary Dialog
    if (mounted) {
      _showTripSummaryDialog(finalDistance, finalSeconds, finalCost);
    }

    // Save Trip Record to Cloud Firestore — call signature preserved.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('trips')
            .add({
          'distanceKm': finalDistance,
          'durationSeconds': finalSeconds,
          'fuelCostRm': finalCost,
          'timestamp': FieldValue.serverTimestamp(),
        });
        // Also update vehicle mileage in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicle')
            .doc('primary')
            .update({
          'currentMileageKm': VehicleInsights.instance.currentMileageKm,
        });
      } catch (e) {
        debugPrint('Firestore trip save error: $e');
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showTripSummaryDialog(double distance, int seconds, double cost) {
    showDialog(
      context: context,
      builder: (context) {
        final ThemeData theme = Theme.of(context);
        final AppColorsExt colors = theme.extension<AppColorsExt>()!;
        final AppTypographyExt typography =
            theme.extension<AppTypographyExt>()!;
        final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.stars, color: colors.warning),
              SizedBox(width: spacing.sm),
              Text(
                'Trip Completed!',
                style:
                    typography.title.copyWith(color: colors.foreground),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DriveCare+ has logged your trip metrics and synced them with your dashboard.',
                style: typography.bodyLarge
                    .copyWith(color: colors.foreground),
              ),
              SizedBox(height: spacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.route_outlined),
                title: const Text('Total Distance'),
                subtitle: Text('${distance.toStringAsFixed(2)} km'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Total Duration'),
                subtitle: Text('${seconds ~/ 60} min ${seconds % 60} sec'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Estimated Fuel Cost'),
                subtitle: Text('RM ${cost.toStringAsFixed(2)}'),
              ),
            ],
          ),
          actions: [
            AppGradientButton(
              label: 'Awesome',
              fullWidth: false,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);
    final Color heroAccent =
        _isTracking ? colors.info : colors.success;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Trip Tracking')),
      body: ListView(
        padding: EdgeInsets.all(spacing.lg),
        children: [
          // Hero status surface — token-driven `Container`. The visual
          // stand-in for the future GoogleMap preview; not the real map.
          Container(
            height: _heroHeight,
            decoration: BoxDecoration(
              color: heroAccent.withValues(alpha: colors.surfaceMedium),
              borderRadius: BorderRadius.circular(radii.large),
              border: Border.all(color: colors.border),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isTracking
                        ? Icons.navigation_outlined
                        : Icons.map_outlined,
                    size: _heroIconSize,
                    color: heroAccent,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    _isTracking
                        ? 'Active Trip in Progress...'
                        : 'Google Maps preview will appear here',
                    style: typography.bodyLarge.copyWith(color: heroAccent),
                  ),
                  if (_isTracking) ...[
                    SizedBox(height: spacing.md),
                    const AppSpinner(),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.lg),

          AppCard(
            padding: EdgeInsets.zero,
            child: AppListTile(
              leading: Icon(Icons.route_outlined, color: colors.emerald500),
              title: Text(
                'Distance',
                style:
                    typography.bodyLarge.copyWith(color: colors.foreground),
              ),
              subtitle: Text(
                _isTracking
                    ? '${_distanceKm.toStringAsFixed(2)} km'
                    : '24.6 km',
                style: typography.body.copyWith(color: mutedForeground),
              ),
            ),
          ),
          SizedBox(height: spacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppListTile(
              leading: Icon(Icons.timer_outlined, color: colors.emerald500),
              title: Text(
                'Duration',
                style:
                    typography.bodyLarge.copyWith(color: colors.foreground),
              ),
              subtitle: Text(
                _isTracking
                    ? _formatDuration(_secondsElapsed)
                    : '42 minutes',
                style: typography.body.copyWith(color: mutedForeground),
              ),
            ),
          ),
          SizedBox(height: spacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppListTile(
              leading:
                  Icon(Icons.payments_outlined, color: colors.emerald500),
              title: Text(
                'Fuel cost estimate',
                style:
                    typography.bodyLarge.copyWith(color: colors.foreground),
              ),
              subtitle: Text(
                _isTracking
                    ? 'RM ${_fuelCostRm.toStringAsFixed(2)}'
                    : 'RM 5.40',
                style: typography.body.copyWith(color: mutedForeground),
              ),
            ),
          ),
          SizedBox(height: spacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppListTile(
              leading:
                  Icon(Icons.analytics_outlined, color: colors.emerald500),
              title: Text(
                'Predictive service estimate',
                style:
                    typography.bodyLarge.copyWith(color: colors.foreground),
              ),
              subtitle: Text(
                'Average ${VehicleInsights.instance.averageDailyDistanceKm.toStringAsFixed(0)} km/day, service due in about ${VehicleInsights.instance.predictedServiceDueDays} days.',
                style: typography.body.copyWith(color: mutedForeground),
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          AppGradientButton(
            label: _isTracking ? 'Stop Trip' : 'Start Trip',
            icon: _isTracking ? Icons.stop : Icons.play_arrow,
            onPressed: _toggleTrip,
          ),
          SizedBox(height: spacing.sm),
          AppSecondaryButton(
            label: 'Open Refuel Log',
            icon: Icons.local_gas_station_outlined,
            fullWidth: true,
            onPressed: () =>
                Navigator.pushNamed(context, RefuelLogScreen.routeName),
          ),
          SizedBox(height: spacing.sm),
          AppSecondaryButton(
            label: 'Open Workshop Map',
            icon: Icons.map_outlined,
            fullWidth: true,
            onPressed: () =>
                Navigator.pushNamed(context, WorkshopMapScreen.routeName),
          ),
        ],
      ),
    ),);
  }
}
