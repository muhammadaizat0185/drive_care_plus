import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_badge.dart';
import 'package:drive_care_plus/widgets/ui/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppBadge].
///
/// Validates Requirement 3.11 contract: each [BadgeKind] resolves to the
/// correct background fill (or gradient) from the active color tokens.
void main() {
  Color? _backgroundOf(WidgetTester tester) {
    final Iterable<Container> containers =
        tester.widgetList<Container>(find.byType(Container));
    for (final Container c in containers) {
      if (c.decoration is BoxDecoration) {
        final BoxDecoration d = c.decoration! as BoxDecoration;
        if (d.color != null && d.color != Colors.transparent) {
          return d.color;
        }
      }
    }
    return null;
  }

  Gradient? _gradientOf(WidgetTester tester) {
    final Iterable<Container> containers =
        tester.widgetList<Container>(find.byType(Container));
    for (final Container c in containers) {
      if (c.decoration is BoxDecoration) {
        final BoxDecoration d = c.decoration! as BoxDecoration;
        if (d.gradient != null) {
          return d.gradient;
        }
      }
    }
    return null;
  }

  group('AppBadge', () {
    testWidgets('neutral renders muted background', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppBadge(text: 'Neutral'),
        ),
      );
      expect(_backgroundOf(tester), AppColors.lightMuted);
    });

    testWidgets('success renders success token background', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppBadge(text: 'OK', kind: BadgeKind.success),
        ),
      );
      expect(_backgroundOf(tester), AppColors.success);
    });

    testWidgets('warning renders warning token background', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppBadge(text: 'Hi', kind: BadgeKind.warning),
        ),
      );
      expect(_backgroundOf(tester), AppColors.warning);
    });

    testWidgets('error renders error token background', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppBadge(text: 'Bad', kind: BadgeKind.error),
        ),
      );
      expect(_backgroundOf(tester), AppColors.error);
    });

    testWidgets('info renders info token background', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppBadge(text: 'Info', kind: BadgeKind.info),
        ),
      );
      expect(_backgroundOf(tester), AppColors.info);
    });

    testWidgets(
        'brand renders emerald500→teal400 gradient, no flat background',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppBadge(text: 'NEW', kind: BadgeKind.brand),
        ),
      );

      final Gradient? gradient = _gradientOf(tester);
      expect(gradient, isA<LinearGradient>());
      expect(
        (gradient! as LinearGradient).colors,
        <Color>[AppColors.emerald500, AppColors.teal400],
      );
    });

    testWidgets('brand variant in dark mode keeps the brand gradient',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          brightness: Brightness.dark,
          child: const AppBadge(text: 'NEW', kind: BadgeKind.brand),
        ),
      );

      final Gradient? gradient = _gradientOf(tester);
      expect(gradient, isA<LinearGradient>());
    });
  });
}
