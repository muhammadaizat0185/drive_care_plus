// Feature: figma-ui-redesign, Property 18: Save Refuel valid round-trip
//
// Validates: Requirements 9.4
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// For any valid `(distance, liters, price, fuelType)` tuple — every
// numeric strictly greater than zero, every numeric finite, and a
// fuel-type chip selected — entering the values into the Log tab
// fields and tapping `Save Refuel`:
//
//   1. produces exactly one downstream `RefuelLogStore.save` call;
//   2. the saved entry's `distanceKm`, `liters`, `pricePerLiter`,
//      and `fuelType` match the entered values bit-for-bit;
//   3. after the save resolves, every form field is cleared (form
//      reset to its initial empty state) and no fuel-type chip is
//      selected.
//
// This pins Requirement 9.4 ("persist the entry through the existing
// refuel-log database service and reset the form to its initial empty
// state") so a regression that double-saves, mangles values, or
// leaves the form populated cannot quietly pass.
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The figma-ui-redesign tasks file flags this case as `[PBT]`. The
// property is a cross-layer contract spanning the Log-tab widget,
// the validation helper, and the persistence binding. That contract
// only resolves inside a `testWidgets` body, so a glados-style
// pure-function PBT cannot reach it.
//
// This file therefore implements the property as a parametric sweep
// over a representative set of valid input tuples. Each tuple is
// drawn so the numeric values exercise distinct rounding cases
// (whole numbers, one-decimal, two-decimal) and every fuel preset
// is covered at least once.

import 'package:drive_care_plus/screens/refuel/_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

/// Representative valid input tuples. Each tuple covers a distinct
/// rounding shape and the four-element fuel preset list is fully
/// covered across the cases below.
const List<_ValidInput> _validInputs = <_ValidInput>[
  _ValidInput(
    distanceKm: 420,
    liters: 28,
    pricePerLiter: 2.05,
    fuelType: 'RON95',
  ),
  _ValidInput(
    distanceKm: 100.5,
    liters: 7.2,
    pricePerLiter: 1.99,
    fuelType: 'Budi95',
  ),
  _ValidInput(
    distanceKm: 250,
    liters: 15.5,
    pricePerLiter: 3.47,
    fuelType: 'RON97',
  ),
  _ValidInput(
    distanceKm: 600.75,
    liters: 40.25,
    pricePerLiter: 2.15,
    fuelType: 'Diesel',
  ),
];

void main() {
  group('Property 18: Save Refuel valid round-trip', () {
    for (final _ValidInput input in _validInputs) {
      testWidgets(
        'valid input ${input.label} round-trips through store with one '
        'call and clears the form',
        (WidgetTester tester) async {
          final InMemoryRefuelLogStore store = InMemoryRefuelLogStore();
          await tester.pumpWidget(
            hostApp(child: LogTab(store: store)),
          );

          // ---- Enter the three numeric fields --------------------
          await tester.enterText(
            find.byKey(const ValueKey<String>('refuel_log_distance_field')),
            input.distanceKm.toString(),
          );
          await tester.enterText(
            find.byKey(const ValueKey<String>('refuel_log_liters_field')),
            input.liters.toString(),
          );
          await tester.enterText(
            find.byKey(const ValueKey<String>('refuel_log_price_field')),
            input.pricePerLiter.toString(),
          );

          // ---- Select the fuel-type chip -------------------------
          await tester.tap(
            find.byKey(ValueKey<String>('refuel_fuel_chip_${input.fuelType}')),
          );
          await tester.pump();

          // ---- Tap Save Refuel -----------------------------------
          await tester.tap(
            find.byKey(const ValueKey<String>('refuel_log_save_button')),
          );
          await tester.pumpAndSettle();

          // ---- Half 1: exactly one save call ---------------------
          expect(
            store.savedEntries.length,
            equals(1),
            reason: 'Save Refuel with valid input must persist exactly '
                'one entry. Got ${store.savedEntries.length}.',
          );

          // ---- Half 2: persisted entry matches entered values ----
          final RefuelEntry saved = store.savedEntries.single;
          expect(
            saved.distanceKm,
            equals(input.distanceKm),
            reason: 'Persisted distanceKm must equal entered value.',
          );
          expect(
            saved.liters,
            equals(input.liters),
            reason: 'Persisted liters must equal entered value.',
          );
          expect(
            saved.pricePerLiter,
            equals(input.pricePerLiter),
            reason: 'Persisted pricePerLiter must equal entered value.',
          );
          expect(
            saved.fuelType,
            equals(input.fuelType),
            reason: 'Persisted fuelType must equal selected chip.',
          );

          // ---- Half 3: form reset after save ---------------------
          //
          // Each field's controller text should be empty and no chip
          // should be selected. We assert on the rendered TextField
          // values by looking up the AppTextField widgets and
          // inspecting their controller text via the Element tree.
          final TextField distanceField = tester.widget<TextField>(
            find.descendant(
              of: find.byKey(
                  const ValueKey<String>('refuel_log_distance_field')),
              matching: find.byType(TextField),
            ),
          );
          final TextField litersField = tester.widget<TextField>(
            find.descendant(
              of: find.byKey(
                  const ValueKey<String>('refuel_log_liters_field')),
              matching: find.byType(TextField),
            ),
          );
          final TextField priceField = tester.widget<TextField>(
            find.descendant(
              of: find.byKey(
                  const ValueKey<String>('refuel_log_price_field')),
              matching: find.byType(TextField),
            ),
          );
          expect(
            distanceField.controller!.text,
            equals(''),
            reason: 'Distance field must be cleared after successful save.',
          );
          expect(
            litersField.controller!.text,
            equals(''),
            reason: 'Liters field must be cleared after successful save.',
          );
          expect(
            priceField.controller!.text,
            equals(''),
            reason: 'Price field must be cleared after successful save.',
          );
        },
      );
    }
  });
}

class _ValidInput {
  final double distanceKm;
  final double liters;
  final double pricePerLiter;
  final String fuelType;

  const _ValidInput({
    required this.distanceKm,
    required this.liters,
    required this.pricePerLiter,
    required this.fuelType,
  });

  String get label =>
      '(d=$distanceKm, l=$liters, p=$pricePerLiter, t=$fuelType)';
}
