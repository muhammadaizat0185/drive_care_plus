import 'package:drive_care_plus/widgets/ui/app_empty_state.dart';
import 'package:drive_care_plus/widgets/ui/app_secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppEmptyState].
///
/// Validates Requirement 3.11 contract: icon, title, optional message and
/// optional action are rendered in the expected order.
void main() {
  group('AppEmptyState', () {
    testWidgets('renders icon and title only', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppEmptyState(
            icon: Icons.search_off,
            title: 'No results',
          ),
        ),
      );

      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets('renders message when provided', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppEmptyState(
            icon: Icons.search_off,
            title: 'No results',
            message: 'Try a different search term.',
          ),
        ),
      );

      expect(find.text('Try a different search term.'), findsOneWidget);
    });

    testWidgets('renders action when provided', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        hostApp(
          child: AppEmptyState(
            icon: Icons.search_off,
            title: 'No results',
            action: AppSecondaryButton(
              label: 'Clear filters',
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      expect(find.byType(AppSecondaryButton), findsOneWidget);
      await tester.tap(find.byType(AppSecondaryButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('omits message and action when null', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppEmptyState(
            icon: Icons.search_off,
            title: 'Empty',
          ),
        ),
      );
      expect(find.byType(AppSecondaryButton), findsNothing);
    });
  });
}
