// Feature: figma-ui-redesign, Property 15: My Bookings populated/empty mutex
//
// Validates: Requirements 7.14
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// For any list of bookings (including the empty list), the My Bookings
// tab body in `lib/screens/workshops/_my_bookings_tab.dart` renders
// **exactly one** of two visible states:
//
//   * the populated branch — a [ListView] keyed with
//     [MyBookingsTab.populatedKey] containing one [AppCard] per booking, OR
//   * the empty branch — an [AppEmptyState] keyed with
//     [MyBookingsTab.emptyKey] showing the `Browse Workshops` CTA.
//
// Stated formally: for any `xs : List<Map<String, dynamic>>`,
//
//     |{ key : key in {populatedKey, emptyKey} and key is in tree }| == 1
//
// after the widget mounts. The two branches are never rendered
// simultaneously, and the choice between them is determined entirely
// by `xs.isEmpty`.
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The mutex predicate only resolves inside a `testWidgets` body. We
// implement the property as a parametric sweep over a representative
// set of booking lists covering every meaningful case:
//
//   * `[]`                          — empty list (empty branch must show).
//   * `[<single>]`                  — one booking (populated branch).
//   * `[<two>]`                     — two bookings (populated branch).
//   * `[<five>]`                    — five bookings (populated branch).
//
// The booking maps inside the populated cases use realistic shapes
// (workshopName, serviceName, date, time, status) so a regression in
// `_BookingCard` rendering surfaces here too.

import 'package:drive_care_plus/screens/workshops/_my_bookings_tab.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

Map<String, dynamic> _booking(int i) => <String, dynamic>{
      'id': 'booking_$i',
      'workshopName': 'Workshop $i',
      'serviceName': 'General Service',
      'date': '2025-01-${(i + 1).toString().padLeft(2, '0')}T10:00:00.000',
      'time': '10:00',
      'status': i.isEven ? 'Confirmed' : 'Pending',
    };

/// Representative booking lists covering the empty and populated
/// branches. Property 15 is exhaustive on the boolean
/// `bookings.isEmpty`, so the only structural cases we need are
/// `[]` and `[non-empty]`. Multiple non-empty sizes are exercised so a
/// regression that breaks the populated branch on, say, list length 1
/// but not 5 (or vice versa) is surfaced.
final List<List<Map<String, dynamic>>> _samples =
    <List<Map<String, dynamic>>>[
  <Map<String, dynamic>>[],
  <Map<String, dynamic>>[_booking(0)],
  <Map<String, dynamic>>[_booking(0), _booking(1)],
  <Map<String, dynamic>>[
    _booking(0),
    _booking(1),
    _booking(2),
    _booking(3),
    _booking(4),
  ],
];

void main() {
  group('Property 15: My Bookings populated/empty mutual exclusion', () {
    for (final List<Map<String, dynamic>> bookings in _samples) {
      final String displayName =
          bookings.isEmpty ? 'empty list' : 'list of ${bookings.length}';
      testWidgets(
        '$displayName → renders exactly one of populated/empty branches',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            hostApp(
              child: MyBookingsTab(
                bookings: bookings,
                onBrowse: () {},
                onReschedule: (_) {},
                onCancel: (_) {},
              ),
            ),
          );

          final Finder populated =
              find.byKey(MyBookingsTab.populatedKey);
          final Finder empty = find.byKey(MyBookingsTab.emptyKey);

          if (bookings.isEmpty) {
            expect(
              empty,
              findsOneWidget,
              reason: 'Empty branch should render for empty bookings list.',
            );
            expect(
              populated,
              findsNothing,
              reason: 'Populated branch should NOT render for empty list.',
            );
            // Browse Workshops CTA should be present in the empty
            // branch's [AppEmptyState].
            expect(
              find.text('Browse Workshops'),
              findsOneWidget,
              reason: 'Empty branch must surface the Browse Workshops CTA.',
            );
          } else {
            expect(
              populated,
              findsOneWidget,
              reason: 'Populated branch should render for non-empty list '
                  '(${bookings.length} bookings).',
            );
            expect(
              empty,
              findsNothing,
              reason: 'Empty branch should NOT render for non-empty list.',
            );
            // Each booking is rendered as one card. Listing many cards
            // pushes later entries off-screen so the test only asserts
            // the first card is visible (always at the top of the
            // [ListView]). The mutex assertion below is the canonical
            // check for the property; the visible-first-card check is
            // a defence-in-depth signal that the populated branch
            // actually rendered the booking content rather than an
            // empty scroll view.
            expect(
              find.text(bookings.first['workshopName'] as String),
              findsOneWidget,
              reason: '${bookings.first['workshopName']} should render '
                  'as the first card.',
            );
            // The populated branch never renders the empty-state
            // headline.
            expect(
              find.text('No bookings yet'),
              findsNothing,
              reason: 'Populated branch should not render the empty '
                  'headline.',
            );
          }

          // Mutex assertion (the property under test): the count of
          // rendered branch keys is exactly one across both branches.
          final int branchCount =
              tester.widgetList(populated).length +
                  tester.widgetList(empty).length;
          expect(
            branchCount,
            1,
            reason: 'Exactly one of populated / empty branches must be '
                'rendered for any input list (Requirement 7.14).',
          );

          // Defensive check: the empty branch is rendered via
          // [AppEmptyState], the populated branch via a [ListView]. A
          // future refactor that swaps either widget keeps the keys
          // intact, so the mutex check above is the canonical
          // assertion; this defensive check is an extra trip-wire.
          if (bookings.isEmpty) {
            expect(find.byType(AppEmptyState), findsOneWidget);
          } else {
            expect(
              find.byType(AppEmptyState),
              findsNothing,
              reason: 'Populated branch should not render an AppEmptyState.',
            );
          }
        },
      );
    }
  });
}
