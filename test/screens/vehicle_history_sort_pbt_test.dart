// Feature: figma-ui-redesign, Property 16: maintenance history descending
//                                          sort
//
// Validates: Requirements 8.4
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// For any list `entries: List<MaintenanceHistoryEntry>` (including empty,
// single-element, mixed-date, duplicate-date, and arbitrary-shape inputs),
// `sortMaintenanceEntriesDescending(entries)` returns a list whose
// elements are in non-strictly-descending date order:
//
//     for all i in [0, sorted.length - 2]:
//         sorted[i].date >= sorted[i + 1].date
//
// Equivalently:
//
//     sorted[i].date.compareTo(sorted[i + 1].date) >= 0
//
// In addition, the helper preserves:
//
//   * Length:    sorted.length == entries.length.
//   * Multiset:  the bag of `(name, mileageKm, date)` tuples is preserved
//                across the sort (no entries dropped, no duplicates added).
//   * Purity:    the input list is not mutated by the sort (`entries`
//                stays in its original order after the call).
//
// Together these four sub-properties pin Requirement 8.4 ("ordered from
// most recent to oldest") so a regression that filters, drops, or
// duplicates entries cannot quietly pass the descending-order check.
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The figma-ui-redesign tasks file flags this case as `[PBT]`. The
// underlying property is a pure function over a list of value-typed
// entries, so the test is implemented with `glados` directly rather
// than a parametric widget sweep. The generator emits arbitrary
// `List<MaintenanceHistoryEntry>` values via a custom Glados
// `Generator` that combines generators for the `mileageKm` (double)
// and `date` (DateTime, derived from a bounded int) fields. The
// `name` field is held to a small fixed pool because it does not
// influence the sort order — keeping it small reduces shrinking
// noise without weakening the property.
//
// The 200-run configuration below comfortably exceeds the
// 100-iteration minimum required by the tasks file.

import 'package:drive_care_plus/screens/vehicle/_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`. Mirrors the
// pattern used by `test/core/util/clamp_percentage_test.dart` and the
// other PBT tests in this repo.
import 'package:glados/glados.dart'
    hide
        expect,
        equals,
        isFalse,
        isTrue,
        isNotNull,
        isNull,
        isEmpty,
        inInclusiveRange,
        test,
        group,
        setUp,
        tearDown,
        setUpAll,
        tearDownAll,
        addTearDown;

// ===========================================================================
// Generator: arbitrary MaintenanceHistoryEntry
// ===========================================================================
//
// `MaintenanceHistoryEntry` is a value type carrying (name, mileageKm,
// date). Glados has no built-in generator for it, so we stitch one
// together from the standard generators for the field types using
// `any.combine2(...)` over `(double mileage, int rawDate)`.
//
// The `name` field is drawn from a small fixed pool via `any.choose`
// because the sort helper compares only by date — varying the name
// pool would expand the search space without strengthening the
// property under test.
//
// `_dateFromInt` maps an arbitrary `int` into a representable
// `DateTime` by interpreting it as a millisecond-since-epoch offset
// modulo a wide safe range. Without the modulo, large randomly-
// generated ints would overflow `DateTime`'s representable range and
// throw on construction. The range chosen (~31 years on either side
// of the epoch) is wide enough to exercise the descending-sort
// property across both past and future dates.

/// Map an arbitrary `int` into a representable `DateTime` so the
/// generator never trips `DateTime`'s overflow edges.
DateTime _dateFromInt(int raw) {
  // ~31 years in milliseconds. Plenty of room for the sort to see
  // variety in dates without ever hitting `DateTime`'s overflow
  // edges. The remainder operator handles negative inputs so the
  // resulting epoch is bounded but can lie before or after 1970.
  const int spanMs = 1000 * 1000 * 1000;
  final int millis = raw.remainder(spanMs);
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

/// Fixed pool of maintenance-item names. The sort compares only by
/// `date`, so a small pool is enough — the name only contributes to
/// the multiset-preservation sub-property.
const List<String> _namePool = <String>[
  'Engine Oil',
  'Brake Pads',
  'Tyres',
  'Battery',
];

Generator<MaintenanceHistoryEntry> get _entry {
  return any
      .combine2<int, double, MaintenanceHistoryEntry>(
        any.int,
        any.double,
        (int rawDate, double mileage) => MaintenanceHistoryEntry(
          // Name is intentionally derived deterministically from
          // `rawDate` rather than its own axis to keep the search
          // space focused on the sort-relevant fields. Modulo of the
          // date keeps the index in range without an extra Glados
          // axis.
          name: _namePool[rawDate.remainder(_namePool.length).abs()],
          mileageKm: mileage,
          date: _dateFromInt(rawDate),
        ),
      );
}

Generator<List<MaintenanceHistoryEntry>> get _entries => any.list(_entry);

// ===========================================================================
// Reference invariants
// ===========================================================================

/// Returns `true` when [entries] is in non-strictly-descending date
/// order. An empty or single-element list trivially satisfies the
/// predicate. Two equal dates are accepted because the sort is stable
/// over equal dates and the requirement is "most recent to oldest",
/// which permits ties.
bool _isDescending(List<MaintenanceHistoryEntry> entries) {
  for (int i = 0; i < entries.length - 1; i++) {
    if (entries[i].date.compareTo(entries[i + 1].date) < 0) {
      return false;
    }
  }
  return true;
}

/// Returns the multiset (bag) of `(name, mileageKm, date)` tuples in
/// [entries] as a sorted list of canonical-string keys. Used to verify
/// the sort preserves the input's contents — no drops, no duplicates,
/// just a reordering.
List<String> _multiset(List<MaintenanceHistoryEntry> entries) {
  final List<String> keys = <String>[
    for (final MaintenanceHistoryEntry e in entries)
      '${e.name}|${e.mileageKm}|${e.date.toIso8601String()}',
  ];
  keys.sort();
  return keys;
}

void main() {
  // ---------------------------------------------------------------------
  // Property 16 — Glados-driven property test over arbitrary lists of
  // MaintenanceHistoryEntry values.
  // ---------------------------------------------------------------------
  Glados<List<MaintenanceHistoryEntry>>(
    _entries,
    ExploreConfig(numRuns: 200),
  ).test(
    'sortMaintenanceEntriesDescending preserves length, preserves the '
    'multiset of entries, leaves the input untouched, and returns a '
    'list in non-strictly-descending date order',
    (List<MaintenanceHistoryEntry> entries) {
      // Snapshot the input as an independent copy so we can verify it
      // isn't mutated by the sort.
      final List<MaintenanceHistoryEntry> originalSnapshot =
          List<MaintenanceHistoryEntry>.of(entries);

      final List<MaintenanceHistoryEntry> sorted =
          sortMaintenanceEntriesDescending(entries);

      // ---- Length ----------------------------------------------------
      expect(
        sorted.length,
        equals(entries.length),
        reason: 'sortMaintenanceEntriesDescending must preserve list '
            'length; expected ${entries.length}, got ${sorted.length}.',
      );

      // ---- Multiset preservation -------------------------------------
      expect(
        _multiset(sorted),
        equals(_multiset(originalSnapshot)),
        reason: 'sortMaintenanceEntriesDescending must preserve the '
            'multiset of input entries; the bag of '
            '(name, mileageKm, date) tuples diverged.',
      );

      // ---- Purity (input not mutated) --------------------------------
      expect(
        entries,
        equals(originalSnapshot),
        reason: 'sortMaintenanceEntriesDescending must not mutate its '
            'input list.',
      );

      // ---- Descending order — the headline property ------------------
      expect(
        _isDescending(sorted),
        isTrue,
        reason: 'sortMaintenanceEntriesDescending must return entries '
            'in non-strictly-descending date order. Got: '
            '${sorted.map((MaintenanceHistoryEntry e) => e.date).toList()}.',
      );
    },
  );

  // ---------------------------------------------------------------------
  // Special-case unit tests — pin the boundary inputs the property
  // generator can already reach, but where an explicit named test
  // surfaces a regression more clearly than a generated counterexample.
  // ---------------------------------------------------------------------
  group('sortMaintenanceEntriesDescending special cases', () {
    test('empty input returns empty list', () {
      expect(
        sortMaintenanceEntriesDescending(
          const <MaintenanceHistoryEntry>[],
        ),
        isEmpty,
      );
    });

    test('single-element input returns the same element', () {
      final MaintenanceHistoryEntry e = MaintenanceHistoryEntry(
        name: 'Engine Oil',
        mileageKm: 30000,
        date: DateTime(2024, 1, 1),
      );
      expect(
        sortMaintenanceEntriesDescending(<MaintenanceHistoryEntry>[e]),
        equals(<MaintenanceHistoryEntry>[e]),
      );
    });

    test('reversed input is fully sorted to descending order', () {
      final List<MaintenanceHistoryEntry> input = <MaintenanceHistoryEntry>[
        MaintenanceHistoryEntry(
          name: 'Oldest',
          mileageKm: 10000,
          date: DateTime(2020, 1, 1),
        ),
        MaintenanceHistoryEntry(
          name: 'Middle',
          mileageKm: 20000,
          date: DateTime(2022, 6, 15),
        ),
        MaintenanceHistoryEntry(
          name: 'Newest',
          mileageKm: 30000,
          date: DateTime(2024, 12, 31),
        ),
      ];

      final List<MaintenanceHistoryEntry> sorted =
          sortMaintenanceEntriesDescending(input);

      expect(sorted[0].name, equals('Newest'));
      expect(sorted[1].name, equals('Middle'));
      expect(sorted[2].name, equals('Oldest'));
    });

    test('duplicate dates are kept (stable sort tolerated)', () {
      final DateTime sharedDate = DateTime(2024, 5, 1);
      final List<MaintenanceHistoryEntry> input = <MaintenanceHistoryEntry>[
        MaintenanceHistoryEntry(
          name: 'A',
          mileageKm: 10000,
          date: sharedDate,
        ),
        MaintenanceHistoryEntry(
          name: 'B',
          mileageKm: 20000,
          date: sharedDate,
        ),
      ];
      final List<MaintenanceHistoryEntry> sorted =
          sortMaintenanceEntriesDescending(input);
      expect(sorted.length, equals(2));
      expect(_isDescending(sorted), isTrue);
    });

    test('does not mutate input list when called', () {
      final List<MaintenanceHistoryEntry> input = <MaintenanceHistoryEntry>[
        MaintenanceHistoryEntry(
          name: 'A',
          mileageKm: 1,
          date: DateTime(2020),
        ),
        MaintenanceHistoryEntry(
          name: 'B',
          mileageKm: 2,
          date: DateTime(2024),
        ),
      ];
      final List<MaintenanceHistoryEntry> snapshot =
          List<MaintenanceHistoryEntry>.of(input);
      sortMaintenanceEntriesDescending(input);
      expect(input, equals(snapshot));
    });
  });
}
