import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppToggleSwitch].
///
/// Validates Requirement 3.10 / 3.11 / 3.12 / 13.3 contract: track shows
/// the brand gradient when on, gestures fire `onChanged`, disabled state
/// rejects taps, hit area ≥ 48x48.
void main() {
  /// Returns the gradient on the AnimatedContainer track, if any.
  Gradient? _trackGradient(WidgetTester tester) {
    final AnimatedContainer container = tester
        .widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    return decoration.gradient;
  }

  Color? _trackColor(WidgetTester tester) {
    final AnimatedContainer container = tester
        .widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    return decoration.color;
  }

  group('AppToggleSwitch', () {
    testWidgets('value=true renders brand gradient track', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppToggleSwitch(
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      // Allow the AnimatedContainer to settle.
      await tester.pumpAndSettle();

      final Gradient? gradient = _trackGradient(tester);
      expect(gradient, isA<LinearGradient>());
      expect(
        (gradient! as LinearGradient).colors,
        <Color>[AppColors.emerald500, AppColors.teal400],
      );
    });

    testWidgets('value=false renders muted border track without gradient',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppToggleSwitch(
            value: false,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_trackGradient(tester), isNull);
      expect(_trackColor(tester), AppColors.lightBorder);
    });

    testWidgets('tap fires onChanged with the inverted value',
        (tester) async {
      bool? captured;
      await tester.pumpWidget(
        hostApp(
          child: AppToggleSwitch(
            value: false,
            onChanged: (v) => captured = v,
          ),
        ),
      );

      await tester.tap(find.byType(AppToggleSwitch));
      await tester.pumpAndSettle();

      expect(captured, true);
    });

    testWidgets('disabled (onChanged=null) rejects taps and uses muted track',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppToggleSwitch(
            value: true,
            onChanged: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No gradient when disabled.
      expect(_trackGradient(tester), isNull);
      // Track uses the muted token (light-mode muted is lightMuted).
      expect(_trackColor(tester), AppColors.lightMuted);

      await tester.tap(
        find.byType(AppToggleSwitch),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      // No callback to assert against — disabled state must not throw.
    });

    testWidgets('hit area is at least 48x48 logical pixels', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppToggleSwitch(
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      final Size size = tester.getSize(find.byType(AppToggleSwitch));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}
