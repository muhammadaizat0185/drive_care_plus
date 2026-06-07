// Feature: figma-ui-redesign — Widget + integration tests for the
// redesigned `DocumentVaultScreen` (Task 12.7).
//
// Validates:
//   * Requirement 10.1 — Search field + chip row filter list via
//                        `filterDocuments`; the `All` chip
//                        short-circuits the category check.
//   * Requirement 10.2 — Default view mode is `list`; `vault_list_view`
//                        is mounted and `vault_grid_view` is absent.
//   * Requirement 10.2 — Tapping the grid toggle swaps the list for
//                        `vault_grid_view`; tapping the list toggle
//                        returns to list. Toggle state persists across
//                        rebuilds within the same state instance.
//   * Requirement 10.6 — Floating add button presents the add sheet,
//                        and a valid submission writes through the
//                        injected `VaultDocumentStore` and pops the
//                        sheet.
//   * Requirement 10.7 — `store.save` failure keeps the sheet open,
//                        retains entered values, and surfaces an
//                        `AppFeedbackBanner` of kind `error` keyed
//                        `vault_add_error_banner`.
//   * Requirement 10.6 — Empty title fails validation: no `store.save`
//                        call, the title `AppTextField.errorText`
//                        carries the validation message.
//
// Why an injected `VaultDocumentStore`:
//   * The production binding `VehicleInsightsVaultDocumentStore` writes
//     through both `VehicleInsights.addDocument` (which touches
//     `SharedPreferences`) and Firestore. The flutter_test process has
//     no Firebase plugin channels, so widget tests inject the
//     `InMemoryVaultDocumentStore` instead, exposing `savedDocuments`
//     for assertions and a `failNext` switch for the persistence-
//     failure branch.
//
// Why `documentsOverride`:
//   * The screen subscribes to `VehicleInsights.instance` via a
//     `ListenableBuilder`. Passing an explicit `documentsOverride`
//     short-circuits `_resolveDocuments` so the rendered list is
//     deterministic and decoupled from the singleton's contents.
//
// Why a pinned `now`:
//   * `VaultDocumentCard` resolves its expiry-status indicator via
//     `expiryStatusOf(document.expiryDate, now)`. Pinning the clock
//     keeps the rendered indicator color stable across runs.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/document_vault/_widgets.dart';
import 'package:drive_care_plus/screens/document_vault_screen.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test fixtures.
// ---------------------------------------------------------------------------

/// Pinned reference date used by every test. Card expiry status
/// indicators are evaluated against this clock.
final DateTime _now = DateTime(2025, 6, 15);

/// Deterministic fixture spanning every category label (minus `All`)
/// so the chip-row filter has at least one match per branch and the
/// list/grid toggle has multiple cards to render.
final List<VaultDocument> _fixtures = <VaultDocument>[
  VaultDocument(
    title: 'Insurance Policy 2026',
    category: 'Insurance',
    expiryDate: DateTime(2026, 6, 15),
  ),
  VaultDocument(
    title: 'Road Tax Renewal',
    category: 'Tax',
    expiryDate: DateTime(2025, 7, 1),
  ),
  VaultDocument(
    title: 'Service Receipt',
    category: 'Receipt',
    fileSizeBytes: 2 * 1024 * 1024,
  ),
  VaultDocument(
    title: 'Battery Warranty',
    category: 'Warranty',
    expiryDate: DateTime(2027, 1, 1),
  ),
];

// ---------------------------------------------------------------------------
// Test harness — pumps `DocumentVaultScreen` inside a token-themed
// `MaterialApp`. Mirrors the pattern used by `refuel_log_screen_test`.
// ---------------------------------------------------------------------------

/// Private harness that wires the redesigned theme into a `MaterialApp`
/// shell so the screen's `Theme.of(context).extension<...>()` look-ups
/// resolve. Avoids `WidgetsApp` plumbing that would otherwise touch
/// Firebase channels.
class _DocumentVaultHarness extends StatelessWidget {
  final InMemoryVaultDocumentStore store;
  final List<VaultDocument> documents;
  final DateTime now;

  const _DocumentVaultHarness({
    required this.store,
    required this.documents,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(AppColors.emerald500, Brightness.light),
      home: DocumentVaultScreen(
        store: store,
        documentsOverride: documents,
        now: () => now,
      ),
    );
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required InMemoryVaultDocumentStore store,
  List<VaultDocument>? documents,
}) async {
  // Bump the viewport so the bottom sheet has room and the chip row
  // does not overflow during interaction.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _DocumentVaultHarness(
      store: store,
      documents: documents ?? _fixtures,
      now: _now,
    ),
  );
  // First frame: initial layout.
  await tester.pump();
}

void main() {
  // ---------------------------------------------------------------------
  // Search + chip filter (Requirement 10.1).
  // ---------------------------------------------------------------------
  group('Search + chip filter', () {
    testWidgets(
      'default chip "All" renders every fixture document',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        for (final VaultDocument doc in _fixtures) {
          expect(
            find.text(doc.title),
            findsOneWidget,
            reason: 'Default "All" chip should keep ${doc.title} visible.',
          );
        }
      },
    );

    testWidgets(
      'tapping the Insurance chip narrows the list to insurance docs',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        await tester.tap(
          find.byKey(
            const ValueKey<String>('vault_category_chip_Insurance'),
          ),
        );
        await tester.pump();

        expect(find.text('Insurance Policy 2026'), findsOneWidget);
        expect(find.text('Road Tax Renewal'), findsNothing);
        expect(find.text('Service Receipt'), findsNothing);
        expect(find.text('Battery Warranty'), findsNothing);
      },
    );

    testWidgets(
      'typing into the search field filters by case-insensitive substring',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        await tester.enterText(
          find.byKey(const ValueKey<String>('vault_search_field')),
          'WARRANTY',
        );
        await tester.pump();

        expect(find.text('Battery Warranty'), findsOneWidget);
        expect(find.text('Insurance Policy 2026'), findsNothing);
        expect(find.text('Road Tax Renewal'), findsNothing);
        expect(find.text('Service Receipt'), findsNothing);
      },
    );

    testWidgets(
      'search + chip combine via AND (substring + category)',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        // Two insurance docs so the AND predicate is meaningful.
        final List<VaultDocument> docs = <VaultDocument>[
          const VaultDocument(
            title: 'Insurance — Comprehensive',
            category: 'Insurance',
          ),
          const VaultDocument(
            title: 'Insurance — Third-party',
            category: 'Insurance',
          ),
          const VaultDocument(
            title: 'Tax — Annual',
            category: 'Tax',
          ),
        ];
        await _pumpScreen(tester, store: store, documents: docs);

        await tester.tap(
          find.byKey(
            const ValueKey<String>('vault_category_chip_Insurance'),
          ),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey<String>('vault_search_field')),
          'comprehensive',
        );
        await tester.pump();

        expect(find.text('Insurance — Comprehensive'), findsOneWidget);
        expect(find.text('Insurance — Third-party'), findsNothing);
        expect(find.text('Tax — Annual'), findsNothing);
      },
    );

    testWidgets(
      'no matches → AppEmptyState appears',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        await tester.enterText(
          find.byKey(const ValueKey<String>('vault_search_field')),
          'nonexistent-document-name',
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('vault_empty_state')),
          findsOneWidget,
        );
        expect(find.text('No documents found'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------
  // List/grid toggle (Requirement 10.2).
  // ---------------------------------------------------------------------
  group('List/grid view toggle', () {
    testWidgets(
      'default view is list — vault_list_view present, vault_grid_view absent',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        expect(
          find.byKey(const ValueKey<String>('vault_list_view')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('vault_grid_view')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping grid toggle swaps list for grid; tapping list returns',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        // Switch to grid.
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vault_view_mode_grid_button'),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('vault_grid_view')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('vault_list_view')),
          findsNothing,
        );

        // Back to list.
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vault_view_mode_list_button'),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('vault_list_view')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('vault_grid_view')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'grid toggle persists across rebuilds within the same state instance',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        // Switch to grid mode.
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vault_view_mode_grid_button'),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('vault_grid_view')),
          findsOneWidget,
        );

        // Trigger a rebuild via a search-field edit (this rebuilds
        // through `_onChange` → `setState` → `build` while keeping the
        // same `_DocumentVaultScreenState` instance).
        await tester.enterText(
          find.byKey(const ValueKey<String>('vault_search_field')),
          'Insurance',
        );
        await tester.pump();

        // Grid mode survived the rebuild.
        expect(
          find.byKey(const ValueKey<String>('vault_grid_view')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('vault_list_view')),
          findsNothing,
        );
      },
    );
  });

  // ---------------------------------------------------------------------
  // Floating add → store.save (Requirement 10.6).
  // ---------------------------------------------------------------------
  group('Floating add button → store.save', () {
    testWidgets(
      'tapping the add button opens the add-document bottom sheet',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        await tester.tap(
          find.byKey(const ValueKey<String>('vault_add_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('vault_add_title_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('vault_add_save_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'valid submission saves through store and pops the sheet',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        await tester.tap(
          find.byKey(const ValueKey<String>('vault_add_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('vault_add_title_field')),
          'New Document',
        );
        // Default category preselects to `Insurance` (first editable
        // entry); valid by validator's contract.
        await tester.tap(
          find.byKey(const ValueKey<String>('vault_add_save_button')),
        );
        await tester.pumpAndSettle();

        // Sheet popped — the title field is no longer in the tree.
        expect(
          find.byKey(const ValueKey<String>('vault_add_title_field')),
          findsNothing,
        );
        // Store recorded exactly one save.
        expect(store.savedDocuments.length, equals(1));
        final VaultDocument saved = store.savedDocuments.single;
        expect(saved.title, equals('New Document'));
        expect(
          kVaultEditableCategories.contains(saved.category),
          isTrue,
          reason: 'Saved category must be one of the editable labels.',
        );
      },
    );
  });

  // ---------------------------------------------------------------------
  // Submission failure (Requirement 10.7).
  // ---------------------------------------------------------------------
  group('Submission failure path', () {
    testWidgets(
      'store throws → sheet stays open, values retained, error banner shown',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore()
          ..failNext = true;
        await _pumpScreen(tester, store: store);

        await tester.tap(
          find.byKey(const ValueKey<String>('vault_add_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('vault_add_title_field')),
          'My Document',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('vault_add_save_button')),
        );
        await tester.pumpAndSettle();

        // Sheet still mounted.
        expect(
          find.byKey(const ValueKey<String>('vault_add_title_field')),
          findsOneWidget,
        );
        // Error banner with the documented key + kind.
        expect(
          find.byKey(const ValueKey<String>('vault_add_error_banner')),
          findsOneWidget,
        );
        final AppFeedbackBanner banner = tester.widget<AppFeedbackBanner>(
          find.byKey(const ValueKey<String>('vault_add_error_banner')),
        );
        expect(banner.kind, equals(FeedbackKind.error));
        // Entered value retained in the controller.
        final TextField titleField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('vault_add_title_field'),
            ),
            matching: find.byType(TextField),
          ),
        );
        expect(titleField.controller!.text, equals('My Document'));
        // Store didn't record the document because save threw.
        expect(store.savedDocuments, isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------
  // Validation failure (Requirement 10.6).
  // ---------------------------------------------------------------------
  group('Validation failure', () {
    testWidgets(
      'empty title → no store.save, errorText surfaces on title field',
      (WidgetTester tester) async {
        final InMemoryVaultDocumentStore store = InMemoryVaultDocumentStore();
        await _pumpScreen(tester, store: store);

        await tester.tap(
          find.byKey(const ValueKey<String>('vault_add_button')),
        );
        await tester.pumpAndSettle();

        // Submit without entering a title.
        await tester.tap(
          find.byKey(const ValueKey<String>('vault_add_save_button')),
        );
        await tester.pumpAndSettle();

        // No save call.
        expect(store.savedDocuments, isEmpty);
        // Sheet still open.
        expect(
          find.byKey(const ValueKey<String>('vault_add_title_field')),
          findsOneWidget,
        );
        // Validator-supplied errorText flows through to the underlying
        // TextField's InputDecoration.
        final TextField titleField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('vault_add_title_field'),
            ),
            matching: find.byType(TextField),
          ),
        );
        expect(titleField.decoration?.errorText, isNotNull);
        expect(
          titleField.decoration!.errorText,
          equals('Document title is required'),
        );
      },
    );
  });
}
