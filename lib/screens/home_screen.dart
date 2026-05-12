// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../services/vehicle_insights.dart';
import '../widgets/glass_container.dart';
import '../widgets/vehicle_health_gauge.dart';
import 'booking_screen.dart';
import 'document_vault_screen.dart';
import 'notifications_screen.dart';
import 'refuel_log_screen.dart';
import 'settings_screen.dart';
import 'vehicle_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  // Static notifier to allow programmatic navigation from any tab or child widget
  static final ValueNotifier<int> activeTabNotifier = ValueNotifier<int>(0);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Active Tab bodies
  final List<Widget> _tabs = [
    const _HomeCockpitBody(),
    const BookingScreen(),
    const VehicleScreen(),
    const RefuelLogScreen(),
    const DocumentVaultScreen(),
  ];

  @override
  void initState() {
    super.initState();
    HomeScreen.activeTabNotifier.value = 0; // Reset index to home cockpit on startup
    HomeScreen.activeTabNotifier.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    HomeScreen.activeTabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        _currentIndex = HomeScreen.activeTabNotifier.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final charcoalColor = isDark ? Colors.white : const Color(0xFF1F2937);

    // Point 2: Radial/Linear gradient background depth wrapper
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
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent, // Allows underlying gradient to shine through!
        // Keep main DriveCare+ appbar only on Cockpit tab
        appBar: _currentIndex == 0
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'DriveCare+',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: charcoalColor,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, NotificationsScreen.routeName),
                    icon: Icon(Icons.notifications_outlined, color: charcoalColor),
                    tooltip: 'Notifications',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, SettingsScreen.routeName),
                    icon: Icon(Icons.settings_outlined, color: charcoalColor),
                    tooltip: 'Settings',
                  ),
                ],
              )
            : null,
        body: _tabs[_currentIndex],
        // Point 5: Floating Bottom Navigation Pill Shape sitting above the bottom edge
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withOpacity(0.65)
                    : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black38 : Colors.black.withAlpha(15),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.white.withOpacity(0.5),
                  width: 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      onTap: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        HomeScreen.activeTabNotifier.value = index;
                      },
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor: Theme.of(context).colorScheme.primary,
                      unselectedItemColor: isDark ? Colors.white38 : Colors.grey.shade400,
                      selectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.speed_outlined),
                          activeIcon: Icon(Icons.speed),
                          label: 'Cockpit',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.storefront_outlined),
                          activeIcon: Icon(Icons.storefront),
                          label: 'Workshops',
                        ),
                        // Center tab is My Car (Index 2)
                        BottomNavigationBarItem(
                          icon: Icon(Icons.directions_car_outlined),
                          activeIcon: Icon(Icons.directions_car),
                          label: 'My Car',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.local_gas_station_outlined),
                          activeIcon: Icon(Icons.local_gas_station),
                          label: 'Refuels',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.folder_copy_outlined),
                          activeIcon: Icon(Icons.folder_copy),
                          label: 'Vault',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Separate body class for the main Cockpit tab
class _HomeCockpitBody extends StatelessWidget {
  const _HomeCockpitBody();

  Future<void> _navigateTo(BuildContext context, String routeName) async {
    if (routeName == VehicleScreen.routeName) {
      HomeScreen.activeTabNotifier.value = 2; // Swaps to My Car tab
    } else if (routeName == BookingScreen.routeName) {
      HomeScreen.activeTabNotifier.value = 1; // Swaps to Workshops tab
    } else if (routeName == RefuelLogScreen.routeName) {
      HomeScreen.activeTabNotifier.value = 3; // Swaps to Refuels tab
    } else if (routeName == DocumentVaultScreen.routeName) {
      HomeScreen.activeTabNotifier.value = 4; // Swaps to Vault tab
    } else {
      await Navigator.pushNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
        children: [
          // Greeting Header
          ListenableBuilder(
            listenable: ProfileService.instance,
            builder: (context, child) {
              final profile = ProfileService.instance;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${profile.displayName}! 👋',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Welcome to your vehicle center',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          letterSpacing: 0.5, // Point 3: Extended Subheader spacing
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _navigateTo(context, VehicleScreen.routeName),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withAlpha(80),
                          width: 2.0,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(profile.photoUrl),
                        backgroundColor: Colors.grey,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28), // Point 5: Spacing breathability

          // Live Custom Health Gauge
          const VehicleHealthGauge(),
          const SizedBox(height: 28), // Point 5: Spacing breathability

          ListenableBuilder(
            listenable: VehicleInsights.instance,
            builder: (context, child) {
              final insights = VehicleInsights.instance;
              final bookings = insights.activeBookings;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bookings.isNotEmpty) ...[
                    // Point 1: Frosted Liquid glassmorphism "Upcoming Appointment" card wrapper
                    GlassContainer(
                      borderRadius: 24,
                      opacity: 0.15,
                      borderColor: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_available,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                         title: Text(
                          'Upcoming Appointment',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF1F2937), // Point 3: Charcoal soft contrast
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            '${bookings.first['workshopName']}\n${bookings.first['serviceName']} • ${bookings.first['date']} at ${bookings.first['time']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isDark ? Colors.white70 : const Color(0xFF1F2937),
                        ),
                        onTap: () => _navigateTo(context, BookingScreen.routeName),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
