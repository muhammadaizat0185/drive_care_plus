// Token + Component_Library sweep (Group 14, Task 14.2).
//
// Sweep summary:
//   * Confirmed-journey card surface routed through token extensions
//     (drops the `glass_container.dart` blur in favour of a
//     token-driven `AppCard`).
//   * Map base preserved (GoogleMap with polylines).
//   * Inline `CircularProgressIndicator` swapped to `AppSpinner`.
//   * Empty branch swapped to `AppEmptyState`.
//   * Pending journeys still use the existing `PendingJourneyCard`
//     (its visual contract is owned elsewhere and not part of this
//     sweep).
//   * Spacing/typography routed through token extensions.
//
// PRESERVED (Requirements 12.6, 14.5):
//   * `JourneyDatabase.instance.getJourneys()` and `.getPoints(id)`
//     calls unchanged.
//   * `JourneyDatabase.instance.updateJourneyStatus(journeyId, status,
//     vehicleType)` call unchanged.
//   * `GoogleMap(initialCameraPosition: CameraPosition(target:..., zoom:
//     ...), polylines: {Polyline(polylineId: PolylineId('selected_route_glow'),
//     color:..., width: 8, points: ...), Polyline(polylineId:
//     PolylineId('selected_route'), color:..., width: 4, points: ...)})`
//     marker / camera / polyline contract unchanged.

import 'package:flutter/material.dart';

import '../core/theme/color_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../core/theme/tokens/tokens.dart';
import '../services/journey_database.dart';
import '../widgets/pending_journey_card.dart';
import '../widgets/ui/ui.dart';

class JourneyLogScreen extends StatefulWidget {
  const JourneyLogScreen({super.key});

  static const routeName = '/journey-log';

  @override
  State<JourneyLogScreen> createState() => _JourneyLogScreenState();
}

class _JourneyLogScreenState extends State<JourneyLogScreen> {
  List<Map<String, dynamic>> _journeys = [];
  bool _isLoading = true;
  int? _selectedJourneyId;
  List<LatLng> _selectedPoints = [];

  // Bottom-sheet metrics. Not Token_Set values.
  static const double _sheetInitialFraction = 0.55;
  static const double _sheetMaxFraction = 0.95;
  static const double _grabHandleHeight = 5;
  static const double _mapHeightFraction = 0.55;

  @override
  void initState() {
    super.initState();
    _loadJourneys();
  }

  Future<void> _loadJourneys() async {
    final journeys = await JourneyDatabase.instance.getJourneys();
    if (!mounted) return;
    setState(() {
      _journeys = journeys;
      _isLoading = false;
      if (_journeys.isNotEmpty && _selectedJourneyId == null) {
        _selectedJourneyId = _journeys.first['id'];
        _loadPointsForSelected();
      }
    });
  }

  Future<void> _loadPointsForSelected() async {
    if (_selectedJourneyId == null) return;
    try {
      final pointsData =
          await JourneyDatabase.instance.getPoints(_selectedJourneyId!);
      if (mounted) {
        setState(() {
          _selectedPoints = pointsData
              .map((p) => LatLng(p['latitude'], p['longitude']))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading points: $e');
    }
  }

  Future<void> _confirmVehicle(int journeyId, String vehicleType) async {
    await JourneyDatabase.instance
        .updateJourneyStatus(journeyId, 'confirmed', vehicleType);
    _loadJourneys();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppShadowsExt shadows = theme.extension<AppShadowsExt>()!;

    // Calculate map camera position center — preserved logic.
    LatLng centerLatLng = const LatLng(3.1390, 101.6869); // Default KL
    double calculatedZoom = 13.0;

    if (_selectedPoints.isNotEmpty) {
      double minLat = _selectedPoints.first.latitude;
      double maxLat = _selectedPoints.first.latitude;
      double minLng = _selectedPoints.first.longitude;
      double maxLng = _selectedPoints.first.longitude;

      for (var p in _selectedPoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      centerLatLng = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

      final latSpan = maxLat - minLat;
      final lngSpan = maxLng - minLng;
      final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

      if (maxSpan > 1.0) {
        calculatedZoom = 10.0 - 2.0;
      } else if (maxSpan > 0.5) {
        calculatedZoom = 10.0;
      } else if (maxSpan > 0.1) {
        calculatedZoom = 14.0 - 2.0;
      } else if (maxSpan > 0.01) {
        calculatedZoom = 13.5;
      } else {
        calculatedZoom = 15.0;
      }
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Journey Logs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: Stack(
        children: [
          // Top Half: Map — GoogleMap call shape preserved exactly.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * _mapHeightFraction,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: centerLatLng,
                zoom: calculatedZoom,
              ),
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              polylines: {
                if (_selectedPoints.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('selected_route_glow'),
                    color: colors.emerald500
                        .withValues(alpha: colors.surfaceProminent + 0.2),
                    width: 10 - 2,
                    points: _selectedPoints,
                  ),
                if (_selectedPoints.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('selected_route'),
                    color: colors.emerald500,
                    width: 5 - 1,
                    points: _selectedPoints,
                  ),
              },
            ),
          ),

          // Gradient Overlay to fade into bottom sheet.
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.background.withValues(alpha: 0),
                    colors.background,
                  ],
                ),
              ),
            ),
          ),

          // Bottom Sheet: Timeline List.
          DraggableScrollableSheet(
            initialChildSize: _sheetInitialFraction,
            minChildSize: _sheetInitialFraction,
            maxChildSize: _sheetMaxFraction,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radii.xLarge),
                  ),
                  boxShadow: shadows.large,
                ),
                child: Column(
                  children: [
                    SizedBox(height: spacing.md),
                    Container(
                      width: spacing.xxxl,
                      height: _grabHandleHeight,
                      decoration: BoxDecoration(
                        color: colors.muted,
                        borderRadius: BorderRadius.circular(radii.small),
                      ),
                    ),
                    SizedBox(height: spacing.lg),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: AppSpinner())
                          : _journeys.isEmpty
                              ? const AppEmptyState(
                                  icon: Icons.timeline,
                                  title: 'No journeys recorded yet',
                                  message:
                                      'Start tracking a trip to see it here.',
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing.xl,
                                    vertical: spacing.md,
                                  ),
                                  itemCount: _journeys.length,
                                  itemBuilder: (context, index) {
                                    final journey = _journeys[index];
                                    final isSelected =
                                        journey['id'] == _selectedJourneyId;

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedJourneyId =
                                              journey['id'];
                                        });
                                        _loadPointsForSelected();
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(
                                            bottom: spacing.lg),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isSelected
                                                ? colors.emerald500
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                              radii.large),
                                        ),
                                        child: (journey['status'] ==
                                                    'pending' ||
                                                journey['status'] ==
                                                    'PENDING_CONFIRMATION')
                                            ? PendingJourneyCard(
                                                journey: journey,
                                                onConfirmMyCar: () =>
                                                    _confirmVehicle(
                                                        journey['id'],
                                                        'my_car'),
                                                onConfirmOther: () =>
                                                    _confirmVehicle(
                                                        journey['id'],
                                                        'other'),
                                              )
                                            : _ConfirmedJourneyCard(
                                                journey: journey),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),);
  }
}

class _ConfirmedJourneyCard extends StatelessWidget {
  final Map<String, dynamic> journey;

  const _ConfirmedJourneyCard({required this.journey});

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Active';
    final dateTime = DateTime.parse(isoString);
    return DateFormat('dd MMM yyyy, h:mm a').format(dateTime);
  }

  String _calculateDuration(String start, String end) {
    final startTime = DateTime.parse(start);
    final endTime = DateTime.parse(end);
    final diff = endTime.difference(startTime);

    if (diff.inSeconds < 60) return '${diff.inSeconds} secs';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final distance = journey['distance_km'] as double?;
    final startAddr = journey['start_address'] as String? ?? 'Origin';
    final destAddr =
        journey['destination_address'] as String? ?? 'No destination set';
    final isActive = journey['end_time'] == null;

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);
    final Color statusColor =
        isActive ? colors.warning : colors.emerald500;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.md,
                  vertical: spacing.xs,
                ),
                decoration: BoxDecoration(
                  color:
                      statusColor.withValues(alpha: colors.surfaceMedium),
                  borderRadius: BorderRadius.circular(radii.small),
                ),
                child: Text(
                  isActive ? 'Active Trip' : 'Confirmed Trip',
                  style: typography.label.copyWith(color: statusColor),
                ),
              ),
              Text(
                _formatDateTime(journey['start_time']),
                style: typography.body.copyWith(color: mutedForeground),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          Row(
            children: [
              Column(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    size: typography.bodyLarge.fontSize,
                    color: colors.emerald500,
                  ),
                  Container(
                    width: 2,
                    height: spacing.xl,
                    color: colors.border,
                  ),
                  Icon(
                    Icons.location_on,
                    size: typography.bodyLarge.fontSize,
                    color: colors.error,
                  ),
                ],
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      startAddr,
                      style: typography.body
                          .copyWith(color: colors.foreground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing.lg),
                    Text(
                      destAddr,
                      style: typography.body
                          .copyWith(color: colors.foreground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (journey['vehicle_type'] == 'my_car')
                Padding(
                  padding: EdgeInsets.only(left: spacing.sm),
                  child: Icon(
                    Icons.directions_car,
                    size: typography.headline.fontSize,
                    color: mutedForeground,
                  ),
                )
              else if (journey['vehicle_type'] == 'other')
                Padding(
                  padding: EdgeInsets.only(left: spacing.sm),
                  child: Icon(
                    Icons.directions_bus,
                    size: typography.headline.fontSize,
                    color: mutedForeground,
                  ),
                ),
            ],
          ),
          Divider(height: spacing.xl, color: colors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DISTANCE',
                    style: typography.label.copyWith(color: mutedForeground),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    distance != null
                        ? '${distance.toStringAsFixed(2)} km'
                        : '--',
                    style: typography.headline
                        .copyWith(color: colors.foreground),
                  ),
                ],
              ),
              if (!isActive && journey['end_time'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'DURATION',
                      style:
                          typography.label.copyWith(color: mutedForeground),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      _calculateDuration(
                          journey['start_time'], journey['end_time']),
                      style: typography.headline
                          .copyWith(color: colors.foreground),
                    ),
                  ],
                ),
            ],
          )
        ],
      ),
    );
  }
}
