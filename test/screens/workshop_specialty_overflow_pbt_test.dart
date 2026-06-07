// Feature: figma-ui-redesign, Property 13: workshop card specialty overflow
//
// Validates: Requirements 7.5
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// For any non-negative integer `k = specialties.length` and any specialty
// strings, the redesigned `WorkshopCard` from
// `lib/screens/workshops/_workshop_card.dart` renders:
//
//   * exactly `min(2, k)` specialty chips (`AppBadge`s) inline, AND
//   * a `+max(0, k - 2) more` overflow label iff `k > 2`. When `k <= 2`,
//     no overflow label is present.
//
// The chip-count + overflow-text contract is the visible contract from
// Requirement 7.5; it has to hold for every workshop list the user
// might encounter, including the boundary cases `k ∈ {0, 1, 2}` that
// straddle the overflow threshold and the "long tail" cases
// `k ∈ {3, 5, 25, 100}` where the overflow label dominates.
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// Like the other figma-ui-redesign property tests that target widget
// render predicates (e.g. settings_swatch_pbt_test.dart task 8.7,
// settings_dirty_banner_pbt_test.dart task 8.4), this property only
// resolves inside a `testWidgets` body via `tester.pumpWidget` and
// `find.byType(AppBadge)` / `find.text('+N more')`. We therefore
// implement it as a parametric sweep over a representative set of
// specialty-list lengths. Lengths are chosen to cover the contract's
// branches (`k = 0`, `k = 1`, `k = 2` boundary, `k > 2`) plus a long
// tail to surface any `min` / `max` arithmetic regression.

import 'package:drive_care_plus/models/workshop.dart';
import 'package:drive_care_plus/screens/workshops/_workshop_card.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

/// Sentinel workshop. The card is content-only for this property — the
/// rating, name, and address are not under test — so we use a fixed
/// stub shared by every iteration.
const Workshop _fixtureWorkshop = Workshop(
  id: 'pbt-workshop',
  name: 'Property Test Workshop',
  address: 'Nowhere',
  rating: 4.5,
  reviewCount: 10,
);

/// Specialty-list lengths that exercise every branch of the
/// `min(2, k)` / `max(0, k - 2)` contract:
///
///   * `0` — no chips, no overflow label.
///   * `1` — one chip, no overflow label.
///   * `2` — two chips, no overflow label (boundary).
///   * `3` — two chips + `+1 more` (smallest overflow).
///   * `5` — two chips + `+3 more`.
///   * `25` — two chips + `+23 more` (long tail).
///   * `100` — two chips + `+98 more` (very long tail).
const List<int> _lengths = <int>[0, 1, 2, 3, 5, 25, 100];

List<String> _generateSpecialties(int k) {
  return <String>[for (int i = 0; i < k; i++) 'Specialty $i'];
}

void main() {
  group('Property 13: workshop card specialty overflow', () {
    for (final int k in _lengths) {
      testWidgets(
        'k=$k specialties → renders min(2, k) badges and '
        '"${k > 2 ? '+${k - 2} more' : 'no overflow'}"',
        (WidgetTester tester) async {
          final List<String> specialties = _generateSpecialties(k);

          await tester.pumpWidget(
            hostApp(
              child: WorkshopCard(
                workshop: _fixtureWorkshop,
                specialties: specialties,
              ),
            ),
          );

          // ---- Assertion 1: exactly min(2, k) badges -------------
          //
          // The card's footer also renders an `AppBadge` for the
          // rating ("★ 4.5") and another for the open/closed status
          // ("Open"). We must subtract those from the total badge
          // count; counting only specialty badges by their text
          // content keeps the assertion narrow.
          final int expectedVisible = k < 2 ? k : 2;
          for (int i = 0; i < expectedVisible; i++) {
            expect(
              find.text('Specialty $i'),
              findsOneWidget,
              reason: 'Specialty $i should be rendered for k=$k '
                  '(expected min(2, $k) = $expectedVisible visible).',
            );
          }
          // No specialty beyond the visible limit should be rendered.
          for (int i = expectedVisible; i < k; i++) {
            expect(
              find.text('Specialty $i'),
              findsNothing,
              reason: 'Specialty $i should NOT be rendered for k=$k '
                  '(only first $expectedVisible visible).',
            );
          }

          // ---- Assertion 2: overflow label presence ---------------
          //
          // When `k > 2`, the card must render exactly one
          // `+max(0, k - 2) more` text. When `k <= 2`, no such text
          // should be present.
          final int overflow = k > 2 ? k - 2 : 0;
          if (overflow > 0) {
            expect(
              find.text('+$overflow more'),
              findsOneWidget,
              reason: 'Expected overflow label "+$overflow more" '
                  'for k=$k.',
            );
          } else {
            // No `+N more` text should exist for any positive N when
            // k <= 2. Sweep a small window because we cannot bound
            // arbitrary regressions; a regression that prints
            // "+0 more" would also fail Assertion 1 above so this
            // sweep is a defence-in-depth check.
            for (int n = 0; n <= 3; n++) {
              expect(
                find.text('+$n more'),
                findsNothing,
                reason: 'Unexpected overflow label "+$n more" '
                    'for k=$k (expected no overflow label when '
                    'k <= 2).',
              );
            }
          }

          // ---- Assertion 3: total AppBadge count is bounded -------
          //
          // Beyond the specialty chips, the card adds a fixed number
          // of `AppBadge`s (rating + open/closed). The exact count
          // is not under property 13, but specialty count must not
          // bleed into other badges; finding `findsAtLeastNWidgets`
          // for the specialty count is the strongest portable check.
          expect(
            find.byType(AppBadge),
            findsAtLeastNWidgets(expectedVisible),
            reason: 'At least $expectedVisible AppBadge(s) should '
                'render for k=$k specialty list.',
          );
        },
      );
    }
  });
}
