import 'package:drive_care_plus/screens/workshops/_edit_booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

final Map<String, dynamic> _mockBooking = <String, dynamic>{
  'id': 'booking-edit-1',
  'workshopName': 'Test Repair Center',
  'serviceName': 'General Service',
  'date': '2026-06-08T10:00:00.000',
  'time': '10:00',
  'status': 'Pending',
};

void main() {
  testWidgets('EditBookingBottomSheet renders initial status, service, and buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(
        child: EditBookingBottomSheet(
          booking: _mockBooking,
          onSave: (_) {},
        ),
      ),
    );

    // Headline and workshop name
    expect(find.text('Edit Appointment'), findsOneWidget);
    expect(find.text('Test Repair Center'), findsOneWidget);

    // Initial Status dropdown value
    expect(find.text('Pending'), findsOneWidget);

    // Initial Service Type dropdown value
    expect(find.text('General Service'), findsOneWidget);

    // Buttons
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('EditBookingBottomSheet updates values and triggers onSave with correct formats',
      (WidgetTester tester) async {
    Map<String, dynamic>? savedUpdates;

    await tester.pumpWidget(
      hostApp(
        child: Scaffold(
          body: EditBookingBottomSheet(
            booking: _mockBooking,
            onSave: (Map<String, dynamic> updates) {
              savedUpdates = updates;
            },
          ),
        ),
      ),
    );

    // Change status dropdown value
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmed').last);
    await tester.pumpAndSettle();

    // Tap save
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(savedUpdates, isNotNull);
    expect(savedUpdates!['status'], 'Confirmed');
    expect(savedUpdates!['serviceName'], 'General Service');
    expect(savedUpdates!['date'], isNotEmpty);
    expect(savedUpdates!['time'], isNotEmpty);
    expect(savedUpdates!['localDate'], isNotEmpty);
    expect(savedUpdates!['localTime'], isNotEmpty);
  });
}
