import 'package:drive_care_plus/widgets/ui/app_phone_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppPhoneStatusBar].
///
/// Validates Requirement 3.11 contract: 24-logical-pixel-tall band that
/// fills the available width.
void main() {
  group('AppPhoneStatusBar', () {
    for (final Brightness brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      testWidgets(
        'renders a 24-pixel-tall SizedBox (${brightness.name})',
        (tester) async {
          await tester.pumpWidget(
            hostApp(
              brightness: brightness,
              child: AppPhoneStatusBar(brightness: brightness),
            ),
          );

          // The widget itself reports a 24-pixel intrinsic height, even
          // though `width: double.infinity` lets it stretch.
          final SizedBox sizedBox = tester.widget<SizedBox>(
            find.descendant(
              of: find.byType(AppPhoneStatusBar),
              matching: find.byType(SizedBox),
            ).first,
          );
          expect(sizedBox.height, 24.0);
          expect(sizedBox.width, double.infinity);

          // The rendered band is 24 logical pixels tall.
          final Size renderedSize =
              tester.getSize(find.byType(AppPhoneStatusBar));
          expect(renderedSize.height, 24.0);
        },
      );
    }
  });
}
