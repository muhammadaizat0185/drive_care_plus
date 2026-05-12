import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../services/vehicle_insights.dart';
import '../widgets/car_health_diagram.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  static const routeName = '/maintenance';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: ListenableBuilder(
        listenable: VehicleInsights.instance,
        builder: (context, child) {
          final insights = VehicleInsights.instance;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: Lottie.asset(
                          'assets/animations/maintenance_service.json',
                          repeat: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Maintenance check in progress',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Animated service status helps users understand vehicle condition quickly.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Oil change due in ${insights.kmUntilService.toStringAsFixed(0)} km',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(value: 0.82),
                      const SizedBox(height: 8),
                      Text(
                        'Based on ${insights.averageDailyDistanceKm.toStringAsFixed(0)} km/day, service is due in approximately ${insights.predictedServiceDueDays} days.',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _playMaintenanceAlert(context, insights.predictedServiceDueDays),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('Play Maintenance Alert'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tap Vehicle Part',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check engine, tyres, brakes, and battery status.',
                      ),
                      const SizedBox(height: 12),
                      CarHealthDiagram(
                        onPartSelected: (message) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Last service'),
                subtitle: Text('Oil filter and engine oil changed at 30,000 km'),
              ),
              const ListTile(
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('Upcoming inspection'),
                subtitle: Text('Tyre rotation and brake check recommended'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _playMaintenanceAlert(BuildContext context, int daysDue) async {
    await SystemSound.play(SystemSoundType.alert);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Audio alert: Oil change due in $daysDue days.',
        ),
      ),
    );
  }
}
