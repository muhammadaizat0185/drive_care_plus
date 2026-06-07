// Feature: figma-ui-redesign, Property 22: expiryStatusOf classification
//
// Validates: Requirements 10.4, 10.5
//
// `expiryStatusOf(DateTime? expiry, DateTime now)` is a pure helper used by
// the document vault and other screens that surface time-sensitive items.
// It classifies an item against the current moment using a four-branch
// rule:
//
//   if expiry == null                       → ExpiryStatus.noExpiry
//   if (now - expiry).inDays > 30           → ExpiryStatus.error
//                                             (expired more than 30 days ago)
//   if |(now - expiry)|.inDays <= 30        → ExpiryStatus.warning
//                                             (within 30 days either side)
//   else                                    → ExpiryStatus.ok
//                                             (more than 30 days in future)
//
// Branches are evaluated in order, so an item that expired exactly 30 days
// ago is classified as warning (the error branch requires `> 30`), and an
// item that expires exactly 30 days from now is also warning.
//
// The property body re-derives the expected status from `offsetDays` — the
// signed count of whole days from `now` until `expiry`, where positive
// means the future, negative means the past, and `null` means there is no
// expiry at all — using independent branch logic, so we assert two
// independently-computed values agree:
//
//   offsetDays == null         → noExpiry
//   offsetDays < -30           → error    (past, > 30 days ago)
//   -30 <= offsetDays <= 30    → warning  (within 30 days either side)
//   offsetDays > 30            → ok       (future, > 30 days away)
//
// Generators:
//   - `now` is a fixed UTC DateTime (`DateTime.utc(2025, 1, 1)`) so that
//     Duration arithmetic round-trips exactly through `DateTime.add` and
//     `DateTime.difference`. UTC sidesteps DST shifts that could otherwise
//     perturb `Duration.inDays` near transition days.
//   - `offsetDays ∈ [-365, 365]` via `any.intInRange(-365, 366)`. Glados
//     ranges are `[min, max)`, so `(-365, 366)` yields integers
//     -365..365 inclusive — a full year before and after `now`. Wrapping
//     in `.nullable` adds `null` to the input space, covering the
//     no-expiry branch. The chosen range exercises all five buckets the
//     task calls out:
//       * null         → noExpiry
//       * far-past     (offsetDays < -30)
//       * recent-past  (-30 <= offsetDays < 0)
//       * future-near  (0 <= offsetDays <= 30)
//       * future-far   (offsetDays > 30)
//
// Glados is configured for 200 runs to comfortably exceed the 100-iteration
// minimum required by the task.

import 'package:drive_care_plus/core/util/expiry.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`. Mirrors the pattern
// used by `test/core/util/greeting_test.dart` and
// `test/core/util/format_bytes_test.dart`.
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

/// Reference time used for every property iteration. Fixed so the test is
/// deterministic, and UTC so `DateTime.add(Duration(days: x))` round-trips
/// exactly through `DateTime.difference` — no DST shifts can perturb
/// `Duration.inDays`.
final DateTime _now = DateTime.utc(2025, 1, 1);

/// Reference implementation of the four-branch rule (Requirements 10.4,
/// 10.5), expressed in terms of `offsetDays` (the signed count of whole
/// days from `_now` until `expiry`). Computed independently of the
/// production helper so the property body asserts equality of two
/// independently-derived values.
ExpiryStatus _expectedStatus(int? offsetDays) {
  if (offsetDays == null) return ExpiryStatus.noExpiry;
  if (offsetDays < -30) return ExpiryStatus.error;
  if (offsetDays >= -30 && offsetDays <= 30) return ExpiryStatus.warning;
  return ExpiryStatus.ok;
}

void main() {
  Glados<int?>(
    any.intInRange(-365, 366).nullable,
    ExploreConfig(numRuns: 200),
  ).test(
    'expiryStatusOf(expiry, now): returned status matches the four-branch '
    'classification rule for null/far-past/recent-past/future-near/future-far '
    'inputs',
    (offsetDays) {
      // Materialise the `expiry` argument from the generated `offsetDays`.
      // `null` covers the no-expiry branch; otherwise we shift `_now` by
      // the offset to construct an expiry date the requested number of
      // days before or after `_now`.
      final DateTime? expiry = offsetDays == null
          ? null
          : _now.add(Duration(days: offsetDays));

      final ExpiryStatus actual = expiryStatusOf(expiry, _now);
      final ExpiryStatus expected = _expectedStatus(offsetDays);

      // Property 22 — returned status equals the expected branch.
      expect(
        actual,
        equals(expected),
        reason:
            'expiryStatusOf('
            '${expiry == null ? 'null' : 'now+${offsetDays}d'}, '
            'now=$_now) should be $expected per the documented four-branch '
            'rule (offsetDays=$offsetDays)',
      );
    },
  );
}
