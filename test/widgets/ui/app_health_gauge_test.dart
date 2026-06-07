import 'package:drive_care_plus/widgets/ui/app_health_gauge.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppHealthGauge].
///
/// Validates Requirements 4.4 / 8.3 / 3.11 contract:
///   * `percentage == null` → renders the `--%` placeholder.
///   * `percentage != null` → renders the rounded numeric label.
void main() {
  group('AppHealthGauge', () {
    testWidgets('percentage=null renders --% placeholder', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppHealthGauge(percentage: null),
        ),
      );
      // Allow the TweenAnimationBuilder to settle.
      await tester.pumpAndSettle();

      expect(find.text('--%'), findsOneWidget);
    });

    testWidgets('percentage=84 renders rounded numeric label',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppHealthGauge(percentage: 84.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('84%'), findsOneWidget);
      expect(find.text('--%'), findsNothing);
    });

    testWidgets('label parameter renders below the numeric value',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppHealthGauge(percentage: 50.0, label: 'STATUS'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STATUS'), findsOneWidget);
    });
  });
}
