import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_gradient_button.dart';
import 'package:drive_care_plus/widgets/ui/app_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppGradientButton].
///
/// Validates the contract from figma-ui-redesign Requirements 3.2, 3.10,
/// 3.11, 3.12, 5.7, 11.5, 13.3, 13.8: emerald500 → teal400 gradient when
/// enabled, inline spinner replacing label while loading, gestures
/// rejected during loading or when disabled.
void main() {
  group('AppGradientButton', () {
    for (final Brightness brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      testWidgets(
        'enabled renders emerald500→teal400 gradient (${brightness.name})',
        (tester) async {
          await tester.pumpWidget(
            hostApp(
              brightness: brightness,
              child: AppGradientButton(
                label: 'Save',
                onPressed: () {},
              ),
            ),
          );

          final Iterable<Container> gradientContainers = tester
              .widgetList<Container>(find.byType(Container))
              .where((c) =>
                  c.decoration is BoxDecoration &&
                  (c.decoration as BoxDecoration).gradient != null);

          expect(gradientContainers, isNotEmpty);
          final LinearGradient gradient =
              (gradientContainers.first.decoration! as BoxDecoration)
                  .gradient! as LinearGradient;
          expect(gradient.colors,
              <Color>[AppColors.emerald500, AppColors.teal400]);
        },
      );
    }

    testWidgets('isLoading replaces label with AppSpinner', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppGradientButton(
            label: 'Save',
            onPressed: () {},
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('isLoading rejects taps', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppGradientButton(
            label: 'Save',
            onPressed: () => taps++,
            isLoading: true,
          ),
        ),
      );

      await tester.tap(find.byType(AppGradientButton));
      // CircularProgressIndicator runs forever; pump a few frames instead
      // of pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 50));

      expect(taps, 0);
    });

    testWidgets('enabled tap fires the callback', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppGradientButton(
            label: 'Save',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(AppGradientButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('disabled rejects taps and removes gradient', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppGradientButton(
            label: 'Save',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(
        find.byType(AppGradientButton),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(taps, 0);

      final Iterable<Container> gradientContainers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).gradient != null);
      expect(gradientContainers, isEmpty);
    });

    testWidgets('hit area is at least 48x48 logical pixels', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppGradientButton(
            label: 'Save',
            onPressed: () {},
            fullWidth: false,
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(AppGradientButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}
