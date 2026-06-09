import 'package:drive_care_plus/screens/workshops/_booking_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

final Map<String, dynamic> _mockBookingFuture = <String, dynamic>{
  'id': 'booking-details-1',
  'workshopName': 'Elite Auto Care',
  'serviceName': 'General Service',
  'date': '2030-06-08T10:00:00.000', // Far future date
  'time': '10:00',
  'status': 'Confirmed',
};

final Map<String, dynamic> _mockBookingPastPending = <String, dynamic>{
  'id': 'booking-details-2',
  'workshopName': 'Legacy Auto Shop',
  'serviceName': 'Oil Change',
  'date': '2020-06-08T10:00:00.000', // Past date
  'time': '10:00',
  'status': 'Pending',
};

void main() {
  testWidgets('BookingDetailsBottomSheet renders future booking details and action buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(
        child: BookingDetailsBottomSheet(
          booking: _mockBookingFuture,
          onSave: (_) {},
        ),
      ),
    );

    // Workshop and service details
    expect(find.text('Elite Auto Care'), findsOneWidget);
    expect(find.text('General Service'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);

    // Action buttons
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Edit Booking'), findsOneWidget);
    
    // Warning banner should NOT be visible
    expect(find.textContaining('attending'), findsNothing);
  });

  testWidgets('BookingDetailsBottomSheet renders past pending booking with confirmation warning',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(
        child: BookingDetailsBottomSheet(
          booking: _mockBookingPastPending,
          onSave: (_) {},
        ),
      ),
    );

    // Workshop name and service details
    expect(find.text('Legacy Auto Shop'), findsOneWidget);
    expect(find.text('Oil Change'), findsOneWidget);

    // Pending confirmation badge instead of raw status
    expect(find.text('Pending Confirmation'), findsOneWidget);

    // Warning banner text
    expect(find.textContaining('attending'), findsNothing); // Attending is in prompt, but let's check action buttons
    expect(find.text('Action Required'), findsOneWidget);

    // Quick attende/cancellation buttons
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Reschedule'), findsOneWidget);
  });

  testWidgets('BookingDetailsBottomSheet switches to edit mode on button tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(
        child: Scaffold(
          body: BookingDetailsBottomSheet(
            booking: _mockBookingFuture,
            onSave: (_) {},
          ),
        ),
      ),
    );

    // Tap Edit Booking
    await tester.tap(find.text('Edit Booking'));
    await tester.pumpAndSettle();

    // Now edit mode should be active
    expect(find.text('Edit Appointment'), findsOneWidget);
    expect(find.text('Back to Details'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    // Tap Back to Details
    await tester.tap(find.text('Back to Details'));
    await tester.pumpAndSettle();

    // Switches back to details mode
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Edit Booking'), findsOneWidget);
  });
}
