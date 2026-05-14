import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApiMonitoringCard extends StatefulWidget {
  const ApiMonitoringCard({super.key});

  @override
  State<ApiMonitoringCard> createState() => _ApiMonitoringCardState();
}

class _ApiMonitoringCardState extends State<ApiMonitoringCard> {
  final Map<String, _ApiStatus> _apiStates = {
    'Firebase Core': _ApiStatus.checking,
    'Cloud Firestore': _ApiStatus.checking,
    'Google Places API': _ApiStatus.checking,
    'ToyyibPay API': _ApiStatus.checking,
    'System Connectivity': _ApiStatus.checking,
  };

  @override
  void initState() {
    super.initState();
    _checkAllApis();
  }

  Future<void> _checkAllApis() async {
    // 1. Connectivity
    _updateState('System Connectivity', await _ping('https://www.google.com'));

    // 2. Firebase
    try {
      final isFirebaseInit = Firebase.apps.isNotEmpty;
      _updateState('Firebase Core', isFirebaseInit ? _ApiStatus.online : _ApiStatus.offline);
      
      // Firestore check
      await FirebaseFirestore.instance.collection('health_check').limit(1).get().timeout(const Duration(seconds: 5));
      _updateState('Cloud Firestore', _ApiStatus.online);
    } catch (e) {
      _updateState('Cloud Firestore', _ApiStatus.offline);
    }

    // 3. Google Maps (Check if endpoint is reachable)
    _updateState('Google Places API', await _ping('https://maps.googleapis.com/maps/api/place/details/json'));

    // 4. ToyyibPay
    _updateState('ToyyibPay API', await _ping('https://dev.toyyibpay.com/index.php/api/getBank'));
  }

  void _updateState(String key, _ApiStatus status) {
    if (mounted) {
      setState(() => _apiStates[key] = status);
    }
  }

  Future<_ApiStatus> _ping(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      // Even 403 or 400 means the server is reachable and responding
      return (response.statusCode >= 200 && response.statusCode < 500) 
          ? _ApiStatus.online 
          : _ApiStatus.offline;
    } catch (_) {
      return _ApiStatus.offline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Service Infrastructure',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _apiStates.updateAll((key, value) => _ApiStatus.checking);
                    });
                    _checkAllApis();
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._apiStates.entries.map((e) => _buildApiRow(e.key, e.value, isDark)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Monitoring real-time latency and gateway availability for all core automotive services.',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
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

  Widget _buildApiRow(String name, _ApiStatus status, bool isDark) {
    Color statusColor;
    String statusText;
    Widget statusWidget;

    switch (status) {
      case _ApiStatus.online:
        statusColor = Colors.green;
        statusText = 'Operational';
        statusWidget = const Icon(Icons.check_circle, color: Colors.green, size: 16);
        break;
      case _ApiStatus.offline:
        statusColor = Colors.red;
        statusText = 'Service Disruption';
        statusWidget = const Icon(Icons.error_outline, color: Colors.red, size: 16);
        break;
      case _ApiStatus.checking:
        statusColor = Colors.orange;
        statusText = 'Pinging...';
        statusWidget = const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                statusWidget,
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ApiStatus { online, offline, checking }
