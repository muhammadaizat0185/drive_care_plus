// Feature: figma-ui-redesign, Property 1: dark-mode shadow opacity scaling
//
// Validates: Requirements 1.8
//
// `scaleShadowOpacity` must be a pure transformation that scales every
// shadow's color opacity by the supplied factor and clamps the result to
// `[0.0, 1.0]`, while preserving every other field of every shadow exactly
// (RGB channels, blur radius, spread radius, offset, blur style).
//
// Property 1 specifically targets the dark-mode multiplier (`2.5`) used by
// `AppTheme.buildTheme` to derive dark-mode shadows from the light-mode
// authoritative `AppShadows.{small, medium, large, xLarge}` tokens.
//
// Generators are constrained to realistic Flutter `BoxShadow` value ranges:
//   - alpha           ∈ [0.0, 1.0]
//   - red/green/blue  ∈ [0.0, 1.0]
//   - blurRadius      ∈ [0.0, 100.0]
//   - spreadRadius    ∈ [-10.0, 100.0]
//   - offset.dx, .dy  ∈ [-100.0, 100.0]
//
// Glados is configured for 200 runs to comfortably exceed the 100-iteration
// minimum required by the task.

import 'package:drive_care_plus/core/theme/color_utils.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`.
import 'package:glados/glados.dart'
    hide
        expect,
        equals,
        closeTo,
        isFalse,
        inInclusiveRange,
        test,
        group,
        setUp,
        tearDown,
        setUpAll,
        tearDownAll,
        addTearDown;

/// Holder used by the multi-field combinator below. Records every input
/// component independently so the property body can rebuild the original
/// `BoxShadow` and assert per-field preservation.
class _ShadowSpec {
  const _ShadowSpec({
    required this.alpha,
    required this.red,
    required this.green,
    required this.blue,
    required this.blurRadius,
    required this.spreadRadius,
    required this.dx,
    required this.dy,
  });

  final double alpha;
  final double red;
  final double green;
  final double blue;
  final double blurRadius;
  final double spreadRadius;
  final double dx;
  final double dy;

  BoxShadow toBoxShadow() {
    return BoxShadow(
      color: Color.from(alpha: alpha, red: red, green: green, blue: blue),
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
      offset: Offset(dx, dy),
    );
  }
}

Generator<_ShadowSpec> _shadowSpecGenerator() {
  // `combine8` keeps each field a first-class shrinkable axis so Glados can
  // pinpoint which component breaks the property if shrinking occurs.
  return any.combine8<double, double, double, double, double, double, double,
      double, _ShadowSpec>(
    any.doubleInRange(0.0, 1.0),
    any.doubleInRange(0.0, 1.0),
    any.doubleInRange(0.0, 1.0),
    any.doubleInRange(0.0, 1.0),
    any.doubleInRange(0.0, 100.0),
    any.doubleInRange(-10.0, 100.0),
    any.doubleInRange(-100.0, 100.0),
    any.doubleInRange(-100.0, 100.0),
    (alpha, red, green, blue, blurRadius, spreadRadius, dx, dy) => _ShadowSpec(
      alpha: alpha,
      red: red,
      green: green,
      blue: blue,
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
      dx: dx,
      dy: dy,
    ),
  );
}

void main() {
  Glados<_ShadowSpec>(
    _shadowSpecGenerator(),
    ExploreConfig(numRuns: 200),
  ).test(
    'scaleShadowOpacity([s], 2.5): alpha clamps to min(1.0, alpha * 2.5); '
    'all other fields preserved exactly',
    (spec) {
      final BoxShadow input = spec.toBoxShadow();
      final List<BoxShadow> result = scaleShadowOpacity([input], 2.5);

      // The input list has length 1, so the output list must have length 1.
      expect(result.length, 1);
      final BoxShadow out = result.single;

      // Property: opacity equals (alpha * 2.5) clamped to [0.0, 1.0].
      // Since the generated alpha is in [0.0, 1.0] and the factor (2.5) is
      // positive, this is equivalent to min(1.0, alpha * 2.5).
      final double expectedAlpha = (spec.alpha * 2.5).clamp(0.0, 1.0);
      expect(out.color.a, closeTo(expectedAlpha, 1e-9));
      expect(out.color.a, inInclusiveRange(0.0, 1.0));

      // Property: every other field is preserved exactly.
      expect(out.color.r, equals(input.color.r), reason: 'red preserved');
      expect(out.color.g, equals(input.color.g), reason: 'green preserved');
      expect(out.color.b, equals(input.color.b), reason: 'blue preserved');
      expect(out.color.colorSpace, equals(input.color.colorSpace),
          reason: 'colorSpace preserved');
      expect(out.blurRadius, equals(input.blurRadius),
          reason: 'blurRadius preserved');
      expect(out.spreadRadius, equals(input.spreadRadius),
          reason: 'spreadRadius preserved');
      expect(out.offset, equals(input.offset), reason: 'offset preserved');
      expect(out.blurStyle, equals(input.blurStyle),
          reason: 'blurStyle preserved');

      // Purity: the input list and its element are not mutated.
      expect(input.color.a, equals(spec.alpha),
          reason: 'input shadow alpha unchanged');

      // The returned list must be a fresh allocation, not the input list.
      final List<BoxShadow> inputList = [input];
      final List<BoxShadow> result2 = scaleShadowOpacity(inputList, 2.5);
      expect(identical(result2, inputList), isFalse,
          reason: 'a fresh list is allocated');
    },
  );
}
