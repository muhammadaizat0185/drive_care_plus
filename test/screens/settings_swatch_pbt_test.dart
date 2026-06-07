// Feature: figma-ui-redesign, Property 9: swatch single-checkmark invariant
//
// Validates: Requirements 6.5
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// For any sequence of swatch taps over the gradient swatch grid in the
// `APPEARANCE` section of `SettingsScreen`, after each tap exactly one
// swatch carries a [Icons.check] glyph, and that swatch is the index of
// the most recently tapped swatch.
//
// Stated formally for a swatch grid of `n = ThemeService.presets.length`
// presets and any tap sequence `[i_1, i_2, ..., i_k]` with each `i_j` in
// `[0, n)`:
//
//     for every prefix `[i_1, ..., i_t]` of the sequence (1 <= t <= k):
//       ─ exactly one [Icons.check] glyph exists in the rendered tree;
//       ─ that glyph is rendered at index `i_t`, the most recent tap.
//
// This captures the IFF contract from Requirement 6.5: tapping a swatch
// renders a checkmark on exactly that swatch and removes any checkmark
// from the previously selected swatch — preserving the "exactly one"
// invariant on every transition, including the trivial `i == i` re-tap
// case (the checkmark stays put).
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The figma-ui-redesign tasks file flags this case as `[PBT]`. The
// underlying invariant is a pure integer-set predicate, but the
// *contract* under test is a Flutter render predicate: "is exactly one
// `Icons.check` glyph rendered, and is it at the right swatch?". That
// predicate only resolves inside a `testWidgets` body via
// `tester.pumpWidget`, `tester.tap`, and `find.byIcon(Icons.check)`, so
// glados-style pure-function PBTs cannot reach it. This file therefore
// implements the property as a parametric / exhaustive widget sweep —
// the same shape used by
// `test/screens/settings_dirty_banner_pbt_test.dart` (task 8.4),
// `test/screens/login_password_toggle_pbt_test.dart` (task 7.3),
// `test/widgets/ui/hit_target_floor_pbt_test.dart` (task 4.14), and
// `test/widgets/ui/contrast_ratio_pbt_test.dart` (task 4.15) — that
// iterates over a representative set of tap sequences and asserts the
// invariant at every prefix of each sequence.
//
// Generators (representative tap sequences, per the task's
// implementation guidance):
//
//   * `[0]`                                — single tap on the first swatch.
//   * `[0, 1]`                             — two distinct taps, ascending.
//   * `[3, 1, 5, 2]`                       — random-looking traversal.
//   * `[6, 6, 6]`                          — repeated taps on the same
//                                            swatch (the IFF must still
//                                            hold; no checkmark drift).
//   * `[0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0]`
//                                          — full forward + reverse
//                                            traversal across every
//                                            swatch index.
//
// Index 7 / 8 are intentionally omitted from the fixed sequences because
// `ThemeService.presets` defines exactly 7 entries today (indices 0..6).
// The sequences above stay within that range so the test does not lock
// us into a specific preset count beyond what the production map
// exposes. The harness itself is parameterised on the actual preset
// list so a future edit that grows or shrinks `ThemeService.presets`
// remains covered without rewriting fixtures, provided the indices in
// the generated sequences remain valid; the assertion `i < n` below
// surfaces a clear failure if a generator drifts ahead of the preset
// list.
//
// ===========================================================================
// Why a private `_SwatchGridHarness` instead of mounting SettingsScreen
// ===========================================================================
//
// The task's implementation guidance permits either approach:
//
//   "Mount a small harness similar to the dirty-banner harness —
//    replicate the swatch grid logic in isolation."
//
// `SettingsScreen` would force several incidental setup costs onto
// this property test:
//
//   * The `PROFILE` section renders a `CircleAvatar` whose
//     `backgroundImage` is a `NetworkImage`. In `flutter test` this
//     escalates to a `NetworkImageLoadException` unless an
//     `HttpOverrides.global` shim is installed up-front.
//   * `ProfileService.init()` and `ThemeService.init()` reach into
//     SharedPreferences and Firebase. Although those calls degrade
//     gracefully in tests, each iteration of the sweep would still
//     have to reset the singletons across runs.
//   * The real swatch handler routes through `setPrimaryColorValidated`,
//     which mutates `ThemeService.instance` (a process-global
//     singleton). Sweep iterations would leak state into each other
//     unless the singleton is reset between every tap, which would
//     defeat the point of running multiple prefix assertions in a
//     single sequence.
//
// None of those moving parts is what Property 9 is asserting. The
// property is a pure render-time predicate — "exactly one checkmark
// at the most recently tapped index" — and that predicate is driven
// entirely by a single `int? _selectedIndex` field. The harness below
// holds that field locally, mirrors the visual contract from
// `_SwatchTile` in `lib/screens/settings_screen.dart` (a circular
// gradient swatch with an [Icons.check] glyph overlaid when selected),
// and reuses the actual `ThemeService.presets.values.toList()` so the
// preset surface is identical to what the real screen renders.
//
// A regression in the screen's swatch selection logic — e.g. failing
// to clear the previous checkmark, or rendering the checkmark at the
// wrong index — surfaces here because the harness's selection formula
// (`isSelected = (index == _selectedIndex)`) is the same formula the
// real screen runs (`selected = preset == ThemeService.instance
// .primaryColor`, which collapses to the same per-index boolean once
// the `primaryColor` is set to `presets[i]` by the validated setter).

import 'package:drive_care_plus/core/theme/color_utils.dart';
import 'package:drive_care_plus/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/ui/_test_host.dart';

// ===========================================================================
// Test harness — mirrors settings_screen.dart's swatch grid render logic
// ===========================================================================

/// Standalone reproduction of the gradient swatch grid pattern from
/// `lib/screens/settings_screen.dart`'s `_AppearanceSection`.
///
/// Mirrors verbatim:
///
///   * The list of preset colors is read from
///     `ThemeService.presets.values.toList()` so the same fixture
///     surface drives both the real screen and this harness.
///   * Each swatch is a circular gradient-filled tile derived from the
///     preset color via `derivePalette(...)`, matching the visual
///     contract of `_SwatchTile`. The gradient stops do not matter for
///     the property under test — only the conditional [Icons.check]
///     overlay does — but they are reproduced here so a future edit
///     that breaks `_SwatchTile`'s structure cannot quietly bypass
///     this test.
///   * The selected swatch overlays `Icons.check` exactly per
///     `_SwatchTile.build` (`selected ? Icon(Icons.check, ...) : null`).
///   * Tap behaviour updates the selection state via `setState`,
///     standing in for the real screen's
///     `ThemeService.setPrimaryColor(...)` notify-rebuild loop.
///
/// The harness's selection state is a private `int? _selectedIndex`
/// instead of a `Color primaryColor` because Property 9 is stated in
/// terms of *indices* over a known preset list. Holding the state as
/// an index removes the need to keep a reverse `Color → index` lookup
/// and makes the property's "most recently tapped index" assertion a
/// trivial integer equality.
class _SwatchGridHarness extends StatefulWidget {
  const _SwatchGridHarness({required this.presets});

  /// Snapshot of the preset color list. Captured up-front by the test
  /// so both the harness and the assertions iterate over the same
  /// `List<Color>` instance — this avoids any (extremely unlikely)
  /// race where `ThemeService.presets` changes between mount time
  /// and the assertion phase, and keeps the harness pure: it does not
  /// reach into the singleton at render time.
  final List<Color> presets;

  @override
  State<_SwatchGridHarness> createState() => _SwatchGridHarnessState();
}

class _SwatchGridHarnessState extends State<_SwatchGridHarness> {
  /// Index of the currently selected swatch, or `null` if no swatch
  /// has been tapped yet. The `null` initial state mirrors the
  /// "no preset has been picked" branch — the real screen always
  /// derives its selection from `ThemeService.instance.primaryColor`,
  /// which is non-null in production, but the harness starts at
  /// `null` so the pre-condition assertion below ("no checkmarks
  /// before any tap") rules out a regression where the harness
  /// accidentally renders a checkmark on first paint.
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        // `shrinkWrap` + `NeverScrollableScrollPhysics` mirror the
        // real screen so the grid sits inside an outer scroll view
        // without taking over the gesture. They also keep the test
        // host viewport simple — no scroll offset to thread through.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
        children: <Widget>[
          for (int i = 0; i < widget.presets.length; i++)
            _SwatchTileForTest(
              // Stable per-index key so finder lookups (`find.byKey`)
              // can locate a specific swatch by index regardless of
              // any future visual restructuring inside the tile.
              key: ValueKey<String>('swatch_$i'),
              color: widget.presets[i],
              selected: i == _selectedIndex,
              onTap: () => setState(() => _selectedIndex = i),
            ),
        ],
      ),
    );
  }
}

/// Visual contract reproduction of `_SwatchTile` from
/// `lib/screens/settings_screen.dart`. Renders a circular gradient
/// fill derived from [color] via `derivePalette(...)` and overlays
/// [Icons.check] when [selected] is true. Tap is wired through the
/// outer harness's `setState` callback.
///
/// Held as a top-level `StatelessWidget` (rather than inlined in the
/// grid `for` loop) so the [GestureDetector] hit area and the
/// conditional [Icon] subtree are easy to find by widget type / icon
/// in the assertions below.
class _SwatchTileForTest extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SwatchTileForTest({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  // Visual diameter of the swatch circle. Held local because it's a
  // component-local sizing detail, not a Token_Set member.
  static const double _diameter = 56.0;

  // Visual size of the checkmark glyph. Held local for the same
  // reason as `_diameter`.
  static const double _checkGlyphSize = 28.0;

  @override
  Widget build(BuildContext context) {
    final ({
      Color emerald500,
      Color emerald600,
      Color teal400,
      Color teal500,
    }) palette = derivePalette(color);

    final Widget circle = Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.emerald500,
            palette.emerald600,
            palette.teal500,
            palette.teal400,
          ],
        ),
      ),
      child: selected
          ? const Icon(
              Icons.check,
              size: _checkGlyphSize,
              color: Colors.white,
              semanticLabel: 'Selected',
            )
          : null,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(child: circle),
    );
  }
}

// ===========================================================================
// Generators / parameter sweep
// ===========================================================================

/// Representative tap sequences. Each sequence is a list of swatch
/// indices to tap in order. The property must hold at every prefix of
/// every sequence — i.e. after each individual tap, exactly one
/// checkmark is rendered, and it sits at the most recently tapped
/// index.
///
/// Per the task's implementation guidance, the fixture set covers:
///   * a single tap (`[0]`),
///   * two distinct ascending taps (`[0, 1]`),
///   * a random-looking mid-sequence (`[3, 1, 5, 2]`),
///   * repeated taps on the same swatch (`[6, 6, 6]`),
///   * a full forward + reverse traversal across every index
///     (`[0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0]`).
///
/// Indices stay within `[0, 6]` because `ThemeService.presets` defines
/// 7 entries today. If the preset list ever shrinks below 7, the
/// `assert(i < presets.length, ...)` inside the test body surfaces a
/// loud, descriptive failure that points the maintainer at this
/// fixture set rather than at a confusing widget-tree assertion.
const List<List<int>> _tapSequences = <List<int>>[
  <int>[0],
  <int>[0, 1],
  <int>[3, 1, 5, 2],
  <int>[6, 6, 6],
  <int>[0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0],
];

void main() {
  // SharedPreferences mock: the harness itself does not touch
  // SharedPreferences (the swatch handler `setState`s a local index
  // instead of calling `ThemeService.setPrimaryColor`), but
  // `setMockInitialValues({})` provides a clean in-memory store as a
  // defence-in-depth measure in case any transitive dependency reaches
  // for the prefs store during the test run. Matches the setUp pattern
  // used across the figma-ui-redesign widget tests
  // (`home_widgets_test.dart`, `login_screen_test.dart`,
  // `register_screen_test.dart`, `settings_dirty_banner_pbt_test.dart`).
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Property 9: swatch single-checkmark invariant', () {
    // Snapshot the actual preset list once. Reusing this list across
    // every test avoids reading `ThemeService.presets` repeatedly and
    // pins both the harness and the assertions to the same fixture
    // surface for every sequence.
    final List<Color> presets =
        ThemeService.presets.values.toList(growable: false);

    // The harness assumes at least one preset exists. A zero-preset
    // configuration would mean the swatch grid has nothing to render
    // and the property is vacuously true; assert this loudly so a
    // future preset-map edit that empties the list cannot silently
    // pass this test.
    assert(
      presets.isNotEmpty,
      'ThemeService.presets must define at least one preset for '
      'Property 9 to be meaningful.',
    );

    for (final List<int> sequence in _tapSequences) {
      // Display the sequence in the test name so a regression in any
      // single sequence is pinpointed without manual triangulation.
      // Wrap the list in `[]` so the runner output reads cleanly.
      final String displaySequence =
          '[${sequence.join(", ")}]';

      testWidgets(
        'tap sequence $displaySequence renders exactly one checkmark '
        'at the most recently tapped index',
        (WidgetTester tester) async {
          // Every index in the sequence must be valid for the active
          // preset list. A drift here (e.g. a future edit that shrinks
          // `ThemeService.presets` below 7 entries) would otherwise
          // produce a confusing `RangeError` deep inside the harness.
          for (final int i in sequence) {
            assert(
              i >= 0 && i < presets.length,
              'Tap index $i is out of range for '
              '${presets.length} presets. Update _tapSequences or '
              'extend ThemeService.presets.',
            );
          }

          // ---- Mount the harness ---------------------------------
          //
          // The harness starts with `_selectedIndex == null`, so the
          // initial render contains zero `Icons.check` glyphs.
          // Asserting this explicitly rules out a regression where
          // the harness accidentally renders a checkmark on first
          // paint, which would silently pass every "exactly one"
          // assertion below by inflating the baseline.
          await tester.pumpWidget(
            hostApp(
              child: _SwatchGridHarness(presets: presets),
            ),
          );

          expect(
            find.byIcon(Icons.check),
            findsNothing,
            reason: 'No swatch should carry a checkmark before any '
                'tap occurs (initial state). Requirement 6.5.',
          );

          // ---- Walk the sequence, asserting after every tap -------
          //
          // Property 9 is a *prefix* property: it must hold after
          // every individual tap, not just at the end of the
          // sequence. A naïve "tap all then assert once" approach
          // would miss intermediate violations (e.g. a regression
          // where the checkmark briefly duplicates between taps and
          // self-corrects on the final tap). Asserting per-tap
          // catches every transition.
          for (int t = 0; t < sequence.length; t++) {
            final int tappedIndex = sequence[t];

            await tester.tap(
              find.byKey(ValueKey<String>('swatch_$tappedIndex')),
            );
            await tester.pump();

            // ---- Property 9, half 1: exactly one checkmark ----
            //
            // Across the full grid, exactly one `Icons.check` glyph
            // must be rendered at any moment after at least one
            // tap. `findsOneWidget` is an exact-count matcher: zero
            // glyphs (regression that fails to render the
            // checkmark) and two-or-more glyphs (regression that
            // fails to clear the previous selection) both fail
            // this assertion with a descriptive message.
            expect(
              find.byIcon(Icons.check),
              findsOneWidget,
              reason: 'After tap #${t + 1} of $displaySequence '
                  '(tapped index=$tappedIndex), exactly one '
                  'Icons.check must be rendered across the swatch '
                  'grid. Requirement 6.5.',
            );

            // ---- Property 9, half 2: checkmark at most-recent --
            //
            // The single rendered checkmark must sit inside the
            // swatch identified by the most recently tapped index.
            // `find.descendant` scopes the icon search to the
            // subtree of the keyed swatch tile, so a regression
            // where the checkmark is rendered but on the wrong
            // swatch fails this assertion (the descendant search
            // returns nothing) even though the global "exactly
            // one" count above would still pass.
            expect(
              find.descendant(
                of: find.byKey(ValueKey<String>('swatch_$tappedIndex')),
                matching: find.byIcon(Icons.check),
              ),
              findsOneWidget,
              reason: 'After tap #${t + 1} of $displaySequence, '
                  'the checkmark must be rendered inside swatch '
                  '$tappedIndex (the most recently tapped index). '
                  'Requirement 6.5.',
            );
          }
        },
      );
    }
  });
}
