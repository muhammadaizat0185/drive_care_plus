// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/color_utils.dart';
import '../services/profile_service.dart';
import '../widgets/ui/ui.dart';
import 'booking_screen.dart';
import 'document_vault_screen.dart';
import 'home/_widgets.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import 'refuel_log_screen.dart';
import 'settings_screen.dart';
import 'trip_planner_screen.dart';
import 'journey_log_screen.dart';
import 'vehicle_screen.dart';
import '../widgets/vehicle_health_gauge.dart';
import 'wallet_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/onboarding_guide.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/activity_recognition_service.dart';
import '../services/bluetooth_vehicle_service.dart';
import '../services/journey_database.dart';
import '../services/location_tracker.dart';
import '../services/toyyibpay_service.dart';
import 'toyyibpay_webview_screen.dart';
import '../core/util/transaction_helper.dart';

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
  DateTime? _lastPressedTime;

  // Active Tab bodies
  final List<Widget> _tabs = [
    const _HomeCockpitBody(),
    const BookingScreen(),
    const VehicleScreen(),
    const RefuelLogScreen(),
    const WalletHistoryScreen(),
  ];

  StreamSubscription<Map<String, dynamic>>? _bluetoothSub;

  @override
  void initState() {
    super.initState();
    HomeScreen.activeTabNotifier.value = 0; // Reset index to home cockpit on startup
    HomeScreen.activeTabNotifier.addListener(_onTabChanged);
    _checkFirstLaunchOnboarding();
    ActivityRecognitionService.instance.startListening();
    _initBluetoothAutoTracking();
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
    _bluetoothSub?.cancel();
    HomeScreen.activeTabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  Future<void> _initBluetoothAutoTracking() async {
    // 1. Check if app was launched via Bluetooth notification
    final startData = await BluetoothVehicleService.instance.getStartIntentData();
    if (startData != null && startData['autoStartTracking'] == true) {
      final String? vehicleId = startData['vehicleId'] as String?;
      if (vehicleId != null && vehicleId.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          _handleBluetoothAutoStart(vehicleId);
        });
      }
    }

    // 2. Listen for live connection events from native
    _bluetoothSub = BluetoothVehicleService.instance.bluetoothEventStream.listen((event) {
      final bool connected = event['connected'] == true;
      final String? vehicleId = event['vehicleId'] as String?;
      if (connected && vehicleId != null && vehicleId.isNotEmpty) {
        _handleBluetoothAutoStart(vehicleId);
      } else if (!connected) {
        _handleBluetoothAutoStop();
      }
    });
  }

  Future<void> _handleBluetoothAutoStart(String vehicleId) async {
    if (await FlutterForegroundTask.isRunningService) {
      debugPrint('HomeScreen: Tracking is already active. Ignoring BT trigger.');
      return;
    }

    final journeys = await JourneyDatabase.instance.getJourneys();
    final bool hasActive = journeys.any((j) => j['end_time'] == null);
    if (hasActive) {
      debugPrint('HomeScreen: Active journey exists in DB. Yielding.');
      return;
    }

    debugPrint('HomeScreen: Starting auto-tracking for vehicle $vehicleId');
    final id = await JourneyDatabase.instance.startJourney(
      status: 'PENDING_CONFIRMATION',
    );
    await JourneyDatabase.instance.updateJourneyAttribution(
      id,
      vehicleId: vehicleId,
      vehicleType: 'my_car',
      transportMode: 'driving',
      source: 'bluetooth_auto',
    );

    LocationTracker.initForegroundTask();
    await LocationTracker.startTracking();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚗 Car Connected: Trip tracking started automatically!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleBluetoothAutoStop() async {
    if (await FlutterForegroundTask.isRunningService) {
      debugPrint('HomeScreen: Stopping auto-tracking due to BT disconnect.');
      await LocationTracker.stopTracking();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔌 Car Disconnected: Trip tracking stopped.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onTabChanged() {
    if (mounted) {
      final int newIndex = HomeScreen.activeTabNotifier.value;
      if (newIndex != 1) {
        BookingScreen.activeTabNotifier.value = 0;
      }
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final charcoalColor = isDark ? Colors.white : const Color(0xFF1F2937);

    // Point 2: Radial/Linear gradient background depth wrapper
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // If not in home cockpit, navigate to cockpit
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          HomeScreen.activeTabNotifier.value = 0;
          return;
        }

        // Double back press to exit
        final now = DateTime.now();
        if (_lastPressedTime == null || now.difference(_lastPressedTime!) > const Duration(seconds: 2)) {
          _lastPressedTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        await SystemNavigator.pop();
      },
      child: AppBackground(
        child: Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent, // Allows underlying gradient to shine through!
          appBar: null,
          body: _tabs[_currentIndex],
          // Point 5: Floating Bottom Navigation Pill Shape sitting above the bottom edge
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: AppFloatingBottomNav(
                currentIndex: _currentIndex,
                onTap: (i) {
                  setState(() => _currentIndex = i);
                  HomeScreen.activeTabNotifier.value = i;
                },
                items: const <NavItem>[
                  NavItem(icon: Icons.speed, label: 'Cockpit'),
                  NavItem(icon: Icons.storefront, label: 'Shops'),
                  NavItem(icon: Icons.directions_car, label: 'My Car'),
                  NavItem(icon: Icons.local_gas_station, label: 'Refuel'),
                  NavItem(icon: Icons.account_balance_wallet, label: 'Wallet'),
                ],
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
    } else if (routeName == WalletHistoryScreen.routeName) {
      HomeScreen.activeTabNotifier.value = 4; // Swaps to Wallet tab
    } else if (routeName == DocumentVaultScreen.routeName) {
      await Navigator.pushNamed(context, routeName); // Pushes Vault screen
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
      builder: (context) => const ProSubscriptionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final charcoalColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
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
                GestureDetector(
                  onTap: () => _showSubscriptionModal(context),
                  child: Container(
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
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, NotificationsScreen.routeName),
            icon: ListenableBuilder(
              listenable: NotificationService.instance,
              builder: (context, _) {
                final int unread = NotificationService.instance.unreadCount;
                return Badge(
                  isLabelVisible: unread > 0,
                  label: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: Icon(Icons.notifications_outlined, color: charcoalColor),
                );
              },
            ),
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, SettingsScreen.routeName),
            icon: Icon(Icons.settings_outlined, color: charcoalColor),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
        children: <Widget>[
          // Greeting Header — Requirements 4.1, 4.2.
          const GreetingHeader(),
          const SizedBox(height: 28),
          // Vehicle Health hero — Requirements 4.3, 4.4.
          const VehicleHealthGauge(),
          const SizedBox(height: 28),
          // Wallet (2/3) + Vault (1/3) row — Requirement 4.5.
          const WalletVaultRow(),
          // Pro Subscription Initialization Trigger (If not Pro).
          // NOTE: Out of scope for the 6.1 cockpit refactor; preserved
          // verbatim from the legacy layout.
          ListenableBuilder(
            listenable: ProfileService.instance,
            builder: (BuildContext context, Widget? _) {
              final ProfileService profile = ProfileService.instance;
              if (profile.isPro) return const SizedBox.shrink();
              final bool isDark =
                  Theme.of(context).brightness == Brightness.dark;
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: GestureDetector(
                  onTap: () => _showSubscriptionModal(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00B894).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF00B894),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Upgrade to Pro',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Unlock AI Insights & Passive Tracking',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          // Upcoming-appointment populated/empty branches — Req. 4.11.
          const UpcomingAppointmentCard(),
          const SizedBox(height: 16),
          // Quick actions row — Requirement 4.12.
          QuickActionsRow(
            onTripPlanner: () =>
                _navigateTo(context, TripPlannerScreen.routeName),
            onJourneyLog: () =>
                _navigateTo(context, JourneyLogScreen.routeName),
          ),
        ],
      ),
    );
  }
}

class ProSubscriptionSheet extends StatefulWidget {
  const ProSubscriptionSheet({super.key});

  @override
  State<ProSubscriptionSheet> createState() => ProSubscriptionSheetState();
}

class ProSubscriptionSheetState extends State<ProSubscriptionSheet> {
  bool _isProcessing = false;

  Future<void> _startSubscriptionPayment() async {
    final bool authorized = await TransactionHelper.confirmAndAuthorizeTransaction(
      context: context,
      amount: 19.90,
      description: 'Monthly Pro Subscription',
      recipient: 'DriveCare+ Premium',
    );

    if (!authorized) return;

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
        try {
          await NotificationService.instance.showMoneyFlowNotification(
            title: 'Pro Subscription Upgraded',
            body: 'Pro Subscription is active! RM 19.90 debited.',
          );
        } catch (e) {
          debugPrint('Error sending sub notification: $e');
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome to Pro! Subscription active. ✨'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  Future<void> _payWithWallet(BuildContext context, double currentBalance) async {
    if (currentBalance < 19.90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient wallet balance. Please top up first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool authorized = await TransactionHelper.confirmAndAuthorizeTransaction(
      context: context,
      amount: 19.90,
      description: 'Monthly Pro Subscription Upgrade',
      recipient: 'DriveCare+ Premium',
    );

    if (!authorized) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Deduct RM 19.90 from the wallet balance
      await ProfileService.instance.addWalletTransaction(
        -19.90,
        'payment',
        'Paid for Pro Subscription via Wallet',
        status: 'completed',
      );

      // 2. Initialize the Pro Subscription
      await ProfileService.instance.initializeProSubscription();

      try {
        await NotificationService.instance.showMoneyFlowNotification(
          title: 'Pro Subscription Upgraded',
          body: 'Pro Subscription is active! RM 19.90 debited.',
        );
      } catch (e) {
        debugPrint('Error sending sub notification: $e');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Pro! Subscription active. ✨'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process wallet payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  TableRow _buildComparisonRow(String feature, String basicVal, String proVal, bool isDark) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            feature,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          basicVal,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          proVal,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF00B894) : const Color(0xFF1B8A5A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPro = ProfileService.instance.isPro;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00B894).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF00B894), size: 32),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'DriveCare+ Pro',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'RM 19.90 / month',
              style: TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Compare Plans',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.8),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Feature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  ),
                  const Text('Basic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  Text(
                    'Pro',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? const Color(0xFF00B894) : const Color(0xFF1B8A5A),
                    ),
                  ),
                ],
              ),
              _buildComparisonRow('Max Registered Vehicles', '2 Cars', 'Unlimited', isDark),
              _buildComparisonRow('Document Vault Storage', '5 MB', '50 MB', isDark),
              _buildComparisonRow('Journey Log Retention', '30 Days', 'Lifetime', isDark),
              _buildComparisonRow('Premium Accent Styles', 'Green Only', 'All Accent Styles', isDark),
            ],
          ),
          const SizedBox(height: 32),
          if (isPro) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00B894).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00B894).withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF00B894)),
                  SizedBox(width: 8),
                  Text(
                    'Your Pro Plan is active!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00B894)),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListenableBuilder(
              listenable: ProfileService.instance,
              builder: (context, _) {
                final double currentBalance = ProfileService.instance.walletBalance;
                return Column(
                  children: [
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
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Pay via ToyyibPay FPX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00B894),
                          side: const BorderSide(color: Color(0xFF00B894), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () => _payWithWallet(context, currentBalance),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_balance_wallet, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Pay with Wallet (Balance: RM ${currentBalance.toStringAsFixed(2)})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),),
    );
  }
}
