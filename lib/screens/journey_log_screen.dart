import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/journey_database.dart';
import '../widgets/glass_container.dart';
import '../widgets/pending_journey_card.dart';

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
      if (_journeys.isNotEmpty && _selectedJourneyId == null) {
        _selectedJourneyId = _journeys.first['id'];
        _loadPointsForSelected();
      }
    });
  }

  Future<void> _loadPointsForSelected() async {
    if (_selectedJourneyId == null) return;
    try {
      final pointsData = await JourneyDatabase.instance.getPoints(_selectedJourneyId!);
      if (mounted) {
        setState(() {
          _selectedPoints = pointsData.map((p) => LatLng(p['latitude'], p['longitude'])).toList();
        });
      }
    } catch (e) {
      print("Error loading points: \$e");
    }
  }

  Future<void> _confirmVehicle(int journeyId, String vehicleType) async {
    await JourneyDatabase.instance.updateJourneyStatus(journeyId, 'confirmed', vehicleType);
    _loadJourneys();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate map camera position center
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

      if (maxSpan > 1.0) calculatedZoom = 8.0;
      else if (maxSpan > 0.5) calculatedZoom = 10.0;
      else if (maxSpan > 0.1) calculatedZoom = 12.0;
      else if (maxSpan > 0.01) calculatedZoom = 13.5;
      else calculatedZoom = 15.0;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Journey Logs',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: Stack(
        children: [
          // Top Half: Map
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.55,
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
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    width: 8,
                    points: _selectedPoints,
                  ),
                if (_selectedPoints.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('selected_route'),
                    color: Theme.of(context).colorScheme.primary,
                    width: 4,
                    points: _selectedPoints,
                  ),
              },
            ),
          ),
          
          // Gradient Overlay to fade into bottom sheet
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
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),

          // Bottom Sheet: Timeline List
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _journeys.isEmpty
                              ? const Center(child: Text("No journeys recorded yet."))
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  itemCount: _journeys.length,
                                  itemBuilder: (context, index) {
                                    final journey = _journeys[index];
                                    final isSelected = journey['id'] == _selectedJourneyId;
                                    
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedJourneyId = journey['id'];
                                        });
                                        _loadPointsForSelected();
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          border: isSelected
                                              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                              : Border.all(color: Colors.transparent, width: 2),
                                          borderRadius: BorderRadius.circular(26),
                                        ),
                                        child: journey['status'] == 'pending'
                                            ? PendingJourneyCard(
                                                journey: journey,
                                                onConfirmMyCar: () => _confirmVehicle(journey['id'], 'my_car'),
                                                onConfirmOther: () => _confirmVehicle(journey['id'], 'other'),
                                              )
                                            : _ConfirmedJourneyCard(journey: journey),
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
    );
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

    if (diff.inSeconds < 60) return '\${diff.inSeconds} secs';
    if (diff.inMinutes < 60) return '\${diff.inMinutes} mins';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '\${hours}h \${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final distance = journey['distance_km'] as double?;
    final startAddr = journey['start_address'] as String? ?? 'Origin';
    final destAddr = journey['destination_address'] as String? ?? 'No destination set';
    final isActive = journey['end_time'] == null;

    return Container(
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
                      isActive ? 'Active Trip' : 'Confirmed Trip',
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
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
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
                        Text(startAddr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 18),
                        Text(destAddr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (journey['vehicle_type'] == 'my_car')
                     const Padding(
                       padding: EdgeInsets.only(left: 8.0),
                       child: Icon(Icons.directions_car, size: 28, color: Colors.grey),
                     )
                  else if (journey['vehicle_type'] == 'other')
                     const Padding(
                       padding: EdgeInsets.only(left: 8.0),
                       child: Icon(Icons.directions_bus, size: 28, color: Colors.grey),
                     )
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DISTANCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(distance != null ? '\${distance.toStringAsFixed(2)} km' : '--', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                  if (!isActive && journey['end_time'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('DURATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(_calculateDuration(journey['start_time'], journey['end_time']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      ],
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
