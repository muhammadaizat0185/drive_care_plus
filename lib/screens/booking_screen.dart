import 'package:flutter/material.dart';

import '../models/workshop.dart';
import '../services/marketplace_repository.dart';
import '../services/vehicle_insights.dart';
import 'workshop_detail_screen.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  static const routeName = '/booking';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
    );
  }
}

class _FindWorkshopsTab extends StatefulWidget {
  const _FindWorkshopsTab();

  @override
  State<_FindWorkshopsTab> createState() => _FindWorkshopsTabState();
}

class _FindWorkshopsTabState extends State<_FindWorkshopsTab> {
  String selectedCategory = 'All';
  String searchQuery = '';

  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': Icons.grid_view_rounded},
    {'name': 'Repairer', 'icon': Icons.build_rounded},
    {'name': 'Maintenance', 'icon': Icons.car_repair_rounded},
    {'name': 'Tires', 'icon': Icons.tire_repair_rounded},
    {'name': 'Wash', 'icon': Icons.local_car_wash_rounded},
  ];

  final List<String> brands = [
    'Bridgestone',
    'Michelin',
    'Dunlop',
    'Yokohama',
    'Perodua',
    'Proton',
  ];

  @override
  Widget build(BuildContext context) {
    // Filter logic
    final workshops = MarketplaceRepository.workshops.where((w) {
      final matchesSearch = w.name.toLowerCase().contains(searchQuery.toLowerCase());
      if (selectedCategory == 'All') return matchesSearch;
      // Simple tag matches
      final isTire = selectedCategory == 'Tires' && w.name.toLowerCase().contains('tire');
      final isRepair = selectedCategory == 'Repairer' && (w.name.toLowerCase().contains('care') || w.name.toLowerCase().contains('mechanic'));
      final isMaintenance = selectedCategory == 'Maintenance' && (w.name.toLowerCase().contains('service') || w.name.toLowerCase().contains('auto'));
      final isWash = selectedCategory == 'Wash' && w.name.toLowerCase().contains('wash');
      return matchesSearch && (isTire || isRepair || isMaintenance || isWash || selectedCategory == 'All');
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // 1. Welcome / Header (Figma style)
        Text(
          'Choose the best\nservice for you',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.2,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 16),

        // 2. Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            onChanged: (val) {
              setState(() {
                searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search services, workshops...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 3. Service Categories Row
        const Text(
          'Service Categories',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat['name'] == selectedCategory;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = cat['name'] as String;
                  });
                },
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        cat['icon'] as IconData,
                        color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['name'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // 4. Top Brands Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top Brands Support',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            TextButton(onPressed: () {}, child: const Text('See All', style: TextStyle(fontSize: 12))),
          ],
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: brands.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final brand = brands[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withAlpha(10)),
                ),
                child: Text(
                  brand,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // 5. Workshops List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              searchQuery.isNotEmpty || selectedCategory != 'All'
                  ? 'Found (${workshops.length}) Workshops'
                  : 'Top Recommended Workshops',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (workshops.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.search_off_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No workshops match your filters.', style: TextStyle(color: Colors.grey)),
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
    final lowestPrice = workshop.services
        .map((service) => service.price)
        .reduce((value, element) => value < element ? value : element);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.black.withAlpha(10)),
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
                      const SizedBox(height: 8),
                      Text(
                        workshop.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
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
                  '${workshop.distance} away',
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
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  const TextSpan(text: 'Services from ', style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: 'RM ${lowestPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openDetails(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Quote', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openDetails(context),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold)),
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
}
