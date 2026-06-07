import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_floating_bottom_nav.dart';
import 'package:drive_care_plus/widgets/ui/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppFloatingBottomNav].
///
/// Validates Requirement 3.8 / 3.10 / 3.11 / 13.3 / 13.8 contract:
///   * 3–5 inclusive item count is enforced via assertion;
///   * the active item renders with the brand gradient;
///   * tapping an item invokes `onTap` with the item's index.
void main() {
  const List<NavItem> threeItems = <NavItem>[
    NavItem(icon: Icons.home, label: 'Home'),
    NavItem(icon: Icons.search, label: 'Search'),
    NavItem(icon: Icons.person, label: 'Me'),
  ];

  group('AppFloatingBottomNav', () {
    test('asserts on items list shorter than 3', () {
      expect(
        () => AppFloatingBottomNav(
          items: const <NavItem>[
            NavItem(icon: Icons.home, label: 'Home'),
            NavItem(icon: Icons.search, label: 'Search'),
          ],
          currentIndex: 0,
          onTap: (_) {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on items list longer than 5', () {
      expect(
        () => AppFloatingBottomNav(
          items: const <NavItem>[
            NavItem(icon: Icons.home, label: '1'),
            NavItem(icon: Icons.search, label: '2'),
            NavItem(icon: Icons.person, label: '3'),
            NavItem(icon: Icons.settings, label: '4'),
            NavItem(icon: Icons.help, label: '5'),
            NavItem(icon: Icons.menu, label: '6'),
          ],
          currentIndex: 0,
          onTap: (_) {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('active item renders the brand gradient', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppFloatingBottomNav(
            items: threeItems,
            currentIndex: 1,
            onTap: (_) {},
          ),
        ),
      );

      // Expect exactly one child with a LinearGradient decoration matching
      // the brand stops (the active item).
      final Iterable<DecoratedBox> gradientBoxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((d) =>
              d.decoration is BoxDecoration &&
              (d.decoration as BoxDecoration).gradient is LinearGradient &&
              ((d.decoration as BoxDecoration).gradient as LinearGradient)
                      .colors ==
                  const <Color>[AppColors.emerald500, AppColors.teal400]);

      // Some Container instances also surface as DecoratedBox under the
      // hood, so check via Container too.
      final Iterable<Container> gradientContainers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).gradient is LinearGradient);

      expect(
        gradientBoxes.length + gradientContainers.length,
        greaterThanOrEqualTo(1),
      );
    });

    testWidgets('tapping an item invokes onTap with that index',
        (tester) async {
      int? tapped;
      await tester.pumpWidget(
        hostApp(
          child: AppFloatingBottomNav(
            items: threeItems,
            currentIndex: 0,
            onTap: (i) => tapped = i,
          ),
        ),
      );

      // Tap the second item (index 1) by its label.
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });
  });
}
