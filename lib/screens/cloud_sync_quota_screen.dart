import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/theme/color_utils.dart';
import '../core/theme/tokens/tokens.dart';
import '../services/api_tracker_service.dart';
import '../widgets/cloud_sync_quota_card.dart';
import '../widgets/ui/ui.dart';

class CloudSyncQuotaScreen extends StatefulWidget {
  const CloudSyncQuotaScreen({super.key});

  static const String routeName = '/settings/cloud-sync-quota';

  @override
  State<CloudSyncQuotaScreen> createState() => _CloudSyncQuotaScreenState();
}

class _CloudSyncQuotaScreenState extends State<CloudSyncQuotaScreen> {
  final Map<String, _ConnectionStatus> _connectionStates = {
    'Firebase Core': _ConnectionStatus.checking,
    'Cloud Firestore': _ConnectionStatus.checking,
    'Google Places API': _ConnectionStatus.checking,
    'ToyyibPay API': _ConnectionStatus.checking,
    'System Connectivity': _ConnectionStatus.checking,
  };

  @override
  void initState() {
    super.initState();
    _checkConnectionHealth();
  }

  Future<void> _checkConnectionHealth() async {
    // 1. Connectivity
    _updateConnection('System Connectivity', await _ping('https://www.google.com'));

    // 2. Firebase Core and Firestore
    try {
      final isFirebaseInit = Firebase.apps.isNotEmpty;
      _updateConnection('Firebase Core', isFirebaseInit ? _ConnectionStatus.online : _ConnectionStatus.offline);
      
      await FirebaseFirestore.instance.collection('health_check').limit(1).get().timeout(const Duration(seconds: 5));
      _updateConnection('Cloud Firestore', _ConnectionStatus.online);
    } catch (_) {
      _updateConnection('Cloud Firestore', _ConnectionStatus.offline);
    }

    // 3. Google Places API (Check reachability)
    _updateConnection('Google Places API', await _ping('https://maps.googleapis.com/maps/api/place/details/json'));

    // 4. ToyyibPay
    _updateConnection('ToyyibPay API', await _ping('https://dev.toyyibpay.com/index.php/api/getBank'));
  }

  void _updateConnection(String key, _ConnectionStatus status) {
    if (mounted) {
      setState(() => _connectionStates[key] = status);
    }
  }

  Future<_ConnectionStatus> _ping(String url) async {
    try {
      ApiTracker.instance.trackCall('System Connectivity');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      return (response.statusCode >= 200 && response.statusCode < 500)
          ? _ConnectionStatus.online
          : _ConnectionStatus.offline;
    } catch (_) {
      return _ConnectionStatus.offline;
    }
  }

  void _refreshAll() {
    setState(() {
      _connectionStates.updateAll((key, value) => _ConnectionStatus.checking);
    });
    _checkConnectionHealth();
  }

  IconData _getIconForApi(String apiName) {
    switch (apiName) {
      case 'Firebase Core':
        return Icons.local_fire_department_outlined;
      case 'Cloud Firestore':
        return Icons.storage_outlined;
      case 'Google Places API':
        return Icons.map_outlined;
      case 'ToyyibPay API':
        return Icons.payment_outlined;
      case 'System Connectivity':
        return Icons.wifi_outlined;
      default:
        return Icons.api_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Sync & API Telemetry',
            style: typography.title.copyWith(color: colors.foreground, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh connection checks',
              onPressed: _refreshAll,
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: ApiTracker.instance,
          builder: (context, _) {
            final transactionCounts = ApiTracker.instance.transactionCounts;

            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.lg,
                vertical: spacing.lg,
              ),
              children: [
                // 1. Existing database quota widget
                const AppSectionHeader(label: 'CLOUD STORAGE QUOTAS'),
                const CloudSyncQuotaCard(),
                SizedBox(height: spacing.xl),

                // 2. Real-time API transaction / connection logs
                const AppSectionHeader(label: 'SESSION API TELEMETRY'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._connectionStates.entries.map((entry) {
                        final String apiName = entry.key;
                        final _ConnectionStatus status = entry.value;
                        final int txCount = transactionCounts[apiName] ?? 0;

                        return _ApiStatusRow(
                          name: apiName,
                          icon: _getIconForApi(apiName),
                          status: status,
                          txCount: txCount,
                        );
                      }),
                      Divider(height: spacing.xl, color: colors.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Request counts reflect the current app session since startup.',
                              style: typography.body.copyWith(
                                color: colors.foreground.withValues(alpha: colors.surfaceProminent),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => ApiTracker.instance.reset(),
                            icon: const Icon(Icons.cleaning_services, size: 16),
                            label: const Text('Reset Counts'),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.emerald500,
                              textStyle: typography.label.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApiStatusRow extends StatelessWidget {
  const _ApiStatusRow({
    required this.name,
    required this.icon,
    required this.status,
    required this.txCount,
  });

  final String name;
  final IconData icon;
  final _ConnectionStatus status;
  final int txCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    Color statusColor;
    String statusText;
    Widget statusWidget;

    switch (status) {
      case _ConnectionStatus.online:
        statusColor = colors.success;
        statusText = 'Connection OK';
        statusWidget = Icon(Icons.check_circle, color: colors.success, size: 16);
        break;
      case _ConnectionStatus.offline:
        statusColor = colors.error;
        statusText = 'Disruption';
        statusWidget = Icon(Icons.error_outline, color: colors.error, size: 16);
        break;
      case _ConnectionStatus.checking:
        statusColor = colors.warning;
        statusText = 'Pinging...';
        statusWidget = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.warning),
        );
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(spacing.sm),
            decoration: BoxDecoration(
              color: colors.foreground.withValues(alpha: colors.surfaceMedium),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: colors.foreground.withValues(alpha: colors.surfaceProminent),
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: typography.bodyLarge.copyWith(color: colors.foreground, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  txCount == 0 ? 'No requests made' : '$txCount requests in session',
                  style: typography.body.copyWith(
                    color: colors.foreground.withValues(alpha: colors.surfaceProminent),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: colors.surfaceMedium),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                statusWidget,
                SizedBox(width: spacing.xs),
                Text(
                  statusText,
                  style: typography.label.copyWith(
                    color: statusColor,
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

enum _ConnectionStatus { online, offline, checking }
