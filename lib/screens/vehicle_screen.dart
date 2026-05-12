import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/vehicle_insights.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  static const routeName = '/vehicle';

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Profile')),
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
                    'Primary Vehicle',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.directions_car_outlined),
                    title: const Text('Model'),
                    subtitle: Text(VehicleInsights.model),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pin_outlined),
                    title: const Text('Plate number'),
                    subtitle: Text(VehicleInsights.plate),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.speed_outlined),
                    title: const Text('Current mileage'),
                    subtitle: Text('${VehicleInsights.currentMileageKm.toStringAsFixed(0)} km'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_gas_station_outlined),
                    title: const Text('Fuel type'),
                    subtitle: Text(VehicleInsights.fuelType),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showEditVehicleDialog,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Vehicle Details'),
          ),
        ],
      ),
    );
  }

  void _showEditVehicleDialog() {
    final modelController = TextEditingController(text: VehicleInsights.model);
    final plateController = TextEditingController(text: VehicleInsights.plate);
    final mileageController = TextEditingController(
      text: VehicleInsights.currentMileageKm.toStringAsFixed(0),
    );
    final fuelTypeController = TextEditingController(text: VehicleInsights.fuelType);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Vehicle Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(labelText: 'Vehicle Model'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(labelText: 'License Plate'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mileageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mileage (km)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fuelTypeController,
                  decoration: const InputDecoration(labelText: 'Fuel Type (e.g. Petrol)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final model = modelController.text.trim();
                final plate = plateController.text.trim();
                final mileage = double.tryParse(mileageController.text) ?? 
                    VehicleInsights.currentMileageKm;
                final fuel = fuelTypeController.text.trim();

                if (model.isEmpty || plate.isEmpty || fuel.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All fields are required.')),
                  );
                  return;
                }

                // Update Local In-Memory State
                setState(() {
                  VehicleInsights.model = model;
                  VehicleInsights.plate = plate;
                  VehicleInsights.currentMileageKm = mileage;
                  VehicleInsights.fuelType = fuel;
                });

                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                // Persist to Cloud Firestore under users/{userId}/vehicle
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('vehicle')
                        .doc('primary')
                        .set({
                      'model': model,
                      'plate': plate,
                      'currentMileageKm': mileage,
                      'fuelType': fuel,
                      'lastUpdated': FieldValue.serverTimestamp(),
                    });
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Vehicle profile saved to Firebase!')),
                    );
                  } catch (e) {
                    debugPrint('Firestore vehicle save fallback: $e');
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Saved locally (Offline mode).')),
                    );
                  }
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Saved locally (Offline/Guest mode).')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

