import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/vehicle_insights.dart';

class RefuelLogScreen extends StatefulWidget {
  const RefuelLogScreen({super.key});

  static const routeName = '/refuel-log';

  @override
  State<RefuelLogScreen> createState() => _RefuelLogScreenState();
}

class _RefuelLogScreenState extends State<RefuelLogScreen> {
  final _distanceController = TextEditingController(text: '420');
  final _litersController = TextEditingController(text: '28');
  final _priceController = TextEditingController(text: '2.05');

  double _distanceKm = 420;
  double _liters = 28;
  double _pricePerLiter = 2.05;

  final List<Map<String, dynamic>> _history = [
    {
      'date': '10/05/2026',
      'distanceKm': 420.0,
      'liters': 28.0,
      'pricePerLiter': 2.05,
      'efficiency': 15.0,
      'cost': 57.40,
    },
    {
      'date': '01/05/2026',
      'distanceKm': 395.0,
      'liters': 27.5,
      'pricePerLiter': 2.05,
      'efficiency': 14.36,
      'cost': 56.38,
    }
  ];

  @override
  void dispose() {
    _distanceController.dispose();
    _litersController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kmPerLiter = VehicleInsights.kmPerLiter(
      distanceKm: _distanceKm,
      liters: _liters,
    );
    final litersPer100Km = VehicleInsights.litersPer100Km(
      distanceKm: _distanceKm,
      liters: _liters,
    );
    final totalCost = VehicleInsights.refuelCost(
      liters: _liters,
      pricePerLiter: _pricePerLiter,
    );
    final costPerKm = _distanceKm <= 0 ? 0 : totalCost / _distanceKm;

    return Scaffold(
      appBar: AppBar(title: const Text('Refuel Log')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fuel Efficiency Calculator',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _distanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Distance since last refuel (km)',
                      prefixIcon: Icon(Icons.route_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _litersController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fuel added (liters)',
                      prefixIcon: Icon(Icons.local_gas_station_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fuel price (RM/liter)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Calculate Efficiency'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ResultTile(
            icon: Icons.speed_outlined,
            title: 'Efficiency',
            value: '${kmPerLiter.toStringAsFixed(1)} km/L',
          ),
          _ResultTile(
            icon: Icons.analytics_outlined,
            title: 'Consumption',
            value: '${litersPer100Km.toStringAsFixed(1)} L/100km',
          ),
          _ResultTile(
            icon: Icons.attach_money,
            title: 'Cost',
            value:
                'RM ${totalCost.toStringAsFixed(2)} total • RM ${costPerKm.toStringAsFixed(2)}/km',
          ),
          const SizedBox(height: 24),
          Text(
            'Refuel History Log',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No previous refuel logs found.'),
              ),
            )
          else
            for (final entry in _history)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.local_gas_station),
                  ),
                  title: Text(
                    'RM ${(entry['cost'] as double).toStringAsFixed(2)} • ${(entry['liters'] as double).toStringAsFixed(1)} L',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Efficiency: ${(entry['efficiency'] as double).toStringAsFixed(1)} km/L\nDate: ${entry['date']}',
                  ),
                  trailing: Text(
                    '${(entry['distanceKm'] as double).toStringAsFixed(0)} km',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  isThreeLine: true,
                ),
              ),
        ],
      ),
    );
  }

  void _calculate() {
    final dist = double.tryParse(_distanceController.text) ?? 0;
    final ltr = double.tryParse(_litersController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;

    if (dist <= 0 || ltr <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numeric parameters.')),
      );
      return;
    }

    final eff = VehicleInsights.kmPerLiter(distanceKm: dist, liters: ltr);
    final cost = VehicleInsights.refuelCost(liters: ltr, pricePerLiter: price);
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    setState(() {
      _distanceKm = dist;
      _liters = ltr;
      _pricePerLiter = price;

      // Add to local list history
      _history.insert(0, {
        'date': dateStr,
        'distanceKm': dist,
        'liters': ltr,
        'pricePerLiter': price,
        'efficiency': eff,
        'cost': cost,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fuel efficiency calculated and saved!')),
    );

    // Save to Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _saveRefuelLogCloud(user.uid, dateStr, dist, ltr, price, eff, cost);
    }
  }

  Future<void> _saveRefuelLogCloud(
    String uid,
    String dateStr,
    double dist,
    double ltr,
    double price,
    double eff,
    double cost,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('refuel_logs')
          .add({
        'date': dateStr,
        'distanceKm': dist,
        'liters': ltr,
        'pricePerLiter': price,
        'efficiency': eff,
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore refuel log save error: $e');
    }
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}

