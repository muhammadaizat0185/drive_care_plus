import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../app.dart';
import '../screens/booking_screen.dart';
import '../screens/journey_log_screen.dart';
import '../screens/maintenance_screen.dart';
import '../screens/notifications_screen.dart';
import 'journey_database.dart';
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

  /// Tapping this payload opens [JourneyLogScreen] with the confirmation
  /// sheet auto-triggered.
  static const String journeyReview = 'journey_review';
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
  static const String _channelJourneyReview = 'journey_review';

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

    // Initialize timezones
    tz.initializeTimeZones();
    try {
      final String localName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

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
      navigator.pushNamed(BookingScreen.routeName, arguments: 1);
    } else if (payload == NotificationPayload.journeyReview) {
      // Open the Journey Log screen; the sticky pending badge will be visible
      // and the user can tap it to open the confirmation sheet.
      navigator.pushNamed(JourneyLogScreen.routeName);
    } else {
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

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelJourneyReview,
        'Trip Review',
        description:
            'Daily reminder to confirm which detected trips were in your car.',
        importance: Importance.defaultImportance,
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

  /// Shows a money flow (top-up, payment, subscription) OS notification and adds an inbox entry.
  Future<void> showMoneyFlowNotification({
    required String title,
    required String body,
  }) async {
    await _addToInbox(InboxNotification(
      id: 'money_${DateTime.now().millisecondsSinceEpoch}',
      type: 'payment',
      title: title,
      body: body,
      timestamp: DateTime.now(),
    ));

    await _dispatch(
      id: _notificationId(title + body),
      title: title,
      body: body,
      channelId: _channelBookings,
      channelName: 'Wallet Transactions',
      payload: 'wallet',
    );
  }

  // -------------------------------------------------------------------------
  // Journey review notifications (Phase 3)
  // -------------------------------------------------------------------------

  /// Schedules a daily trip-review notification at 9 PM local time.
  ///
  /// The notification fires every day at 21:00 and is automatically cancelled
  /// if [cancelDailyTripReviewNotification] is called (e.g. user opts out).
  /// Calling this method multiple times is safe — it cancels the previous
  /// schedule before creating a new one.
  ///
  /// The notification checks at fire-time whether there are pending journeys.
  /// Because `zonedSchedule` fires unconditionally, the actual pending-check
  /// happens in [checkAndSendTripReviewIfNeeded], which the app calls from a
  /// background task or on resume.
  Future<void> scheduleDailyTripReviewNotification() async {
    if (!_initialized) return;
    try {
      // Cancel any existing schedule first.
      await _plugin.cancel(_tripReviewNotificationId);

      // Build next 9 PM in local timezone.
      final tz.TZDateTime scheduledTime = _nextDailyAt(hour: 21, minute: 0);

      await _plugin.zonedSchedule(
        _tripReviewNotificationId,
        '🚗 Trip Review',
        'You have unconfirmed trips today — tap to confirm your vehicle.',
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelJourneyReview,
            'Trip Review',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            // Show "Confirm Now" action button on Android.
            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'confirm_trips',
                'Confirm Now',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
        payload: NotificationPayload.journeyReview,
      );
      debugPrint(
          'NotificationService: trip review scheduled daily at 21:00, next=$scheduledTime');
    } catch (e) {
      debugPrint('NotificationService.scheduleDailyTripReviewNotification: $e');
    }
  }

  /// Cancels the daily trip-review notification.
  Future<void> cancelDailyTripReviewNotification() async {
    await _plugin.cancel(_tripReviewNotificationId);
  }

  /// Fires an **immediate** trip-review notification.
  ///
  /// Called when the app is foregrounded and there are ≥2 pending journeys
  /// from today. Deduped per day so it only fires once per calendar day.
  Future<void> showTripReviewNotification({
    required int pendingCount,
    required double totalKm,
  }) async {
    if (!_initialized) return;

    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final String dedupKey = 'trip_review_notified_$today';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(dedupKey) == true) return;

    final String title =
        '🚗 $pendingCount trip${pendingCount == 1 ? '' : 's'} detected today';
    final String body =
        '${totalKm.toStringAsFixed(1)} km recorded — confirm which trips were in your car.';

    await _addToInbox(InboxNotification(
      id: 'trip_review_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationPayload.journeyReview,
      title: title,
      body: body,
      timestamp: DateTime.now(),
    ));

    await _dispatch(
      id: _tripReviewNotificationId,
      title: title,
      body: body,
      channelId: _channelJourneyReview,
      channelName: 'Trip Review',
      payload: NotificationPayload.journeyReview,
    );

    await prefs.setBool(dedupKey, true);
  }

  /// Checks today's journey database and fires [showTripReviewNotification]
  /// if there are ≥1 PENDING_CONFIRMATION journeys.
  ///
  /// Call this from:
  ///   • App resume (in [AppLifecycleObserver])
  ///   • End of a passive background journey ([ActivityRecognitionService])
  Future<void> checkAndSendTripReviewIfNeeded() async {
    try {
      final stats =
          await JourneyDatabase.instance.getDailyStats(DateTime.now());
      final int pending = stats['pendingCount'] as int? ?? 0;
      if (pending < 1) return;

      // Compute total detected km for the notification body.
      final journeys = await JourneyDatabase.instance.getJourneys();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      double totalKm = 0.0;
      for (final j in journeys) {
        final st = j['start_time'] as String? ?? '';
        if (!st.startsWith(today)) continue;
        if (j['status'] == 'PENDING_CONFIRMATION' ||
            j['status'] == 'pending') {
          totalKm += (j['distance_km'] as num?)?.toDouble() ?? 0.0;
        }
      }

      await showTripReviewNotification(
        pendingCount: pending,
        totalKm: totalKm,
      );
    } catch (e) {
      debugPrint('NotificationService.checkAndSendTripReviewIfNeeded: $e');
    }
  }

  // Fixed notification ID for the daily trip review
  static const int _tripReviewNotificationId = 77001;

  /// Returns the next [tz.TZDateTime] for [hour]:[minute] local time.
  /// If that time has already passed today, returns tomorrow's occurrence.
  tz.TZDateTime _nextDailyAt({required int hour, required int minute}) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // -------------------------------------------------------------------------
  // Maintenance reminders
  // -------------------------------------------------------------------------

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

  /// Schedules two booking reminders: one at 30 minutes before, and one at the exact booking time.
  Future<void> scheduleBookingReminders({
    required String bookingId,
    required String workshopName,
    required String serviceName,
    required DateTime bookingDateTime,
  }) async {
    // Check toggle preference
    if (!NotificationPreferences.instance.bookingConfirmations) return;

    // First cancel any existing reminders for this booking ID
    await cancelBookingReminders(bookingId);

    final now = DateTime.now();

    // 1. 30 minutes before
    final reminder30Min = bookingDateTime.subtract(const Duration(minutes: 30));
    if (reminder30Min.isAfter(now)) {
      await _schedule(
        id: _reminder30MinId(bookingId),
        title: 'Booking Reminder ⏰',
        body: 'Your booking for $serviceName at $workshopName is in 30 minutes!',
        scheduledTime: reminder30Min,
        payload: NotificationPayload.booking,
      );
    }

    // 2. Exact booking time ("right now")
    if (bookingDateTime.isAfter(now)) {
      await _schedule(
        id: _reminderExactId(bookingId),
        title: 'Appointment Time 🛠️',
        body: 'Your appointment for $serviceName at $workshopName is starting now!',
        scheduledTime: bookingDateTime,
        payload: NotificationPayload.booking,
      );
    }
  }

  /// Cancels scheduled reminders for a specific booking.
  Future<void> cancelBookingReminders(String bookingId) async {
    try {
      await _plugin.cancel(_reminder30MinId(bookingId));
      await _plugin.cancel(_reminderExactId(bookingId));
      debugPrint('NotificationService: Cancelled reminders for booking=$bookingId');
    } catch (e) {
      debugPrint('NotificationService: Error canceling reminders for booking=$bookingId: $e');
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelBookings,
            'Booking Confirmations',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('NotificationService: Scheduled notification id=$id at $scheduledTime');
    } catch (e) {
      debugPrint('NotificationService._schedule error: $e');
    }
  }

  int _reminder30MinId(String bookingId) => (bookingId + '_30min').hashCode.abs() % 100000;
  int _reminderExactId(String bookingId) => (bookingId + '_exact').hashCode.abs() % 100000;
}
