import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/google_maps_service.dart';
import '../models/workshop.dart';
import 'workshop_detail_screen.dart';

class WorkshopMapScreen extends StatefulWidget {
  const WorkshopMapScreen({super.key});

  static const routeName = '/workshop-map';

  @override
  State<WorkshopMapScreen> createState() => _WorkshopMapScreenState();
}

class _WorkshopMapScreenState extends State<WorkshopMapScreen> {
  double _radiusKm = 5.0;
  List<Workshop> _workshops = [];
  bool _isLoading = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndSearch();
  }

  Future<void> _getCurrentLocationAndSearch() async {
    setState(() => _isLoading = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
      
      await _searchWorkshops();
    } catch (e) {
      debugPrint('Location Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchWorkshops() async {
    if (_currentPosition == null) return;
    
    setState(() => _isLoading = true);
    final results = await GoogleMapsService.searchNearbyWorkshops(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      _radiusKm,
    );

    setState(() {
      _workshops = results.map((json) => Workshop.fromGooglePlace(json)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workshop Discovery'),
        actions: [
          IconButton(
            onPressed: _getCurrentLocationAndSearch,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          // Proximity Slider Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Search Radius',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_radiusKm.toInt()} km',
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: '${_radiusKm.toInt()} km',
                      onChanged: (val) {
                        setState(() => _radiusKm = val);
                      },
                      onChangeEnd: (val) {
                        _searchWorkshops();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _workshops.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: isDark ? Colors.white24 : Colors.black12),
                            const SizedBox(height: 16),
                            const Text('No workshops found in this area.'),
                            TextButton(
                              onPressed: _searchWorkshops,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _workshops.length,
                        itemBuilder: (context, index) {
                          final workshop = _workshops[index];
                          return _WorkshopSummaryCard(workshop: workshop);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopSummaryCard extends StatelessWidget {
  final Workshop workshop;

  const _WorkshopSummaryCard({required this.workshop});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkshopDetailScreen(workshop: workshop),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.build_circle_outlined, color: primaryColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workshop.name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workshop.address,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          workshop.rating.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${workshop.reviewCount})',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
