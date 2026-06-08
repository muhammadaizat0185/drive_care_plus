// Phase 2 — Journey Log Screen (redesigned).
//
// Changes from the original:
//   • Date navigator bar (← date →) with day-by-day browsing.
//   • GoogleMap routes coloured by attribution status:
//       emerald  = confirmed my-car trip
//       amber    = pending confirmation
//       grey     = other / public transport
//   • Daily stat bar: confirmed km · vehicle name · estimated fuel cost.
//   • Timeline list: place dots + trip cards connected by a vertical line.
//   • Sticky amber bottom badge when there are PENDING_CONFIRMATION journeys;
//     tapping opens [TripConfirmationSheet].
//   • [_ConfirmedJourneyCard] and [PendingJourneyCard] preserved for backward
//     compatibility during Phase 2 migration.
//
// PRESERVED (Requirements 12.6, 14.5):
//   • JourneyDatabase.instance.getJourneys() and .getPoints(id) calls unchanged.
//   • JourneyDatabase.instance.updateJourneyStatus(journeyId, status, vehicleType)
//     call unchanged.
//   • GoogleMap polyline contract (polylineId, color, width, points) unchanged.

import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../core/theme/color_utils.dart';
import '../core/theme/tokens/tokens.dart';
import '../services/journey_database.dart';
import '../services/profile_service.dart';
import '../services/vehicle_insights.dart';
import '../widgets/pending_journey_card.dart';
import '../widgets/ui/ui.dart';
import 'journey_log/trip_confirmation_sheet.dart';
import 'journey_log/mileage_impact_screen.dart';

class JourneyLogScreen extends StatefulWidget {
  const JourneyLogScreen({super.key});

  static const routeName = '/journey-log';

  @override
  State<JourneyLogScreen> createState() => _JourneyLogScreenState();
}

class _JourneyLogScreenState extends State<JourneyLogScreen> {
  List<Map<String, dynamic>> _allJourneys = [];
  bool _isLoading = true;
  int? _selectedJourneyId;
  List<LatLng> _selectedPoints = [];

  // Date navigation — defaults to today.
  DateTime _viewDate = DateTime.now();

  // Bottom-sheet metrics — not Token_Set values.
  static const double _sheetInitialFraction = 0.50;
  static const double _sheetMaxFraction = 0.95;
  static const double _grabHandleHeight = 5;
  static const double _mapHeightFraction = 0.50;

  @override
  void initState() {
    super.initState();
    _loadJourneys();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadJourneys() async {
    final journeys = await JourneyDatabase.instance.getJourneys();
    if (!mounted) return;
    setState(() {
      _allJourneys = journeys;
      _isLoading = false;
      _pickInitialSelection();
    });
  }

  void _pickInitialSelection() {
    final dayJourneys = _journeysForDate(_viewDate);
    if (dayJourneys.isNotEmpty && _selectedJourneyId == null) {
      _selectedJourneyId = dayJourneys.first['id'];
      _loadPointsForSelected();
    }
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

  // ---------------------------------------------------------------------------
  // Date navigation helpers
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _journeysForDate(DateTime date) {
    final dateStr = '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return _allJourneys.where((j) {
      final st = j['start_time'] as String? ?? '';
      return st.startsWith(dateStr);
    }).toList();
  }

  List<Map<String, dynamic>> _pendingJourneysForDate(DateTime date) =>
      _journeysForDate(date)
          .where((j) =>
              j['status'] == 'PENDING_CONFIRMATION' ||
              j['status'] == 'pending')
          .toList();

  void _goToPreviousDay() {
    setState(() {
      _viewDate = _viewDate.subtract(const Duration(days: 1));
      _selectedJourneyId = null;
      _selectedPoints = [];
      _pickInitialSelection();
    });
  }

  void _goToNextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_viewDate.isBefore(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))) {
      setState(() {
        _viewDate = _viewDate.add(const Duration(days: 1));
        _selectedJourneyId = null;
        _selectedPoints = [];
        _pickInitialSelection();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Daily stats
  // ---------------------------------------------------------------------------

  double _confirmedKmForDate(DateTime date) {
    return _journeysForDate(date).fold(0.0, (sum, j) {
      if (j['status'] == 'confirmed' && j['vehicle_type'] == 'my_car') {
        return sum + ((j['distance_km'] as num?)?.toDouble() ?? 0.0);
      }
      return sum;
    });
  }

  // ---------------------------------------------------------------------------
  // Confirmation sheet
  // ---------------------------------------------------------------------------

  void _openConfirmationSheet(List<Map<String, dynamic>> pending) {
    final previousKm = VehicleInsights.instance.currentMileageKm;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripConfirmationSheet(
        pendingJourneys: pending,
        registeredVehicles: VehicleInsights.instance.vehicles,
        onConfirmed: () async {
          await _loadJourneys();
          if (!mounted) return;
          final addedKm =
              VehicleInsights.instance.currentMileageKm - previousKm;
          if (addedKm > 0) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MileageImpactScreen(
                args: MileageImpactArgs(
                  previousMileageKm: previousKm,
                  addedKm: addedKm,
                  vehicleModel: VehicleInsights.instance.model,
                  vehiclePlate: VehicleInsights.instance.plate,
                ),
              ),
            ));
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppShadowsExt shadows = theme.extension<AppShadowsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Color mutedFg =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    final List<Map<String, dynamic>> dayJourneys =
        _journeysForDate(_viewDate);
    final List<Map<String, dynamic>> pendingJourneys =
        _pendingJourneysForDate(_viewDate);
    final double confirmedKm = _confirmedKmForDate(_viewDate);
    final double estimatedCost = confirmedKm * 0.22;

    // Map camera — compute bounding box of selected points.
    LatLng centerLatLng = const LatLng(3.1390, 101.6869);
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
      final maxSpan = ((maxLat - minLat) > (maxLng - minLng))
          ? (maxLat - minLat)
          : (maxLng - minLng);
      if (maxSpan > 1.0) {
        calculatedZoom = 8.0;
      } else if (maxSpan > 0.5) {
        calculatedZoom = 10.0;
      } else if (maxSpan > 0.1) {
        calculatedZoom = 12.0;
      } else if (maxSpan > 0.01) {
        calculatedZoom = 13.5;
      } else {
        calculatedZoom = 15.0;
      }
    }

    // Build map polylines for ALL journeys of the day (coloured by status).
    final Set<Polyline> allPolylines = {};
    // For now we show the selected journey's points; future iteration will
    // load all day's polylines in parallel.
    if (_selectedPoints.isNotEmpty) {
      final selectedJourney = dayJourneys.firstWhere(
          (j) => j['id'] == _selectedJourneyId,
          orElse: () => {});
      final polylineColor = _polylineColor(selectedJourney, colors);
      allPolylines.addAll({
        Polyline(
          polylineId: const PolylineId('selected_route_glow'),
          color: polylineColor.withValues(alpha: colors.surfaceProminent + 0.2),
          width: 8,
          points: _selectedPoints,
        ),
        Polyline(
          polylineId: const PolylineId('selected_route'),
          color: polylineColor,
          width: 4,
          points: _selectedPoints,
        ),
      });
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Journey Log'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(),
        ),
        body: Stack(
          children: [
            // ── Map (top half) ────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height:
                  MediaQuery.of(context).size.height * _mapHeightFraction,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: centerLatLng,
                  zoom: calculatedZoom,
                ),
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                polylines: allPolylines,
              ),
            ),

            // ── Gradient overlay ──────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).size.height * 0.32,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.20,
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

            // ── Bottom draggable sheet ────────────────────────────────────
            DraggableScrollableSheet(
              initialChildSize: _sheetInitialFraction,
              minChildSize: _sheetInitialFraction,
              maxChildSize: _sheetMaxFraction,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(radii.xLarge)),
                    boxShadow: shadows.large,
                  ),
                  child: Column(
                    children: [
                      // Grab handle
                      SizedBox(height: spacing.md),
                      Container(
                        width: spacing.xxxl,
                        height: _grabHandleHeight,
                        decoration: BoxDecoration(
                          color: colors.muted,
                          borderRadius: BorderRadius.circular(radii.small),
                        ),
                      ),
                      SizedBox(height: spacing.sm),

                      // ── Date navigator ──────────────────────────────────
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: spacing.xl),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppIconButton(
                              icon: Icons.chevron_left,
                              semanticsLabel: 'Previous day',
                              onPressed: _goToPreviousDay,
                            ),
                            Column(
                              children: [
                                Text(
                                  DateFormat('EEE, d MMM').format(_viewDate),
                                  style: typography.title
                                      .copyWith(color: colors.foreground),
                                ),
                                Text(
                                  '${dayJourneys.length} trip${dayJourneys.length == 1 ? '' : 's'} recorded',
                                  style: typography.label
                                      .copyWith(color: mutedFg),
                                ),
                              ],
                            ),
                            AppIconButton(
                              icon: Icons.chevron_right,
                              semanticsLabel: 'Next day',
                              onPressed: _goToNextDay,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing.sm),

                      // ── Daily stat bar ──────────────────────────────────
                      if (confirmedKm > 0)
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: spacing.xl),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: spacing.lg,
                                vertical: spacing.sm),
                            decoration: BoxDecoration(
                              color: colors.emerald500
                                  .withValues(alpha: colors.surfaceMedium),
                              borderRadius:
                                  BorderRadius.circular(radii.large),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatPill(
                                  icon: Icons.route_outlined,
                                  label:
                                      '${confirmedKm.toStringAsFixed(1)} km',
                                  color: colors.emerald500,
                                  typography: typography,
                                  spacing: spacing,
                                ),
                                Container(
                                    width: 1,
                                    height: 20,
                                    color: colors.emerald500
                                        .withValues(alpha: 0.3)),
                                _StatPill(
                                  icon: Icons.directions_car_outlined,
                                  label: VehicleInsights.instance.model,
                                  color: colors.emerald500,
                                  typography: typography,
                                  spacing: spacing,
                                ),
                                Container(
                                    width: 1,
                                    height: 20,
                                    color: colors.emerald500
                                        .withValues(alpha: 0.3)),
                                _StatPill(
                                  icon: Icons.monetization_on_outlined,
                                  label:
                                      'RM ${estimatedCost.toStringAsFixed(2)}',
                                  color: colors.emerald500,
                                  typography: typography,
                                  spacing: spacing,
                                ),
                              ],
                            ),
                          ),
                        ),

                      SizedBox(height: spacing.sm),

                      // ── Pro banner ──────────────────────────────────────
                      if (!ProfileService.instance.isPro) ...[
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: spacing.xl),
                          child: const AppFeedbackBanner(
                            kind: FeedbackKind.info,
                            message:
                                'Basic plan stores journey logs for 30 days. Upgrade to Pro for lifetime tracking history.',
                          ),
                        ),
                        SizedBox(height: spacing.sm),
                      ],

                      // ── Journey list ────────────────────────────────────
                      Expanded(
                        child: _isLoading
                            ? const Center(child: AppSpinner())
                            : dayJourneys.isEmpty
                                ? const AppEmptyState(
                                    icon: Icons.timeline,
                                    title: 'No journeys on this day',
                                    message:
                                        'Use the trip planner to record a journey.',
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    padding: EdgeInsets.fromLTRB(
                                        spacing.xl,
                                        spacing.md,
                                        spacing.xl,
                                        // Extra bottom padding for the
                                        // pending badge.
                                        pendingJourneys.isNotEmpty
                                            ? 80
                                            : spacing.md),
                                    itemCount: dayJourneys.length,
                                    itemBuilder: (context, index) {
                                      final journey = dayJourneys[index];
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
                                        child: Column(
                                          children: [
                                            // Timeline connector dot
                                            if (index > 0)
                                              Padding(
                                                padding: EdgeInsets.only(
                                                    left: spacing.md + 4),
                                                child: Row(
                                                  children: [
                                                    Column(
                                                      children: [
                                                        Container(
                                                          width: 2,
                                                          height: spacing.md,
                                                          color: colors.border,
                                                        ),
                                                        Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                colors.border,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                        ),
                                                        Container(
                                                          width: 2,
                                                          height: spacing.md,
                                                          color: colors.border,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                            Container(
                                              margin: EdgeInsets.only(
                                                  bottom: spacing.sm),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: isSelected
                                                      ? _polylineColor(
                                                          journey, colors)
                                                      : Colors.transparent,
                                                  width: 2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        radii.large),
                                              ),
                                              child: _buildJourneyCard(
                                                  journey, colors),
                                            ),
                                          ],
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

            // ── Sticky pending badge ──────────────────────────────────────
            if (pendingJourneys.isNotEmpty)
              Positioned(
                bottom: spacing.xl,
                left: spacing.xl,
                right: spacing.xl,
                child: GestureDetector(
                  onTap: () => _openConfirmationSheet(pendingJourneys),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: spacing.lg, vertical: spacing.md),
                    decoration: BoxDecoration(
                      color: colors.warning,
                      borderRadius: BorderRadius.circular(radii.large),
                      boxShadow: [
                        BoxShadow(
                          color: colors.warning.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pending_actions_outlined,
                            color: Colors.white, size: 18),
                        SizedBox(width: spacing.sm),
                        Text(
                          '${pendingJourneys.length} trip${pendingJourneys.length == 1 ? '' : 's'} need review',
                          style: typography.bodyLarge
                              .copyWith(color: Colors.white),
                        ),
                        SizedBox(width: spacing.sm),
                        const Icon(Icons.arrow_forward_ios,
                            color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCard(
      Map<String, dynamic> journey, AppColorsExt colors) {
    final status = journey['status'] as String? ?? '';
    if (status == 'pending' || status == 'PENDING_CONFIRMATION') {
      return PendingJourneyCard(
        journey: journey,
        onConfirmMyCar: () =>
            _confirmVehicle(journey['id'], 'my_car'),
        onConfirmOther: () =>
            _confirmVehicle(journey['id'], 'other'),
      );
    }
    return _ConfirmedJourneyCard(journey: journey);
  }

  Color _polylineColor(
      Map<String, dynamic> journey, AppColorsExt colors) {
    final status = journey['status'] as String? ?? '';
    final vt = journey['vehicle_type'] as String? ?? '';
    if (status == 'pending' || status == 'PENDING_CONFIRMATION') {
      return colors.warning;
    }
    if (vt == 'my_car') return colors.emerald500;
    return colors.muted;
  }
}

// ---------------------------------------------------------------------------
// Confirmed journey card (token-driven)
// ---------------------------------------------------------------------------

class _ConfirmedJourneyCard extends StatelessWidget {
  final Map<String, dynamic> journey;

  const _ConfirmedJourneyCard({required this.journey});

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Active';
    return DateFormat('dd MMM yyyy, h:mm a').format(DateTime.parse(isoString));
  }

  String _calculateDuration(String start, String end) {
    final diff = DateTime.parse(end).difference(DateTime.parse(start));
    if (diff.inSeconds < 60) return '${diff.inSeconds} secs';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins';
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final double? distance = (journey['distance_km'] as num?)?.toDouble();
    final String startAddr = journey['start_address'] as String? ?? 'Origin';
    final String destAddr =
        journey['destination_address'] as String? ?? 'No destination set';
    final bool isActive = journey['end_time'] == null;
    final String vt = journey['vehicle_type'] as String? ?? '';

    final Color mutedFg =
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
                    horizontal: spacing.md, vertical: spacing.xs),
                decoration: BoxDecoration(
                  color: statusColor
                      .withValues(alpha: colors.surfaceMedium),
                  borderRadius: BorderRadius.circular(radii.small),
                ),
                child: Text(
                  isActive ? 'Active Trip' : 'Confirmed Trip',
                  style: typography.label.copyWith(color: statusColor),
                ),
              ),
              Text(
                _formatDateTime(journey['start_time']),
                style: typography.body.copyWith(color: mutedFg),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          Row(
            children: [
              Column(
                children: [
                  Icon(Icons.radio_button_checked,
                      size: typography.bodyLarge.fontSize,
                      color: colors.emerald500),
                  Container(
                      width: 2, height: spacing.xl, color: colors.border),
                  Icon(Icons.location_on,
                      size: typography.bodyLarge.fontSize,
                      color: colors.error),
                ],
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(startAddr,
                        style:
                            typography.body.copyWith(color: colors.foreground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    SizedBox(height: spacing.lg),
                    Text(destAddr,
                        style:
                            typography.body.copyWith(color: colors.foreground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (vt == 'my_car')
                Padding(
                  padding: EdgeInsets.only(left: spacing.sm),
                  child: Icon(Icons.directions_car,
                      size: typography.headline.fontSize,
                      color: mutedFg),
                )
              else if (vt == 'other' || vt == 'public_transport')
                Padding(
                  padding: EdgeInsets.only(left: spacing.sm),
                  child: Icon(Icons.directions_bus,
                      size: typography.headline.fontSize,
                      color: mutedFg),
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
                  Text('DISTANCE',
                      style: typography.label.copyWith(color: mutedFg)),
                  SizedBox(height: spacing.xs),
                  Text(
                    distance != null
                        ? '${distance.toStringAsFixed(2)} km'
                        : '--',
                    style:
                        typography.headline.copyWith(color: colors.foreground),
                  ),
                ],
              ),
              if (!isActive && journey['end_time'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DURATION',
                        style: typography.label.copyWith(color: mutedFg)),
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
          ),
          // Phase 5: deviation badge — only shown when a planned distance exists
          Builder(builder: (_) {
            final deviationRaw = journey['deviation_km'];
            if (deviationRaw == null) return const SizedBox.shrink();
            final double deviation =
                (deviationRaw as num).toDouble();
            final bool over = deviation > 0;
            final Color deviationColor =
                over ? Colors.amber.shade700 : Colors.green.shade600;
            final IconData deviationIcon =
                over ? Icons.arrow_upward : Icons.arrow_downward;
            final String label = over
                ? '+${deviation.toStringAsFixed(1)} km vs plan'
                : '${deviation.toStringAsFixed(1)} km vs plan';
            return Padding(
              padding: EdgeInsets.only(top: spacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: spacing.sm, vertical: spacing.xs / 2),
                    decoration: BoxDecoration(
                      color: deviationColor.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(radii.small),
                      border: Border.all(
                          color: deviationColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(deviationIcon,
                            size: 12, color: deviationColor),
                        SizedBox(width: spacing.xs),
                        Text(label,
                            style: typography.label
                                .copyWith(color: deviationColor)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat pill helper
// ---------------------------------------------------------------------------

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final AppTypographyExt typography;
  final AppSpacingExt spacing;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.typography,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        SizedBox(width: spacing.xs),
        Text(label,
            style: typography.label.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
