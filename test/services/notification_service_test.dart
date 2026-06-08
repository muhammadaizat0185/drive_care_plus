import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drive_care_plus/services/notification_service.dart';
import 'package:drive_care_plus/services/notification_preferences.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeFlutterLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #initialize) {
      return Future<bool>.value(true);
    }
    if (name == #zonedSchedule || name == #cancel || name == #show) {
      return Future<void>.value();
    }
    return null;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    
    // Set mock platform instance
    FlutterLocalNotificationsPlatform.instance = FakeFlutterLocalNotificationsPlatform();

    // Initialize preferences and service
    await NotificationPreferences.instance.init();
    await NotificationService.instance.init();
  });

  group('NotificationService Booking Reminders Tests', () {
    test('Can initialize NotificationService and timezone database', () async {
      expect(NotificationService.instance, isNotNull);
    });

    test('scheduleBookingReminders completes without error', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 2));
      
      expect(
        () => NotificationService.instance.scheduleBookingReminders(
          bookingId: 'test_booking_123',
          workshopName: 'Budi Workshop',
          serviceName: 'Oil Change',
          bookingDateTime: futureDate,
        ),
        returnsNormally,
      );
    });

    test('cancelBookingReminders completes without error', () async {
      expect(
        () => NotificationService.instance.cancelBookingReminders('test_booking_123'),
        returnsNormally,
      );
    });
  });
}
