import 'package:drive_care_plus/widgets/ui/_hit_target_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the internal `HitTargetFloor` wrapper.
///
/// Validates the contract spelled out in figma-ui-redesign Requirements
/// 3.10 and 13.3: any interactive surface wrapped in `HitTargetFloor` is
/// rendered with a gesture region of at least `48 x 48` logical pixels,
/// regardless of the child's intrinsic size.
void main() {
  Widget hostApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets(
    'HitTargetFloor enlarges a smaller child to the 48x48 floor',
    (tester) async {
      const Key childKey = Key('tiny-child');

      await tester.pumpWidget(
        hostApp(
          const HitTargetFloor(
            child: SizedBox(
              key: childKey,
              width: 12,
              height: 12,
            ),
          ),
        ),
      );

      // The visible child stays at its intrinsic 12 x 12 size; the floor
      // is enforced by the wrapper around it, not by stretching the
      // child.
      final Size childSize = tester.getSize(find.byKey(childKey));
      expect(childSize.width, 12.0);
      expect(childSize.height, 12.0);

      // The wrapper itself reports a rendered size at or above the floor.
      final Size wrapperSize = tester.getSize(find.byType(HitTargetFloor));
      expect(wrapperSize.width, greaterThanOrEqualTo(HitTargetFloor.minSize));
      expect(wrapperSize.height, greaterThanOrEqualTo(HitTargetFloor.minSize));
    },
  );

  testWidgets(
    'HitTargetFloor does not shrink a child larger than 48x48',
    (tester) async {
      const Key childKey = Key('big-child');

      await tester.pumpWidget(
        hostApp(
          const HitTargetFloor(
            child: SizedBox(
              key: childKey,
              width: 120,
              height: 80,
            ),
          ),
        ),
      );

      final Size childSize = tester.getSize(find.byKey(childKey));
      expect(childSize.width, 120.0);
      expect(childSize.height, 80.0);

      final Size wrapperSize = tester.getSize(find.byType(HitTargetFloor));
      expect(wrapperSize.width, 120.0);
      expect(wrapperSize.height, 80.0);
    },
  );

  test('HitTargetFloor.minSize equals the 48-logical-pixel floor', () {
    // Sanity check so the contract is anchored in code rather than only
    // in the rendered size assertions above.
    expect(HitTargetFloor.minSize, 48.0);
  });
}
