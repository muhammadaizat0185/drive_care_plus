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
import 'trip_planner_screen.dart';
import 'journey_log_screen.dart';
import 'vehicle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/onboarding_guide.dart';
import '../widgets/wallet_top_up_sheet.dart';
import 'wallet_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/activity_recognition_service.dart';
import '../services/toyyibpay_service.dart';
import 'toyyibpay_webview_screen.dart';

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
    _checkFirstLaunchOnboarding();
    ActivityRecognitionService.instance.startListening();
  }

  Future<void> _checkFirstLaunchOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_seen_onboarding_guide') ?? false;
      if (!hasSeen) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return OnboardingGuide(
                onFinished: () async {
                  Navigator.pop(context);
                  await prefs.setBool('has_seen_onboarding_guide', true);
                },
              );
            },
          );
        }
      }
    } catch (_) {}
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
                title: ListenableBuilder(
                  listenable: ProfileService.instance,
                  builder: (context, _) {
                    final isPro = ProfileService.instance.isPro;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DriveCare+',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: charcoalColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: isPro
                                ? const LinearGradient(
                                    colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
                                  )
                                : null,
                            color: isPro ? null : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPro) ...[
                                const Icon(Icons.verified, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isPro ? 'PRO' : 'BASIC',
                                style: TextStyle(
                                  color: isPro ? Colors.white : Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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
                          label: 'Wallet',
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
    } else if (routeName == TripPlannerScreen.routeName) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TripPlannerScreen()),
      );
    } else if (routeName == JourneyLogScreen.routeName) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const JourneyLogScreen()),
      );
    } else {
      await Navigator.pushNamed(context, routeName);
    }
  }

  void _showSubscriptionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _ProSubscriptionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
        children: [
          // Greeting Header
          ListenableBuilder(
            listenable: ProfileService.instance,
            builder: (context, child) {
              try {
                final profile = ProfileService.instance;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${profile.displayName}! 👋',
                              style: TextStyle(
                                fontSize: 24,
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
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, SettingsScreen.routeName),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withAlpha(50),
                                width: 2.0,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(profile.photoUrl),
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } catch (e, stackTrace) {
                return Card(
                  color: Colors.red.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Profile builder error: $e\n$stackTrace'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 28),
          const VehicleHealthGauge(),
          const SizedBox(height: 28),
          // Wallet & Vault Row (Moved below Car Health)
          ListenableBuilder(
            listenable: ProfileService.instance,
            builder: (context, _) {
              final profile = ProfileService.instance;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final primaryColor = Theme.of(context).colorScheme.primary;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, primaryColor.withBlue(200).withGreen(200)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Text(
                                    'DriveCare+ Wallet',
                                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.help_outline, color: Colors.white70, size: 14),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'RM ${profile.walletBalance.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => const WalletTopUpSheet(),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.add, color: primaryColor, size: 18),
                                          const SizedBox(width: 4),
                                          Text("Top Up", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () => HomeScreen.activeTabNotifier.value = 4, // Switch to Vault/Wallet tab
                          child: Container(
                            height: 104, // Roughly match wallet card height
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, primaryColor.withBlue(200).withGreen(200)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.folder_copy, color: Colors.white, size: 28),
                                ),
                                const SizedBox(height: 6),
                                const Text('Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Pro Subscription Initialization Trigger (If not Pro)
                  if (!profile.isPro) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _showSubscriptionModal(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00B894).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Color(0xFF00B894)),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Upgrade to Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Unlock AI Insights & Passive Tracking', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.black26),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 28),

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
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: primaryColor,
                          ),
                        ),
                        title: Text(
                          'Upcoming Appointment',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${bookings.first['workshopName']}\n${bookings.first['serviceName']} • ${bookings.first['date']} at ${bookings.first['time']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                        onTap: () => HomeScreen.activeTabNotifier.value = 1,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Trip Planner Button
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12), // Very soft theme primary
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.map,
                  color: primaryColor,
                ),
              ),
              title: Text(
                'Trip Planner',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Plan your routes and visualize dynamic directions.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              onTap: () => _navigateTo(context, TripPlannerScreen.routeName),
            ),
          ),
          const SizedBox(height: 16),
          // Journey Log Button
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12), // Very soft theme primary
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.explore,
                  color: primaryColor,
                ),
              ),
              title: Text(
                'Journey Logs',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'View history of recorded trips and statistics offline.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              onTap: () => _navigateTo(context, JourneyLogScreen.routeName),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProSubscriptionSheet extends StatefulWidget {
  const _ProSubscriptionSheet();

  @override
  State<_ProSubscriptionSheet> createState() => _ProSubscriptionSheetState();
}

class _ProSubscriptionSheetState extends State<_ProSubscriptionSheet> {
  bool _isProcessing = false;

  Future<void> _startSubscriptionPayment() async {
    setState(() => _isProcessing = true);

    final user = FirebaseAuth.instance.currentUser;
    final payerName = user?.displayName ?? 'DriveCare Driver';
    final payerEmail = user?.email ?? 'driver@drivecareplus.com';
    final payerPhone = ProfileService.instance.phone.replaceAll(RegExp(r'[^\d]'), '');

    final billCode = await ToyyibPayService.createSubscriptionBill(
      payerName: payerName,
      payerEmail: payerEmail,
      payerPhone: payerPhone,
    );

    if (billCode == null) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error creating subscription bill.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final checkoutUrl = 'https://dev.toyyibpay.com/$billCode';
    if (mounted) {
      final result = await Navigator.push<bool?>(
        context,
        MaterialPageRoute(
          builder: (context) => ToyyibPayWebViewScreen(
            checkoutUrl: checkoutUrl,
            returnUrl: ToyyibPayService.returnUrl,
          ),
        ),
      );

      setState(() => _isProcessing = false);

      if (result == true) {
        await ProfileService.instance.initializeProSubscription();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome to Pro! Subscription active. ✨'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00B894).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF00B894), size: 32),
          ),
          const SizedBox(height: 24),
          const Text(
            'DriveCare+ Pro',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'RM 19.90 / month',
            style: TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 24),
          _buildFeatureRow(Icons.psychology, 'AI-Powered Maintenance Predictions'),
          _buildFeatureRow(Icons.history_toggle_off, 'Passive Trip Detection & Recording'),
          _buildFeatureRow(Icons.cloud_sync, 'Unlimited Cloud Log Backups'),
          _buildFeatureRow(Icons.analytics, 'Deep Fuel Efficiency Analytics'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B894),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isProcessing ? null : _startSubscriptionPayment,
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Subscribe & Unlock Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00B894)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
