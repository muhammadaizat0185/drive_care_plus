import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/_focus_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

void main() {
  group('AppFocusIndicator', () {
    testWidgets('unfocused does not render outline border', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: AppFocusIndicator(
            enabled: true,
            borderRadius: BorderRadius.circular(8.0),
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      // Verify no focus outline Container with border is present
      final outlineContainers = tester.widgetList<Container>(find.byType(Container)).where(
            (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).border != null,
          );
      expect(outlineContainers, isEmpty);
    });

    testWidgets('focused renders outline border in correct color for light theme', (tester) async {
      final FocusNode focusNode = FocusNode();
      await tester.pumpWidget(
        hostApp(
          brightness: Brightness.light,
          child: AppFocusIndicator(
            enabled: true,
            focusNode: focusNode,
            borderRadius: BorderRadius.circular(8.0),
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Verify focus outline Container with border is present and correct
      final outlineContainers = tester.widgetList<Container>(find.byType(Container)).where(
            (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).border != null,
          );
      expect(outlineContainers, isNotEmpty);

      final decoration = outlineContainers.first.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.emerald500);
      expect(border.top.width, 2.0);
      expect(decoration.borderRadius, BorderRadius.circular(8.0));
      
      focusNode.dispose();
    });

    testWidgets('focused renders outline border in correct color for dark theme', (tester) async {
      final FocusNode focusNode = FocusNode();
      await tester.pumpWidget(
        hostApp(
          brightness: Brightness.dark,
          child: AppFocusIndicator(
            enabled: true,
            focusNode: focusNode,
            borderRadius: BorderRadius.circular(8.0),
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Verify focus outline Container with border is present and correct
      final outlineContainers = tester.widgetList<Container>(find.byType(Container)).where(
            (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).border != null,
          );
      expect(outlineContainers, isNotEmpty);

      final decoration = outlineContainers.first.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.teal400);
      expect(border.top.width, 2.0);
      expect(decoration.borderRadius, BorderRadius.circular(8.0));
      
      focusNode.dispose();
    });
  });
}
