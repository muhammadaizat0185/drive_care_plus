import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppCard].
///
/// Validates Requirements 3.10, 3.11, 13.3: surface, border, shadow, large
/// radius; interactive variant adds an `InkWell` gated by a 48x48 hit-area
/// floor.
void main() {
  /// Returns the BoxDecoration backing the outermost decorated Container of
  /// the rendered card.
  BoxDecoration _surfaceDecoration(WidgetTester tester) {
    final Iterable<Container> decorated = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.decoration is BoxDecoration);
    expect(decorated, isNotEmpty);
    return decorated.first.decoration! as BoxDecoration;
  }

  group('AppCard', () {
    for (final Brightness brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      testWidgets(
        'static card renders surface, border, shadow, large radius '
        '(${brightness.name})',
        (tester) async {
          await tester.pumpWidget(
            hostApp(
              brightness: brightness,
              child: AppCard(
                child: const Text('Body'),
              ),
            ),
          );

          final BoxDecoration d = _surfaceDecoration(tester);

          // Surface fills with the card token.
          expect(
            d.color,
            brightness == Brightness.light
                ? AppColors.lightCard
                : AppColors.darkCard,
          );

          // 1-px border in the neutral border token.
          final Border border = d.border! as Border;
          expect(border.top.width, 1.0);
          expect(
            border.top.color,
            brightness == Brightness.light
                ? AppColors.lightBorder
                : AppColors.darkBorder,
          );

          // Large corner radius.
          expect(
            d.borderRadius,
            BorderRadius.circular(AppRadii.large),
          );

          // Shadow set is small at rest.
          expect(d.boxShadow, isNotEmpty);
        },
      );
    }

    testWidgets('onTap variant adds an InkWell with hit area floor ≥ 48',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: SizedBox(
            width: 200,
            child: AppCard(
              onTap: () => taps++,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);

      // The card height respects the 48 logical-pixel hit-area floor even
      // though the child collapses to nothing.
      final Size cardSize = tester.getSize(find.byType(AppCard));
      expect(cardSize.height, greaterThanOrEqualTo(48.0));

      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('static card has no InkWell', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppCard(
            child: const Text('Body'),
          ),
        ),
      );

      expect(find.byType(InkWell), findsNothing);
    });
  });
}
