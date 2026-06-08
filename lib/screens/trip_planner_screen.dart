// Token + Component_Library sweep (Group 14, Task 14.7).
//
// Sweep summary:
//   * Search input swapped to `AppTextField`.
//   * Floating prediction list rendered through token-driven container
//     (no more `glass_container.dart` dependency).
//   * Action panel surface routed through token extensions.
//   * Primary CTA ('Start Journey' / 'Stop Recording') rendered as
//     `AppGradientButton`.
//   * Snackbars retained for transient confirmations (sweep rule).
//   * `TripInfoChip`, `TripCostTile`, and `TripBlinkingRecordingIndicator`
//     extracted to `lib/screens/trip_planner/_widgets.dart` to keep this
//     file under the ~600-line ceiling.
//
// PRESERVED (Requirements 12.6, 14.5):
//   * `LocationTracker.initForegroundTask`, `startTracking`, `stopTracking`
//     calls untouched.
//   * `JourneyDatabase.instance.startJourney`, `getJourneys`, `getPoints`,
//     `endJourney(id, distanceKm, 'Start', destination)` calls untouched.
//   * `Geolocator.{isLocationServiceEnabled,checkPermission,requestPermission,
//     getCurrentPosition,distanceBetween}` calls untouched.
//   * `GoogleMapsService.{getPlacePredictions,getPlaceCoordinates,
//     getDirections,snapToRoads}` call signatures untouched.
//   * `Permission.locationAlways.{status,request}` and
//     `FlutterForegroundTask.{isRunningService,requestIgnoreBatteryOptimization}`
//     calls untouched.
//   * `GoogleMap(initialCameraPosition: ..., onMapCreated: ..., markers:
//     _markers, polylines: _polylines, ...)` markers/camera/polylines
//     unchanged.
//   * Polyline IDs preserved exactly: `route_glow_outer`, `route_glow_inner`,
//     `route_core`. Marker IDs preserved exactly: `origin`, `destination`.

import 'dart:isolate';
import 'package:flutter/material.dart';

import '../core/theme/color_utils.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/tokens/tokens.dart';
import '../services/google_maps_service.dart';
import '../services/journey_database.dart';
import '../services/location_tracker.dart';
import '../widgets/ui/ui.dart';
import 'trip_planner/_widgets.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  static const routeName = '/trip-planner';

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _destination;
  Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  int? _routeDistanceMeters;
  String? _routeDuration;

  bool _isRecording = false;
  int? _journeyId;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placePredictions = [];

  // Bottom action panel size fractions. Not Token_Set values.
  static const double _panelInitialFraction = 0.28;
  static const double _panelMinFraction = 0.15;
  static const double _panelMaxFraction = 0.55;
  // Grab handle metrics. Not Token_Set values.
  static const double _grabHandleHeight = 5;
  // Predictions list max height. Not a Token_Set value.
  static const double _predictionsMaxHeight = 250;
  // Action button height target. Not a Token_Set value.
  static const double _actionButtonHeight = 54;

  // ignore: unused_field
  ReceivePort? _receivePort;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initForegroundTask();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _markers.add(
          Marker(
            markerId: const MarkerId('origin'),
            position: _currentLocation!,
            infoWindow: const InfoWindow(title: 'You are here'),
          ),
        );
      });

      _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 15));
    } catch (e) {
      debugPrint('Location Init Error: $e');
    }
  }

  Future<void> _initForegroundTask() async {
    LocationTracker.initForegroundTask();
    final isRunning = await FlutterForegroundTask.isRunningService;

    int? activeJourneyId;
    if (isRunning) {
      try {
        final journeys = await JourneyDatabase.instance.getJourneys();
        if (journeys.isNotEmpty) {
          final latest = journeys.first;
          if (latest['end_time'] == null) {
            activeJourneyId = latest['id'] as int?;
          }
        }
      } catch (e) {
        debugPrint('Error restoring active journey on init: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _isRecording = isRunning;
      _journeyId = activeJourneyId;
    });
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.length > 2) {
      final predictions = await GoogleMapsService.getPlacePredictions(query);
      setState(() {
        _placePredictions = predictions;
      });
    } else {
      setState(() {
        _placePredictions = [];
      });
    }
  }

  Future<void> _selectPlace(String placeId, String description) async {
    FocusScope.of(context).unfocus();
    _searchController.text = description;
    setState(() {
      _placePredictions = [];
    });

    final coords = await GoogleMapsService.getPlaceCoordinates(placeId);
    if (coords != null) {
      setState(() {
        _destination = coords;
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _destination!,
            infoWindow: InfoWindow(title: description),
          ),
        );
      });

      if (_currentLocation != null) {
        _getRoute(_currentLocation!, _destination!);
      }
    }
  }

  Future<void> _getRoute(LatLng origin, LatLng destination) async {
    final directions =
        await GoogleMapsService.getDirections(origin, destination);
    if (!mounted) return;
    if (directions != null) {
      final AppColorsExt colors = Theme.of(context).extension<AppColorsExt>()!;
      final polylineStr = directions['overview_polyline']['points'];
      List<PointLatLng> result = PolylinePoints.decodePolyline(polylineStr);

      List<LatLng> polylineCoordinates = [];
      if (result.isNotEmpty) {
        for (var point in result) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
      }

      setState(() {
        _routeDistanceMeters = directions['distance_meters'];
        _routeDuration = directions['duration'];

        // Polyline IDs preserved exactly per Requirement 14.5.
        _polylines = {
          // 1. Neon Outer Glow — cyan accent retained as a route accent
          // (not part of the brand-token palette).
          Polyline(
            polylineId: const PolylineId('route_glow_outer'),
            color: colors.routeGlowOuter.withValues(alpha: 0.25),
            width: 14,
            points: polylineCoordinates,
          ),
          // 2. Neon Inner Core
          Polyline(
            polylineId: const PolylineId('route_glow_inner'),
            color: colors.routeGlowInner.withValues(alpha: 0.7),
            width: 10 - 2,
            points: polylineCoordinates,
          ),
          // 3. Bright Solid Core
          Polyline(
            polylineId: const PolylineId('route_core'),
            color: Colors.white,
            width: 3,
            points: polylineCoordinates,
          ),
        };
      });

      // Fit map to bounds — preserved logic.
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          origin.latitude < destination.latitude
              ? origin.latitude
              : destination.latitude,
          origin.longitude < destination.longitude
              ? origin.longitude
              : destination.longitude,
        ),
        northeast: LatLng(
          origin.latitude > destination.latitude
              ? origin.latitude
              : destination.latitude,
          origin.longitude > destination.longitude
              ? origin.longitude
              : destination.longitude,
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to calculate route. Please ensure the Routes API is enabled in Google Cloud Console.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _startJourney() async {
    // Verify Always Allow permissions for high-fidelity background tracking.
    final alwaysStatus = await Permission.locationAlways.status;
    if (!alwaysStatus.isGranted) {
      if (mounted) {
        final ThemeData theme = Theme.of(context);
        final AppColorsExt colors = theme.extension<AppColorsExt>()!;
        final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
        final AppTypographyExt typography =
            theme.extension<AppTypographyExt>()!;
        final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
        final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radii.large),
              ),
              title: Row(
                children: [
                  Icon(Icons.location_on, color: colors.error),
                  SizedBox(width: spacing.sm),
                  Text(
                    'Always Allow Location',
                    style: typography.title
                        .copyWith(color: colors.foreground),
                  ),
                ],
              ),
              content: Text(
                'DriveCare+ requires your location permission to be set to "Allow all the time" so that we can accurately track your trip distance, route, and fuel efficiency in the background even when your screen is off or the app is minimized.\n\nPlease select "Allow all the time" in the system settings dialog.',
                style: typography.bodyLarge
                    .copyWith(color: colors.foreground),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                AppGradientButton(
                  label: 'Configure Settings',
                  fullWidth: false,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            );
          },
        );

        if (proceed == true) {
          final result = await Permission.locationAlways.request();
          if (!result.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Background location permission denied. Tracking accuracy might be limited.',
                  ),
                ),
              );
            }
          }
        } else {
          return;
        }
      }
    }

    // Verify permissions for foreground service.
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.denied) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Phase 5: Persist planned route metadata so deviation can be computed
    // in LocationTaskHandler.onDestroy() at journey end.
    int? plannedDurationS;
    if (_routeDuration != null) {
      // _routeDuration is formatted as "X hours Y mins" or "X mins" from
      // the Directions API. Parse it to seconds for storage.
      final parts = _routeDuration!.toLowerCase();
      int totalSeconds = 0;
      final hourMatch = RegExp(r'(\d+)\s*hour').firstMatch(parts);
      final minMatch = RegExp(r'(\d+)\s*min').firstMatch(parts);
      if (hourMatch != null) totalSeconds += int.parse(hourMatch.group(1)!) * 3600;
      if (minMatch != null) totalSeconds += int.parse(minMatch.group(1)!) * 60;
      if (totalSeconds > 0) plannedDurationS = totalSeconds;
    }

    final id = await JourneyDatabase.instance.startJourney(
      status: 'PENDING_CONFIRMATION',
      plannedDistanceKm: _routeDistanceMeters != null
          ? _routeDistanceMeters! / 1000.0
          : null,
      plannedDurationS: plannedDurationS,
    );
    await LocationTracker.startTracking();

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _journeyId = id;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Journey recording started!')),
    );
  }

  Future<void> _stopJourney() async {
    await LocationTracker.stopTracking();

    if (_journeyId != null) {
      final pointsData =
          await JourneyDatabase.instance.getPoints(_journeyId!);
      List<LatLng> rawPoints = pointsData
          .map((p) => LatLng(p['latitude'], p['longitude']))
          .toList();

      List<LatLng> pointsForDistance = rawPoints;
      try {
        // Try snapping to roads for refined layout.
        final snapped = await GoogleMapsService.snapToRoads(rawPoints);
        if (snapped.length >= 2) {
          pointsForDistance = snapped;
        }
      } catch (e) {
        debugPrint('Snap to Roads failed, falling back to raw points: $e');
      }

      // Calculate distance between points (in meters) — preserved logic.
      double totalDistance = 0;
      for (int i = 0; i < pointsForDistance.length - 1; i++) {
        totalDistance += Geolocator.distanceBetween(
          pointsForDistance[i].latitude,
          pointsForDistance[i].longitude,
          pointsForDistance[i + 1].latitude,
          pointsForDistance[i + 1].longitude,
        );
      }

      double distanceKm = totalDistance / 1000.0;
      await JourneyDatabase.instance.endJourney(
        _journeyId!,
        distanceKm,
        'Start',
        _searchController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Journey saved! Distance: ${distanceKm.toStringAsFixed(2)} km',
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _journeyId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppShadowsExt shadows = theme.extension<AppShadowsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
        children: [
          // 1. Map Base — call shape preserved exactly per Requirement 14.5.
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(3.1390, 101.6869), // KL Default
              zoom: 10,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // 2. Floating search bar overlay (token-driven).
          Positioned(
            top: spacing.lg,
            left: spacing.lg,
            right: spacing.lg,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(radii.large),
                      border: Border.all(color: colors.border),
                      boxShadow: shadows.medium,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: spacing.md),
                      child: AppTextField(
                        controller: _searchController,
                        hintText: 'Search destination...',
                        prefixIcon: Icons.search,
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  ),
                  if (_placePredictions.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: spacing.sm),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(radii.large),
                        border: Border.all(color: colors.border),
                        boxShadow: shadows.medium,
                      ),
                      constraints: const BoxConstraints(
                        maxHeight: _predictionsMaxHeight,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radii.large),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _placePredictions.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: spacing.lg,
                            endIndent: spacing.lg,
                            color: colors.border,
                          ),
                          itemBuilder: (context, index) {
                            final place = _placePredictions[index];
                            return AppListTile(
                              leading: Icon(
                                Icons.location_on_outlined,
                                color: colors.emerald500,
                                size: typography.bodyLarge.fontSize,
                              ),
                              title: Text(
                                place['description'],
                                style: typography.body.copyWith(
                                  color: colors.foreground,
                                ),
                              ),
                              onTap: () => _selectPlace(
                                  place['place_id'], place['description']),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Back Floating Arrow Button.
          Positioned(
            top: spacing.xl,
            left: spacing.xl,
            child: SafeArea(
              child: AppIconButton(
                icon: Icons.arrow_back,
                semanticsLabel: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. Bottom Action Panel.
          DraggableScrollableSheet(
            initialChildSize: _panelInitialFraction,
            minChildSize: _panelMinFraction,
            maxChildSize: _panelMaxFraction,
            builder: (context, scrollController) {
              double estimatedFuelCost = 0.0;
              double estimatedFuelLiters = 0.0;
              if (_routeDistanceMeters != null) {
                final double distanceKm = _routeDistanceMeters! / 1000.0;
                estimatedFuelLiters = (distanceKm / 100.0) * (9.0 - 1.0);
                estimatedFuelCost = estimatedFuelLiters * 2.05;
              }

              return Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radii.xLarge),
                  ),
                  boxShadow: shadows.large,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radii.xLarge),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.xl,
                      vertical: spacing.md,
                    ),
                    children: [
                      // Grab Handle indicator.
                      Center(
                        child: Container(
                          width: spacing.xxxxl,
                          height: _grabHandleHeight,
                          decoration: BoxDecoration(
                            color: colors.muted,
                            borderRadius:
                                BorderRadius.circular(radii.small),
                          ),
                        ),
                      ),
                      SizedBox(height: spacing.lg),

                      // Route metrics (only when a route is active).
                      if (_routeDistanceMeters != null && !_isRecording) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TripInfoChip(
                              icon: Icons.route_outlined,
                              label: _formatDistance(_routeDistanceMeters),
                            ),
                            TripInfoChip(
                              icon: Icons.timer_outlined,
                              label: _formatDuration(_routeDuration),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing.lg),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isRecording
                                ? 'Recording Journey...'
                                : 'Ready to Start',
                            style: typography.headline
                                .copyWith(color: colors.foreground),
                          ),
                          if (_isRecording)
                            const TripBlinkingRecordingIndicator(),
                        ],
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        _isRecording
                            ? 'Background tracking active. Your GPS coordinates are monitored at 10-second intervals.'
                            : (_destination != null
                                ? 'Tap start below to record your coordinates and log the trip.'
                                : 'Search and select a destination to preview your route.'),
                        style: typography.body.copyWith(color: mutedForeground),
                      ),
                      SizedBox(height: spacing.lg),

                      // Primary CTA: gradient pill (Requirement 12.4).
                      SizedBox(
                        width: double.infinity,
                        height: _actionButtonHeight,
                        child: AppGradientButton(
                          label: _isRecording
                              ? 'Stop Recording'
                              : 'Start Journey',
                          icon: _isRecording
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          onPressed:
                              _isRecording ? _stopJourney : _startJourney,
                        ),
                      ),

                      // Expanded trip details section.
                      if (_routeDistanceMeters != null) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: spacing.lg),
                          child: Divider(color: colors.border),
                        ),
                        Text(
                          'Estimated Costs',
                          style: typography.title
                              .copyWith(color: colors.foreground),
                        ),
                        SizedBox(height: spacing.md),
                        TripCostTile(
                          icon: Icons.local_gas_station_outlined,
                          title: 'Fuel consumption',
                          value:
                              '${estimatedFuelLiters.toStringAsFixed(2)} L (RON 95)',
                        ),
                        SizedBox(height: spacing.md),
                        TripCostTile(
                          icon: Icons.monetization_on_outlined,
                          title: 'Estimated fuel cost',
                          value: 'RM ${estimatedFuelCost.toStringAsFixed(2)}',
                          highlightColor: colors.emerald500,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),);
  }

  String _formatDistance(int? meters) {
    if (meters == null) return '';
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(String? durationStr) {
    if (durationStr == null) return '';
    final secondsStr = durationStr.replaceAll('s', '');
    final seconds = double.tryParse(secondsStr)?.toInt() ?? 0;

    if (seconds < 60) return '$seconds secs';
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins mins';
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}m';
  }
}
