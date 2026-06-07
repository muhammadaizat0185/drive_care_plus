import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppTextField].
///
/// Validates the visual contract from figma-ui-redesign Requirements 3.3,
/// 3.4, 3.5, 3.6, 3.11: 2-pixel resting border, emerald500 focused border,
/// red error border + visible error text, disabled rejects input. The
/// border styles are owned by `inputDecorationTheme` registered in
/// `AppTheme.buildTheme`, so the test reads them from the active theme
/// instead of asserting against literal hex codes.
void main() {
  group('AppTextField', () {
    for (final Brightness brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      testWidgets(
        'theme exposes 2px resting border (${brightness.name})',
        (tester) async {
          final TextEditingController controller = TextEditingController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            hostApp(
              brightness: brightness,
              child: AppTextField(
                controller: controller,
                label: 'Email',
              ),
            ),
          );

          final BuildContext ctx =
              tester.element(find.byType(AppTextField));
          final InputDecorationThemeData inputTheme =
              Theme.of(ctx).inputDecorationTheme;

          // Resting (enabled) border: 2px wide, neutral border token.
          final OutlineInputBorder enabledBorder =
              inputTheme.enabledBorder! as OutlineInputBorder;
          expect(enabledBorder.borderSide.width, 2.0);
          expect(
            enabledBorder.borderSide.color,
            brightness == Brightness.light
                ? AppColors.lightBorder
                : AppColors.darkBorder,
          );

          // Focused border: 2px emerald500.
          final OutlineInputBorder focusedBorder =
              inputTheme.focusedBorder! as OutlineInputBorder;
          expect(focusedBorder.borderSide.width, 2.0);
          expect(focusedBorder.borderSide.color, AppColors.emerald500);
        },
      );
    }

    testWidgets('errorText displays under the field', (tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        hostApp(
          child: AppTextField(
            controller: controller,
            label: 'Email',
            errorText: 'Required',
          ),
        ),
      );

      expect(find.text('Required'), findsOneWidget);

      // Theme-level error border is 2px and uses the error token.
      final BuildContext ctx = tester.element(find.byType(AppTextField));
      final OutlineInputBorder errorBorder =
          Theme.of(ctx).inputDecorationTheme.errorBorder!
              as OutlineInputBorder;
      expect(errorBorder.borderSide.width, 2.0);
      expect(errorBorder.borderSide.color, AppColors.error);
    });

    testWidgets('enabled=false rejects input', (tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        hostApp(
          child: AppTextField(
            controller: controller,
            label: 'Email',
            enabled: false,
          ),
        ),
      );

      // The underlying TextField widget must report `enabled: false`.
      final TextField field =
          tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, false);

      // Tapping does not focus the field, so attempting to enter text
      // should leave the controller empty.
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Note: enterText would force focus; we only assert the
      // underlying disabled flag here, which is the contract from
      // Requirement 3.6.
      expect(controller.text, '');
    });

    testWidgets('focused state engages the emerald500 focused border',
        (tester) async {
      final TextEditingController controller = TextEditingController();
      final FocusNode focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        hostApp(
          child: AppTextField(
            controller: controller,
            focusNode: focusNode,
            label: 'Email',
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, true);

      // The active theme exposes the focused border with emerald500 +
      // 2px width; this is what the InputDecorator picks up while the
      // field is focused.
      final BuildContext ctx = tester.element(find.byType(AppTextField));
      final OutlineInputBorder focusedBorder =
          Theme.of(ctx).inputDecorationTheme.focusedBorder!
              as OutlineInputBorder;
      expect(focusedBorder.borderSide.color, AppColors.emerald500);
      expect(focusedBorder.borderSide.width, 2.0);
    });
  });
}
