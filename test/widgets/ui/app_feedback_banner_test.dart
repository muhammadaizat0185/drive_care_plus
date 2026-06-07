import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_feedback_banner.dart';
import 'package:drive_care_plus/widgets/ui/app_icon_button.dart';
import 'package:drive_care_plus/widgets/ui/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppFeedbackBanner].
///
/// Validates Requirement 3.7 / 3.11 contract: each [FeedbackKind] resolves
/// to the correct accent (border + icon) and matching leading icon, and
/// the dismiss button is conditional on `onDismiss`.
void main() {
  /// Returns the accent color of the banner — the border color of the
  /// outermost Container that owns the banner's decoration.
  Color _accentOf(WidgetTester tester) {
    final Iterable<Container> bordered = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).border != null);
    expect(bordered, isNotEmpty);
    final Border border =
        (bordered.first.decoration! as BoxDecoration).border! as Border;
    return border.top.color;
  }

  group('AppFeedbackBanner', () {
    final List<({FeedbackKind kind, Color accent, IconData icon})> cases =
        <({FeedbackKind kind, Color accent, IconData icon})>[
      (
        kind: FeedbackKind.success,
        accent: AppColors.success,
        icon: Icons.check_circle,
      ),
      (
        kind: FeedbackKind.error,
        accent: AppColors.error,
        icon: Icons.error,
      ),
      (
        kind: FeedbackKind.warning,
        accent: AppColors.warning,
        icon: Icons.warning,
      ),
      (
        kind: FeedbackKind.info,
        accent: AppColors.info,
        icon: Icons.info,
      ),
    ];

    for (final c in cases) {
      testWidgets('${c.kind.name} renders correct accent + icon',
          (tester) async {
        await tester.pumpWidget(
          hostApp(
            child: AppFeedbackBanner(
              message: 'Hello',
              kind: c.kind,
            ),
          ),
        );

        expect(_accentOf(tester), c.accent);
        expect(find.byIcon(c.icon), findsOneWidget);
      });
    }

    testWidgets('dismiss button only renders when onDismiss provided',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppFeedbackBanner(
            message: 'Hi',
            kind: FeedbackKind.info,
          ),
        ),
      );
      expect(find.byType(AppIconButton), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.pumpWidget(
        hostApp(
          child: AppFeedbackBanner(
            message: 'Hi',
            kind: FeedbackKind.info,
            onDismiss: () {},
          ),
        ),
      );
      expect(find.byType(AppIconButton), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('tapping dismiss invokes the callback', (tester) async {
      int dismisses = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppFeedbackBanner(
            message: 'Hi',
            kind: FeedbackKind.info,
            onDismiss: () => dismisses++,
          ),
        ),
      );

      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();

      expect(dismisses, 1);
    });
  });
}
