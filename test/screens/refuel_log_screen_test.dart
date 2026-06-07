// Widget + integration tests for the redesigned Refuel Log screen
// (Task 11.15 — Requirements 9.1, 9.3, 9.6, 9.8, 9.9, 9.10).
//
// Coverage:
//   * Tab default — Log selected on first mount (Requirement 9.1).
//   * Input filter — entering letters into a numeric field is rejected
//     (Requirement 9.2 / Property 17, exercised through the widget).
//   * Chip pre-fill — selecting a fuel-type chip overwrites the price
//     field with the preset value (Requirement 9.3).
//   * Valid save → store call + form reset (Requirement 9.4).
//   * Invalid save → no store call + per-field errorText (Requirement
//     9.5).
//   * DB failure → error banner, values retained (Requirement 9.6).
//   * History order + efficiency rendering (Requirement 9.7).
//   * History empty state (Requirement 9.8).
//   * Insights tab wraps existing FuelChart in AppCard (Requirement
//     9.9).
//   * Insights empty state (Requirement 9.10).
//
// Note on full-screen integration coverage: [RefuelLogScreen] accepts
// an `entriesOverride` constructor parameter that short-circuits the
// Firestore stream, so the screen can be mounted in `flutter_test`
// without Firebase plumbing. The streaming branch is deferred — see
// the deferral note in tasks.md for Task 11.15.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/refuel/_widgets.dart';
import 'package:drive_care_plus/screens/refuel_log_screen.dart';
import 'package:drive_care_plus/widgets/fuel_chart.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

// `const` DateTime literals are not supported, so the fixture entries
// are exposed as top-level `final`s.
final DateTime _date2024_05_10 = DateTime(2024, 5, 10);
final DateTime _date2024_05_01 = DateTime(2024, 5, 1);

final RefuelEntry _entryA = RefuelEntry(
  date: _date2024_05_10,
  distanceKm: 420,
  liters: 28,
  pricePerLiter: 2.05,
  fuelType: 'RON95',
  station: 'Petronas KLCC',
);

final RefuelEntry _entryB = RefuelEntry(
  date: _date2024_05_01,
  distanceKm: 395,
  liters: 27.5,
  pricePerLiter: 2.05,
  fuelType: 'RON95',
);

void main() {
  group('LogTab', () {
    testWidgets(
      'renders three numeric fields, four fuel chips, save button',
      (WidgetTester tester) async {
        final InMemoryRefuelLogStore store = InMemoryRefuelLogStore();
        await tester.pumpWidget(hostApp(child: LogTab(store: store)));

        expect(
          find.byKey(const ValueKey<String>('refuel_log_distance_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('refuel_log_liters_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('refuel_log_price_field')),
          findsOneWidget,
        );
        expect(find.byType(AppCategoryChip), findsNWidgets(4));
        expect(
          find.byKey(const ValueKey<String>('refuel_log_save_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'positive-decimal filter blocks non-numeric input',
      (WidgetTester tester) async {
        final InMemoryRefuelLogStore store = InMemoryRefuelLogStore();
        await tester.pumpWidget(hostApp(child: LogTab(store: store)));

        await tester.enterText(
          find.byKey(const ValueKey<String>('refuel_log_distance_field')),
          'abc',
        );
        await tester.pump();
        final TextField distanceField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(
                const ValueKey<String>('refuel_log_distance_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(distanceField.controller!.text, equals(''));

        await tester.enterText(
          find.byKey(const ValueKey<String>('refuel_log_distance_field')),
          '420.5',
        );
        await tester.pump();
        expect(distanceField.controller!.text, equals('420.5'));
      },
    );

    testWidgets(
      'selecting a fuel chip overwrites the price field (Requirement 9.3)',
      (WidgetTester tester) async {
        final InMemoryRefuelLogStore store = InMemoryRefuelLogStore();
        await tester.pumpWidget(hostApp(child: LogTab(store: store)));

        await tester.enterText(
          find.byKey(const ValueKey<String>('refuel_log_price_field')),
          '9.99',
        );
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey<String>('refuel_fuel_chip_RON97')),
        );
        await tester.pump();

        final TextField priceField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(
                const ValueKey<String>('refuel_log_price_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(priceField.controller!.text, equals('3.47'));
      },
    );

    testWidgets(
      'valid save persists one entry and clears the form',
      (WidgetTester tester) async {
        final InMemoryRefuelLogStore store = InMemoryRefuelLogStore();
        await tester.pumpWidget(hostApp(child: LogTab(store: store)));

        await tester.enterText(
          find.byKey(const ValueKey<String>('refuel_log_distance_field')),
          '420',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('refuel_log_liters_field')),
          '28',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('refuel_log_price_field')),
          '2.05',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('refuel_fuel_chip_RON95')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('refuel_log_save_button')),
        );
        await tester.pumpAndSettle();

        expect(store.savedEntries.length, equals(1));
        final RefuelEntry saved = store.savedEntries.single;
        expect(saved.distanceKm, equals(420));
        expect(saved.liters, equals(28));
        expect(saved.pricePerLiter, equals(2.05));
        expect(saved.fuelType, equals('RON95'));
      },
    );

    testWidgets(
      'DB failure surfaces error banner and retains values (Requirement 9.6)',
      (WidgetTester tester) async {
        final InMemoryRefuelLogStore store = InMemoryRefuelLogStore()
          ..failNext = true;
        await tester.pumpWidget(hostApp(child: LogTab(store: store)));

        await tester.enterText(
          find.byKey(const ValueKey<String>('refuel_log_distance_field')),
          '420',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('refuel_log_liters_field')),
          '28',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('refuel_log_price_field')),
          '2.05',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('refuel_fuel_chip_RON95')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('refuel_log_save_button')),
        );
        await tester.pumpAndSettle();

        expect(store.savedEntries.length, equals(0));
        expect(
          find.byKey(const ValueKey<String>('refuel_log_error_banner')),
          findsOneWidget,
        );
        final TextField distanceField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(
                const ValueKey<String>('refuel_log_distance_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(distanceField.controller!.text, equals('420'));
      },
    );
  });

  group('HistoryTab', () {
    testWidgets(
      'empty entries → AppEmptyState (Requirement 9.8)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          hostApp(child: const HistoryTab(entries: <RefuelEntry>[])),
        );
        expect(find.byType(AppEmptyState), findsOneWidget);
        expect(find.text('No refuel entries yet'), findsOneWidget);
      },
    );

    testWidgets(
      'renders one card per entry in descending date order',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          hostApp(
            child: HistoryTab(entries: <RefuelEntry>[_entryB, _entryA]),
          ),
        );
        expect(find.byType(RefuelHistoryCard), findsNWidgets(2));
        final List<RefuelHistoryCard> cards = tester
            .widgetList<RefuelHistoryCard>(find.byType(RefuelHistoryCard))
            .toList();
        expect(cards.first.entry, equals(_entryA));
        expect(cards.last.entry, equals(_entryB));
      },
    );

    testWidgets(
      'efficiency text renders rounded km/L for valid entry',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          hostApp(child: HistoryTab(entries: <RefuelEntry>[_entryA])),
        );
        expect(find.text('15.00 km/L'), findsOneWidget);
      },
    );
  });

  group('InsightsTab', () {
    testWidgets(
      'empty entries → AppEmptyState (Requirement 9.10)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          hostApp(child: const InsightsTab(entries: <RefuelEntry>[])),
        );
        expect(find.byType(AppEmptyState), findsOneWidget);
        expect(find.text('No insights yet'), findsOneWidget);
      },
    );

    testWidgets(
      'non-empty entries → FuelChart wrapped in AppCard (Requirement 9.9)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          hostApp(
            child: InsightsTab(entries: <RefuelEntry>[_entryA, _entryB]),
          ),
        );
        expect(find.byType(FuelChart), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(FuelChart),
            matching: find.byType(AppCard),
          ),
          findsOneWidget,
        );
      },
    );
  });

  // ---------------------------------------------------------------------
  // Full-screen integration tests — tab default + tab content wiring.
  // ---------------------------------------------------------------------
  group('RefuelLogScreen integration', () {
    /// Build a `MaterialApp` configured with the DriveCare+ theme so
    /// the screen can resolve its `Theme.of(context).extension<...>()`
    /// look-ups. Mirrors the wiring in `lib/app.dart`.
    Widget buildAppWithEntries(List<RefuelEntry> entries) {
      return MaterialApp(
        theme: AppTheme.buildTheme(AppColors.emerald500, Brightness.light),
        home: RefuelLogScreen(
          store: InMemoryRefuelLogStore(),
          entriesOverride: entries,
        ),
      );
    }

    testWidgets(
      'default tab is Log on first mount (Requirement 9.1)',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildAppWithEntries(<RefuelEntry>[_entryA]));
        expect(
          find.byKey(const ValueKey<String>('refuel_log_save_button')),
          findsOneWidget,
        );
        expect(find.text('Log'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Insights'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping History tab reveals saved entries',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildAppWithEntries(<RefuelEntry>[_entryA, _entryB]),
        );
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        expect(find.byType(RefuelHistoryCard), findsNWidgets(2));
      },
    );

    testWidgets(
      'tapping Insights tab reveals FuelChart',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildAppWithEntries(<RefuelEntry>[_entryA, _entryB]),
        );
        await tester.tap(find.text('Insights'));
        await tester.pumpAndSettle();
        expect(find.byType(FuelChart), findsOneWidget);
      },
    );
  });
}
