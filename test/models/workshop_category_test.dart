// Unit tests for WorkshopCategory enum + Workshop.category getter (Task 9.1).
//
// Validates: Requirements 7.2, 14.3, 14.9.
//
// The category getter is the keystone of the Browse-tab category chip
// row. The mapping is precedence-first (repair > carWash > parts) and
// must remain stable as new types appear in the Google Places taxonomy.

import 'package:drive_care_plus/models/workshop.dart';
import 'package:flutter_test/flutter_test.dart';

Workshop _w(List<String> types) => Workshop(
      id: 'w',
      name: 'name',
      address: 'addr',
      types: types,
    );

void main() {
  group('WorkshopCategory enum', () {
    test('declares the four expected variants', () {
      expect(WorkshopCategory.values, <WorkshopCategory>[
        WorkshopCategory.all,
        WorkshopCategory.repair,
        WorkshopCategory.carWash,
        WorkshopCategory.parts,
      ]);
    });
  });

  group('Workshop.category mapping', () {
    test('car_repair → repair', () {
      expect(_w(<String>['car_repair']).category, WorkshopCategory.repair);
    });

    test('car_repairer → repair (alternative spelling)', () {
      expect(_w(<String>['car_repairer']).category, WorkshopCategory.repair);
    });

    test('car_wash → carWash', () {
      expect(_w(<String>['car_wash']).category, WorkshopCategory.carWash);
    });

    test('repair > carWash precedence (workshop tagged as both)', () {
      expect(
        _w(<String>['car_wash', 'car_repair']).category,
        WorkshopCategory.repair,
      );
    });

    test('gas_station alone → parts (catch-all bucket)', () {
      expect(_w(<String>['gas_station']).category, WorkshopCategory.parts);
    });

    test('unknown type → parts (long-tail fallback)', () {
      expect(_w(<String>['something_else']).category, WorkshopCategory.parts);
    });

    test('empty types → parts (long-tail fallback)', () {
      expect(_w(const <String>[]).category, WorkshopCategory.parts);
    });

    test('repair beats gas_station combo', () {
      expect(
        _w(<String>['gas_station', 'car_repair']).category,
        WorkshopCategory.repair,
      );
    });

    test('category never returns the All sentinel', () {
      // The All variant is reserved for the chip row's filter sentinel
      // and represents a *filter*, not a workshop. The getter must
      // never return it.
      for (final List<String> types in <List<String>>[
        const <String>[],
        <String>['car_repair'],
        <String>['car_wash'],
        <String>['gas_station'],
        <String>['random'],
      ]) {
        expect(
          _w(types).category,
          isNot(WorkshopCategory.all),
          reason: 'category for types=$types must not be All.',
        );
      }
    });
  });
}
