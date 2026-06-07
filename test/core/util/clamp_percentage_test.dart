// Feature: figma-ui-redesign, Property 5: percentage clamp
//
// Validates: Requirements 4.3, 8.2
//
// `clampPercentage(double? value)` is a pure helper that normalises a raw
// `double?` percentage value into a safe `int?` in the inclusive range
// `[0, 100]`. The four-branch rule is:
//
//   value == null            → null
//   value is not finite      → null   (NaN, +infinity, -infinity)
//   otherwise (finite)       → value.clamp(0.0, 100.0).round()
//                               which is guaranteed to land in [0, 100].
//
// The universal property the task asks us to assert is:
//
//   For any `double` input (including `NaN`, ±infinity, negatives, > 100),
//   the result is either `null` OR in the inclusive integer range
//   `[0, 100]`.
//
// The property body asserts both halves of that disjunction together with
// the per-branch invariant required by the spec rule, by independently
// re-deriving the expected output from the input:
//
//   * If `value == null` or `!value.isFinite`, the expected output is
//     `null`. We assert `actual == null`.
//   * Otherwise the expected output is `value.clamp(0.0, 100.0).round()`,
//     which by construction is an `int` in `[0, 100]`. We assert
//     `actual == expected` AND `0 <= actual <= 100`.
//
// Generators:
//   - `value: double` via `any.double`. The Glados standard double
//     generator is `doubleInRange(null, null)`, which produces values in
//     `[-size, size)` where `size` is the run's size parameter (typically
//     up to ~100). This covers negatives, zero, positives, and values
//     greater than 100, exercising every branch of the `clamp` rule for
//     finite inputs.
//   - The Glados `any.double` generator never emits `NaN`, `+infinity`,
//     or `-infinity`, so the non-finite branch is exercised by the
//     dedicated unit tests below (`clampPercentage(double.nan)`,
//     `clampPercentage(double.infinity)`,
//     `clampPercentage(double.negativeInfinity)`). The unit tests also
//     pin the `null` and representative finite cases the task calls out
//     explicitly.
//
// Glados is configured for 200 runs to comfortably exceed the
// 100-iteration minimum required by the task.

import 'package:drive_care_plus/core/util/clamp_percentage.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`. Mirrors the
// pattern used by `test/core/util/greeting_test.dart`,
// `test/core/util/format_bytes_test.dart`, and
// `test/core/util/expiry_test.dart`.
import 'package:glados/glados.dart'
    hide
        expect,
        equals,
        isFalse,
        isTrue,
        isNotNull,
        isNull,
        inInclusiveRange,
        test,
        group,
        setUp,
        tearDown,
        setUpAll,
        tearDownAll,
        addTearDown;

/// Reference implementation of the four-branch rule (Requirements 4.3,
/// 8.2). Mirrors the branch logic in [clampPercentage] exactly so the
/// property body asserts equality of two independently-derived values.
int? _expectedClamp(double? value) {
  if (value == null) return null;
  if (!value.isFinite) return null;
  return value.clamp(0.0, 100.0).round();
}

void main() {
  // ---------------------------------------------------------------------
  // Property 5 — Glados-driven property test over arbitrary finite doubles.
  // ---------------------------------------------------------------------
  //
  // The disjunctive postcondition `result == null OR result in [0, 100]`
  // is asserted alongside the stronger per-branch equality with the
  // independently-derived reference value, so any future regression that
  // returns the wrong integer (e.g. `value.toInt()` truncating instead of
  // `round()`-ing, or skipping the clamp) is caught even when the value
  // happens to fall in `[0, 100]` by accident.
  Glados<double>(
    any.double,
    ExploreConfig(numRuns: 200),
  ).test(
    'clampPercentage(value): result is null or an int in [0, 100], '
    'and equals value.clamp(0,100).round() when value is finite',
    (value) {
      final int? actual = clampPercentage(value);
      final int? expected = _expectedClamp(value);

      // Property 5 — full equality with the reference rule.
      expect(
        actual,
        equals(expected),
        reason:
            'clampPercentage($value) should equal $expected per the '
            'documented rule (null/non-finite → null; finite → '
            'value.clamp(0,100).round())',
      );

      // Property 5 — disjunctive postcondition. For every input, the
      // result is either `null` or in the inclusive integer range
      // `[0, 100]`. The Glados standard double generator only emits
      // finite values, so for this property iteration the result is
      // always non-null and in `[0, 100]`; the null branch is covered
      // by the unit tests below.
      if (actual == null) {
        // Null is a valid output — only allowed when the input is
        // null or non-finite. The Glados generator never emits those,
        // so this branch is unreachable for the property body.
        expect(
          value.isFinite,
          isFalse,
          reason:
              'clampPercentage($value) returned null but $value is finite — '
              'finite inputs must produce a clamped int in [0, 100]',
        );
      } else {
        expect(
          actual,
          inInclusiveRange(0, 100),
          reason:
              'clampPercentage($value) = $actual must be in [0, 100]',
        );
      }
    },
  );

  // ---------------------------------------------------------------------
  // Special-case unit tests — pin the inputs the property generator
  // cannot reach (null, NaN, ±infinity) and the representative finite
  // cases called out by the task (-50.0, 150.0, 50.0).
  // ---------------------------------------------------------------------
  group('clampPercentage special cases', () {
    test('null input returns null', () {
      expect(clampPercentage(null), isNull);
    });

    test('NaN returns null', () {
      expect(clampPercentage(double.nan), isNull);
    });

    test('+infinity returns null', () {
      expect(clampPercentage(double.infinity), isNull);
    });

    test('-infinity returns null', () {
      expect(clampPercentage(double.negativeInfinity), isNull);
    });

    test('negative finite value clamps to 0', () {
      expect(clampPercentage(-50.0), equals(0));
    });

    test('value greater than 100 clamps to 100', () {
      expect(clampPercentage(150.0), equals(100));
    });

    test('value within range round-trips unchanged', () {
      expect(clampPercentage(50.0), equals(50));
    });
  });
}
