import 'package:drive_care_plus/widgets/ui/app_skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// Widget tests for [AppSkeletonLoader].
///
/// Validates Requirement 3.11 / 11.8 contract: when `enabled = true` the
/// child is wrapped under a shimmer overlay (rendered via
/// `AnimatedBuilder` + `DecoratedBox` + `Opacity(0)`); when `enabled =
/// false` the child is rendered untouched.
void main() {
  group('AppSkeletonLoader', () {
    testWidgets('enabled=true wraps child under shimmer overlay',
        (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppSkeletonLoader(
            child: SizedBox(
              key: Key('child'),
              width: 100,
              height: 32,
            ),
          ),
        ),
      );
      // Shimmer animates continuously; pump a single frame instead of
      // pumpAndSettle so the test does not hang.
      await tester.pump(const Duration(milliseconds: 50));

      // The shimmer overlay is built via AnimatedBuilder.
      expect(find.byType(AnimatedBuilder), findsWidgets);

      // The original child is rendered fully transparent inside Opacity.
      final Finder opacityFinder = find.ancestor(
        of: find.byKey(const Key('child')),
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsOneWidget);

      final Opacity opacity = tester.widget<Opacity>(opacityFinder.first);
      expect(opacity.opacity, 0.0);
    });

    testWidgets('enabled=false renders child as-is', (tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const AppSkeletonLoader(
            enabled: false,
            child: SizedBox(
              key: Key('child'),
              width: 100,
              height: 32,
            ),
          ),
        ),
      );

      // No Opacity(0) wrapper around the child when shimmer is off.
      final Finder opacityFinder = find.ancestor(
        of: find.byKey(const Key('child')),
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsNothing);
    });
  });
}
