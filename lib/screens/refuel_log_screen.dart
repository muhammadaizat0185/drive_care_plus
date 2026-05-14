import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/vehicle_insights.dart';
import '../widgets/eco_insights_card.dart';
import '../widgets/fuel_chart.dart';

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

  String _selectedFuelType = 'Budi MADANI (Budi95)';

  final Map<String, double> _fuelPresets = {
    'Budi MADANI (Budi95)': 1.99,
    'RON95': 4.02,
    'RON97': 4.90,
    'Diesel': 5.17,
    'Custom': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _priceController.text = _fuelPresets['Budi MADANI (Budi95)']!.toStringAsFixed(2);
  }

  final List<Map<String, dynamic>> _history = [
    {
      'date': '10/05/2026',
      'distanceKm': 420.0,
      'liters': 28.0,
      'pricePerLiter': 2.05,
      'fuelType': 'RON95',
      'efficiency': 15.0,
      'cost': 57.40,
    },
    {
      'date': '01/05/2026',
      'distanceKm': 395.0,
      'liters': 27.5,
      'pricePerLiter': 2.05,
      'fuelType': 'RON95',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Refuel Log', style: TextStyle(fontWeight: FontWeight.bold))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
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
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                        letterSpacing: -0.5,
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
                    DropdownButtonFormField<String>(
                      value: _selectedFuelType,
                      decoration: const InputDecoration(
                        labelText: 'Fuel Type Preset',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _fuelPresets.keys.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedFuelType = val;
                            if (val != 'Custom') {
                              _priceController.text = _fuelPresets[val]!.toStringAsFixed(2);
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        // If user edits manually, set to custom
                        if (_selectedFuelType != 'Custom') {
                          setState(() => _selectedFuelType = 'Custom');
                        }
                      },
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
              icon: Icons.payments_outlined,
              title: 'Cost Analysis',
              value: 'RM ${totalCost.toStringAsFixed(2)} total • RM ${costPerKm.toStringAsFixed(2)}/km',
            ),
            const SizedBox(height: 16),
            EcoInsightsCard(kmPerLiter: kmPerLiter),
            const SizedBox(height: 16),
            FuelChart(
              dataPoints: _history
                  .map((h) => (h['efficiency'] as num).toDouble())
                  .toList()
                  .reversed
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Refuel History Log',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: 12),
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
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: entry['fuelType'] == 'Budi MADANI (Budi95)' 
                              ? Colors.blue.shade100 
                              : Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.local_gas_station,
                            color: entry['fuelType'] == 'Budi MADANI (Budi95)' 
                                ? Colors.blue.shade700 
                                : Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'RM ${(entry['cost'] as double).toStringAsFixed(2)}  •  ${(entry['liters'] as double).toStringAsFixed(1)} L',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                                          letterSpacing: -0.2,
                                        ),
                                  ),
                                  if (entry['fuelType'] == 'Budi MADANI (Budi95)') ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Text(
                                        'Budi95',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.flash_on, size: 12, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(entry['efficiency'] as double).toStringAsFixed(1)} km/L',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.calendar_today, size: 11, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry['date'],
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(entry['distanceKm'] as double).toStringAsFixed(0)} km',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'INTERVAL',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
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

      _history.insert(0, {
        'date': dateStr,
        'distanceKm': dist,
        'liters': ltr,
        'pricePerLiter': price,
        'fuelType': _selectedFuelType,
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
      _saveRefuelLogCloud(user.uid, dateStr, dist, ltr, price, _selectedFuelType, eff, cost);
    }
  }

  Future<void> _saveRefuelLogCloud(
    String uid,
    String dateStr,
    double dist,
    double ltr,
    double price,
    String fuelType,
    double eff,
    double cost,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('refuel_logs')
          .add({
        'distanceKm': dist,
        'liters': ltr,
        'pricePerLiter': price,
        'fuelType': fuelType,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

