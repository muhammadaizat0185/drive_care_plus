import 'package:drive_care_plus/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows DriveCare+ splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DriveCarePlusApp());

    expect(find.text('DriveCare+'), findsOneWidget);
    expect(
      find.text('Smart vehicle maintenance and trip tracker'),
      findsOneWidget,
    );

    // Clean up transition timer
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 100));
  });
}
