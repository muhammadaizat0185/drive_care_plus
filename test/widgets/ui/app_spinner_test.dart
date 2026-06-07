import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppSpinner].
///
/// Validates Requirement 3.11 contract: renders a sized
/// `CircularProgressIndicator` whose `valueColor` is the explicit
/// `color` override or the brand `emerald500` default.
void main() {
  group('AppSpinner', () {
    testWidgets('default tint is emerald500 and size is 24', (tester) async {
      await tester.pumpWidget(
        hostApp(child: const AppSpinner()),
      );

      final SizedBox box = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(box.width, 24.0);
      expect(box.height, 24.0);

      final CircularProgressIndicator indicator =
          tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      final AlwaysStoppedAnimation<Color> tint =
          indicator.valueColor! as AlwaysStoppedAnimation<Color>;
      expect(tint.value, AppColors.emerald500);
    });

    testWidgets('custom color overrides the default', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppSpinner(color: Colors.white, size: 16),
        ),
      );

      final CircularProgressIndicator indicator =
          tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      final AlwaysStoppedAnimation<Color> tint =
          indicator.valueColor! as AlwaysStoppedAnimation<Color>;
      expect(tint.value, Colors.white);

      final SizedBox box = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(box.width, 16.0);
      expect(box.height, 16.0);
    });
  });
}
