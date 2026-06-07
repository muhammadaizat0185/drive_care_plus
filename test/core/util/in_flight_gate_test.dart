// Feature: figma-ui-redesign, Property 6: in-flight gate single-effect
//
// Validates: Requirements 4.8, 5.7
//
// `InFlightGate.run<T>(Future<T> Function() action)` is the reusable
// single-effect guard used by the home cockpit `Top Up` action
// (Requirement 4.8) and the login `Sign In` button (Requirement 5.7). Its
// contract is:
//
//   * If a previous invocation is still in flight (`isRunning == true`),
//     the new call is dropped — `action` is **never invoked** and the call
//     resolves to `null`.
//   * Otherwise the gate flips to in-flight, awaits `action()`, returns
//     the resolved value, and flips back to idle in a `finally` block so
//     subsequent calls can proceed.
//
// The universal property the task asks us to assert is:
//
//   For any `n ∈ [1, 100]`, kicking off `n` rapid `gate.run(action)` calls
//   during a single in-flight window produces **exactly one** downstream
//   effect — the first call's `action()` is invoked once, every later
//   call is dropped before `action()` runs, and no late-firing action
//   ever increments the effect counter after the gate releases.
//
// Property body:
//   1. Construct a fresh `InFlightGate` per iteration.
//   2. Use a `Completer<void>` as the in-flight signal so the first
//      `action()` stays awaiting until we explicitly complete it. This
//      keeps the gate `isRunning == true` for every subsequent
//      `gate.run(...)` call in the same loop tick, exercising the
//      "drop re-entrant call" branch.
//   3. Kick off `n` rapid `gate.run(action)` calls without awaiting any
//      of them. `action()` increments a shared counter at its very
//      first synchronous statement, before awaiting the completer.
//   4. Assert the counter equals 1 immediately after the loop. Dart
//      runs an async function body synchronously up to its first
//      `await`, so the first call's `_inFlight = true` is set and the
//      first `action()`'s `counter++` runs before control returns to
//      the next loop iteration. Every subsequent iteration short-
//      circuits at the `if (_inFlight)` branch and `action()` is
//      never invoked.
//   5. Complete the completer to let the first call finish.
//   6. Await every kicked-off future via `Future.wait` so any late-
//      firing side effect would have time to surface.
//   7. Assert the counter is still 1 — the gate's release path runs
//      `_inFlight = false` only after the first `action()` resolves,
//      and the dropped calls have already returned `null`, so no
//      action body can run after the await chain completes.
//
// Generator:
//   - `n: int` via `any.intInRange(1, 101)`. Glados `intInRange` is
//     half-open `[min, max)`, so `(1, 101)` yields integers `1..100`
//     inclusive, matching the task's `n ∈ [1, 100]` requirement.
//
// Glados is configured for 100 runs so this property comfortably meets
// the 100-iteration minimum required by the task.

import 'dart:async';

import 'package:drive_care_plus/core/util/in_flight_gate.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`. Mirrors the
// pattern used by the other PBT tests in this folder. `Completer` is
// imported from `dart:async` and does not conflict with any glados
// re-export, so it is intentionally not hidden.
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

void main() {
  Glados<int>(
    // n ∈ [1, 100] — Glados intInRange is half-open [min, max).
    any.intInRange(1, 101),
    ExploreConfig(numRuns: 100),
  ).test(
    'InFlightGate.run: exactly one downstream effect for n rapid calls '
    'during in-flight; no late-firing action after release',
    (int n) async {
      final InFlightGate gate = InFlightGate();
      final Completer<void> release = Completer<void>();
      int counter = 0;

      // The single shared action: increments the counter at its first
      // synchronous statement (before any `await`), so the very act of
      // invoking it produces an observable effect. Awaiting `release`
      // pins the first call in-flight until the property body decides
      // to let it complete.
      Future<int> action() async {
        counter++;
        await release.future;
        return counter;
      }

      // Kick off `n` rapid `gate.run` calls without awaiting any of
      // them. The first call enters the gate, runs `action()`'s
      // pre-await body (incrementing the counter to 1), and then
      // suspends on `release.future`. The remaining `n - 1` calls
      // observe `_inFlight == true` and short-circuit at the
      // `if (_inFlight) return null` branch — `action()` is never
      // invoked for them.
      final List<Future<int?>> futures = <Future<int?>>[];
      for (int i = 0; i < n; i++) {
        futures.add(gate.run<int>(action));
      }

      // Property 6 — exactly one downstream effect was observed at
      // the moment all `n` calls have been kicked off. The first
      // call's `action()` ran its pre-await body once; every later
      // call was dropped before `action()` was invoked.
      expect(
        counter,
        equals(1),
        reason:
            'After kicking off $n rapid gate.run() calls during a single '
            'in-flight window, exactly one action() invocation should '
            'have been observed (counter was $counter)',
      );

      // Release the first call so it can finish; this also flips
      // `_inFlight` back to false in the gate's `finally` block.
      release.complete();

      // Await every kicked-off future. Dropped calls already
      // resolved to `null` synchronously; the first call resolves
      // to its returned value once `action()` runs through to its
      // `return` statement after the await.
      await Future.wait<int?>(futures);

      // Property 6 — no late-firing actions. After the await chain
      // completes, the counter is still 1: the dropped calls never
      // invoked `action()`, and the first call's `action()` body
      // increments the counter only once before the first await.
      expect(
        counter,
        equals(1),
        reason:
            'After awaiting all $n gate.run() futures and releasing the '
            'in-flight action, counter should still be 1 — dropped calls '
            'must not invoke action() after the gate releases (counter was '
            '$counter)',
      );
    },
  );
}
