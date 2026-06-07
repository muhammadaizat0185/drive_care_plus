// Feature: figma-ui-redesign, Property 21: formatBytes unit selection
//
// Validates: Requirements 10.3
//
// `formatBytes(int bytes)` is a pure helper that renders a byte count as a
// one-decimal-place numeric value followed by a suffix selected by
// power-of-1024 thresholds:
//
//   bytes < 1024              → "<bytes / 1>.0 B"
//   bytes < 1024 * 1024       → "<bytes / 1024 to 1dp> KB"
//   bytes >= 1024 * 1024      → "<bytes / (1024 * 1024) to 1dp> MB"
//
// The numeric portion is always produced via [num.toStringAsFixed] with
// exactly one decimal place, and the value and suffix are separated by a
// single ASCII space.
//
// The property body asserts:
//   1. The output splits cleanly into `[numericPart, suffix]` on the first
//      space character.
//   2. The suffix matches the threshold rule (`B`, `KB`, or `MB`) given
//      the input `bytes`.
//   3. The numeric portion equals `(bytes / divisor).toStringAsFixed(1)`,
//      i.e. it is `bytes` divided by the suffix-implied divisor (1, 1024,
//      or 1024*1024) rounded to one decimal place.
//
// Generators:
//   - `bytes ∈ [0, 100_000_000]` via `any.intInRange(0, 100_000_001)`.
//     Glados ranges are `[min, max)`, so `(0, 100_000_001)` yields integers
//     0..100_000_000 inclusive (100 MB). This range is the documented
//     fallback in the task's implementation guidance — Glados internally
//     uses `Random.nextInt(max - min)` whose argument is bounded by
//     `1 << 32`, so the requirement-stated 10^12 upper bound exceeds the
//     generator's practical limit. 100 MB still covers all three threshold
//     branches: the `B` branch (bytes < 1024), the `KB` branch
//     (1024 <= bytes < 1024*1024), and the `MB` branch (bytes >= 1024*1024).
//
// Glados is configured for 200 runs to comfortably exceed the 100-iteration
// minimum required by the task.

import 'package:drive_care_plus/core/util/format_bytes.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`. Mirrors the pattern
// used by `test/core/util/greeting_test.dart`.
import 'package:glados/glados.dart'
    hide
        expect,
        equals,
        isFalse,
        isTrue,
        isNotNull,
        inInclusiveRange,
        test,
        group,
        setUp,
        tearDown,
        setUpAll,
        tearDownAll,
        addTearDown;

/// Threshold constants — mirror the literals used inside [formatBytes].
const int _kKb = 1024;
const int _kMb = 1024 * 1024;

/// Reference implementation of the suffix rule. Mirrors the branch logic
/// in [formatBytes] exactly so the property body asserts equality of two
/// independently-derived values.
String _expectedSuffix(int bytes) {
  if (bytes < _kKb) return 'B';
  if (bytes < _kMb) return 'KB';
  return 'MB';
}

/// Reference implementation of the divisor rule, paired with [_expectedSuffix].
int _expectedDivisor(int bytes) {
  if (bytes < _kKb) return 1;
  if (bytes < _kMb) return _kKb;
  return _kMb;
}

void main() {
  Glados<int>(
    any.intInRange(0, 100000001),
    ExploreConfig(numRuns: 200),
  ).test(
    'formatBytes(bytes): suffix matches the power-of-1024 threshold rule '
    'and the numeric portion equals (bytes / divisor) rendered to one '
    'decimal place',
    (bytes) {
      final String result = formatBytes(bytes);

      // Property 21 — output structure. The result must split into exactly
      // two pieces on the first space: the numeric portion and the suffix.
      final List<String> parts = result.split(' ');
      expect(
        parts.length,
        equals(2),
        reason:
            'formatBytes($bytes) = "$result" should contain exactly one '
            'space separating the numeric value and the unit suffix',
      );

      final String numericPart = parts[0];
      final String suffix = parts[1];

      // Property 21 — suffix matches the threshold rule.
      final String expectedSuffix = _expectedSuffix(bytes);
      expect(
        suffix,
        equals(expectedSuffix),
        reason:
            'formatBytes($bytes) suffix should be "$expectedSuffix" per the '
            'power-of-1024 threshold rule',
      );

      // Property 21 — numeric portion equals (bytes / divisor) rendered to
      // one decimal place. Compare both as strings (the format the helper
      // emits) and as doubles within a tight epsilon to guard against any
      // future locale-sensitive rendering changes.
      final int divisor = _expectedDivisor(bytes);
      final double expectedValue = bytes / divisor;
      final String expectedNumericString = expectedValue.toStringAsFixed(1);

      expect(
        numericPart,
        equals(expectedNumericString),
        reason:
            'formatBytes($bytes) numeric part should equal '
            '"(bytes / $divisor).toStringAsFixed(1)" = '
            '"$expectedNumericString"',
      );

      // Defensive double-equality check: parsing the emitted numeric portion
      // must round-trip to within 0.05 of the expected value, the maximum
      // representable error after rounding to one decimal place.
      final double parsed = double.parse(numericPart);
      expect(
        (parsed - expectedValue).abs() <= 0.05,
        isTrue,
        reason:
            'formatBytes($bytes) parsed numeric value $parsed should be '
            'within 0.05 of expected $expectedValue',
      );
    },
  );
}
