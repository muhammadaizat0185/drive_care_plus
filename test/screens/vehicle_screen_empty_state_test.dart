import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drive_care_plus/screens/vehicle_screen.dart';
import 'package:drive_care_plus/widgets/vehicle_health_gauge.dart';
import 'package:drive_care_plus/services/vehicle_insights.dart';
import 'package:drive_care_plus/screens/home_screen.dart';
import '../widgets/ui/_test_host.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await VehicleInsights.instance.clear();
  });

  testWidgets('VehicleHealthGauge renders empty state when no vehicles', (tester) async {
    final insights = VehicleInsights.instance;
    await insights.clear();

    await tester.pumpWidget(
      hostApp(child: const VehicleHealthGauge()),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Vehicle Registered'), findsOneWidget);
    expect(find.textContaining('Register your vehicle to start tracking'), findsOneWidget);
    expect(find.text('Add Vehicle'), findsOneWidget);

    // Initial tab is 0
    HomeScreen.activeTabNotifier.value = 0;

    await tester.tap(find.text('Add Vehicle'));
    await tester.pumpAndSettle();

    // Verify it changed to tab 2 (My Car)
    expect(HomeScreen.activeTabNotifier.value, equals(2));
  });

  testWidgets('VehicleScreen renders empty state when no vehicles', (tester) async {
    final insights = VehicleInsights.instance;
    await insights.clear();

    await tester.pumpWidget(
      hostApp(child: const VehicleScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Garage is Empty'), findsOneWidget);
    expect(find.textContaining('Add your first vehicle to unlock odometer tracking'), findsOneWidget);
    expect(find.text('Register Vehicle'), findsOneWidget);

    // Standard cards should NOT be rendered
    expect(find.text('Current Odometer'), findsNothing);
    expect(find.text('Diagnostic Health Profile'), findsNothing);
    expect(find.text('Specifications'), findsNothing);
    expect(find.text('Service Watchlist'), findsNothing);
  });
}
