import 'package:drive_care_plus/widgets/ui/app_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppListTile].
///
/// Validates Requirements 3.10, 3.11, 13.3 contract: leading/title/subtitle/
/// trailing layout, optional `onTap` wiring, hit-area floor.
void main() {
  group('AppListTile', () {
    testWidgets('renders leading, title, subtitle, trailing slots',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Change password'),
            subtitle: Text('30 days ago'),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('30 days ago'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('onTap fires and InkWell is present', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppListTile(
            title: const Text('Tap me'),
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byType(AppListTile));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('static tile has no InkWell', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppListTile(
            title: Text('Static'),
          ),
        ),
      );
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('interactive tile enforces a 48-logical-pixel hit-area floor',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppListTile(
            title: const Text('Tap'),
            onTap: () {},
          ),
        ),
      );

      final Size size = tester.getSize(find.byType(AppListTile));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}
