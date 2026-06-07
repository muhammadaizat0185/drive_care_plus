import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_category_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppCategoryChip].
///
/// Validates Requirement 3.10 / 3.11 / 13.3 contract: selected → brand
/// gradient, unselected → muted fill, optional `trailingPriceText`
/// renders, tap fires.
void main() {
  Container _decoratedRoot(WidgetTester tester) {
    return tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((c) => c.decoration is BoxDecoration);
  }

  group('AppCategoryChip', () {
    testWidgets('selected renders brand gradient', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppCategoryChip(
            label: 'Petrol',
            selected: true,
            onTap: () {},
          ),
        ),
      );

      final BoxDecoration d =
          _decoratedRoot(tester).decoration! as BoxDecoration;
      final LinearGradient gradient = d.gradient! as LinearGradient;
      expect(gradient.colors,
          <Color>[AppColors.emerald500, AppColors.teal400]);
    });

    testWidgets('unselected renders muted fill', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppCategoryChip(
            label: 'Petrol',
            selected: false,
            onTap: () {},
          ),
        ),
      );

      final BoxDecoration d =
          _decoratedRoot(tester).decoration! as BoxDecoration;
      expect(d.gradient, isNull);
      expect(d.color, Colors.white);
      expect(d.border, isNotNull);
      expect(d.boxShadow, isNotEmpty);
    });

    testWidgets('renders trailingPriceText when provided', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppCategoryChip(
            label: 'Petrol',
            selected: false,
            onTap: () {},
            trailingPriceText: 'RM 2.05/L',
          ),
        ),
      );

      expect(find.text('RM 2.05/L'), findsOneWidget);
    });

    testWidgets('omits trailingPriceText when null', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppCategoryChip(
            label: 'Petrol',
            selected: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('RM 2.05/L'), findsNothing);
    });

    testWidgets('tap fires the callback', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppCategoryChip(
            label: 'Petrol',
            selected: false,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(AppCategoryChip));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });
}
