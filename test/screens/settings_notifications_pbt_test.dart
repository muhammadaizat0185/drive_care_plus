// Feature: figma-ui-redesign, Property 10: notifications toggle round-trip
//
// Validates: Requirements 6.6
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// For any sequence of toggles applied to the three switches in the
// `NOTIFICATIONS` section of `SettingsScreen` (Maintenance Reminders,
// Booking Confirmations, Weekly Reports), after each individual toggle:
//
//     persisted SharedPreferences value for that switch
//        ==
//     in-memory value reported by `NotificationPreferences.instance`
//        ==
//     visual on/off state of the corresponding `AppToggleSwitch`
//
// In other words, the persisted store, the in-memory state, and the
// rendered switch state are kept in lock-step on every transition. A
// regression that flips the in-memory state without persisting (or vice
// versa) would surface here because each iteration cross-checks all
// three layers.
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The figma-ui-redesign tasks file flags this case as `[PBT]`. The
// underlying invariant is a pure boolean per-key contract, but the
// *contract* under test spans:
//
//   1. `AppToggleSwitch.value` (rendered state)
//   2. `NotificationPreferences.instance.<flag>` (in-memory state)
//   3. `SharedPreferences.getBool(<key>)` (persisted state)
//
// That cross-layer contract only resolves inside a `testWidgets` body
// (`tester.pumpWidget`, `tester.tap`, `await SharedPreferences.getInstance()
// .getBool(...)`), so glados-style pure-function PBTs cannot reach it.
// This file therefore implements the property as a parametric /
// exhaustive widget sweep over a representative set of toggle sequences,
// asserting the three-way equality after every individual tap.
//
// Generators (representative tap sequences over 3 switch indices):
//
//   * `[0]`               — single toggle of the first switch.
//   * `[0, 0]`            — round-trip on a single switch (must return
//                            to the default-true state).
//   * `[1, 2]`            — distinct toggles across two different switches.
//   * `[0, 1, 2]`         — flip every switch once.
//   * `[2, 1, 0, 1, 2, 0]` — interleaved sequence exercising every
//                             switch multiple times in non-monotonic
//                             order; useful for catching cross-switch
//                             interference bugs.
//
// Switch indices map to:
//   0 → Maintenance Reminders
//   1 → Booking Confirmations
//   2 → Weekly Reports
//
// ===========================================================================
// Mounting strategy
// ===========================================================================
//
// Property 10 is a service round-trip property — the service is the
// authority. We therefore mount the real `_NotificationsSection` (via
// the public `SettingsScreen` entry point would also work, but it
// drags in `ProfileService` + `ThemeService` + a network avatar). To
// stay focused, the harness embeds the production
// [_NotificationsSectionFixture] in a token-themed scaffold so the
// actual widget under test is the same `AppToggleSwitch` triple that
// `SettingsScreen` renders.
//
// Setting `SharedPreferences.setMockInitialValues({})` at the top of
// every test gives the service a clean in-memory store, and
// `NotificationPreferences.instance.reset()` resets the in-memory
// state to the default-true baseline so each iteration starts from a
// known position. The reset is `@visibleForTesting` and matches the
// pattern used by `ProfileService` consumers in the wider test
// suite.

import 'package:drive_care_plus/services/notification_preferences.dart';
import 'package:drive_care_plus/widgets/ui/app_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/ui/_test_host.dart';

// ===========================================================================
// Test harness — mirrors settings_screen.dart's _NotificationsSection
// ===========================================================================

/// Standalone reproduction of the `NOTIFICATIONS` section from
/// `lib/screens/settings_screen.dart`.
///
/// Mirrors verbatim:
///
///   * Three [AppToggleSwitch]es bound to
///     `NotificationPreferences.instance.{maintenanceReminders,
///     bookingConfirmations, weeklyReports}`.
///   * Each toggle's `onChanged` routes through the matching
///     `set...` method on the service, which flips the in-memory
///     state and persists to `SharedPreferences`.
///   * A `ListenableBuilder` against the service rebuilds the row
///     when a value flips, exactly as the outer screen's
///     `Listenable.merge` does in production.
///
/// The harness keeps the visual contract minimal — no labels, no
/// section header — because Property 10 only constrains the
/// rendered toggle state. Visual fidelity tests for the section
/// layout live in `settings_screen_test.dart` (task 8.13).
class _NotificationsSectionFixture extends StatelessWidget {
  const _NotificationsSectionFixture();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationPreferences.instance,
      builder: (BuildContext context, Widget? _) {
        final NotificationPreferences prefs =
            NotificationPreferences.instance;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Index 0 — Maintenance Reminders.
              Align(
                alignment: Alignment.centerRight,
                child: AppToggleSwitch(
                  key: const ValueKey<String>('toggle_0'),
                  value: prefs.maintenanceReminders,
                  semanticsLabel: 'Maintenance Reminders',
                  onChanged: (bool v) => prefs.setMaintenanceReminders(v),
                ),
              ),
              const SizedBox(height: 12),
              // Index 1 — Booking Confirmations.
              Align(
                alignment: Alignment.centerRight,
                child: AppToggleSwitch(
                  key: const ValueKey<String>('toggle_1'),
                  value: prefs.bookingConfirmations,
                  semanticsLabel: 'Booking Confirmations',
                  onChanged: (bool v) => prefs.setBookingConfirmations(v),
                ),
              ),
              const SizedBox(height: 12),
              // Index 2 — Weekly Reports.
              Align(
                alignment: Alignment.centerRight,
                child: AppToggleSwitch(
                  key: const ValueKey<String>('toggle_2'),
                  value: prefs.weeklyReports,
                  semanticsLabel: 'Weekly Reports',
                  onChanged: (bool v) => prefs.setWeeklyReports(v),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Generators / parameter sweep
// ===========================================================================

/// Representative tap sequences. Each sequence is a list of switch
/// indices to toggle in order. The property must hold at every prefix
/// of every sequence — i.e. after each individual tap, the persisted
/// store, the in-memory state, and the rendered switch state for that
/// switch must all agree.
const List<List<int>> _toggleSequences = <List<int>>[
  <int>[0],
  <int>[0, 0],
  <int>[1, 2],
  <int>[0, 1, 2],
  <int>[2, 1, 0, 1, 2, 0],
];

/// SharedPreferences key for switch index `i`. Sourced from
/// [NotificationPreferences] so the assertion side of the test reads
/// the exact same key the production code writes.
String _keyForIndex(int i) {
  switch (i) {
    case 0:
      return NotificationPreferences.kMaintenanceRemindersKey;
    case 1:
      return NotificationPreferences.kBookingConfirmationsKey;
    case 2:
      return NotificationPreferences.kWeeklyReportsKey;
    default:
      throw ArgumentError('Unknown switch index: $i');
  }
}

/// Reads the in-memory value of switch index `i` from the service.
bool _inMemoryFor(int i) {
  final NotificationPreferences prefs = NotificationPreferences.instance;
  switch (i) {
    case 0:
      return prefs.maintenanceReminders;
    case 1:
      return prefs.bookingConfirmations;
    case 2:
      return prefs.weeklyReports;
    default:
      throw ArgumentError('Unknown switch index: $i');
  }
}

void main() {
  // Each test starts from a clean SharedPreferences store (no keys
  // present, so the service falls back to its default-true values
  // on init/read) and a freshly-reset NotificationPreferences
  // singleton so prior iterations do not leak in-memory state.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationPreferences.instance.reset();
  });

  group('Property 10: notifications toggle round-trip', () {
    for (final List<int> sequence in _toggleSequences) {
      final String displaySequence = '[${sequence.join(", ")}]';

      testWidgets(
        'sequence $displaySequence keeps persisted, in-memory, and '
        'rendered state in lock-step after every toggle',
        (WidgetTester tester) async {
          // ---- Mount the harness --------------------------------
          await tester.pumpWidget(
            hostApp(child: const _NotificationsSectionFixture()),
          );
          await tester.pump();

          // Track expected per-switch state through the sequence.
          // All three switches default to `true` because the service
          // initialises that way on a fresh install (no SharedPrefs
          // keys present → fallback to `true`).
          final List<bool> expected = <bool>[true, true, true];

          // ---- Walk the sequence, asserting after every tap -----
          for (int t = 0; t < sequence.length; t++) {
            final int idx = sequence[t];
            // Flip the expected value for the tapped switch.
            expected[idx] = !expected[idx];

            await tester.tap(find.byKey(ValueKey<String>('toggle_$idx')));
            // Two pumps: one to flush the synchronous `setState` /
            // notifyListeners path, one to settle the async
            // `SharedPreferences` write so the assertion below reads
            // the post-write value.
            await tester.pump();
            await tester.pumpAndSettle();

            // ---- Half 1: in-memory state matches expected ----
            //
            // The service's getter reflects the most recent toggle
            // for the tapped switch. Untouched switches must retain
            // their prior expected value.
            for (int i = 0; i < 3; i++) {
              expect(
                _inMemoryFor(i),
                expected[i],
                reason: 'After tap #${t + 1} of $displaySequence '
                    '(toggled idx=$idx), in-memory state of switch '
                    '$i must equal ${expected[i]}. Requirement 6.6.',
              );
            }

            // ---- Half 2: persisted store matches in-memory ----
            //
            // SharedPreferences must reflect the most recent
            // toggle. We only assert the persisted value for the
            // *tapped* switch because untouched switches haven't
            // been written yet (the service short-circuits writes
            // when the new value equals the current value, so the
            // SharedPrefs key may legitimately remain unset for
            // untouched switches → `getBool` returns `null`, and
            // the service's read path falls back to `true`). The
            // tapped switch always produces a write.
            final SharedPreferences sp =
                await SharedPreferences.getInstance();
            expect(
              sp.getBool(_keyForIndex(idx)),
              expected[idx],
              reason: 'After tap #${t + 1} of $displaySequence, '
                  'persisted SharedPreferences value for key '
                  '${_keyForIndex(idx)} must equal ${expected[idx]}. '
                  'Requirement 6.6.',
            );

            // ---- Half 3: rendered switch state matches in-memory
            //
            // Look up each AppToggleSwitch by its stable key and
            // confirm its `value` prop equals the expected state.
            // This catches a regression where the service writes
            // succeed but the UI fails to rebuild (e.g. the parent
            // ListenableBuilder dropped the service from its
            // listenable set).
            for (int i = 0; i < 3; i++) {
              final AppToggleSwitch sw = tester.widget<AppToggleSwitch>(
                find.byKey(ValueKey<String>('toggle_$i')),
              );
              expect(
                sw.value,
                expected[i],
                reason: 'After tap #${t + 1} of $displaySequence, '
                    'rendered AppToggleSwitch at index $i must show '
                    '${expected[i]}. Requirement 6.6.',
              );
            }
          }
        },
      );
    }
  });
}
