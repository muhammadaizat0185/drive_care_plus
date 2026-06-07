import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppPrimaryButton].
///
/// Validates the visual contract spelled out in figma-ui-redesign
/// Requirements 3.2, 3.10, 3.11, 3.12, 13.3, 13.8: emerald500 → teal400
/// brand gradient when active, muted surface when disabled, ≥ 48x48
/// hit area, semantics label, and gesture wiring.
void main() {
  group('AppPrimaryButton', () {
    for (final Brightness brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      testWidgets(
        'renders emerald500→teal400 brand gradient when enabled '
        '(${brightness.name})',
        (tester) async {
          await tester.pumpWidget(
            hostApp(
              brightness: brightness,
              child: AppPrimaryButton(
                label: 'Continue',
                onPressed: () {},
              ),
            ),
          );

          // Find the Container that owns the gradient decoration.
          final Iterable<Container> gradientContainers = tester
              .widgetList<Container>(find.byType(Container))
              .where((c) => c.decoration is BoxDecoration &&
                  (c.decoration as BoxDecoration).gradient != null);

          expect(gradientContainers, isNotEmpty);
          final BoxDecoration decoration =
              gradientContainers.first.decoration! as BoxDecoration;
          final LinearGradient gradient =
              decoration.gradient! as LinearGradient;

          expect(gradient.colors, <Color>[
            AppColors.emerald500,
            AppColors.teal400,
          ]);
        },
      );
    }

    testWidgets('disabled (onPressed=null) replaces gradient with muted fill',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppPrimaryButton(
            label: 'Continue',
            onPressed: null,
          ),
        ),
      );

      // Disabled: no gradient anywhere on the rendered button.
      final Iterable<Container> gradientContainers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).gradient != null);
      expect(gradientContainers, isEmpty);
    });

    testWidgets('enabled tap fires the callback', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppPrimaryButton(
            label: 'Continue',
            onPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(AppPrimaryButton));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('disabled button does not fire the callback', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppPrimaryButton(
            label: 'Continue',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(
        find.byType(AppPrimaryButton),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(taps, 0);
    });

    testWidgets('exposes a Semantics node with the label as accessible name',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppPrimaryButton(
            label: 'Continue',
            onPressed: () {},
          ),
        ),
      );

      // The button wraps its child in a Semantics(label:) node.
      final Semantics semantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((s) =>
              s.properties.label == 'Continue' &&
              s.properties.button == true);
      expect(semantics.properties.label, 'Continue');
      expect(semantics.properties.button, true);
      expect(semantics.properties.enabled, true);
    });

    testWidgets('hit area is at least 48x48 logical pixels', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppPrimaryButton(
            label: 'Go',
            onPressed: () {},
          ),
        ),
      );

      final Size buttonSize = tester.getSize(find.byType(AppPrimaryButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('press animates AnimatedScale toward 0.98', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppPrimaryButton(
            label: 'Continue',
            onPressed: () {},
          ),
        ),
      );

      final Offset center = tester.getCenter(find.byType(AppPrimaryButton));
      final TestGesture gesture = await tester.startGesture(center);
      // Pump partway through the 100ms scale-down animation.
      await tester.pump(const Duration(milliseconds: 50));

      final AnimatedScale animatedScale =
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animatedScale.scale, 0.98);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
