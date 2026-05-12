import 'package:flutter/material.dart';

import '../services/vehicle_insights.dart';
import '../widgets/dashboard_card.dart';
import 'booking_screen.dart';
import 'document_vault_screen.dart';
import 'maintenance_screen.dart';
import 'notifications_screen.dart';
import 'refuel_log_screen.dart';
import 'trip_tracking_screen.dart';
import 'vehicle_screen.dart';
import 'workshop_map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Simple helper to navigate and rebuild when returning
  Future<void> _navigateTo(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    if (mounted) {
      setState(() {}); // Rebuild to refresh dashboard statistics
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DriveCare+'),
        actions: [
          IconButton(
            onPressed: () => _navigateTo(NotificationsScreen.routeName),
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Vehicle Dashboard',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text('Track mileage, service status, trips, and bookings.'),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                DashboardCard(
                  icon: Icons.directions_car_outlined,
                  title: 'Vehicle',
                  value: VehicleInsights.model,
                  subtitle: '${VehicleInsights.currentMileageKm.toStringAsFixed(0)} km',
                  onTap: () => _navigateTo(VehicleScreen.routeName),
                ),
                DashboardCard(
                  icon: Icons.build_outlined,
                  title: 'Next Service',
                  value:
                      '${VehicleInsights.kmUntilService.toStringAsFixed(0)} km',
                  subtitle:
                      'About ${VehicleInsights.predictedServiceDueDays} days left',
                  onTap: () => _navigateTo(MaintenanceScreen.routeName),
                ),
                DashboardCard(
                  icon: Icons.route_outlined,
                  title: 'Recent Trip',
                  value:
                      '${VehicleInsights.recentTripDistanceKm.toStringAsFixed(1)} km',
                  subtitle:
                      'RM ${VehicleInsights.recentTripCostPerKm.toStringAsFixed(2)} / km',
                  onTap: () => _navigateTo(TripTrackingScreen.routeName),
                ),
                DashboardCard(
                  icon: Icons.storefront_outlined,
                  title: 'Workshop',
                  value: 'Book Now',
                  subtitle: '3 nearby workshops',
                  onTap: () => _navigateTo(BookingScreen.routeName),
                ),
                DashboardCard(
                  icon: Icons.local_gas_station_outlined,
                  title: 'Refuel Log',
                  value: 'Calculate',
                  subtitle: 'km/L and L/100km',
                  onTap: () => _navigateTo(RefuelLogScreen.routeName),
                ),
                DashboardCard(
                  icon: Icons.map_outlined,
                  title: 'Map View',
                  value: 'Nearby',
                  subtitle: 'Workshop markers',
                  onTap: () => _navigateTo(WorkshopMapScreen.routeName),
                ),
                DashboardCard(
                  icon: Icons.folder_copy_outlined,
                  title: 'Vault',
                  value: 'Documents',
                  subtitle: 'Receipts and insurance',
                  onTap: () => _navigateTo(DocumentVaultScreen.routeName),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

