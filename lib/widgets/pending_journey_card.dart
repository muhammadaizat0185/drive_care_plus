import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'glass_container.dart';

class PendingJourneyCard extends StatelessWidget {
  final Map<String, dynamic> journey;
  final VoidCallback onConfirmMyCar;
  final VoidCallback onConfirmOther;

  const PendingJourneyCard({
    super.key,
    required this.journey,
    required this.onConfirmMyCar,
    required this.onConfirmOther,
  });

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Active';
    final dateTime = DateTime.parse(isoString);
    return DateFormat('dd MMM yyyy, h:mm a').format(dateTime);
  }

  String _calculateDuration(String start, String end) {
    final startTime = DateTime.parse(start);
    final endTime = DateTime.parse(end);
    final diff = endTime.difference(startTime);

    if (diff.inSeconds < 60) {
      return '\${diff.inSeconds} secs';
    } else if (diff.inMinutes < 60) {
      return '\${diff.inMinutes} mins';
    } else {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      return '\${hours}h \${mins}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final distance = journey['distance_km'] as double?;
    final isActive = journey['end_time'] == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(isDark ? 0.2 : 0.1),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: GlassContainer(
          borderRadius: 24,
          blurSigma: 16,
          opacity: isDark ? 0.08 : 0.45,
          borderColor: Colors.amber.withOpacity(0.5),
          borderWidth: 1.5,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.help_outline, size: 14, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Pending (Active)' : 'Pending Confirmation',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDateTime(journey['start_time']),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DISTANCE',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          distance != null ? '\${distance.toStringAsFixed(2)} km' : '--',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ],
                    ),
                    if (!isActive && journey['end_time'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'DURATION',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _calculateDuration(journey['start_time'], journey['end_time']),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ],
                      ),
                  ],
                ),
                const Divider(height: 32),
                
                const Text(
                  'Confirm Vehicle?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Was this trip taken in your car? Confirm to update maintenance data.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onConfirmMyCar,
                        icon: const Icon(Icons.directions_car, size: 16),
                        label: const Text('My Car'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onConfirmOther,
                        icon: const Icon(Icons.directions_bus, size: 16),
                        label: const Text('Other'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
