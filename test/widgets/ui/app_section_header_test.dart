import 'package:drive_care_plus/widgets/ui/app_section_header.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppSectionHeader].
///
/// Validates Requirement 3.11 contract: caller-provided label is rendered
/// uppercased.
void main() {
  group('AppSectionHeader', () {
    testWidgets('uppercases mixed-case label', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppSectionHeader(label: 'Privacy & Security'),
        ),
      );
      expect(find.text('PRIVACY & SECURITY'), findsOneWidget);
      expect(find.text('Privacy & Security'), findsNothing);
    });

    testWidgets('already-uppercase label remains uppercase', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppSectionHeader(label: 'GENERAL'),
        ),
      );
      expect(find.text('GENERAL'), findsOneWidget);
    });
  });
}
