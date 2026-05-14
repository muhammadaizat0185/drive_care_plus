import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/journey_database.dart';
import '../widgets/glass_container.dart';

class JourneyLogScreen extends StatefulWidget {
  const JourneyLogScreen({super.key});

  static const routeName = '/journey-log';

  @override
  State<JourneyLogScreen> createState() => _JourneyLogScreenState();
}

class _JourneyLogScreenState extends State<JourneyLogScreen> {
  List<Map<String, dynamic>> _journeys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJourneys();
  }

  Future<void> _loadJourneys() async {
    final journeys = await JourneyDatabase.instance.getJourneys();
    setState(() {
      _journeys = journeys;
      _isLoading = false;
    });
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Active';
    final dateTime = DateTime.parse(isoString);
    return DateFormat('dd MMM yyyy, h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Journey Logs',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF022C22)]
                : [const Color(0xFFEFFDF5), const Color(0xFFF9FAFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _journeys.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: 72,
                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recorded journeys yet.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your completed trip tracks will appear here.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white30 : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _journeys.length,
                      itemBuilder: (context, index) {
                        return _JourneyCard(journey: _journeys[index]);
                      },
                    ),
        ),
      ),
    );
  }
}

class _JourneyCard extends StatefulWidget {
  final Map<String, dynamic> journey;

  const _JourneyCard({super.key, required this.journey});

  @override
  State<_JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends State<_JourneyCard> {
  List<LatLng> _points = [];
  bool _isLoadingPoints = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final pointsData = await JourneyDatabase.instance.getPoints(widget.journey['id']);
      if (mounted) {
        setState(() {
          _points = pointsData.map((p) => LatLng(p['latitude'], p['longitude'])).toList();
          _isLoadingPoints = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPoints = false;
        });
      }
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Active';
    final dateTime = DateTime.parse(isoString);
    return DateFormat('dd MMM yyyy, h:mm a').format(dateTime);
  }

  String _calculateDuration(String start, String end) {
    final startTime = DateTime.parse(start);
    final endTime = DateTime.parse(end);
    final diff = endTime.difference(startTime);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} secs';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mins';
    } else {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final journey = widget.journey;
    final distance = journey['distance_km'] as double?;
    final startAddr = journey['start_address'] as String? ?? 'Origin';
    final destAddr = journey['destination_address'] as String? ?? 'No destination set';
    final isActive = journey['end_time'] == null;

    // Calculate map camera position center
    LatLng centerLatLng = const LatLng(3.1390, 101.6869); // Default KL
    double calculatedZoom = 13.0;

    if (_points.isNotEmpty) {
      double minLat = _points.first.latitude;
      double maxLat = _points.first.latitude;
      double minLng = _points.first.longitude;
      double maxLng = _points.first.longitude;

      for (var p in _points) {
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: GlassContainer(
          borderRadius: 24,
          blurSigma: 16,
          opacity: isDark ? 0.08 : 0.45,
          borderColor: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.5),
          borderWidth: 1.2,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.amber.withOpacity(0.15)
                          : Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActive ? 'Active Trip' : 'Completed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isActive
                            ? Colors.amber.shade700
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    _formatDateTime(journey['start_time']),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Column(
                    children: [
                      Icon(Icons.radio_button_checked, size: 16, color: Theme.of(context).colorScheme.primary),
                      Container(width: 2, height: 24, color: isDark ? Colors.white24 : Colors.black12),
                      Icon(Icons.location_on, size: 16, color: Colors.red.shade400),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          startAddr,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          destAddr,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Visual Mini-Map Section (Displays actual route thumbnail)
              if (!_isLoadingPoints && _points.isNotEmpty) ...[
                const Text(
                  'ROUTE SUMMARY',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: centerLatLng,
                        zoom: calculatedZoom,
                      ),
                      liteModeEnabled: true, // Optimized static rendering for ScrollView lists on Android
                      zoomGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('mini_route_glow'),
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                          width: 6,
                          points: _points,
                        ),
                        Polyline(
                          polylineId: const PolylineId('mini_route'),
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                          points: _points,
                        ),
                      },
                    ),
                  ),
                ),
                const Divider(height: 32),
              ] else if (!_isLoadingPoints && _points.isEmpty) ...[
                // Edge Case: 0.00 km / empty coordinate log placeholder
                Container(
                  height: 60,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: isDark ? Colors.white30 : Colors.black38),
                      const SizedBox(width: 8),
                      Text(
                        'No path coordinates logged for this trip',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white30 : Colors.black38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DISTANCE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        distance != null ? '${distance.toStringAsFixed(2)} km' : '--',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                  if (!isActive && journey['end_time'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'DURATION',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _calculateDuration(journey['start_time'], journey['end_time']),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ],
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    ),
    );
  }
}
