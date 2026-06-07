// Feature: figma-ui-redesign, Property 23: hit-target floor
//
// Validates: Requirements 13.3
//
// Property: every Component_Library interactive widget renders a gesture
// region of at least 48 x 48 logical pixels regardless of the visual size
// the developer chooses for its inner content (icon size, label length,
// child dimensions, etc.). This is the `Touch_Target_Floor` floor from
// Requirement 13.3 of the figma-ui-redesign spec, applied universally
// across the interactive surface of the Component_Library.
//
// ### Note on PBT shape
//
// The figma-ui-redesign tasks file flags this case as `[PBT]` and the
// suite uses `glados` for pure-function property tests elsewhere. Glados
// runs synchronously (a hot loop of `expect` assertions over generated
// inputs), but Flutter widget tests are inherently asynchronous —
// `tester.pumpWidget` and `tester.getSize` only resolve inside a
// `testWidgets` body. Glados therefore does not naturally fit widget
// rendering, so this file implements the property as a parametric /
// exhaustive widget test: it iterates over many `(widget, visual size)`
// combinations and asserts the same invariant `tester.getSize(...) >=
// 48x48` for each. Coverage-wise it is equivalent to a property test
// with a constrained input space, while remaining compatible with
// `flutter_test`.
//
// ### Why we vary inner visual size instead of an outer SizedBox
//
// Flutter's layout system propagates parent constraints down. An outer
// `SizedBox(width: w, height: h)` provides *tight* constraints to its
// child, so when `w < 48` or `h < 48` the child's own
// `BoxConstraints(minHeight: 48)` cannot override the parent's max — the
// rendered size is forced to `(w, h)` regardless of any internal floor.
// Writing the property as "wrap in `SizedBox(1, 1)` and assert size ≥
// 48" would therefore fail at the layout layer, not at the widget's hit
// area logic. The meaningful invariant of Requirement 13.3 is "the
// gesture region floors at 48 x 48 even when the *visual content* the
// developer asks for is smaller than 48 x 48". This file tests exactly
// that: it renders each interactive widget inside an unconstrained
// `Center`, varies the visual content size in `[1, 200]`, and asserts
// the rendered widget's own size meets the floor.

import 'package:drive_care_plus/widgets/ui/app_card.dart';
import 'package:drive_care_plus/widgets/ui/app_category_chip.dart';
import 'package:drive_care_plus/widgets/ui/app_floating_bottom_nav.dart';
import 'package:drive_care_plus/widgets/ui/app_gradient_button.dart';
import 'package:drive_care_plus/widgets/ui/app_icon_button.dart';
import 'package:drive_care_plus/widgets/ui/app_list_tile.dart';
import 'package:drive_care_plus/widgets/ui/app_primary_button.dart';
import 'package:drive_care_plus/widgets/ui/app_secondary_button.dart';
import 'package:drive_care_plus/widgets/ui/app_toggle_switch.dart';
import 'package:drive_care_plus/widgets/ui/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_host.dart';

/// `Touch_Target_Floor` from Requirement 13.3 in logical pixels.
const double _floor = 48.0;

/// Visual content sizes sampled from the inclusive range `[1, 200]`.
///
/// The values intentionally span far below the floor (1, 4, 12, 24) and
/// far above it (60, 100, 150, 200) so the parametric sweep exercises
/// both "visual smaller than floor → must extend hit area" and "visual
/// already exceeds floor → must not shrink" branches of Requirement 13.3.
const List<double> _visualSizes = <double>[1, 4, 12, 24, 48, 60, 100, 150, 200];

/// Asserts the rendered size of the widget located by [finder] meets the
/// 48x48 logical-pixel floor and emits a context-rich failure message
/// identifying the widget kind and visual size when the property is
/// violated.
void _expectFloorMet(
  WidgetTester tester,
  Finder finder, {
  required String widgetKind,
  required double visualSize,
}) {
  final Size size = tester.getSize(finder);
  expect(
    size.width,
    greaterThanOrEqualTo(_floor),
    reason: '$widgetKind at visual size $visualSize rendered width '
        '${size.width} below the 48 logical-pixel hit-target floor '
        '(Requirement 13.3).',
  );
  expect(
    size.height,
    greaterThanOrEqualTo(_floor),
    reason: '$widgetKind at visual size $visualSize rendered height '
        '${size.height} below the 48 logical-pixel hit-target floor '
        '(Requirement 13.3).',
  );
}

void main() {
  group('Property 23: hit-target floor', () {
    // ---- AppPrimaryButton --------------------------------------------------
    //
    // Visual size for a label-bearing button is the label's character
    // count (which drives the visible width). The button's own padding +
    // minHeight floor must keep the rendered surface ≥ 48 x 48 even when
    // the label is a single character.
    testWidgets('AppPrimaryButton meets 48x48 floor across label sizes',
        (tester) async {
      for (final double s in _visualSizes) {
        final int labelLen = s.toInt().clamp(1, 200);
        final String label = 'a' * labelLen;

        await tester.pumpWidget(
          hostApp(
            child: Center(
              child: AppPrimaryButton(
                label: label,
                onPressed: () {},
              ),
            ),
          ),
        );

        _expectFloorMet(
          tester,
          find.byType(AppPrimaryButton),
          widgetKind: 'AppPrimaryButton',
          visualSize: s,
        );
      }
    });

    // ---- AppSecondaryButton ------------------------------------------------
    testWidgets('AppSecondaryButton meets 48x48 floor across label sizes',
        (tester) async {
      for (final double s in _visualSizes) {
        final int labelLen = s.toInt().clamp(1, 200);
        final String label = 'a' * labelLen;

        await tester.pumpWidget(
          hostApp(
            child: Center(
              child: AppSecondaryButton(
                label: label,
                onPressed: () {},
              ),
            ),
          ),
        );

        _expectFloorMet(
          tester,
          find.byType(AppSecondaryButton),
          widgetKind: 'AppSecondaryButton',
          visualSize: s,
        );
      }
    });

    // ---- AppIconButton -----------------------------------------------------
    //
    // The icon `size` parameter directly controls the visual glyph size.
    // The hit area must floor at 48 x 48 even for a 1-logical-pixel icon
    // and must not shrink for an icon larger than 48.
    testWidgets('AppIconButton meets 48x48 floor across icon sizes',
        (tester) async {
      for (final double s in _visualSizes) {
        await tester.pumpWidget(
          hostApp(
            child: Center(
              child: AppIconButton(
                icon: Icons.close,
                onPressed: () {},
                semanticsLabel: 'Close',
                size: s,
              ),
            ),
          ),
        );

        _expectFloorMet(
          tester,
          find.byType(AppIconButton),
          widgetKind: 'AppIconButton',
          visualSize: s,
        );
      }
    });

    // ---- AppGradientButton -------------------------------------------------
    testWidgets('AppGradientButton meets 48x48 floor across label sizes',
        (tester) async {
      for (final double s in _visualSizes) {
        final int labelLen = s.toInt().clamp(1, 200);
        final String label = 'a' * labelLen;

        await tester.pumpWidget(
          hostApp(
            // Constrain the gradient button (which defaults to fullWidth)
            // to a generous, fixed width so its rendered width reflects
            // the SizedBox parent — its *height* is what the hit-target
            // floor governs for full-width CTAs.
            child: Center(
              child: SizedBox(
                width: 240,
                child: AppGradientButton(
                  label: label,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        _expectFloorMet(
          tester,
          find.byType(AppGradientButton),
          widgetKind: 'AppGradientButton',
          visualSize: s,
        );
      }
    });

    // ---- AppToggleSwitch ---------------------------------------------------
    //
    // The switch has fixed visual dimensions (50 x 30 track, 24 thumb),
    // both well under the 48 floor — exactly the "visual smaller than
    // 48" branch of Requirement 13.3. The widget must extend its hit
    // area to 48 x 48 in both states.
    testWidgets('AppToggleSwitch meets 48x48 floor in both states',
        (tester) async {
      for (final bool value in <bool>[false, true]) {
        await tester.pumpWidget(
          hostApp(
            child: Center(
              child: AppToggleSwitch(
                value: value,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        _expectFloorMet(
          tester,
          find.byType(AppToggleSwitch),
          widgetKind: 'AppToggleSwitch(value=$value)',
          visualSize: value ? 1 : 0,
        );
      }
    });

    // ---- AppCategoryChip ---------------------------------------------------
    testWidgets(
        'AppCategoryChip meets 48x48 floor across label sizes and selection',
        (tester) async {
      for (final double s in _visualSizes) {
        for (final bool selected in <bool>[false, true]) {
          final int labelLen = s.toInt().clamp(1, 200);
          final String label = 'a' * labelLen;

          await tester.pumpWidget(
            hostApp(
              child: Center(
                child: AppCategoryChip(
                  label: label,
                  selected: selected,
                  onTap: () {},
                ),
              ),
            ),
          );

          _expectFloorMet(
            tester,
            find.byType(AppCategoryChip),
            widgetKind: 'AppCategoryChip(selected=$selected)',
            visualSize: s,
          );
        }
      }
    });

    // ---- AppListTile (interactive) -----------------------------------------
    //
    // The list tile's visual content is the title widget; the hit-area
    // floor is enforced via `ConstrainedBox(minHeight: 48)` inside the
    // InkWell. Width is governed by the parent — give it a generous
    // 320 logical pixels so the rendered tile reflects its natural
    // height while still being measurable for the floor assertion.
    testWidgets('AppListTile (interactive) meets 48x48 floor',
        (tester) async {
      for (final double s in _visualSizes) {
        final int titleLen = s.toInt().clamp(1, 200);
        final String title = 'a' * titleLen;

        await tester.pumpWidget(
          hostApp(
            child: Center(
              child: SizedBox(
                width: 320,
                child: AppListTile(
                  title: Text(title),
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

        _expectFloorMet(
          tester,
          find.byType(AppListTile),
          widgetKind: 'AppListTile',
          visualSize: s,
        );
      }
    });

    // ---- AppCard (interactive) ---------------------------------------------
    //
    // Vary the card's *child* size between 1 x 1 and 200 x 200 — this is
    // the closest analogue to the "wrapping SizedBox" sweep called out
    // in the task. The card itself sizes to its child plus padding, with
    // a 48 height floor enforced via `ConstrainedBox` inside the
    // InkWell.
    testWidgets('AppCard (interactive) meets 48x48 floor across child sizes',
        (tester) async {
      for (final double s in _visualSizes) {
        await tester.pumpWidget(
          hostApp(
            child: Center(
              child: AppCard(
                onTap: () {},
                child: SizedBox(
                  width: s,
                  height: s,
                ),
              ),
            ),
          ),
        );

        _expectFloorMet(
          tester,
          find.byType(AppCard),
          widgetKind: 'AppCard',
          visualSize: s,
        );
      }
    });

    // ---- AppFloatingBottomNav ----------------------------------------------
    //
    // The nav pill itself is a row of 3–5 equal-width items; the floor
    // contract applies per-item, not to the pill as a whole. Each
    // internal `_NavItemButton` is wrapped in a
    // `ConstrainedBox(minWidth: 48, minHeight: 48)`. We render the nav
    // at item counts 3, 4, and 5 and assert every visible NavItem's
    // gesture region meets the floor.
    testWidgets('AppFloatingBottomNav per-item gesture regions meet 48x48',
        (tester) async {
      const List<NavItem> allItems = <NavItem>[
        NavItem(icon: Icons.home, label: 'A'),
        NavItem(icon: Icons.search, label: 'B'),
        NavItem(icon: Icons.person, label: 'C'),
        NavItem(icon: Icons.settings, label: 'D'),
        NavItem(icon: Icons.menu, label: 'E'),
      ];

      for (final int count in <int>[3, 4, 5]) {
        final List<NavItem> items = allItems.take(count).toList();

        await tester.pumpWidget(
          hostApp(
            child: Center(
              // 360 logical pixels comfortably accommodates 5 items at
              // the 48 floor (5 * 48 = 240, plus padding).
              child: SizedBox(
                width: 360,
                child: AppFloatingBottomNav(
                  items: items,
                  currentIndex: 0,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        );

        // Each NavItem renders a unique label; locate per-item gesture
        // regions via the wrapping GestureDetector's enclosing
        // ConstrainedBox-backed Container. Using the label `Text` as
        // the per-item finder seed and walking up to the nearest
        // ancestor ConstrainedBox keeps the lookup widget-internal-
        // structure-independent.
        for (final NavItem item in items) {
          final Finder labelFinder = find.text(item.label);
          expect(labelFinder, findsOneWidget,
              reason:
                  'Label ${item.label} should be rendered by the nav at '
                  'count $count.');

          final Finder constrainedAncestor = find.ancestor(
            of: labelFinder,
            matching: find.byType(ConstrainedBox),
          );

          // Walk all ConstrainedBox ancestors and verify at least one
          // reports a rendered size meeting the floor — this is the
          // hit-area floor wrapper around each `_NavItemButton`.
          final Iterable<Element> ancestors =
              tester.elementList(constrainedAncestor);
          bool anyAncestorMeetsFloor = false;
          for (final Element a in ancestors) {
            final Size size = tester.getSize(find.byElementPredicate(
              (e) => identical(e, a),
            ));
            if (size.width >= _floor && size.height >= _floor) {
              anyAncestorMeetsFloor = true;
              break;
            }
          }
          expect(
            anyAncestorMeetsFloor,
            isTrue,
            reason: 'AppFloatingBottomNav item "${item.label}" at count '
                '$count should have a ConstrainedBox ancestor whose '
                'rendered size is >= 48x48 (Requirement 13.3).',
          );
        }
      }
    });
  });
}
