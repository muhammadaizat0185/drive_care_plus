// Widget tests for the redesigned WorkshopDetailSheet (Task 9.11, 9.15).
//
// Validates: Requirements 7.9, 7.10, 7.11.
//
// Structural sweep — quick-info grid, services chip cloud, opening-hours
// list, footer Call + Book Now actions.

import 'package:drive_care_plus/models/workshop.dart';
import 'package:drive_care_plus/screens/workshops/_workshop_detail_sheet.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

const Workshop _workshop = Workshop(
  id: 'detail-w1',
  name: 'Detail Workshop',
  address: '1 Example Lane',
  rating: 4.7,
  reviewCount: 23,
  distance: '0.8 km',
  types: <String>['car_repair'],
  isOpenNow: true,
);

void main() {
  testWidgets('detail sheet renders header, quick-info, services, hours',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(child: const WorkshopDetailSheet(workshop: _workshop)),
    );

    // Header
    expect(find.text('Detail Workshop'), findsOneWidget);
    expect(find.text('★ 4.7'), findsOneWidget);
    expect(find.text('(23 reviews)'), findsOneWidget);

    // Quick info section header
    expect(find.text('QUICK INFO'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('0.8 km'), findsOneWidget);

    // Services section
    expect(find.text('SERVICES'), findsOneWidget);

    // Opening hours section
    expect(find.text('OPENING HOURS'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
  });

  testWidgets(
      'detail sheet footer renders Call (secondary) and Book Now (gradient)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(child: const WorkshopDetailSheet(workshop: _workshop)),
    );

    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Book Now'), findsOneWidget);
    expect(find.byType(AppGradientButton), findsOneWidget);
    // The footer Call button is an AppSecondaryButton — at least one
    // should be present (the only one in the sheet body).
    expect(find.byType(AppSecondaryButton), findsOneWidget);
  });

  testWidgets('detail sheet shows Closed when isOpenNow is false',
      (WidgetTester tester) async {
    const Workshop closed = Workshop(
      id: 'detail-w2',
      name: 'Closed Workshop',
      address: '',
      isOpenNow: false,
    );
    await tester.pumpWidget(
      hostApp(child: const WorkshopDetailSheet(workshop: closed)),
    );

    // The Closed status appears in the quick-info Status tile and may
    // also appear in the placeholder opening hours ("Sunday: Closed").
    // Look for at least one render and assert "Open" is absent from
    // the Status tile.
    expect(find.text('Closed'), findsAtLeastNWidgets(1));
    // Status tile value: "Open" should NOT appear when isOpenNow=false.
    expect(find.text('Open'), findsNothing);
  });
}
