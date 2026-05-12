import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'glass_container.dart';
import '../services/vehicle_insights.dart';

class CloudSyncQuotaCard extends StatelessWidget {
  const CloudSyncQuotaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final insights = VehicleInsights.instance;
    final isConnected = user != null;

    // Calculate active synced entities as writes
    final vehicleWriteCount = 1; // 1 profile document
    final bookingWriteCount = insights.bookings.length;
    final documentWriteCount = insights.documents.length;
    final totalWritesUsed = vehicleWriteCount + bookingWriteCount + documentWriteCount;

    // Firebase Spark Plan Free Tier Limits
    const double maxWrites = 20000.0;
    const double maxReads = 50000.0;

    // Local simulated stats
    final double writesProgress = totalWritesUsed / maxWrites;
    final double readsProgress = 8 / maxReads; // Simulated session reads

    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isConnected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      color: isConnected ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cloud Sync & Quota',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isConnected ? Colors.green : Colors.grey).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnected ? 'Connected' : 'Offline Mode',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isConnected) ...[
              Text(
                'Firebase Spark Plan (Free Tier)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Synced to: ${user.email ?? "Anonymous User"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ] else ...[
              const Text(
                'Guest Session (No Cloud Connection)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your modifications are safely cached in SharedPreferences locally. Register/Sign in to sync with Google Firestore.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            
            // Write Quota
            _QuotaProgressBar(
              title: 'Daily Write Operations (Writes)',
              used: totalWritesUsed.toDouble(),
              total: maxWrites,
              progress: writesProgress,
              color: Colors.green,
            ),
            const SizedBox(height: 12),

            // Read Quota
            _QuotaProgressBar(
              title: 'Daily Read Operations (Reads)',
              used: isConnected ? 12.0 : 0.0,
              total: maxReads,
              progress: isConnected ? readsProgress : 0.0,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),

            // Storage Quota
            _QuotaProgressBar(
              title: 'Database Cloud Storage (1GB Limit)',
              used: isConnected ? 0.04 * totalWritesUsed : 0.0, // approx size in KB
              total: 1024 * 1024, // 1 GB in KB
              progress: isConnected ? (0.04 * totalWritesUsed) / (1024 * 1024) : 0.0,
              color: Colors.purple,
              unit: 'KB',
            ),
            const SizedBox(height: 8),
            const Text(
              '*Your active car details and logs consume very little data. Firebase Free Tier will last indefinitely for your usage!',
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      );
  }
}

class _QuotaProgressBar extends StatelessWidget {
  const _QuotaProgressBar({
    required this.title,
    required this.used,
    required this.total,
    required this.progress,
    required this.color,
    this.unit = '',
  });

  final String title;
  final double used;
  final double total;
  final double progress;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final displayUnit = unit.isNotEmpty ? ' $unit' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text(
              '${used.toStringAsFixed(used > 100 ? 0 : 2)}$displayUnit / ${total.toStringAsFixed(0)}$displayUnit',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0001, 1.0),
            backgroundColor: Colors.grey.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
