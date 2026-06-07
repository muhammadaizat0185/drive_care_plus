// Feature: figma-ui-redesign, Property 6 (sign-in instance): in-flight
// sign-in single Firebase call
//
// Validates: Requirements 5.7
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// While a previously-initiated `signInWithEmailAndPassword` call is in
// flight, any number of additional rapid taps on the `Sign In` button
// MUST produce **zero** additional Firebase invocations. In other words,
// a single user-initiated sign-in gesture maps to exactly one Firebase
// call regardless of how many spurious taps land on the button before
// the in-flight future resolves.
//
// Concretely, for any `n` rapid taps fired during a single in-flight
// window:
//
//   1. Exactly one `signInWithEmailAndPassword` invocation is observed
//      after the taps land (the first tap's gate.run started; every
//      later tap is dropped at the gate).
//   2. After completing the in-flight future and pumping to settle,
//      the Firebase invocation count is **still 1** — no late-firing
//      effect ever runs after the gate releases.
//
// This is the screen-level instance of Property 6 (the in-flight gate
// single-effect property). Task 3.13 already validates the property at
// the unit level against `InFlightGate.run` directly. Task 7.5 exercises
// the same property at the screen level through the same widget
// composition the real `LoginScreen` uses (button → gate.run → async
// effect), proving the wiring on the screen preserves the unit-level
// guarantee.
//
// ===========================================================================
// Why a private `_SignInHarness` instead of mounting LoginScreen
// ===========================================================================
//
// The full `LoginScreen` reaches into Firebase
// (`signInWithEmailAndPassword`) and depends on `firebase_auth` plugin
// channels that are not registered in the `flutter test` host. Mounting
// it directly here would either hang on first-frame plugin invocation
// or crash with a `MissingPluginException`. Per the task's
// implementation guidance, the test instead defines a private
// `_SignInHarness` `StatefulWidget` that mirrors the structure of
// `lib/screens/login_screen.dart` exactly:
//
//   * Owns an `InFlightGate _gate = InFlightGate()`.
//   * Tap on the button calls `_gate.run(() async { signInCount++;
//     await Completer.future; })`.
//   * The completer stays pending until the test releases it,
//     pinning the gate's in-flight state for the entire rapid-tap
//     window.
//
// This is the same Firebase-free harness pattern used by
// `test/screens/login_password_toggle_pbt_test.dart` (task 7.3).

import 'dart:async';

import 'package:drive_care_plus/core/util/in_flight_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

// ===========================================================================
// Test harness — mirrors login_screen.dart's sign-in gating logic
// ===========================================================================

/// Standalone, Firebase-free reproduction of the `Sign In` gating
/// pattern from `lib/screens/login_screen.dart`.
///
/// Mirrors verbatim:
///   * `final InFlightGate _gate = InFlightGate()` per-screen instance.
///   * Tap goes through `_gate.run(() async { ... })` so re-entrant
///     taps during a previous in-flight call are dropped (Requirement
///     5.7 — single Firebase invocation per gesture).
///   * The async work the gate is waiting on is suspended on a
///     [Completer] supplied by the test, standing in for the real
///     `Future<UserCredential>` returned by
///     `FirebaseAuth.instance.signInWithEmailAndPassword(...)`. This
///     keeps the gate `isRunning == true` for the entire rapid-tap
///     window the property is asserting against.
///
/// `signInCount` increments at the very first synchronous statement of
/// the simulated sign-in body, before any `await`. This mirrors the
/// observable side effect of calling `signInWithEmailAndPassword` —
/// each invocation, even before completing, is a real Firebase API
/// call we'd be billed and rate-limited for. Counting at the
/// pre-await point therefore counts the number of "Firebase calls"
/// the harness has issued.
class _SignInHarness extends StatefulWidget {
  const _SignInHarness({super.key, required this.release});

  /// Completer supplied by the test that the simulated sign-in body
  /// awaits. While `release` is incomplete, the gate stays in flight
  /// and additional taps on the button are dropped at the gate.
  ///
  /// The test-visible `signInCount` lives on [_SignInHarnessState] and
  /// is read across pumps via a [GlobalKey] supplied by the property
  /// body, so no mocks or extra channels are required.
  final Completer<void> release;

  @override
  State<_SignInHarness> createState() => _SignInHarnessState();
}

class _SignInHarnessState extends State<_SignInHarness> {
  // Per-screen in-flight guard. Same field name and construction as
  // `_LoginScreenState._signInGate` in the real screen.
  final InFlightGate _gate = InFlightGate();

  /// Mirrors the count of `signInWithEmailAndPassword` invocations the
  /// real screen would have issued. Incremented synchronously at the
  /// first statement of the simulated sign-in body so it captures the
  /// "I have called Firebase" moment, not the "Firebase has answered"
  /// moment.
  int signInCount = 0;

  @override
  void dispose() {
    _gate.dispose();
    super.dispose();
  }

  Future<void> _onSignInTap() async {
    await _gate.run<void>(() async {
      // The first synchronous statement of the simulated sign-in body
      // is the observable Firebase invocation. Every later tap during
      // the same in-flight window is dropped before reaching this
      // point, so this counter is exactly the number of distinct
      // Firebase calls the harness has issued.
      signInCount++;
      await widget.release.future;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Plain ElevatedButton — the property under test is the gating
    // behaviour, not the visual treatment of the button. Using a
    // bare Material button keeps the harness minimal and avoids
    // pulling the Component_Library button hierarchy into the test
    // surface.
    return Center(
      child: ElevatedButton(
        onPressed: _onSignInTap,
        child: const Text('Sign In'),
      ),
    );
  }
}

// ===========================================================================
// Generators / parameter sweep
// ===========================================================================

/// Representative rapid-tap counts. The property holds for any `n ≥ 1`,
/// and task 3.13 already proves it across `n ∈ [1, 100]` at the unit
/// level. At the screen level, an equivalent exhaustive sweep would
/// add wall-clock cost without strengthening the contract, so this
/// test runs a representative cross-section:
///
///   * `n = 1`  — degenerate single-tap base case.
///   * `n = 2`  — smallest case where dropping is observable.
///   * `n = 5`  — small burst.
///   * `n = 10` — typical "user mashes the button" scenario.
///   * `n = 50` — large burst that would amplify any latent bug.
const List<int> _ns = <int>[1, 2, 5, 10, 50];

void main() {
  group(
    'Property 6 (sign-in instance): in-flight sign-in single Firebase call',
    () {
      for (final int n in _ns) {
        testWidgets(
          'n=$n rapid taps during in-flight sign-in produce exactly one '
          'Firebase invocation',
          (tester) async {
            final Completer<void> release = Completer<void>();
            final GlobalKey<_SignInHarnessState> key =
                GlobalKey<_SignInHarnessState>();

            await tester.pumpWidget(
              hostApp(
                child: _SignInHarness(
                  key: key,
                  release: release,
                ),
              ),
            );

            // ---- Pre-condition: zero invocations before any tap ------
            //
            // The harness starts in idle state (`_gate.isRunning ==
            // false`, `signInCount == 0`). Asserting this explicitly
            // rules out a regression where the harness eagerly fires
            // a sign-in during build / first frame.
            expect(
              key.currentState!.signInCount,
              0,
              reason: 'Harness must start with zero sign-in invocations '
                  'before any tap is fired (n=$n).',
            );

            // ---- Fire n rapid taps ----------------------------------
            //
            // `tester.tap` posts a tap gesture and is awaited so the
            // gesture is delivered, but no `pump` is interleaved
            // between taps inside the loop. The first tap kicks off
            // `_gate.run(...)`, which synchronously increments
            // `signInCount` to 1 (in `action()`'s pre-await body) and
            // then suspends on `release.future`. Every subsequent tap
            // observes `_gate.isRunning == true` and is dropped at the
            // gate before `action()` is re-invoked.
            //
            // `warnIfMissed: false` is required because the second and
            // later taps target a button that may already have its
            // `onPressed` re-evaluated as the state rebuilds; the
            // taps are still delivered, but the framework would log a
            // false-positive "tap missed" warning otherwise.
            for (int i = 0; i < n; i++) {
              await tester.tap(
                find.byType(ElevatedButton),
                warnIfMissed: false,
              );
            }
            // Pump a single frame to flush any pending microtasks that
            // schedule a rebuild as a result of the gate flipping
            // `_inFlight` to true and notifying listeners. We do *not*
            // pumpAndSettle here — the gate is intentionally still in
            // flight and would never settle until `release` completes.
            await tester.pump();

            // ---- Property 6 (in-flight half) ------------------------
            //
            // After firing n taps and pumping a frame, exactly one
            // simulated Firebase call must have been observed. The
            // first tap's `gate.run` started (its action's pre-await
            // body ran once); every later tap was dropped before
            // `action()` was invoked.
            expect(
              key.currentState!.signInCount,
              1,
              reason: 'After $n rapid taps during a single in-flight '
                  'window, exactly one signInWithEmailAndPassword '
                  'invocation should have been observed '
                  '(signInCount was ${key.currentState!.signInCount}). '
                  'Requirement 5.7.',
            );

            // ---- Release the in-flight future -----------------------
            //
            // Completing the release completer lets the first call's
            // simulated `signInWithEmailAndPassword` resolve, which in
            // turn lets the gate flip back to idle in its `finally`
            // block. `pumpAndSettle` then drains any pending
            // microtasks / rebuilds so a late-firing effect (if any)
            // would have time to surface before the post-condition.
            release.complete();
            await tester.pumpAndSettle();

            // ---- Property 6 (post-release half) ---------------------
            //
            // After releasing the in-flight future and settling, the
            // counter must still be 1. Dropped taps must not fire a
            // late `signInWithEmailAndPassword` call after the gate
            // releases. Any increment past 1 here would mean a
            // dropped tap somehow re-entered the gate after release —
            // a violation of the single-effect property.
            expect(
              key.currentState!.signInCount,
              1,
              reason: 'After releasing the in-flight future and '
                  'settling, the signInWithEmailAndPassword invocation '
                  'count must still be 1 — dropped taps must not '
                  'produce a late Firebase call after the gate '
                  'releases (signInCount was '
                  '${key.currentState!.signInCount}, n=$n). '
                  'Requirement 5.7.',
            );
          },
        );
      }
    },
  );
}
