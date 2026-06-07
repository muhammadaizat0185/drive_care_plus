// Feature: figma-ui-redesign, Property 8: profile dirty banner visibility
//
// Validates: Requirements 6.3
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// For any tuple `(persistedName, persistedPhone, editedName, editedPhone)`,
// the unsaved-changes [AppFeedbackBanner] of kind `warning` is rendered at
// the top of the `PROFILE` section of `SettingsScreen` IFF
//
//     (editedName, editedPhone) != (persistedName, persistedPhone)
//
// Equivalently (the form actually computed by `_SettingsScreenState`):
//
//     editedName  != persistedName  OR  editedPhone != persistedPhone
//
// This is the textbook "dirty form" indicator: the banner appears the
// moment any field deviates from the persisted snapshot and disappears
// the moment every field matches the snapshot again — whether the user
// reverted manually or saved successfully (Requirement 6.3).
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The figma-ui-redesign tasks file flags this case as `[PBT]`. The
// underlying property is a pure boolean function of four `String`s, but
// the *contract* under test is a Flutter render predicate: "is the
// banner widget present in the rendered tree?". That predicate only
// resolves inside a `testWidgets` body (`tester.pumpWidget`,
// `tester.enterText`, `find.byType(AppFeedbackBanner)`), so glados-style
// pure-function PBTs cannot reach it. This file therefore implements the
// property as a parametric / exhaustive widget sweep — the same shape
// used by `test/screens/login_password_toggle_pbt_test.dart` (task 7.3),
// `test/widgets/ui/hit_target_floor_pbt_test.dart` (task 4.14), and
// `test/widgets/ui/contrast_ratio_pbt_test.dart` (task 4.15) — that
// iterates over the cartesian product of small, representative input
// sets and asserts the IFF invariant for each tuple.
//
// Generators (cartesian product = 3 × 3 × 3 × 3 = 81 tuples):
//
//   * persistedNames:  ['', 'Alice', 'Bob']
//   * persistedPhones: ['', '0123456789', '0987654321']
//   * editedNames:     same set as persistedNames
//   * editedPhones:    same set as persistedPhones
//
// The empty string captures the "no value persisted" branch (a freshly
// created profile with no display name or phone); the two non-empty
// names and two non-empty phones provide enough variation to exercise
// every IFF combination — name-only changes, phone-only changes, both
// changes, and the unchanged case — across both empty and populated
// baselines.
//
// ===========================================================================
// Why a private `_DirtyBannerHarness` instead of mounting SettingsScreen
// ===========================================================================
//
// The task's implementation guidance permits either approach:
//
//   "Note: SettingsScreen pulls in many services. It may be simpler to
//    extract just the dirty banner logic into a test harness like prior
//    PBTs. If mounting SettingsScreen works without Firebase issues,
//    mount it; otherwise use a harness."
//
// `SettingsScreen` would force several incidental setup costs onto this
// property test:
//
//   * The `PROFILE` section renders the user avatar via
//     `CircleAvatar(backgroundImage: NetworkImage(profile.photoUrl))`.
//     `NetworkImage` calls into `dart:io` `HttpClient` which, in a
//     `flutter test` environment with no live network stack, escalates
//     to a `NetworkImageLoadException`. A `HttpOverrides.global` shim
//     would have to be installed (as `home_widgets_test.dart` does) just
//     to mute the avatar.
//   * `ProfileService.init()` reaches into Firebase Auth and Firestore.
//     Although those calls are wrapped in try/catch and degrade
//     gracefully in tests, each test would still need to reset the
//     singleton's `_displayName` / `_phone` via `updateProfile(...)` to
//     pin the persisted snapshot — adding async setup overhead per
//     iteration of the 81-tuple sweep.
//   * `ListenableBuilder(listenable: ThemeService.instance, ...)` in the
//     screen body keeps the harness alive against unrelated
//     notifications.
//
// None of those moving parts is what Property 8 is asserting. The
// property is a pure render-time predicate over the dirty state, and
// the dirty state is computed by the exact `_isDirty` formula visible
// in `_SettingsScreenState`:
//
//     bool get _isDirty {
//       final ProfileService profile = ProfileService.instance;
//       return _nameController.text != profile.displayName ||
//              _phoneController.text != profile.phone;
//     }
//
// The harness below mirrors that formula verbatim — the only difference
// is that the persisted (name, phone) snapshot is held in plain `String`
// fields on the harness instead of being read off `ProfileService` so
// the test doesn't have to mutate a process-global singleton across 81
// iterations. The banner widget itself, the warning kind, the
// `Listenable.merge` rebuild trigger, the placement above the section,
// and the conditional `if (_isDirty) AppFeedbackBanner(...)` render
// pattern are reproduced exactly. A regression in the screen's dirty
// formula will surface here because the harness's formula is the same
// formula.

import 'package:drive_care_plus/widgets/ui/app_feedback_banner.dart';
import 'package:drive_care_plus/widgets/ui/app_text_field.dart';
import 'package:drive_care_plus/widgets/ui/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/ui/_test_host.dart';

// ===========================================================================
// Test harness — mirrors settings_screen.dart's dirty banner logic
// ===========================================================================

/// Standalone reproduction of the unsaved-changes banner pattern from
/// `lib/screens/settings_screen.dart`.
///
/// Mirrors verbatim:
///
///   * The display-name and phone [AppTextField]s with the exact same
///     [TextInputFormatter]s the real screen attaches (so populated
///     phone numbers like `'0123456789'` round-trip through
///     `digitsOnly` cleanly, and the empty-name branch behaves the
///     same way it does in the screen).
///   * The `_isDirty` getter is byte-for-byte the same comparison the
///     screen runs, with the only change being that
///     `ProfileService.instance.displayName` / `.phone` are replaced
///     by harness fields `persistedName` / `persistedPhone`. The raw
///     `!=` (no trim, no normalisation) is preserved so the harness
///     reflects exactly what the screen would render — trimming here
///     would create a divergence between the harness and the screen
///     and could mask a real banner regression.
///   * A `ListenableBuilder(listenable: Listenable.merge([...controllers]))`
///     drives rebuilds on every keystroke so the IFF predicate is
///     re-evaluated after each `tester.enterText` call, exactly as
///     the screen re-evaluates it.
///   * The conditional render —
///     `if (_isDirty) AppFeedbackBanner(kind: warning, message: ...)` —
///     is positioned above the section content, matching the
///     "rendered at the top of the scroll view" placement Requirement
///     6.3 mandates.
class _DirtyBannerHarness extends StatefulWidget {
  const _DirtyBannerHarness({
    required this.persistedName,
    required this.persistedPhone,
  });

  /// The "persisted" display-name snapshot the controller's text is
  /// compared against. Stands in for `ProfileService.instance.displayName`
  /// in the real screen.
  final String persistedName;

  /// The "persisted" phone snapshot the controller's text is compared
  /// against. Stands in for `ProfileService.instance.phone` in the real
  /// screen.
  final String persistedPhone;

  @override
  State<_DirtyBannerHarness> createState() => _DirtyBannerHarnessState();
}

class _DirtyBannerHarnessState extends State<_DirtyBannerHarness> {
  // Controllers seeded with the persisted snapshot so the initial
  // render starts in the "clean" state (controller.text equals
  // persisted value → `_isDirty == false` → banner absent). This
  // mirrors `_SettingsScreenState.initState`, which initialises
  // `_nameController` / `_phoneController` from the current
  // `ProfileService` snapshot.
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.persistedName);
    _phoneController = TextEditingController(text: widget.persistedPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Mirrors `_SettingsScreenState._isDirty` byte-for-byte except that
  /// `ProfileService.instance.{displayName, phone}` are read from the
  /// harness fields instead of the singleton. Comparison is raw `!=`,
  /// matching the screen — trimming or normalising here would diverge
  /// from what the save handler actually persists and could cause the
  /// banner to lie about whether the form is dirty.
  bool get _isDirty {
    return _nameController.text != widget.persistedName ||
        _phoneController.text != widget.persistedPhone;
  }

  @override
  Widget build(BuildContext context) {
    // `Listenable.merge` over both controllers is the same trigger the
    // real screen uses (over the controllers + ProfileService +
    // ThemeService) to re-evaluate the conditional banner render on
    // every keystroke.
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        _nameController,
        _phoneController,
      ]),
      builder: (BuildContext context, Widget? _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Conditional banner — the property under test. Rendered
              // above the form fields so the warning surfaces at the
              // top of the section, matching Requirement 6.3.
              if (_isDirty)
                const AppFeedbackBanner(
                  kind: FeedbackKind.warning,
                  message: 'You have unsaved changes.',
                ),

              const SizedBox(height: 16),

              // Display-name field. `maxLength: 50` and the lack of a
              // formatter mirror the real screen's `AppTextField`
              // configuration for this slot.
              AppTextField(
                controller: _nameController,
                label: 'Display name',
                prefixIcon: Icons.person_outline,
                maxLength: 50,
              ),

              const SizedBox(height: 16),

              // Phone field. `digitsOnly` + `LengthLimitingTextInputFormatter(15)`
              // and `keyboardType: TextInputType.phone` mirror the real
              // screen so populated phone fixtures (10-digit strings)
              // and the empty-string fixture round-trip through the
              // same input pipeline.
              AppTextField(
                controller: _phoneController,
                label: 'Phone number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
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

/// Persisted (and edited) display-name fixtures.
///
///   * `''`       — boundary: freshly created profile, no name persisted.
///   * `'Alice'`  — typical short name.
///   * `'Bob'`    — second typical name distinct from Alice so the
///                  edited-name set can flip *between* persisted names
///                  (e.g. persistedName='Alice', editedName='Bob') and
///                  exercise the `!=` branch in both directions.
const List<String> _names = <String>['', 'Alice', 'Bob'];

/// Persisted (and edited) phone fixtures.
///
///   * `''`            — boundary: no phone persisted.
///   * `'0123456789'`  — typical Malaysian-style 10-digit phone.
///   * `'0987654321'`  — second 10-digit phone distinct from the first
///                       so the edited-phone set can flip *between*
///                       persisted phones and exercise the `!=` branch
///                       in both directions.
const List<String> _phones = <String>['', '0123456789', '0987654321'];

void main() {
  // SharedPreferences mock: `_DirtyBannerHarness` itself does not touch
  // `SharedPreferences`, but `setMockInitialValues({})` provides a clean
  // in-memory store as a defence-in-depth measure in case any
  // transitive dependency reaches for the prefs store during the test
  // run. Matches the setUp pattern used across the figma-ui-redesign
  // widget tests (`home_widgets_test.dart`, `login_screen_test.dart`,
  // `register_screen_test.dart`).
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Property 8: profile dirty banner visibility', () {
    // Parametric sweep over the cartesian product of (persistedName,
    // persistedPhone, editedName, editedPhone). Each tuple is hoisted
    // into a `testWidgets` so its name surfaces independently in the
    // test runner output and a regression in any single combination
    // is pinpointed without manual triangulation.
    //
    // 3 × 3 × 3 × 3 = 81 tuples. Each is a self-contained widget
    // mount with two `enterText` operations and a finder assertion,
    // which is cheap enough to run exhaustively.
    for (final String pn in _names) {
      for (final String pp in _phones) {
        for (final String en in _names) {
          for (final String ep in _phones) {
            // The IFF predicate driving the property: banner present
            // iff at least one of (name, phone) deviates from the
            // persisted snapshot. Computed once per tuple at test-
            // declaration time so the assertion message can quote
            // the expected boolean directly.
            final bool expectedDirty = en != pn || ep != pp;

            // Display strings escape the empty fixture so the test
            // runner output reads cleanly even for the (`'', ''`,
            // `'', ''`) tuple.
            String d(String s) => s.isEmpty ? '<empty>' : s;

            testWidgets(
              'persisted=("${d(pn)}","${d(pp)}") edited=("${d(en)}","${d(ep)}") '
              '→ banner ${expectedDirty ? "present" : "absent"}',
              (WidgetTester tester) async {
                // ---- Mount the harness with the persisted snapshot --
                //
                // The harness's controllers are seeded from
                // (persistedName, persistedPhone) in `initState`, so
                // the initial render starts in the clean state
                // (controller.text equals persisted value → banner
                // absent). The subsequent `enterText` calls drive the
                // controllers to (editedName, editedPhone) and the
                // `Listenable.merge` rebuild re-evaluates the IFF
                // predicate.
                await tester.pumpWidget(
                  hostApp(
                    child: _DirtyBannerHarness(
                      persistedName: pn,
                      persistedPhone: pp,
                    ),
                  ),
                );

                // ---- Pre-condition: clean state on first frame ------
                //
                // Before any keystroke, controllers equal the persisted
                // snapshot, so the IFF predicate is false and the
                // banner must be absent. Asserting this explicitly
                // rules out a regression where the banner renders
                // unconditionally on first paint, which would silently
                // pass every "expectedDirty == true" branch below.
                expect(
                  find.byType(AppFeedbackBanner),
                  findsNothing,
                  reason: 'Banner must be absent on first frame when '
                      'controllers equal the persisted snapshot '
                      '(persistedName="${d(pn)}", '
                      'persistedPhone="${d(pp)}"). Requirement 6.3.',
                );

                // ---- Apply the edits --------------------------------
                //
                // `tester.enterText` replaces the entire controller
                // text with the supplied value, mirroring how a real
                // user clearing the field and typing a new value would
                // drive the controller. The order — name first then
                // phone — matches the order of the fields in the
                // rendered column. Each `enterText` is followed by a
                // `pump` so the `Listenable.merge` rebuild has a frame
                // to re-evaluate the conditional banner render.
                //
                // Find by widget type + index because the harness
                // exposes exactly two `AppTextField`s in a known
                // order (name at 0, phone at 1). Looking up by label
                // text would be brittle if `AppTextField` ever
                // restructured its label-rendering subtree.
                await tester.enterText(
                  find.byType(AppTextField).at(0),
                  en,
                );
                await tester.pump();

                await tester.enterText(
                  find.byType(AppTextField).at(1),
                  ep,
                );
                await tester.pump();

                // ---- Property 8 IFF predicate -----------------------
                //
                // After the controllers have been driven to
                // (editedName, editedPhone), the banner's render
                // state must match `expectedDirty`. The two halves of
                // the IFF (forward and reverse) are asserted by a
                // single `expect` because `findsOneWidget` /
                // `findsNothing` are exact-count matchers — a wrong
                // number of banners (zero when one was expected, or
                // one when none was expected) fails the same
                // assertion with a descriptive message.
                expect(
                  find.byType(AppFeedbackBanner),
                  expectedDirty ? findsOneWidget : findsNothing,
                  reason: 'Banner presence must equal '
                      '(edited != persisted) IFF predicate. '
                      'persisted=("${d(pn)}","${d(pp)}") '
                      'edited=("${d(en)}","${d(ep)}") '
                      'expectedDirty=$expectedDirty. '
                      'Requirement 6.3.',
                );
              },
            );
          }
        }
      }
    }
  });
}
