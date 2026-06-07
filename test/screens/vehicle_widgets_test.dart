// Widget tests for the redesigned Vehicle screen building blocks
// (Task 10.8 — Requirements 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8).
//
// These are unmocked structural sweeps over the public components in
// `lib/screens/vehicle/_widgets.dart`:
//
//   * `VehicleHeroCard`        — hero gradient + plate + edit overlay
//   * `VehicleHealthGrid`      — 4 tiles, `--%` placeholder branch
//   * `MaintenanceHistoryList` — populated rendering + descending order
//                                + empty-state branch
//   * `UpcomingTasksList`      — priority-color encoding + empty-state
//
// The hero edit-button → customizer route navigation is exercised by
// mounting a tiny `MaterialApp` that registers
// `VehicleCustomizerScreen.routeName` against a sentinel screen and
// then asserting the sentinel becomes visible after tapping the
// `AppIconButton` overlay. Mounting the real `VehicleCustomizerScreen`
// would pull in `VehicleInsights` + `flutter_svg` asset loading; the
// sentinel substitution keeps the navigation contract focused without
// dragging in those side effects.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/vehicle/_widgets.dart';
import 'package:drive_care_plus/screens/vehicle_customizer_screen.dart';
import 'package:drive_care_plus/services/vehicle_insights.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

// ===========================================================================
// Helpers
// ===========================================================================

/// Build a `MaintenanceItem` fixture used by the watchlist-driven
/// widgets ([VehicleHealthGrid], [UpcomingTasksList]).
///
/// `interval` and `lastServiceMileage` drive `healthPercentage` and
/// `status` deterministically: `remainingKm = lastServiceMileage +
/// interval - currentMileage`. Setting `lastServiceMileage = 0` and
/// `currentMileage = (1 - h) * interval` yields a target health of
/// `h * 100` percent.
MaintenanceItem _itemAt({
  required String name,
  required double interval,
  required double targetHealth,
  DateTime? lastServiceDate,
}) {
  final double currentMileage = (1.0 - targetHealth) * interval;
  return MaintenanceItem(
    name: name,
    currentMileage: currentMileage,
    lastServiceMileage: 0.0,
    lastServiceDate: lastServiceDate ?? DateTime(2024, 1, 1),
    interval: interval,
  );
}

/// Build the typical four-item watchlist used by the redesigned
/// vehicle screen so the health grid's name-substring match resolves
/// every tile.
List<MaintenanceItem> _fourItemWatchlist() {
  return <MaintenanceItem>[
    _itemAt(name: 'Engine Oil', interval: 10000, targetHealth: 0.85),
    _itemAt(name: 'Brake Pads', interval: 40000, targetHealth: 0.70),
    _itemAt(name: 'Battery', interval: 60000, targetHealth: 0.95),
    _itemAt(name: 'Tyres', interval: 50000, targetHealth: 0.50),
  ];
}

void main() {
  // ===========================================================================
  // VehicleHeroCard (Task 10.1 / Requirement 8.1)
  // ===========================================================================

  group('VehicleHeroCard', () {
    testWidgets('renders plate, car emoji, and edit AppIconButton',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const VehicleHeroCard(plate: 'ABC 1234', model: 'Axia'),
        ),
      );

      // Plate is rendered as a headline-styled label.
      expect(find.text('ABC 1234'), findsOneWidget);
      // Model is rendered when supplied.
      expect(find.text('Axia'), findsOneWidget);
      // Car emoji anchors the hero visually.
      expect(find.text('🚗'), findsOneWidget);
      // Edit button is exposed as an AppIconButton with the correct
      // semantics label.
      final Finder editButton = find.byWidgetPredicate(
        (Widget w) =>
            w is AppIconButton && w.semanticsLabel == 'Edit vehicle',
      );
      expect(editButton, findsOneWidget);
    });

    testWidgets(
      'renders hero gradient with the documented top-left and '
      'bottom-right colors',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          hostApp(
            child: const VehicleHeroCard(plate: 'ABC 1234'),
          ),
        );

        // Locate the gradient-decorated container.
        final Finder gradientContainer = find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).gradient != null,
        );
        expect(gradientContainer, findsOneWidget);

        final Container container =
            tester.widget<Container>(gradientContainer);
        final BoxDecoration deco = container.decoration as BoxDecoration;
        final LinearGradient gradient = deco.gradient as LinearGradient;

        expect(gradient.begin, equals(Alignment.topLeft));
        expect(gradient.end, equals(Alignment.bottomRight));
        expect(gradient.colors.first, equals(const Color(0xFF2563EB)));
        expect(gradient.colors.last, equals(const Color(0xFF4338CA)));
      },
    );

    testWidgets(
      'edit button → pushNamed(VehicleCustomizerScreen.routeName)',
      (WidgetTester tester) async {
        // A sentinel screen registered against the customizer route so
        // the navigation contract can be observed without mounting the
        // real customizer body.
        const Key sentinelKey = Key('customizer_sentinel');

        final ThemeData theme =
            AppTheme.buildTheme(AppColors.emerald500, Brightness.light);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: VehicleHeroCard(plate: 'ABC 1234'),
            ),
            routes: <String, WidgetBuilder>{
              VehicleCustomizerScreen.routeName: (_) => const Scaffold(
                    key: sentinelKey,
                    body: Text('customizer-sentinel'),
                  ),
            },
          ),
        );

        // Sentinel is not visible before the tap.
        expect(find.byKey(sentinelKey), findsNothing);

        await tester.tap(find.byWidgetPredicate(
          (Widget w) =>
              w is AppIconButton && w.semanticsLabel == 'Edit vehicle',
        ));
        await tester.pumpAndSettle();

        // Sentinel becomes visible after the tap, confirming the
        // pushNamed call resolved to the registered route.
        expect(find.byKey(sentinelKey), findsOneWidget);
      },
    );
  });

  // ===========================================================================
  // VehicleHealthGrid (Task 10.2 / Requirements 8.2, 8.3)
  // ===========================================================================

  group('VehicleHealthGrid', () {
    testWidgets(
      'renders four labelled tiles for Engine, Brakes, Battery, Tires',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          hostApp(
            child: VehicleHealthGrid(
              watchlistItems: _fourItemWatchlist(),
            ),
          ),
        );
        // Wait for the gauge tween animation to complete.
        await tester.pumpAndSettle();

        expect(find.text('Engine'), findsOneWidget);
        expect(find.text('Brakes'), findsOneWidget);
        expect(find.text('Battery'), findsOneWidget);
        expect(find.text('Tires'), findsOneWidget);

        expect(find.byType(AppHealthGauge), findsNWidgets(4));
      },
    );

    testWidgets(
      'renders --% placeholder when the matching watchlist item is '
      'absent',
      (WidgetTester tester) async {
        // Empty watchlist — every tile should fall back to placeholder.
        await tester.pumpWidget(
          hostApp(
            child: const VehicleHealthGrid(
              watchlistItems: <MaintenanceItem>[],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Each of the four tiles renders its `--%` placeholder.
        expect(find.text('--%'), findsNWidgets(4));
      },
    );

    testWidgets(
      'partial watchlist → present tiles render numeric, missing tiles '
      'render --% (Requirement 8.3)',
      (WidgetTester tester) async {
        // Only Engine and Battery are populated; Brakes and Tyres are
        // absent so those tiles must fall back to the placeholder.
        await tester.pumpWidget(
          hostApp(
            child: VehicleHealthGrid(
              watchlistItems: <MaintenanceItem>[
                _itemAt(
                  name: 'Engine Oil',
                  interval: 10000,
                  targetHealth: 0.85,
                ),
                _itemAt(
                  name: 'Battery',
                  interval: 60000,
                  targetHealth: 0.50,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Two tiles fall back to placeholder (Brakes, Tires).
        expect(find.text('--%'), findsNWidgets(2));
      },
    );
  });

  // ===========================================================================
  // MaintenanceHistoryList (Task 10.3 / Requirements 8.4, 8.6)
  // ===========================================================================

  group('MaintenanceHistoryList', () {
    testWidgets('renders entries in descending date order',
        (WidgetTester tester) async {
      final List<MaintenanceHistoryEntry> entries =
          <MaintenanceHistoryEntry>[
        MaintenanceHistoryEntry(
          name: 'Oldest',
          mileageKm: 10000,
          date: DateTime(2020, 1, 1),
        ),
        MaintenanceHistoryEntry(
          name: 'Newest',
          mileageKm: 30000,
          date: DateTime(2024, 12, 31),
        ),
        MaintenanceHistoryEntry(
          name: 'Middle',
          mileageKm: 20000,
          date: DateTime(2022, 6, 15),
        ),
      ];

      await tester.pumpWidget(
        hostApp(child: MaintenanceHistoryList(entries: entries)),
      );

      // Three AppListTile rows are present.
      expect(find.byType(AppListTile), findsNWidgets(3));

      // Read the rendered titles in their visual order via the AppListTile
      // index. The list is sorted descending so 'Newest' is first.
      final List<AppListTile> tiles =
          tester.widgetList<AppListTile>(find.byType(AppListTile)).toList();
      expect((tiles[0].title as Text).data, equals('Newest'));
      expect((tiles[1].title as Text).data, equals('Middle'));
      expect((tiles[2].title as Text).data, equals('Oldest'));
    });

    testWidgets('renders AppEmptyState when entries is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const MaintenanceHistoryList(
            entries: <MaintenanceHistoryEntry>[],
          ),
        ),
      );

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('No maintenance logged'), findsOneWidget);
    });
  });

  // ===========================================================================
  // UpcomingTasksList (Task 10.5 / Requirements 8.5, 8.7)
  // ===========================================================================

  group('UpcomingTasksList', () {
    testWidgets(
      'renders one row per task with priority-colored pills',
      (WidgetTester tester) async {
        final List<UpcomingTaskEntry> tasks = <UpcomingTaskEntry>[
          const UpcomingTaskEntry(
            name: 'Engine Oil',
            remainingKm: 100,
            priority: UpcomingTaskPriority.high,
          ),
          const UpcomingTaskEntry(
            name: 'Brake Pads',
            remainingKm: 1500,
            priority: UpcomingTaskPriority.medium,
          ),
          const UpcomingTaskEntry(
            name: 'Battery',
            remainingKm: 8000,
            priority: UpcomingTaskPriority.low,
          ),
        ];

        await tester.pumpWidget(
          hostApp(child: UpcomingTasksList(tasks: tasks)),
        );

        expect(find.byType(AppListTile), findsNWidgets(3));
        expect(find.text('Engine Oil'), findsOneWidget);
        expect(find.text('Brake Pads'), findsOneWidget);
        expect(find.text('Battery'), findsOneWidget);

        // Each priority bucket is rendered with the keyed pill so we
        // can verify the encoding without scraping the painted color.
        expect(
          find.byKey(const ValueKey<String>('priority_pill_high')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('priority_pill_medium')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('priority_pill_low')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'pill color matches AppColors error/warning/info per priority '
      '(Requirement 8.5)',
      (WidgetTester tester) async {
        final List<UpcomingTaskEntry> tasks = <UpcomingTaskEntry>[
          const UpcomingTaskEntry(
            name: 'High',
            remainingKm: 100,
            priority: UpcomingTaskPriority.high,
          ),
          const UpcomingTaskEntry(
            name: 'Medium',
            remainingKm: 1500,
            priority: UpcomingTaskPriority.medium,
          ),
          const UpcomingTaskEntry(
            name: 'Low',
            remainingKm: 8000,
            priority: UpcomingTaskPriority.low,
          ),
        ];

        await tester.pumpWidget(
          hostApp(child: UpcomingTasksList(tasks: tasks)),
        );

        // Resolve the active color tokens off the running theme so the
        // assertion compares against the same values the widget reads.
        final BuildContext ctx =
            tester.element(find.byType(UpcomingTasksList));
        final AppColorsExt colors =
            Theme.of(ctx).extension<AppColorsExt>()!;

        Color colorOfPill(String key) {
          final Container pill = tester.widget<Container>(
            find.byKey(ValueKey<String>('priority_pill_$key')),
          );
          return (pill.decoration as BoxDecoration).color!;
        }

        expect(colorOfPill('high'), equals(colors.error));
        expect(colorOfPill('medium'), equals(colors.warning));
        expect(colorOfPill('low'), equals(colors.info));
      },
    );

    testWidgets('renders AppEmptyState when tasks is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const UpcomingTasksList(
            tasks: <UpcomingTaskEntry>[],
          ),
        ),
      );

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('No upcoming tasks'), findsOneWidget);
    });
  });
}
