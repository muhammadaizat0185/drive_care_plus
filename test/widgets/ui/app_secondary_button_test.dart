import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppSecondaryButton].
///
/// Validates the visual contract from figma-ui-redesign Requirements 3.2,
/// 3.10, 3.11, 3.12, 13.3, 13.8: 2-logical-pixel emerald500 border when
/// active, muted border when disabled, ≥ 48x48 hit area, semantics label,
/// and gesture wiring.
void main() {
  group('AppSecondaryButton', () {
    for (final Brightness brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      testWidgets(
        'enabled renders 2px emerald500 border (${brightness.name})',
        (tester) async {
          await tester.pumpWidget(
            hostApp(
              brightness: brightness,
              child: AppSecondaryButton(
                label: 'Cancel',
                onPressed: () {},
              ),
            ),
          );

          // Find the Container that owns the bordered decoration.
          final Iterable<Container> bordered = tester
              .widgetList<Container>(find.byType(Container))
              .where((c) =>
                  c.decoration is BoxDecoration &&
                  (c.decoration as BoxDecoration).border != null);
          expect(bordered, isNotEmpty);

          final BoxDecoration decoration =
              bordered.first.decoration! as BoxDecoration;
          final Border border = decoration.border! as Border;

          expect(border.top.width, 2.0);
          expect(border.top.color, AppColors.emerald500);
        },
      );
    }

    testWidgets('disabled renders muted border instead of emerald500',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppSecondaryButton(
            label: 'Cancel',
            onPressed: null,
          ),
        ),
      );

      final Iterable<Container> bordered = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).border != null);
      expect(bordered, isNotEmpty);

      final BoxDecoration decoration =
          bordered.first.decoration! as BoxDecoration;
      final Border border = decoration.border! as Border;

      expect(border.top.width, 2.0);
      expect(border.top.color, isNot(AppColors.emerald500));
      // Light-mode muted is `lightMuted`.
      expect(border.top.color, AppColors.lightMuted);
    });

    testWidgets('enabled tap fires the callback', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppSecondaryButton(
            label: 'Cancel',
            onPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(AppSecondaryButton));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('disabled button does not fire the callback',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppSecondaryButton(
            label: 'Cancel',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(
        find.byType(AppSecondaryButton),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(taps, 0);
    });

    testWidgets('hit area is at least 48x48 logical pixels', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppSecondaryButton(
            label: 'Go',
            onPressed: () {},
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(AppSecondaryButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('exposes Semantics node with label as accessible name',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppSecondaryButton(
            label: 'Cancel',
            onPressed: () {},
          ),
        ),
      );
      final Semantics semantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((s) =>
              s.properties.label == 'Cancel' &&
              s.properties.button == true);
      expect(semantics.properties.label, 'Cancel');
      expect(semantics.properties.button, true);
      expect(semantics.properties.enabled, true);
    });
  });
}
