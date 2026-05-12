import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/vehicle_insights.dart';
import 'refuel_log_screen.dart';
import 'workshop_map_screen.dart';

class TripTrackingScreen extends StatefulWidget {
  const TripTrackingScreen({super.key});

  static const routeName = '/trip-tracking';

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  Timer? _tripTimer;
  bool _isTracking = false;
  int _secondsElapsed = 0;
  double _distanceKm = 0.0;
  double _fuelCostRm = 0.0;

  @override
  void dispose() {
    _tripTimer?.cancel();
    super.dispose();
  }

  void _toggleTrip() {
    if (_isTracking) {
      _stopTrip();
    } else {
      _startTrip();
    }
  }

  void _startTrip() {
    setState(() {
      _isTracking = true;
      _secondsElapsed = 0;
      _distanceKm = 0.0;
      _fuelCostRm = 0.0;
    });

    // Simulating driving speed of approx 60 km/h (0.016 km/sec)
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
        _distanceKm += 0.017; // Increments by 0.017 km every second (~61 km/h)
        _fuelCostRm = _distanceKm * 0.22; // Estimate RM 0.22 fuel cost per km
      });
    });
  }

  Future<void> _stopTrip() async {
    _tripTimer?.cancel();
    setState(() => _isTracking = false);

    final finalDistance = _distanceKm;
    final finalSeconds = _secondsElapsed;
    final finalCost = _fuelCostRm;

    // Save in-memory for immediate dashboard synchronization
    VehicleInsights.recentTripDistanceKm = finalDistance;
    VehicleInsights.recentTripFuelCostRm = finalCost;
    // Also add to vehicle mileage
    VehicleInsights.currentMileageKm += finalDistance;

    // Show Trip Summary Dialog
    _showTripSummaryDialog(finalDistance, finalSeconds, finalCost);

    // Save Trip Record to Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('trips')
            .add({
          'distanceKm': finalDistance,
          'durationSeconds': finalSeconds,
          'fuelCostRm': finalCost,
          'timestamp': FieldValue.serverTimestamp(),
        });
        // Also update vehicle mileage in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicle')
            .doc('primary')
            .update({
          'currentMileageKm': VehicleInsights.currentMileageKm,
        });
      } catch (e) {
        debugPrint('Firestore trip save error: $e');
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showTripSummaryDialog(double distance, int seconds, double cost) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.stars, color: Colors.amber),
              SizedBox(width: 8),
              Text('Trip Completed!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DriveCare+ has logged your trip metrics and synced them with your dashboard.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.route_outlined),
                title: const Text('Total Distance'),
                subtitle: Text('${distance.toStringAsFixed(2)} km'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Total Duration'),
                subtitle: Text('${seconds ~/ 60} min ${seconds % 60} sec'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Estimated Fuel Cost'),
                subtitle: Text('RM ${cost.toStringAsFixed(2)}'),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Awesome'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Tracking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: _isTracking ? Colors.blue.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isTracking ? Icons.navigation_outlined : Icons.map_outlined,
                    size: 56,
                    color: _isTracking ? Colors.blue : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isTracking ? 'Active Trip in Progress...' : 'Google Maps preview will appear here',
                    style: TextStyle(
                      fontWeight: _isTracking ? FontWeight.bold : FontWeight.normal,
                      color: _isTracking ? Colors.blue : null,
                    ),
                  ),
                  if (_isTracking) ...[
                    const SizedBox(height: 12),
                    const SizedBox(
                      width: 140,
                      child: LinearProgressIndicator(),
                    ),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.route_outlined),
            title: const Text('Distance'),
            subtitle: Text(_isTracking ? '${_distanceKm.toStringAsFixed(2)} km' : '24.6 km'),
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Duration'),
            subtitle: Text(_isTracking ? _formatDuration(_secondsElapsed) : '42 minutes'),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Fuel cost estimate'),
            subtitle: Text(_isTracking ? 'RM ${_fuelCostRm.toStringAsFixed(2)}' : 'RM 5.40'),
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Predictive service estimate'),
            subtitle: Text(
              'Average ${VehicleInsights.averageDailyDistanceKm.toStringAsFixed(0)} km/day, service due in about ${VehicleInsights.predictedServiceDueDays} days.',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _toggleTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTracking ? Colors.red : null,
              foregroundColor: _isTracking ? Colors.white : null,
            ),
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            label: Text(_isTracking ? 'Stop Trip' : 'Start Trip'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, RefuelLogScreen.routeName),
            icon: const Icon(Icons.local_gas_station_outlined),
            label: const Text('Open Refuel Log'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, WorkshopMapScreen.routeName),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open Workshop Map'),
          ),
        ],
      ),
    );
  }
}

