// Feature: figma-ui-redesign, Property 11: chip single-selection invariant
//
// Validates: Requirements 7.2, 10.1, 11.4
//
// `SingleSelectController<T>` is the canonical state object behind every
// chip row in the figma-ui-redesign feature:
//
//   * `workshop_map_screen.dart` Browse tab category chip row
//     `All / Repair / Car Wash / Parts`           — Requirements 7.2, 11.4.
//   * `document_vault_screen.dart` category chip row
//     `All / Insurance / Tax / Receipt / Warranty` — Requirement 10.1.
//
// Its single-selection contract is:
//
//   * The controller is constructed with a constraint list `values` and an
//     optional `initial` selection that, when non-null, must be present in
//     `values`.
//   * `selected` is a single `T?` field, so by construction at most one
//     value from `values` is selected at any moment.
//   * `select(value)` (with `value` in `values`) sets `selected = value`.
//   * After every tap, `selected` equals the most recent tap value.
//
// The universal property the task asks us to assert (Property 11):
//
//   For any non-empty list of distinct values and any tap sequence, after
//   every tap exactly one value is selected and that value equals the
//   most recent tap. The "exactly one" half is structural (the controller
//   holds a single `T?` field) and we additionally assert
//   `selected != null`. The "equals the most recent tap" half is the
//   behavioural contract we exercise.
//
// Property body (per iteration):
//   1. Dedup the generated raw values list (preserving order) so we have a
//      non-empty list of *distinct* ints, matching the task's generator
//      guidance. If the dedup result is empty (the raw list was empty),
//      skip the iteration — we cannot construct a controller without at
//      least one constraint value.
//   2. Construct `SingleSelectController<int>(values: values,
//      initial: values.first)`.
//   3. Assert `selected == values.first` (the initial-selection invariant
//      from `SingleSelectController`'s constructor contract).
//   4. For each raw tap-index in the tap sequence:
//        idx = rawTap.abs() % values.length     // keep glados simple: any
//                                               // int is mod'd to a valid
//                                               // index in the property
//                                               // body, per the task's
//                                               // implementation guidance.
//        tap = values[idx]
//        controller.select(tap)
//        assert controller.selected == tap     // most-recent-tap invariant
//        assert controller.selected != null    // single-selection invariant
//        assert values.contains(controller.selected)  // membership in values
//
// Generators:
//   - `rawValues: List<int>` via `any.list(any.int)` — Glados produces lists
//     of any non-negative length, including the empty list. We dedup
//     downstream and skip the empty case.
//   - `rawTaps: List<int>` via `any.list(any.int)` — also any-length,
//     including empty. An empty tap sequence is legal: in that case only
//     the initial-selection assertion is exercised.
//
// Glados is configured for 200 runs to comfortably exceed the
// 100-iteration minimum required by the task.

import 'package:drive_care_plus/core/util/single_select_controller.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`. Mirrors the
// pattern used by the other PBT tests in this folder
// (`greeting_test.dart`, `format_bytes_test.dart`, `expiry_test.dart`,
// `clamp_percentage_test.dart`, `in_flight_gate_test.dart`,
// `search_filter_test.dart`).
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

/// Deduplicate [raw] preserving the relative order of first occurrences.
/// Used to coerce the generator's `List<int>` into a list of *distinct*
/// ints, satisfying `SingleSelectController`'s implicit constraint that
/// each constraint value should be unique (so `select(v)` unambiguously
/// designates one position in `values`).
List<int> _dedup(List<int> raw) {
  final Set<int> seen = <int>{};
  final List<int> result = <int>[];
  for (final int v in raw) {
    if (seen.add(v)) result.add(v);
  }
  return result;
}

void main() {
  Glados2<List<int>, List<int>>(
    any.list(any.int),
    any.list(any.int),
    ExploreConfig(numRuns: 200),
  ).test(
    'SingleSelectController.select(v): after every tap exactly one value '
    'is selected and equals the most recent tap; initial selection equals '
    'values.first',
    (rawValues, rawTaps) {
      final List<int> values = _dedup(rawValues);
      // Skip iterations where the raw list deduped to empty — the
      // controller's constructor requires `initial` (when non-null) to be
      // present in `values`, so we cannot construct a meaningful instance
      // without at least one constraint value. The task's generator
      // guidance explicitly calls for a *non-empty* list of distinct ints.
      if (values.isEmpty) return;

      final SingleSelectController<int> controller = SingleSelectController<int>(
        values: values,
        initial: values.first,
      );

      // Property 11 — initial-selection invariant. Constructed with
      // `initial: values.first`, so before any tap exactly one value is
      // selected and it equals `values.first`.
      expect(
        controller.selected,
        equals(values.first),
        reason:
            'SingleSelectController initialised with initial=values.first '
            'should report selected=${values.first} before any tap '
            '(values=$values)',
      );
      expect(
        controller.selected,
        isNotNull,
        reason:
            'SingleSelectController initialised with a non-null initial '
            'must always report a non-null selection (values=$values)',
      );

      // Property 11 — single-selection invariant + most-recent-tap
      // invariant. After every tap, the controller's `selected` equals
      // the value just passed to `select`, and is necessarily a member of
      // `values` (the controller's `select` asserts membership in debug
      // mode and never widens the selection set).
      for (final int rawTap in rawTaps) {
        // The task's implementation guidance: generate any int and
        // modulo it to a valid index in the property body. `rawTap.abs()`
        // protects against the negative-modulo trap (`-1 % n` is `n - 1`
        // in Dart, but `abs()` keeps the index derivation transparent
        // for the test reader).
        final int idx = rawTap.abs() % values.length;
        final int tap = values[idx];

        controller.select(tap);

        // Most-recent-tap invariant.
        expect(
          controller.selected,
          equals(tap),
          reason:
              'After SingleSelectController.select($tap) the controller '
              'should report selected=$tap, but reported '
              '${controller.selected} (values=$values, tapIndex=$idx)',
        );

        // Single-selection invariant — the selected value is non-null
        // (something is selected) and is in the constraint list (only
        // values from the constraint set can be selected).
        expect(
          controller.selected,
          isNotNull,
          reason:
              'After SingleSelectController.select($tap) the controller '
              'must report a non-null selection (values=$values, '
              'tapIndex=$idx)',
        );
        expect(
          values.contains(controller.selected),
          isTrue,
          reason:
              'After SingleSelectController.select($tap) the selected '
              'value (${controller.selected}) must be a member of values '
              '($values)',
        );
      }
    },
  );
}
