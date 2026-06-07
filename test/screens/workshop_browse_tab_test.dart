// Widget tests for the Browse-tab body of the redesigned Workshops screen.
//
// Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.12 (Task 9.15).
//
// These are unmocked structural sweeps — they assert the layout contract
// (search field present, chip row populated, list/map toggle visible,
// list renders cards, empty state appears when filtering returns nothing)
// without exercising Firebase or Google Maps plugin channels.

import 'package:drive_care_plus/models/workshop.dart';
import 'package:drive_care_plus/screens/workshops/_browse_tab.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../widgets/ui/_test_host.dart';

const CameraPosition _camera =
    CameraPosition(target: LatLng(3.139, 101.6869), zoom: 13);

const List<Workshop> _workshops = <Workshop>[
  Workshop(
    id: 'w1',
    name: 'Repair Hub',
    address: 'Address 1',
    rating: 4.5,
    reviewCount: 12,
    distance: '1.2 km',
    types: <String>['car_repair'],
  ),
  Workshop(
    id: 'w2',
    name: 'Sparkle Wash',
    address: 'Address 2',
    rating: 4.0,
    reviewCount: 50,
    distance: '0.5 km',
    types: <String>['car_wash'],
  ),
  Workshop(
    id: 'w3',
    name: 'Parts Plus',
    address: 'Address 3',
    rating: 3.8,
    reviewCount: 7,
    distance: '2.0 km',
    types: <String>['auto_parts_store'],
  ),
];

void main() {
  testWidgets('Browse tab renders search field, chip row, and list',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(
        child: const BrowseTab(
          workshops: _workshops,
          initialCameraPosition: _camera,
        ),
      ),
    );

    // Search field with the magnifier prefix is visible.
    expect(find.byIcon(Icons.search), findsOneWidget);
    // Trailing filter icon is visible.
    expect(find.byIcon(Icons.tune), findsOneWidget);
    // The four category chips are visible.
    expect(find.byType(AppCategoryChip), findsNWidgets(4));
    // List/map toggle icon buttons are visible.
    expect(find.byIcon(Icons.view_list), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    // The first card is rendered (later cards may be off-screen at the
    // default viewport height; the list is a scroll view, not a paginator).
    expect(find.text('Repair Hub'), findsOneWidget);
  });

  testWidgets('Browse tab filters by category chip selection',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(
        child: const BrowseTab(
          workshops: _workshops,
          initialCameraPosition: _camera,
        ),
      ),
    );

    // Tap the "Repair" chip — locate it via the AppCategoryChip widget
    // type so the chip text doesn't collide with the specialty badge
    // text inside cards.
    final Finder repairChip = find.descendant(
      of: find.byType(AppCategoryChip),
      matching: find.text('Repair'),
    );
    await tester.tap(repairChip.first);
    await tester.pump();

    expect(find.text('Repair Hub'), findsOneWidget);
    expect(find.text('Sparkle Wash'), findsNothing);
    expect(find.text('Parts Plus'), findsNothing);
  });

  testWidgets('Browse tab filters by search query',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(
        child: const BrowseTab(
          workshops: _workshops,
          initialCameraPosition: _camera,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'parts');
    await tester.pump();

    expect(find.text('Parts Plus'), findsOneWidget);
    expect(find.text('Repair Hub'), findsNothing);
    expect(find.text('Sparkle Wash'), findsNothing);
  });

  testWidgets('Browse tab shows AppEmptyState when filter has no results',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      hostApp(
        child: const BrowseTab(
          workshops: _workshops,
          initialCameraPosition: _camera,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pump();

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('No workshops found'), findsOneWidget);
    // Search field and chip row should remain visible.
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byType(AppCategoryChip), findsNWidgets(4));
  });

  testWidgets(
    'Browse tab list mode renders WorkshopCard surfaces by default '
    '(default viewMode: list)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        hostApp(
          child: const BrowseTab(
            workshops: <Workshop>[
              Workshop(
                id: 'only',
                name: 'Only Workshop',
                address: '',
                rating: 5.0,
                reviewCount: 1,
                distance: '0.0 km',
                types: <String>['car_repair'],
              ),
            ],
            initialCameraPosition: _camera,
          ),
        ),
      );

      // Default mode is list — the workshop card is rendered.
      expect(find.text('Only Workshop'), findsOneWidget);
      // Map view should not be present (no GoogleMap key in the tree).
      expect(
        find.byKey(const ValueKey<String>('workshops_browse_map')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('workshops_browse_list')),
        findsOneWidget,
      );
    },
  );
}
