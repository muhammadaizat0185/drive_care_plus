import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workshop.dart';
import '../services/google_maps_service.dart';
import '../services/vehicle_insights.dart';
import '../widgets/glass_container.dart';
import 'workshop_detail_screen.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  static const routeName = '/booking';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F172A), // Deep Slate Dark
                  const Color(0xFF022C22), // Deep Obsidian Dark Green
                ]
              : [
                  const Color(0xFFEFFDF5), // Soft pastel mint
                  const Color(0xFFF9FAFB), // Soft premium grey
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Workshops & Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
            bottom: const TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.storefront_outlined),
                  text: 'Find Workshops',
                ),
                Tab(
                  icon: Icon(Icons.event_available_outlined),
                  text: 'My Bookings',
                ),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _FindWorkshopsTab(),
              _MyBookingsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindWorkshopsTab extends StatefulWidget {
  const _FindWorkshopsTab();

  @override
  State<_FindWorkshopsTab> createState() => _FindWorkshopsTabState();
}

class _FindWorkshopsTabState extends State<_FindWorkshopsTab> {
  String selectedCategory = 'Repair';
  String searchQuery = '';
  double maxDistance = 5.0;
  List<Workshop> workshops = [];
  bool isLoading = false;
  Position? currentPosition;

  final List<Map<String, dynamic>> categories = [
    {'name': 'Carwash', 'icon': Icons.local_car_wash_rounded},
    {'name': 'Repair', 'icon': Icons.build_rounded},
    {'name': 'Car Accessories', 'icon': Icons.settings_input_component_rounded},
    {'name': 'Other', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndSearch();
  }

  Future<void> _getCurrentLocationAndSearch() async {
    setState(() => isLoading = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => currentPosition = position);
      
      await _searchWorkshops();
    } catch (e) {
      debugPrint('Location Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _searchWorkshops() async {
    if (currentPosition == null) return;
    
    setState(() => isLoading = true);
    
    List<String>? includedTypes;
    if (selectedCategory == 'Repair') {
      includedTypes = ['car_repair'];
    } else if (selectedCategory == 'Carwash') {
      includedTypes = ['car_wash'];
    } else if (selectedCategory == 'Car Accessories') {
      includedTypes = ['auto_parts_store'];
    }
    // For 'Other', we leave includedTypes null to search broadly

    final results = await GoogleMapsService.searchNearbyWorkshops(
      LatLng(currentPosition!.latitude, currentPosition!.longitude),
      maxDistance,
      includedTypes: includedTypes,
    );

    if (mounted) {
      setState(() {
        workshops = results
            .map((json) => Workshop.fromGooglePlace(json))
            .where((w) => !w.isGasStation) // Exclude gas stations here as per request
            .map((w) {
          if (w.location != null && currentPosition != null) {
            final dist = Geolocator.distanceBetween(
              currentPosition!.latitude,
              currentPosition!.longitude,
              w.location!.latitude,
              w.location!.longitude,
            );
            final km = dist / 1000;
            return Workshop(
              id: w.id,
              name: w.name,
              address: w.address,
              rating: w.rating,
              reviewCount: w.reviewCount,
              location: w.location,
              isGooglePlace: true,
              openingHours: w.openingHours,
              distance: '${km.toStringAsFixed(1)} km',
              distanceValue: km,
              types: w.types,
              isOpenNow: w.isOpenNow,
            );
          }
          return w;
        }).toList();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text(
          'Choose the best\nservice for you',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.2,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
        ),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            onChanged: (val) {
              setState(() {
                searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search services, workshops...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Within ${maxDistance.toInt()} km',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            Expanded(
              child: Slider(
                value: maxDistance,
                min: 1.0,
                max: 50.0,
                divisions: 49,
                label: '${maxDistance.toInt()} km',
                onChanged: (val) {
                  setState(() => maxDistance = val);
                },
                onChangeEnd: (val) {
                  _searchWorkshops();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Service Categories',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white70 : Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat['name'] == selectedCategory;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = cat['name'] as String;
                  });
                  _searchWorkshops();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: GlassContainer(
                    borderRadius: 24,
                    blurSigma: 12,
                    opacity: isSelected ? 0.18 : 0.05,
                    backgroundColor: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : (isDark ? Colors.white : Colors.black),
                    borderColor: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
                        : (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                    borderWidth: isSelected ? 1.5 : 0.8,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : Theme.of(context).colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            cat['icon'] as IconData,
                            color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat['name'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            color: isSelected 
                                ? (isDark ? Colors.white : Theme.of(context).colorScheme.primary) 
                                : (isDark ? Colors.white70 : Colors.black54),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top Recommended Workshops',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (isLoading && workshops.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ))
        else if (workshops.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.search_off_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No workshops found in this area.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: workshops.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final workshop = workshops[index];
              return _WorkshopCard(workshop: workshop);
            },
          ),
      ],
    );
  }
}

class _MyBookingsTab extends StatelessWidget {
  const _MyBookingsTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VehicleInsights.instance,
      builder: (context, child) {
        final bookings = VehicleInsights.instance.bookings;

        if (bookings.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No appointments booked',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Browse workshops in the first tab to book services.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final price = booking['servicePrice'] as double? ?? 0.0;
            final status = booking['status'] as String? ?? 'Confirmed';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            booking['workshopName'] ?? 'Workshop',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.build_circle_outlined, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            booking['serviceName'] ?? 'Service',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('${booking['date']} at ${booking['time']}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Estimated: RM ${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({required this.workshop});

  final Workshop workshop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    final String statusLabel = workshop.isOpenNow == true ? 'Open Now' : (workshop.isOpenNow == false ? 'Closed' : 'Status: N/A');
    final Color statusColor = workshop.isOpenNow == true ? Colors.green : Colors.red;

    String typeLabel = 'Automotive';
    if (workshop.types.contains('car_repair')) typeLabel = 'Workshop';
    else if (workshop.types.contains('gas_station')) typeLabel = 'Fuel & Services';
    else if (workshop.types.contains('car_wash')) typeLabel = 'Car Wash';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withAlpha(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'POPULAR',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              typeLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        workshop.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        workshop.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  workshop.distance ?? 'Nearby',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.comment_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${workshop.reviewCount} Reviews',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                children: [
                  const TextSpan(text: 'Status: ', style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _launchNavigation,
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Navigate', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openDetails(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(
                      workshop.isGasStation ? 'View Details' : 'Book Now',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkshopDetailScreen(workshop: workshop),
      ),
    );
  }

  Future<void> _launchNavigation() async {
    if (workshop.location == null) return;
    
    final lat = workshop.location!.latitude;
    final lng = workshop.location!.longitude;
    final url = Uri.parse('google.navigation:q=$lat,$lng');
    final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}
