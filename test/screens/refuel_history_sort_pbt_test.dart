// Feature: figma-ui-redesign, Property 20: History sort + efficiency
//                                          rendering
//
// Validates: Requirements 9.7
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// For any list `entries: List<RefuelEntry>` (including empty,
// single-element, mixed-date, duplicate-date, and arbitrary-shape
// inputs), `sortRefuelEntriesDescending(entries)` returns a list whose
// elements are in non-strictly-descending date order:
//
//     for all i in [0, sorted.length - 2]:
//         sorted[i].date.compareTo(sorted[i + 1].date) >= 0
//
// AND, for any `(distanceKm, liters)` pair, the formatted efficiency
// string returned by `formatEfficiency(distanceKm, liters)` equals:
//
//     * "<kmPerLiter(distanceKm, liters)> km/L" rounded to two decimals
//       when liters > 0 and the result is finite and positive;
//     * "– km/L" otherwise (placeholder when liters ≤ 0, NaN, etc.).
//
// In addition, the sort helper preserves length, multiset of entries,
// and does not mutate the input list.
//
// Together these sub-properties pin Requirement 9.7 ("ordered most
// recent to oldest" + "efficiency km/L = distance / liters") so a
// regression in either the sort or the efficiency formatter cannot
// quietly pass the order-then-render pipeline.
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The figma-ui-redesign tasks file flags this case as `[PBT]`. The
// underlying property is a pure function over a list of value-typed
// entries plus a pure efficiency formatter, so the test is
// implemented with `glados` directly rather than a parametric widget
// sweep.
//
// The 200-run configuration below comfortably exceeds the
// 100-iteration minimum required by the tasks file.

import 'package:drive_care_plus/core/util/refuel_math.dart';
import 'package:drive_care_plus/screens/refuel/_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
// Generators
// ===========================================================================

/// Map an arbitrary `int` into a representable `DateTime` so the
/// generator never trips `DateTime`'s overflow edges.
DateTime _dateFromInt(int raw) {
  const int spanMs = 1000 * 1000 * 1000;
  final int millis = raw.remainder(spanMs);
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

const List<String> _fuelTypePool = <String>[
  'Budi95',
  'RON95',
  'RON97',
  'Diesel',
];

Generator<RefuelEntry> get _entry {
  return any.combine4<int, double, double, double, RefuelEntry>(
    any.int,
    any.double,
    any.double,
    any.double,
    (int rawDate, double distance, double liters, double price) =>
        RefuelEntry(
      date: _dateFromInt(rawDate),
      distanceKm: distance,
      liters: liters,
      pricePerLiter: price,
      fuelType: _fuelTypePool[rawDate.remainder(_fuelTypePool.length).abs()],
    ),
  );
}

Generator<List<RefuelEntry>> get _entries => any.list(_entry);

// ===========================================================================
// Reference invariants
// ===========================================================================

/// Returns `true` when [entries] is in non-strictly-descending date
/// order.
bool _isDescending(List<RefuelEntry> entries) {
  for (int i = 0; i < entries.length - 1; i++) {
    if (entries[i].date.compareTo(entries[i + 1].date) < 0) {
      return false;
    }
  }
  return true;
}

/// Multiset key for a [RefuelEntry] used to assert sort preserves the
/// input contents.
List<String> _multiset(List<RefuelEntry> entries) {
  final List<String> keys = <String>[
    for (final RefuelEntry e in entries)
      '${e.date.toIso8601String()}|${e.distanceKm}|${e.liters}|'
          '${e.pricePerLiter}|${e.fuelType}',
  ];
  keys.sort();
  return keys;
}

void main() {
  // ---------------------------------------------------------------------
  // Property 20a — sort returns a descending, length-preserving,
  // multiset-preserving, purity-respecting list.
  // ---------------------------------------------------------------------
  Glados<List<RefuelEntry>>(
    _entries,
    ExploreConfig(numRuns: 200),
  ).test(
    'sortRefuelEntriesDescending preserves length, multiset, leaves '
    'the input untouched, and returns a list in non-strictly-'
    'descending date order',
    (List<RefuelEntry> entries) {
      final List<RefuelEntry> snapshot = List<RefuelEntry>.of(entries);
      final List<RefuelEntry> sorted = sortRefuelEntriesDescending(entries);

      expect(sorted.length, equals(entries.length),
          reason: 'sort must preserve length.');
      expect(_multiset(sorted), equals(_multiset(snapshot)),
          reason: 'sort must preserve the multiset of entries.');
      expect(entries, equals(snapshot),
          reason: 'sort must not mutate its input.');
      expect(_isDescending(sorted), isTrue,
          reason: 'sort must return entries in descending date order.');
    },
  );

  // ---------------------------------------------------------------------
  // Property 20b — formatEfficiency returns the rounded km/L value or
  // the placeholder for any (distanceKm, liters) pair.
  // ---------------------------------------------------------------------
  Glados2<double, double>(
    any.double,
    any.double,
    ExploreConfig(numRuns: 200),
  ).test(
    'formatEfficiency renders the rounded km/L value when valid, or '
    'the "– km/L" placeholder otherwise',
    (double distanceKm, double liters) {
      final String result = formatEfficiency(distanceKm, liters);
      final double kpl = kmPerLiter(distanceKm, liters);

      if (kpl.isFinite && kpl > 0) {
        // Valid branch: the formatted string must end with " km/L"
        // and the leading numeric token must equal the rounded
        // kmPerLiter to two decimals.
        expect(
          result,
          equals('${kpl.toStringAsFixed(2)} km/L'),
          reason:
              'formatEfficiency must render <rounded> km/L for valid input.',
        );
      } else {
        // Placeholder branch: liters ≤ 0, NaN, etc.
        expect(
          result,
          equals('– km/L'),
          reason: 'formatEfficiency must render the placeholder for '
              'non-finite or non-positive results.',
        );
      }
    },
  );

  // ---------------------------------------------------------------------
  // Special-case unit tests — pin the boundary inputs the property
  // generator can already reach.
  // ---------------------------------------------------------------------
  group('sortRefuelEntriesDescending special cases', () {
    test('empty input returns empty list', () {
      expect(sortRefuelEntriesDescending(const <RefuelEntry>[]), isEmpty);
    });

    test('reversed input is fully sorted to descending order', () {
      final RefuelEntry oldest = RefuelEntry(
        date: DateTime(2020, 1, 1),
        distanceKm: 100,
        liters: 10,
        pricePerLiter: 2,
        fuelType: 'RON95',
      );
      final RefuelEntry middle = RefuelEntry(
        date: DateTime(2022, 6, 15),
        distanceKm: 200,
        liters: 15,
        pricePerLiter: 2.05,
        fuelType: 'RON95',
      );
      final RefuelEntry newest = RefuelEntry(
        date: DateTime(2024, 12, 31),
        distanceKm: 300,
        liters: 20,
        pricePerLiter: 2.1,
        fuelType: 'RON97',
      );
      final List<RefuelEntry> sorted = sortRefuelEntriesDescending(
        <RefuelEntry>[oldest, middle, newest],
      );
      expect(sorted[0], equals(newest));
      expect(sorted[1], equals(middle));
      expect(sorted[2], equals(oldest));
    });
  });

  group('formatEfficiency special cases', () {
    test('positive distance and positive liters → rounded km/L', () {
      expect(formatEfficiency(420, 28), equals('15.00 km/L'));
    });

    test('zero liters → placeholder', () {
      expect(formatEfficiency(420, 0), equals('– km/L'));
    });

    test('negative liters → placeholder', () {
      expect(formatEfficiency(420, -5), equals('– km/L'));
    });

    test('zero distance with positive liters → placeholder', () {
      expect(formatEfficiency(0, 28), equals('– km/L'));
    });
  });
}
