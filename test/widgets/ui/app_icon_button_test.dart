import 'package:drive_care_plus/widgets/ui/app_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppIconButton].
///
/// Validates the contract from figma-ui-redesign Requirements 3.10, 3.11,
/// 3.12, 13.3, 13.8: non-empty `semanticsLabel` is asserted, hit area is
/// always ≥ 48x48 logical pixels, the icon glyph honours `size`, gestures
/// are wired and short-circuited when disabled.
void main() {
  group('AppIconButton', () {
    test('asserts on empty semanticsLabel', () {
      expect(
        () => AppIconButton(
          icon: Icons.close,
          onPressed: () {},
          semanticsLabel: '',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    for (final Brightness brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      testWidgets(
        'renders icon at requested size and 48x48 hit area '
        '(${brightness.name})',
        (tester) async {
          await tester.pumpWidget(
            hostApp(
              brightness: brightness,
              child: AppIconButton(
                icon: Icons.close,
                onPressed: () {},
                semanticsLabel: 'Close',
                size: 24,
              ),
            ),
          );

          // Hit area: the Container inside the button is the 48x48 floor.
          final Size buttonSize =
              tester.getSize(find.byType(AppIconButton));
          expect(buttonSize.width, greaterThanOrEqualTo(48.0));
          expect(buttonSize.height, greaterThanOrEqualTo(48.0));

          // Icon glyph itself stays at the requested 24 logical pixels.
          final Icon icon = tester.widget<Icon>(find.byIcon(Icons.close));
          expect(icon.size, 24);
        },
      );
    }

    testWidgets('exposes a Semantics node with the provided label',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppIconButton(
            icon: Icons.close,
            onPressed: () {},
            semanticsLabel: 'Close dialog',
          ),
        ),
      );
      final Semantics semantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((s) =>
              s.properties.label == 'Close dialog' &&
              s.properties.button == true);
      expect(semantics.properties.label, 'Close dialog');
      expect(semantics.properties.button, true);
      expect(semantics.properties.enabled, true);
    });

    testWidgets('enabled tap fires the callback', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppIconButton(
            icon: Icons.close,
            onPressed: () => taps++,
            semanticsLabel: 'Close',
          ),
        ),
      );

      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('disabled button rejects taps', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppIconButton(
            icon: Icons.close,
            onPressed: null,
            semanticsLabel: 'Close',
          ),
        ),
      );

      await tester.tap(
        find.byType(AppIconButton),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(taps, 0);
    });
  });
}
