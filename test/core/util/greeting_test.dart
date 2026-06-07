// Feature: figma-ui-redesign, Property 4: greeting function
//
// Validates: Requirements 4.1, 4.2
//
// `getGreeting(int hour24, String? firstName)` is a pure helper used by the
// home/cockpit greeting header. The function must satisfy two rules:
//
//   Rule A — greeting prefix is fully determined by `hour24`:
//     6  <= h <= 11   → "Good morning"
//     12 <= h <= 17   → "Good afternoon"
//     else            → "Good evening"
//   (Requirement 4.1)
//
//   Rule B — name part is derived from `firstName`:
//     null OR empty OR whitespace-only → "there"
//     otherwise                        → firstName.trim()
//   (Requirement 4.2)
//
//   The full return value is `"<prefix>, <namePart>"` — comma plus a single
//   space between the two pieces.
//
// The property body asserts the full equality plus the two boundary
// invariants requested by the task:
//   1. `result == "<expectedPrefix>, <expectedNamePart>"`.
//   2. `result.startsWith(expectedPrefix)`.
//   3. `result.endsWith(expectedNamePart)`.
//
// Generators:
//   - `hour ∈ [0, 23]` via `any.intInRange(0, 24)`. The Glados range is
//     `[min, max)`, so `(0, 24)` yields integers 0..23 inclusive (24 hours).
//   - `firstName: String?` via `any.stringOf(_firstNameCharset).nullable`
//     where the charset includes whitespace (' ', '\t', '\n'), the full
//     letter range (a..z, A..Z), digits (0..9), and a few punctuation
//     characters. Because `stringOf` is built on `list(choose(...))` it can
//     produce an empty list (`''`), a list containing only whitespace
//     characters (whitespace-only strings), or any mix of letters/digits/
//     whitespace/punctuation (arbitrary strings). Wrapping it in `.nullable`
//     adds `null` to the input space, giving full coverage of all four
//     `firstName` cases the task calls out.
//
// Glados is configured for 200 runs to comfortably exceed the 100-iteration
// minimum required by the task.

import 'package:drive_care_plus/core/util/greeting.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`. Mirrors the pattern
// used by `test/core/theme/color_utils_test.dart`.
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

/// Character pool fed to `any.stringOf(...)` for the `firstName` generator.
/// The pool is intentionally a mix of:
///   - whitespace (' ', '\t', '\n') so whitespace-only strings can appear,
///   - lowercase letters a..z and uppercase letters A..Z,
///   - digits 0..9,
///   - punctuation `-`, `'`, `.` (common in real names like O'Brien, Anne-Marie).
const String _firstNameCharset =
    ' \t\nabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-\'.';

/// Reference implementation of the prefix rule (Requirement 4.1). Mirrors
/// the branch logic in `getGreeting` exactly so the property body asserts
/// equality of two independently-derived values.
String _expectedPrefix(int hour24) {
  if (hour24 >= 6 && hour24 <= 11) return 'Good morning';
  if (hour24 >= 12 && hour24 <= 17) return 'Good afternoon';
  return 'Good evening';
}

/// Reference implementation of the name-part rule (Requirement 4.2). Mirrors
/// the branch logic in `getGreeting` exactly so the property body asserts
/// equality of two independently-derived values.
String _expectedNamePart(String? firstName) {
  if (firstName == null || firstName.trim().isEmpty) return 'there';
  return firstName.trim();
}

void main() {
  Glados2<int, String?>(
    any.intInRange(0, 24),
    any.stringOf(_firstNameCharset).nullable,
    ExploreConfig(numRuns: 200),
  ).test(
    'getGreeting(hour, firstName): output equals "<prefix>, <namePart>"; '
    'starts with the hour-derived prefix; ends with firstName.trim() or '
    '"there" per the rule',
    (hour, firstName) {
      final String result = getGreeting(hour, firstName);

      final String expectedPrefix = _expectedPrefix(hour);
      final String expectedNamePart = _expectedNamePart(firstName);
      final String expectedFull = '$expectedPrefix, $expectedNamePart';

      // Property 4 — full equality. The output is exactly the prefix
      // determined by `hour` joined to the name part determined by
      // `firstName` with a literal `", "` separator.
      expect(
        result,
        equals(expectedFull),
        reason:
            'getGreeting($hour, ${firstName == null ? 'null' : '"$firstName"'}) '
            'should equal "$expectedFull"',
      );

      // Property 4 — startsWith the hour-derived prefix.
      expect(
        result.startsWith(expectedPrefix),
        isTrue,
        reason: 'output should start with prefix "$expectedPrefix"',
      );

      // Property 4 — endsWith the expected name part (`firstName.trim()` or
      // the literal `"there"` fallback).
      expect(
        result.endsWith(expectedNamePart),
        isTrue,
        reason: 'output should end with name part "$expectedNamePart"',
      );
    },
  );
}
