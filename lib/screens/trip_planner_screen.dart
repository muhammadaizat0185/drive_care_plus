import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/google_maps_service.dart';
import '../services/journey_database.dart';
import '../services/location_tracker.dart';
import '../widgets/glass_container.dart';

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
  Set<Marker> _markers = {};
  
  int? _routeDistanceMeters;
  String? _routeDuration;
  
  bool _isRecording = false;
  int? _journeyId;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placePredictions = [];

  ReceivePort? _receivePort;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initForegroundTask();
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
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

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 15));
    } catch (e) {
      debugPrint("Location Init Error: $e");
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
        debugPrint("Error restoring active journey on init: $e");
      }
    }

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
    final directions = await GoogleMapsService.getDirections(origin, destination);
    if (directions != null) {
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
        
        // Must create a NEW Set object for GoogleMap to detect the state change
        _polylines = {
          // 1. Neon Outer Glow
          Polyline(
            polylineId: const PolylineId('route_glow_outer'),
            color: const Color(0xFF06B6D4).withOpacity(0.25), // Cyan neon tint
            width: 14,
            points: polylineCoordinates,
          ),
          // 2. Neon Inner Core
          Polyline(
            polylineId: const PolylineId('route_glow_inner'),
            color: const Color(0xFF22D3EE).withOpacity(0.7), // Rich cyan accent
            width: 8,
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

      // Fit map to bounds
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          origin.latitude < destination.latitude ? origin.latitude : destination.latitude,
          origin.longitude < destination.longitude ? origin.longitude : destination.longitude,
        ),
        northeast: LatLng(
          origin.latitude > destination.latitude ? origin.latitude : destination.latitude,
          origin.longitude > destination.longitude ? origin.longitude : destination.longitude,
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to calculate route. Please ensure the Routes API is enabled in Google Cloud Console.')),
        );
      }
    }
  }

  Future<void> _startJourney() async {
    // Verify Always Allow permissions for high-fidelity background tracking
    final alwaysStatus = await Permission.locationAlways.status;
    if (!alwaysStatus.isGranted) {
      if (mounted) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Always Allow Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: const Text(
                'DriveCare+ requires your location permission to be set to "Allow all the time" so that we can accurately track your trip distance, route, and fuel efficiency in the background even when your screen is off or the app is minimized.\n\nPlease select "Allow all the time" in the system settings dialog.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Configure Settings'),
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
                const SnackBar(content: Text('Background location permission denied. Tracking accuracy might be limited.')),
              );
            }
          }
        } else {
          return;
        }
      }
    }

    // Verify permissions for foreground service
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.denied) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    final id = await JourneyDatabase.instance.startJourney();
    await LocationTracker.startTracking();
    
    setState(() {
      _isRecording = true;
      _journeyId = id;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journey recording started!')));
  }

  Future<void> _stopJourney() async {
    await LocationTracker.stopTracking();

    if (_journeyId != null) {
      final pointsData = await JourneyDatabase.instance.getPoints(_journeyId!);
      List<LatLng> rawPoints = pointsData.map((p) => LatLng(p['latitude'], p['longitude'])).toList();

      List<LatLng> pointsForDistance = rawPoints;
      try {
        // Try snapping to roads for refined layout
        final snapped = await GoogleMapsService.snapToRoads(rawPoints);
        if (snapped.length >= 2) {
          pointsForDistance = snapped;
        }
      } catch (e) {
        debugPrint("Snap to Roads failed, falling back to raw points: $e");
      }

      // Calculate distance between points (in meters)
      double totalDistance = 0;
      for (int i = 0; i < pointsForDistance.length - 1; i++) {
        totalDistance += Geolocator.distanceBetween(
          pointsForDistance[i].latitude, pointsForDistance[i].longitude,
          pointsForDistance[i+1].latitude, pointsForDistance[i+1].longitude,
        );
      }

      double distanceKm = totalDistance / 1000.0;
      await JourneyDatabase.instance.endJourney(_journeyId!, distanceKm, 'Start', _searchController.text);
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Journey saved! Distance: ${distanceKm.toStringAsFixed(2)} km')));
    }

    setState(() {
      _isRecording = false;
      _journeyId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Base
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
          
          // 2. Glassmorphic Floating Search Bar UI overlay
          Positioned(
            top: 20, left: 16, right: 16,
            child: SafeArea(
              child: Column(
                children: [
                  GlassContainer(
                    borderRadius: 24,
                    blurSigma: 12,
                    opacity: isDark ? 0.15 : 0.65,
                    backgroundColor: isDark ? Colors.black : Colors.white,
                    borderColor: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                    borderWidth: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search destination...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  if (_placePredictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _placePredictions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, index) {
                            final place = _placePredictions[index];
                            return ListTile(
                              leading: Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                              title: Text(
                                place['description'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              onTap: () => _selectPlace(place['place_id'], place['description']),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Back Floating Arrow Button
          Positioned(
            top: 24,
            left: 20,
            child: SafeArea(
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),

          // 3. Bottom Action Panel with DraggableScrollableSheet
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize: 0.15,
            maxChildSize: 0.55,
            builder: (context, scrollController) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final primaryColor = Theme.of(context).colorScheme.primary;

              // Estimated fuel cost: calculate based on _routeDistanceMeters
              // Heuristic: 8.0 Liters per 100km, multiplied by RM 2.05 (RON 95 fuel price)
              double estimatedFuelCost = 0.0;
              double estimatedFuelLiters = 0.0;
              if (_routeDistanceMeters != null) {
                final double distanceKm = _routeDistanceMeters! / 1000.0;
                estimatedFuelLiters = (distanceKm / 100.0) * 8.0;
                estimatedFuelCost = estimatedFuelLiters * 2.05;
              }

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.92) : Colors.white.withOpacity(0.92),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: GlassContainer(
                    borderRadius: 32,
                    blurSigma: 12,
                    opacity: isDark ? 0.05 : 0.3,
                    borderColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      children: [
                        // Grab Handle indicator
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Route metrics (Only shown when a route is active)
                        if (_routeDistanceMeters != null && !_isRecording) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildInfoChip(Icons.route_outlined, _formatDistance(_routeDistanceMeters)),
                              _buildInfoChip(Icons.timer_outlined, _formatDuration(_routeDuration)),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isRecording ? 'Recording Journey...' : 'Ready to Start',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            if (_isRecording)
                              const _BlinkingRecordingIndicator()
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRecording
                              ? 'Background tracking active. Your GPS coordinates are monitored at 10-second intervals.'
                              : (_destination != null
                                  ? 'Tap start below to record your coordinates and log the trip.'
                                  : 'Search and select a destination to preview your route.'),
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Large Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRecording ? Colors.red.shade600 : primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 4,
                            ),
                            onPressed: _isRecording ? _stopJourney : _startJourney,
                            icon: Icon(_isRecording ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 26),
                            label: Text(
                              _isRecording ? 'Stop Recording' : 'Start Journey',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ),

                        // Expanded trip details section (Swipe up to see)
                        if (_routeDistanceMeters != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Divider(),
                          ),
                          Text(
                            'Estimated Costs',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _buildCostTile(
                            Icons.local_gas_station_outlined,
                            'Fuel consumption',
                            '${estimatedFuelLiters.toStringAsFixed(2)} L (RON 95)',
                          ),
                          const SizedBox(height: 12),
                          _buildCostTile(
                            Icons.monetization_on_outlined,
                            'Estimated fuel cost',
                            'RM ${estimatedFuelCost.toStringAsFixed(2)}',
                            highlightColor: primaryColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostTile(IconData icon, String title, String value, {Color? highlightColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: highlightColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingRecordingIndicator extends StatefulWidget {
  const _BlinkingRecordingIndicator();

  @override
  State<_BlinkingRecordingIndicator> createState() => _BlinkingRecordingIndicatorState();
}

class _BlinkingRecordingIndicatorState extends State<_BlinkingRecordingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.shade600.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'REC',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
