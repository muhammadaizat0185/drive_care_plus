// ignore_for_file: deprecated_member_use
//
// Modular cockpit widgets for the redesigned Home screen
// (`lib/screens/home_screen.dart`).
//
// This module hosts the building blocks of the Home cockpit body:
//   * [GreetingHeader]            — Greeting text + welcome subtitle + avatar.
//   * [VehicleHealthHero]         — `AppHealthGauge` wrapping `clampPercentage`
//                                   over the watchlist health metrics.
//   * [WalletVaultRow]            — 2/3 wallet card + 1/3 vault tile row.
//   * [UpcomingAppointmentCard]   — Populated/empty appointment branches.
//   * [QuickActionsRow]           — Existing quick-action tiles (Trip
//                                   Planner, Journey Log) using existing
//                                   handlers.
//
// Design references:
//   * figma-ui-redesign Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.11, 4.12.
//   * `design.md` → `home_screen.dart` blueprint.
//
// Notes:
//   * The widgets are defined as public types so they can be imported by
//     `home_screen.dart` directly (Dart privacy is per-library; the task
//     description allows public names: "(or `_GreetingHeader` — public OK
//     if cleaner)").
//   * Task 6.2 (replace bottom nav with `AppFloatingBottomNav`) and task
//     6.3 (`InFlightGate` for wallet Top Up) are intentionally **NOT**
//     handled here. Tap handlers preserve the existing `showModalBottomSheet`
//     / `HomeScreen.activeTabNotifier` wiring so the visual refactor
//     doesn't change behavior.
//   * Theme/visual literals largely match the legacy cockpit styling so
//     this refactor does not introduce visual regressions while the wider
//     redesign is still in progress.

import 'package:flutter/material.dart';

import '../../core/util/clamp_percentage.dart';
import '../../core/util/greeting.dart';
import '../../core/util/in_flight_gate.dart';
import '../../services/profile_service.dart';
import '../../services/vehicle_insights.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/wallet_top_up_sheet.dart';
import '../document_vault_screen.dart';
import '../home_screen.dart';
import '../settings_screen.dart';

/// Time-based greeting + welcome subtitle + avatar header for the cockpit.
///
/// Greeting text is produced by `getGreeting(DateTime.now().hour, firstName)`
/// where `firstName` is the leading whitespace-delimited token of
/// `ProfileService.instance.displayName` (or empty / null → "there"
/// fallback handled by the helper).
///
/// Tapping the avatar pushes `SettingsScreen.routeName`, preserving the
/// existing handler.
///
/// Validates: Requirements 4.1, 4.2.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  /// Extract the first whitespace-delimited token from a display name.
  ///
  /// `null` / empty / whitespace-only → `null` (so `getGreeting` falls
  /// back to its `"there"` branch per Requirement 4.2).
  static String? _firstNameOf(String? displayName) {
    if (displayName == null) return null;
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) return null;
    final List<String> parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;
    return parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color charcoal =
        isDark ? Colors.white : const Color(0xFF1F2937);

    return ListenableBuilder(
      listenable: ProfileService.instance,
      builder: (BuildContext context, Widget? _) {
        final ProfileService profile = ProfileService.instance;
        final String? firstName = _firstNameOf(profile.displayName);
        final String greeting = getGreeting(DateTime.now().hour, firstName);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: charcoal,
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
            ),
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, SettingsScreen.routeName),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withAlpha(50),
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
        );
      },
    );
  }
}

/// Cockpit vehicle-health hero card.
///
/// Wraps [AppHealthGauge] with the percentage produced by
/// `clampPercentage(...)` over the average `healthPercentage` of the
/// watchlist items pulled from `VehicleInsights.instance` (Engine Oil,
/// Brake Pads, Tyres, Battery). When the metric is unavailable (no
/// watchlist items, NaN, etc.), the gauge renders the `--%` placeholder
/// branch (Requirement 4.4).
///
/// Validates: Requirements 4.3, 4.4.
class VehicleHealthHero extends StatelessWidget {
  const VehicleHealthHero({super.key});

  /// Compute the representative health percentage for the gauge:
  /// the arithmetic mean of every watchlist item's `healthPercentage`.
  /// Returns `null` when no items are available.
  static double? _averageHealthPercentage(List<MaintenanceItem> items) {
    if (items.isEmpty) return null;
    double sum = 0.0;
    for (final MaintenanceItem item in items) {
      sum += item.healthPercentage;
    }
    return sum / items.length;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: VehicleInsights.instance,
      builder: (BuildContext context, Widget? _) {
        final VehicleInsights insights = VehicleInsights.instance;
        final List<MaintenanceItem> watchlist = insights.watchlistItems;
        final double? rawAverage = _averageHealthPercentage(watchlist);

        // Funnel through the shared `clampPercentage` helper. Returns
        // an `int?` in `[0, 100]`, or `null` when raw input is null /
        // non-finite. AppHealthGauge expects a `double?`.
        final int? clamped = clampPercentage(rawAverage);
        final double? gaugeValue = clamped?.toDouble();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Car Health',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                insights.model.toUpperCase(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: AppHealthGauge(
                  percentage: gaugeValue,
                  label: 'STATUS',
                  size: 120,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Wallet (2/3 width) + Vault (1/3 width) horizontal row.
///
/// Layout uses `Row(children: [Expanded(flex: 2, ...), SizedBox(...),
/// Expanded(flex: 1, ...)])` so the wallet card spans roughly two-thirds
/// of the row's content width and the vault tile occupies the remaining
/// third (Requirement 4.5).
///
/// The wallet `Top Up` action is routed through a per-screen
/// [InFlightGate] (`_topUpGate`) so that even with rapid double / triple
/// taps, exactly one [WalletTopUpSheet] is presented per user-initiated
/// gesture. While the sheet's `showModalBottomSheet` future is in flight,
/// the gate drops further `Top Up` invocations (Requirements 4.7, 4.8).
///
/// Tapping the vault tile sets `HomeScreen.activeTabNotifier.value = 4`
/// so the Vault tab is selected — preserving the existing handler.
///
/// Validates: Requirements 4.5, 4.7, 4.8, 4.12 (vault navigation).
class WalletVaultRow extends StatefulWidget {
  const WalletVaultRow({super.key});

  @override
  State<WalletVaultRow> createState() => _WalletVaultRowState();
}

class _WalletVaultRowState extends State<WalletVaultRow> {
  /// Per-screen in-flight gate that ensures one [WalletTopUpSheet] is
  /// presented per gesture, even with rapid taps (Requirement 4.8).
  final InFlightGate _topUpGate = InFlightGate();

  @override
  void dispose() {
    _topUpGate.dispose();
    super.dispose();
  }

  /// Routes the wallet `Top Up` tap through [_topUpGate.run] so that
  /// concurrent invocations during in-flight presentation are dropped
  /// (Requirements 4.7, 4.8).
  Future<void> _handleTopUp(BuildContext context) async {
    await _topUpGate.run(() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) => const WalletTopUpSheet(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return ListenableBuilder(
      listenable: ProfileService.instance,
      builder: (BuildContext context, Widget? _) {
        final ProfileService profile = ProfileService.instance;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Wallet card spans 2/3 of the row.
              Expanded(
                flex: 2,
                child: _WalletCard(
                  balance: profile.walletBalance,
                  primaryColor: primaryColor,
                  onTopUp: () => _handleTopUp(context),
                ),
              ),
              const SizedBox(width: 12),
              // Vault tile occupies 1/3 of the row.
              Expanded(
                flex: 1,
                child: _VaultTile(
                  primaryColor: primaryColor,
                  onTap: () => Navigator.pushNamed(context, DocumentVaultScreen.routeName),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Internal wallet card for [WalletVaultRow].
class _WalletCard extends StatelessWidget {
  final double balance;
  final Color primaryColor;
  final VoidCallback onTopUp;

  const _WalletCard({
    required this.balance,
    required this.primaryColor,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            primaryColor,
            primaryColor.withBlue(200).withGreen(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              Text(
                'DriveCare+ Wallet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.help_outline, color: Colors.white70, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  'RM ${balance.toStringAsFixed(2)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onTopUp,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.add, color: primaryColor, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Top Up',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Internal vault tile for [WalletVaultRow].
class _VaultTile extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const _VaultTile({
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              primaryColor,
              primaryColor.withBlue(200).withGreen(200),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.folder_copy,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vault',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Upcoming-appointment card with populated/empty branches.
///
/// Populated branch: when `VehicleInsights.instance.activeBookings` is
/// non-empty, renders the next booking (workshop name + service + date +
/// time) inside a tappable tile that switches to the Workshops tab.
/// Empty branch: renders an `AppEmptyState` with `Icons.event_busy` and
/// the message "No upcoming appointments".
///
/// Validates: Requirement 4.11.
class UpcomingAppointmentCard extends StatelessWidget {
  const UpcomingAppointmentCard({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return ListenableBuilder(
      listenable: VehicleInsights.instance,
      builder: (BuildContext context, Widget? _) {
        final VehicleInsights insights = VehicleInsights.instance;
        final List<Map<String, dynamic>> bookings = insights.activeBookings;

        if (bookings.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: const AppEmptyState(
              icon: Icons.event_busy,
              title: 'No upcoming appointments',
              message: 'Booked services will appear here.',
            ),
          );
        }

        final Map<String, dynamic> next = bookings.first;
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.calendar_today, color: primaryColor),
            ),
            title: Text(
              'Upcoming Appointment',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isDark
                    ? Colors.white
                    : const Color(0xFF1F2937),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${next['workshopName']}\n'
                '${next['serviceName']} • ${next['date']} at ${next['time']}',
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
        );
      },
    );
  }
}

/// Quick-actions tile column for the Home cockpit.
///
/// Renders the existing Trip Planner and Journey Log tiles using the
/// [onTripPlanner] / [onJourneyLog] callbacks supplied by the cockpit
/// body, so the existing navigation handlers (which invoke
/// `Navigator.push(...)` with the correct route) are preserved verbatim.
///
/// Despite the "Row" name carried over from the design.md blueprint,
/// the content is currently a vertical column of tiles to match the
/// existing cockpit layout. Future iterations may transition to a
/// horizontal grid; preserving the legacy structure here keeps the
/// refactor visually backward-compatible.
///
/// Validates: Requirement 4.12 (quick-action navigation handlers).
class QuickActionsRow extends StatelessWidget {
  /// Tap handler for the Trip Planner tile. Wired by the cockpit body
  /// to the existing `Navigator.push → TripPlannerScreen` flow.
  final VoidCallback onTripPlanner;

  /// Tap handler for the Journey Log tile. Wired by the cockpit body to
  /// the existing `Navigator.push → JourneyLogScreen` flow.
  final VoidCallback onJourneyLog;

  const QuickActionsRow({
    super.key,
    required this.onTripPlanner,
    required this.onJourneyLog,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _QuickActionTile(
          icon: Icons.map,
          title: 'Trip Planner',
          subtitle: 'Plan your routes and visualize dynamic directions.',
          onTap: onTripPlanner,
        ),
        const SizedBox(height: 16),
        _QuickActionTile(
          icon: Icons.explore,
          title: 'Journey Logs',
          subtitle: 'View history of recorded trips and statistics offline.',
          onTap: onJourneyLog,
        ),
      ],
    );
  }
}

/// Internal quick-action tile used by [QuickActionsRow].
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: primaryColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
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
        onTap: onTap,
      ),
    );
  }
}
