// Feature: figma-ui-redesign, Property 7: password visibility toggle round-trip
//
// Validates: Requirements 5.4
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// Given any `String password` entered into the login password field, and
// any non-negative even integer `k`, performing exactly `k` taps on the
// visibility toggle returns the field to its initial obscured state
// (`obscureText == true`) AND leaves the controller's text equal to the
// originally entered `password`. In other words, the toggle is a self-
// inverse operation: an even number of toggles is the identity for both
// the obscure flag and the entered text.
//
// This captures the contract from Requirement 5.4 (figma-ui-redesign):
// tapping the password visibility toggle flips obscured/revealed state,
// updates the icon, and "preserves the entered password value across the
// toggle" — applied across an arbitrary number of toggle pairs.
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The figma-ui-redesign tasks file flags this case as `[PBT]`. Glados-
// style property tests run synchronously over generated inputs, but a
// password-visibility round-trip is fundamentally a *widget* test:
// `tester.pumpWidget`, `tester.enterText`, and `tester.tap` only resolve
// inside a `testWidgets` body. This file therefore implements the
// property as a parametric / exhaustive widget sweep — the same shape
// used by `test/widgets/ui/hit_target_floor_pbt_test.dart` (task 4.14)
// and `test/widgets/ui/contrast_ratio_pbt_test.dart` (task 4.15) — that
// iterates over a representative `(password, k)` cartesian product and
// asserts the round-trip invariant for each combination.
//
// ===========================================================================
// Why a private `_PasswordFieldHarness` instead of mounting LoginScreen
// ===========================================================================
//
// The full `LoginScreen` reaches into Firebase (`signInWithEmailAndPassword`)
// inside `initState` / build paths and depends on `firebase_auth` plugin
// channels that are not registered in the `flutter test` host. Mounting
// it directly here would either hang on first-frame plugin invocation or
// crash with a `MissingPluginException`. Per the task's implementation
// guidance, the test instead defines a private `_PasswordFieldHarness`
// `StatefulWidget` that mirrors the toggle logic from
// `lib/screens/login_screen.dart` exactly: a private `bool _obscure`
// initialised to `true`, an `AppTextField` whose `obscureText` is bound
// to the flag, and an `AppIconButton` suffix that flips the flag inside
// `setState`. Testing the harness exercises the same toggle pattern in
// isolation, with no Firebase or plugin dependency.

import 'package:drive_care_plus/widgets/ui/app_icon_button.dart';
import 'package:drive_care_plus/widgets/ui/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

// ===========================================================================
// Test harness — mirrors login_screen.dart's password toggle logic
// ===========================================================================

/// Standalone, Firebase-free reproduction of the password field + toggle
/// pattern from `lib/screens/login_screen.dart`.
///
/// Mirrors verbatim:
///   * `bool _obscure = true` initial state (Requirement 5.3).
///   * `AppTextField(obscureText: _obscure, ...)` with a leading lock
///     icon and an `AppIconButton` suffix.
///   * Tapping the suffix calls `setState(() => _obscure = !_obscure)`,
///     swaps the icon between `Icons.visibility` and
///     `Icons.visibility_off`, and leaves the `TextEditingController`
///     untouched (Requirement 5.4).
///
/// The harness exposes its `TextEditingController` via the `controller`
/// parameter so the test can read the entered text directly after a
/// sequence of toggles, and exposes its current `_obscure` value
/// indirectly via the rendered `AppTextField.obscureText` field (read
/// through `tester.widget<AppTextField>(...)`).
class _PasswordFieldHarness extends StatefulWidget {
  const _PasswordFieldHarness({required this.controller});

  final TextEditingController controller;

  @override
  State<_PasswordFieldHarness> createState() => _PasswordFieldHarnessState();
}

class _PasswordFieldHarnessState extends State<_PasswordFieldHarness> {
  // Initial state: obscured. This matches Requirement 5.3 ("first
  // displayed ... obscured state with the visibility toggle icon set to
  // the show-password indicator") and is exactly the initialiser used
  // in `lib/screens/login_screen.dart`.
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: 'Password',
      prefixIcon: Icons.lock_outline,
      obscureText: _obscure,
      suffix: AppIconButton(
        // Icon swap mirrors login_screen.dart: when obscured we show
        // the "eye-off" glyph (i.e. "tap to reveal"); when revealed
        // we show the "eye" glyph (i.e. "tap to hide").
        icon: _obscure ? Icons.visibility_off : Icons.visibility,
        semanticsLabel: _obscure ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

// ===========================================================================
// Generators / parameter sweep
// ===========================================================================

/// Representative password sample set covering the input space:
///   * empty string                      — boundary case
///   * single ASCII char                 — minimal non-empty
///   * mixed-case + symbols + digits     — typical strong password
///   * long string with whitespace       — ensures spaces survive toggles
///   * emoji                             — exercises grapheme handling
const List<String> _passwords = <String>[
  '',
  'a',
  'pa\$\$w0rd!',
  'verylongpasswordwith spaces',
  '🔒emoji',
];

/// Non-negative even integers: `k = 0` is the trivial identity case
/// (no toggles), `k = 2` is one pair, `k = 4` is two pairs, `k = 10` is
/// five pairs — sufficient to exercise the round-trip invariant under
/// repeated application without inflating wall-clock time.
const List<int> _ks = <int>[0, 2, 4, 10];

void main() {
  group('Property 7: password visibility toggle round-trip', () {
    // Parametric sweep over the cartesian product of password values and
    // even toggle counts. Each (password, k) pair is hoisted into a
    // `testWidgets` so its name surfaces independently in the test
    // runner output and a regression in any single combination is
    // pinpointed without manual triangulation.
    for (final String password in _passwords) {
      for (final int k in _ks) {
        // Sanity-check the generator: the property only applies for
        // non-negative even k. A non-even or negative entry in `_ks`
        // would silently invalidate the property; assert at the
        // generator level so a future edit cannot drift.
        assert(k >= 0, 'k must be non-negative');
        assert(k % 2 == 0, 'k must be even for the round-trip property');

        // Display passwords escape control / special chars so the
        // testWidgets name remains readable in the runner output even
        // for emoji and embedded whitespace.
        final String displayPassword = password.isEmpty
            ? '<empty>'
            : password.replaceAll(' ', '·');

        testWidgets(
          'k=$k toggles return to obscured for password="$displayPassword"',
          (tester) async {
            final TextEditingController controller =
                TextEditingController();
            addTearDown(controller.dispose);

            await tester.pumpWidget(
              hostApp(
                child: _PasswordFieldHarness(controller: controller),
              ),
            );

            // ---- Pre-condition: initial state is obscured ------------
            //
            // Requirement 5.3 mandates the field renders obscured on
            // first display. The round-trip property assumes this as
            // its starting point — a regression in the initial state
            // would silently invalidate every (password, k) assertion
            // below, so it is asserted explicitly before any toggling.
            AppTextField field =
                tester.widget<AppTextField>(find.byType(AppTextField));
            expect(
              field.obscureText,
              isTrue,
              reason: 'AppTextField must render obscured on first '
                  'display (Requirement 5.3) before the round-trip '
                  'property can be evaluated.',
            );

            // ---- Enter the generated password ------------------------
            //
            // `enterText` writes through the TextField and updates the
            // bound controller as a real keyboard would. For the empty
            // password case this is effectively a no-op — `controller
            // .text` already starts as the empty string.
            if (password.isNotEmpty) {
              await tester.enterText(find.byType(AppTextField), password);
              await tester.pump();
            }

            expect(
              controller.text,
              password,
              reason: 'Controller text after enterText must equal the '
                  'generated password before any toggles are applied.',
            );

            // ---- Perform k visibility toggles ------------------------
            //
            // Each tap on the AppIconButton suffix flips _obscure. For
            // any non-negative even k, the field must end up in its
            // original obscured state, and the controller text must
            // remain unchanged. The loop applies the toggles one by
            // one, pumping a frame after each so the next tap targets
            // the freshly rebuilt suffix icon.
            for (int i = 0; i < k; i++) {
              await tester.tap(find.byType(AppIconButton));
              await tester.pump();
            }

            // ---- Post-condition: field obscured AND text preserved ---
            //
            // The round-trip invariant has two halves:
            //   1. obscureText returns to `true`.
            //   2. controller.text equals the originally entered
            //      password (toggles are visually-only; they must not
            //      mutate the entered value — Requirement 5.4 "preserves
            //      the entered password value across the toggle").
            // Both are asserted independently with explanatory `reason`
            // messages so a failure surfaces which half of the property
            // broke.
            field = tester.widget<AppTextField>(find.byType(AppTextField));
            expect(
              field.obscureText,
              isTrue,
              reason: 'After $k toggles (even), AppTextField.obscureText '
                  'must return to true (round-trip identity, '
                  'Requirement 5.4). password="$displayPassword".',
            );
            expect(
              controller.text,
              password,
              reason: 'After $k toggles (even), the password controller '
                  'text must still equal the originally entered value '
                  '(Requirement 5.4 — toggle preserves entered value). '
                  'password="$displayPassword".',
            );
          },
        );
      }
    }
  });
}
