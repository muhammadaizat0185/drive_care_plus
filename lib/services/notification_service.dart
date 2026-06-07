import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../screens/booking_screen.dart';
import '../screens/maintenance_screen.dart';
import '../screens/notifications_screen.dart';
import 'notification_preferences.dart';
import 'vehicle_insights.dart';

// ---------------------------------------------------------------------------
// Notification payloads (type identifiers)
// ---------------------------------------------------------------------------

/// Payload strings embedded in OS notifications so tapping them deep-links
/// to the correct screen inside the app.
class NotificationPayload {
  static const String maintenance = 'maintenance';
  static const String booking = 'booking';
}

// ---------------------------------------------------------------------------
// InboxNotification model
// ---------------------------------------------------------------------------

/// A single entry in the in-app notification inbox.
class InboxNotification {
  final String id;

  /// 'maintenance' | 'booking'
  final String type;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  InboxNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory InboxNotification.fromJson(Map<String, dynamic> json) =>
      InboxNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------

/// Singleton service that:
///
///  1. Initialises `flutter_local_notifications` with two Android channels.
///  2. Respects the three toggles in [NotificationPreferences].
///  3. Maintains an in-app notification **inbox** backed by SharedPreferences.
///  4. Deep-links into the correct screen when a notification is tapped —
///     both from the OS notification tray and from the in-app inbox.
class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const String _inboxKey = 'inbox_notifications';
  static const int _maxInboxSize = 50;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Android notification channel IDs
  static const String _channelMaintenance = 'maintenance_reminders';
  static const String _channelBookings = 'booking_confirmations';

  List<InboxNotification> _inbox = [];
  bool _initialized = false;

  /// All inbox entries, newest first.
  List<InboxNotification> get inbox => List.unmodifiable(_inbox);

  /// Number of unread inbox entries (drives the badge on the bell icon).
  int get unreadCount => _inbox.where((n) => !n.isRead).length;

  // -------------------------------------------------------------------------
  // Initialisation
  // -------------------------------------------------------------------------

  Future<void> init() async {
    if (_initialized) return;

    final AndroidInitializationSettings androidInit =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    // Wire the tap handler so OS notification taps deep-link into the app
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android channels
    await _createAndroidChannels();

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Load persisted inbox
    await _loadInbox();

    _initialized = true;
    debugPrint('NotificationService: initialized');
  }

  /// Called by the plugin when the user taps a notification in the system
  /// tray. Uses [DriveCarePlusApp.navigatorKey] to navigate without a
  /// [BuildContext].
  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    debugPrint('NotificationService: tapped payload=$payload');
    _navigateForPayload(payload);
  }

  /// Navigates to the correct screen based on [payload].
  ///
  /// Used for OS notification tray taps — navigates directly to the source
  /// screen so the user lands on the relevant content immediately.
  static void _navigateForPayload(String? payload) {
    final navigator = DriveCarePlusApp.navigatorKey.currentState;
    if (navigator == null) return;

    if (payload == NotificationPayload.maintenance) {
      navigator.pushNamed(MaintenanceScreen.routeName);
    } else if (payload == NotificationPayload.booking) {
      // arguments: 1 opens the "My Bookings" tab directly
      navigator.pushNamed(BookingScreen.routeName, arguments: 1);
    } else {
      // Fallback: open the notification inbox
      navigator.pushNamed(NotificationsScreen.routeName);
    }
  }

  /// Called from [NotificationsScreen] when the user taps an inbox card.
  /// Uses the [BuildContext]-free navigator key so the screen doesn't need
  /// to pass a context into the service.
  static void navigateForType(String type) {
    _navigateForPayload(type);
  }

  Future<void> _createAndroidChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelMaintenance,
        'Maintenance Reminders',
        description: 'Alerts when vehicle maintenance is due soon.',
        importance: Importance.high,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelBookings,
        'Booking Confirmations',
        description: 'Confirms workshop appointments you have scheduled.',
        importance: Importance.high,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Public dispatch helpers
  // -------------------------------------------------------------------------

  /// Shows a booking-confirmation OS notification and adds an inbox entry.
  Future<void> showBookingConfirmation({
    required String workshopName,
    required String date,
    required String time,
  }) async {
    final String title = 'Booking Confirmed ✅';
    final String body = '$workshopName — $date at $time';

    // Always add to inbox
    await _addToInbox(InboxNotification(
      id: 'booking_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationPayload.booking,
      title: title,
      body: body,
      timestamp: DateTime.now(),
    ));

    if (!NotificationPreferences.instance.bookingConfirmations) return;

    await _dispatch(
      id: _notificationId('booking'),
      title: title,
      body: body,
      channelId: _channelBookings,
      channelName: 'Booking Confirmations',
      payload: NotificationPayload.booking,
    );
  }

  /// Shows a maintenance-reminder OS notification and adds an inbox entry.
  Future<void> showMaintenanceReminder({
    required String itemName,
    required String detail,
  }) async {
    final String title = '🔧 Maintenance Due: $itemName';
    final String body = detail;

    await _addToInbox(InboxNotification(
      id: 'maint_${itemName}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationPayload.maintenance,
      title: title,
      body: body,
      timestamp: DateTime.now(),
    ));

    if (!NotificationPreferences.instance.maintenanceReminders) return;

    await _dispatch(
      id: _notificationId('maint_$itemName'),
      title: title,
      body: body,
      channelId: _channelMaintenance,
      channelName: 'Maintenance Reminders',
      payload: NotificationPayload.maintenance,
    );
  }

  /// Iterates all vehicle watchlist items and fires a reminder for every
  /// item in **Red** or **Yellow** status. Deduped per day.
  Future<void> checkAndSendMaintenanceReminders() async {
    final List<MaintenanceItem> items = VehicleInsights.instance.watchlistItems;
    final String today = DateTime.now().toIso8601String().substring(0, 10);

    for (final MaintenanceItem item in items) {
      if (item.status == 'Green') continue;

      final String dedupKey = 'maint_reminded_${item.name}_$today';
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(dedupKey) == true) continue;

      final String detail = item.remainingKm <= 0
          ? '${item.name} is overdue! Last serviced at '
              '${item.lastServiceMileage.toStringAsFixed(0)} km.'
          : () {
              final double daily = VehicleInsights.instance.averageKmPerDay;
              final int days = daily > 0
                  ? (item.remainingKm / daily).ceil().clamp(0, 365)
                  : 0;
              return '${item.name} due in '
                  '${item.remainingKm.toStringAsFixed(0)} km'
                  '${days > 0 ? ' (~$days days)' : ''}.';
            }();

      await showMaintenanceReminder(itemName: item.name, detail: detail);
      await prefs.setBool(dedupKey, true);
    }
  }

  // -------------------------------------------------------------------------
  // Inbox management
  // -------------------------------------------------------------------------

  Future<void> markAllRead() async {
    for (final n in _inbox) {
      n.isRead = true;
    }
    notifyListeners();
    await _persistInbox();
  }

  Future<void> clearAll() async {
    _inbox.clear();
    notifyListeners();
    await _persistInbox();
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  Future<void> _dispatch({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService._dispatch error: $e');
    }
  }

  Future<void> _addToInbox(InboxNotification notification) async {
    _inbox.insert(0, notification);
    if (_inbox.length > _maxInboxSize) {
      _inbox = _inbox.sublist(0, _maxInboxSize);
    }
    notifyListeners();
    await _persistInbox();
  }

  Future<void> _loadInbox() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? raw = prefs.getStringList(_inboxKey);
      if (raw != null) {
        _inbox = raw
            .map((s) => InboxNotification.fromJson(
                jsonDecode(s) as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('NotificationService._loadInbox error: $e');
    }
  }

  Future<void> _persistInbox() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw =
          _inbox.map((n) => jsonEncode(n.toJson())).toList();
      await prefs.setStringList(_inboxKey, raw);
    } catch (e) {
      debugPrint('NotificationService._persistInbox error: $e');
    }
  }

  int _notificationId(String key) => key.hashCode.abs() % 100000;
}
