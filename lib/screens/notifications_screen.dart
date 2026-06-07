import 'package:flutter/material.dart';

import '../core/theme/color_utils.dart';
import '../core/theme/tokens/tokens.dart';
import '../screens/booking_screen.dart';
import '../screens/maintenance_screen.dart';
import '../services/notification_service.dart';
import '../widgets/ui/ui.dart';

/// Real notification inbox screen backed by [NotificationService].
///
/// Each card is tappable — tapping it marks it as read and navigates to the
/// screen relevant to that notification type:
///   * `maintenance` → Maintenance screen
///   * `booking`     → Bookings tab
///
/// OS notifications tapped from the system tray also deep-link here via
/// [NotificationService.navigateForType].
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static const routeName = '/notifications';

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read as soon as the inbox opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return AppBackground(
      child: ListenableBuilder(
        listenable: NotificationService.instance,
        builder: (context, _) {
          final inbox = NotificationService.instance.inbox;

          // Partition into today vs earlier
          final DateTime now = DateTime.now();
          final DateTime todayStart =
              DateTime(now.year, now.month, now.day);

          final List<InboxNotification> today = inbox
              .where((n) => n.timestamp.isAfter(todayStart))
              .toList();
          final List<InboxNotification> earlier = inbox
              .where((n) => !n.timestamp.isAfter(todayStart))
              .toList();

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                if (inbox.isNotEmpty)
                  TextButton(
                    onPressed: () => NotificationService.instance.clearAll(),
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: colors.emerald500,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            body: inbox.isEmpty
                ? _EmptyState(colors: colors, spacing: spacing)
                : ListView(
                    padding: EdgeInsets.all(spacing.lg),
                    children: [
                      if (today.isNotEmpty) ...[
                        const AppSectionHeader(label: 'TODAY'),
                        ...today.map((n) => _NotificationCard(
                              notification: n,
                              colors: colors,
                              spacing: spacing,
                            )),
                        SizedBox(height: spacing.lg),
                      ],
                      if (earlier.isNotEmpty) ...[
                        const AppSectionHeader(label: 'EARLIER'),
                        ...earlier.map((n) => _NotificationCard(
                              notification: n,
                              colors: colors,
                              spacing: spacing,
                            )),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors, required this.spacing});

  final AppColorsExt colors;
  final AppSpacingExt spacing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: colors.foreground.withValues(alpha: 0.2),
          ),
          SizedBox(height: spacing.lg),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.foreground.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            'Booking confirmations and\nmaintenance reminders will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.foreground.withValues(alpha: 0.35),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification card — tappable, navigates to source screen
// ---------------------------------------------------------------------------

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.colors,
    required this.spacing,
  });

  final InboxNotification notification;
  final AppColorsExt colors;
  final AppSpacingExt spacing;

  /// Destination label shown in the trailing hint so users know where the tap
  /// will take them before they tap.
  String get _destinationLabel {
    switch (notification.type) {
      case 'maintenance':
        return 'View Maintenance';
      case 'booking':
        return 'View Bookings';
      default:
        return 'Open';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMaintenance = notification.type == 'maintenance';

    final Color iconColor =
        isMaintenance ? Colors.amber : colors.emerald500;
    final IconData iconData = isMaintenance
        ? Icons.build_circle_outlined
        : Icons.calendar_month_outlined;

    final String relativeTime = _formatRelativeTime(notification.timestamp);

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.md),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onTap(context),
          child: AppCard(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 22),
                ),
                SizedBox(width: spacing.md),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: colors.foreground,
                              ),
                            ),
                          ),
                          // Unread dot
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: EdgeInsets.only(left: spacing.sm),
                              decoration: BoxDecoration(
                                color: colors.emerald500,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: spacing.xs),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.foreground.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      // Bottom row: timestamp + tap-hint
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            relativeTime,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  colors.foreground.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _destinationLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.emerald500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: spacing.xs),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: colors.emerald500,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    // Mark as read
    notification.isRead = true;
    NotificationService.instance.markAllRead();

    // Navigate directly to the source screen using the local context —
    // avoids the loop caused by re-pushing NotificationsScreen.
    switch (notification.type) {
      case 'maintenance':
        Navigator.of(context).pushNamed(MaintenanceScreen.routeName);
        break;
      case 'booking':
        // arguments: 1 opens the "My Bookings" tab directly
        Navigator.of(context).pushNamed(BookingScreen.routeName, arguments: 1);
        break;
      default:
        // Nothing extra to navigate to
        break;
    }
  }

  String _formatRelativeTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${time.day}/${time.month}/${time.year}';
  }
}
