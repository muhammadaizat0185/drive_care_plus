// Feature: figma-ui-redesign — Widget tests for the redesigned
// `VaultDocumentCard` exposed by
// `lib/screens/document_vault/_widgets.dart` (Task 12.7).
//
// Validates:
//   * Requirement 10.3 — Card renders title (truncated), category
//                        badge, expiry copy, and file-size copy when
//                        `fileSizeBytes` is provided.
//   * Requirement 10.4 — Expiry-status indicator color reflects the
//                        four-branch `expiryStatusOf` classification:
//                        `noExpiry`, `ok`, `warning`, `error`.
//   * Requirement 10.5 — Warning + error indicators are visually
//                        distinct from the ok indicator.
//
// These tests render the card widget directly through the shared
// `hostApp` helper (no `DocumentVaultScreen`, no `VehicleInsights`,
// no Firebase) so the four expiry branches and the file-size text
// path are exercised in isolation. The clock is pinned to a fixed
// `DateTime` so the branch under test is deterministic.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/document_vault/_widgets.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/ui/_test_host.dart';

/// Pinned clock used by every test in this file. Picking a fixed
/// reference date keeps the four expiry branches deterministic.
final DateTime _now = DateTime(2025, 6, 15);

/// Resolves the active `AppColorsExt` from the rendered card subtree.
AppColorsExt _colorsOf(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(VaultDocumentCard));
  return Theme.of(context).extension<AppColorsExt>()!;
}

/// Reads the resolved color from the status-dot `Container` decoration.
Color _statusDotColor(WidgetTester tester) {
  final Container container = tester.widget<Container>(
    find.byKey(const ValueKey<String>('vault_document_card_status_dot')),
  );
  final BoxDecoration decoration = container.decoration! as BoxDecoration;
  return decoration.color!;
}

void main() {
  group('VaultDocumentCard — content branches', () {
    testWidgets(
      'renders title, category badge, and expiry text',
      (WidgetTester tester) async {
        const VaultDocument doc = VaultDocument(
          title: 'Insurance Cover Note',
          category: 'Insurance',
          expiryDate: null,
        );
        await tester.pumpWidget(
          hostApp(child: VaultDocumentCard(document: doc, now: _now)),
        );

        expect(
          find.byKey(const ValueKey<String>('vault_document_card_title')),
          findsOneWidget,
        );
        expect(find.text('Insurance Cover Note'), findsOneWidget);

        // Category badge content.
        final Finder badgeFinder = find.byKey(
          const ValueKey<String>('vault_document_card_category'),
        );
        expect(badgeFinder, findsOneWidget);
        expect(
          find.descendant(of: badgeFinder, matching: find.text('Insurance')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'noExpiry branch — placeholder copy "No expiry" with info color',
      (WidgetTester tester) async {
        const VaultDocument doc = VaultDocument(
          title: 'Receipt',
          category: 'Receipt',
          expiryDate: null,
        );
        await tester.pumpWidget(
          hostApp(child: VaultDocumentCard(document: doc, now: _now)),
        );

        // Documented placeholder copy.
        expect(
          find.byKey(const ValueKey<String>('vault_document_card_expiry')),
          findsOneWidget,
        );
        expect(find.text('No expiry'), findsOneWidget);

        // Indicator color → info token (noExpiry branch).
        final AppColorsExt colors = _colorsOf(tester);
        expect(_statusDotColor(tester), equals(colors.info));
      },
    );

    testWidgets(
      'ok branch — expiry far in the future shows success indicator '
      'and no warning/error coloring',
      (WidgetTester tester) async {
        // 365 days in the future is well outside the 30-day warning
        // window so `expiryStatusOf` returns `ExpiryStatus.ok`.
        final VaultDocument doc = VaultDocument(
          title: 'Insurance Policy 2026',
          category: 'Insurance',
          expiryDate: _now.add(const Duration(days: 365)),
        );
        await tester.pumpWidget(
          hostApp(child: VaultDocumentCard(document: doc, now: _now)),
        );

        final AppColorsExt colors = _colorsOf(tester);
        final Color dotColor = _statusDotColor(tester);
        expect(
          dotColor,
          equals(colors.success),
          reason: 'ok branch must use the success token color.',
        );
        expect(dotColor, isNot(equals(colors.warning)));
        expect(dotColor, isNot(equals(colors.error)));
        // Expiry copy should display the formatted future date.
        expect(find.textContaining('Expires'), findsOneWidget);
      },
    );

    testWidgets(
      'warning branch — expiry within 30 days shows warning indicator',
      (WidgetTester tester) async {
        // 10 days from now → falls inside the 30-day warning window.
        final VaultDocument doc = VaultDocument(
          title: 'Road Tax',
          category: 'Tax',
          expiryDate: _now.add(const Duration(days: 10)),
        );
        await tester.pumpWidget(
          hostApp(child: VaultDocumentCard(document: doc, now: _now)),
        );

        final AppColorsExt colors = _colorsOf(tester);
        expect(
          _statusDotColor(tester),
          equals(colors.warning),
          reason: 'warning branch must use the warning token color.',
        );
      },
    );

    testWidgets(
      'error branch — expired more than 30 days ago shows error indicator',
      (WidgetTester tester) async {
        // 60 days in the past → outside the 30-day grace window, so
        // `expiryStatusOf` returns `ExpiryStatus.error`.
        final VaultDocument doc = VaultDocument(
          title: 'Old Warranty',
          category: 'Warranty',
          expiryDate: _now.subtract(const Duration(days: 60)),
        );
        await tester.pumpWidget(
          hostApp(child: VaultDocumentCard(document: doc, now: _now)),
        );

        final AppColorsExt colors = _colorsOf(tester);
        expect(
          _statusDotColor(tester),
          equals(colors.error),
          reason: 'error branch must use the error token color.',
        );
      },
    );

    testWidgets(
      'fileSizeBytes is formatted via formatBytes and rendered on card',
      (WidgetTester tester) async {
        // 2_097_152 bytes = exactly 2.0 MB under the power-of-1024
        // threshold rule encoded by `formatBytes`.
        const VaultDocument doc = VaultDocument(
          title: 'Service Invoice',
          category: 'Receipt',
          fileSizeBytes: 2 * 1024 * 1024,
        );
        await tester.pumpWidget(
          hostApp(child: VaultDocumentCard(document: doc, now: _now)),
        );

        expect(
          find.byKey(const ValueKey<String>('vault_document_card_size')),
          findsOneWidget,
        );
        expect(find.text('2.0 MB'), findsOneWidget);
      },
    );

    testWidgets(
      'fileSizeBytes null → size row is not rendered',
      (WidgetTester tester) async {
        const VaultDocument doc = VaultDocument(
          title: 'Receipt',
          category: 'Receipt',
        );
        await tester.pumpWidget(
          hostApp(child: VaultDocumentCard(document: doc, now: _now)),
        );

        expect(
          find.byKey(const ValueKey<String>('vault_document_card_size')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'card renders inside an AppCard surface (Requirement 10.3 / 3.11)',
      (WidgetTester tester) async {
        const VaultDocument doc = VaultDocument(
          title: 'Receipt',
          category: 'Receipt',
        );
        await tester.pumpWidget(
          hostApp(child: VaultDocumentCard(document: doc, now: _now)),
        );

        // The card content lives inside an `AppCard` so it picks up
        // the token-driven surface styling.
        expect(find.byType(AppCard), findsOneWidget);
      },
    );

    testWidgets(
      'theme switches do not break the card render path',
      (WidgetTester tester) async {
        // Render the card in dark mode to confirm token resolution
        // works for both brightness branches.
        const VaultDocument doc = VaultDocument(
          title: 'Insurance',
          category: 'Insurance',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildTheme(AppColors.emerald500, Brightness.dark),
            home: Scaffold(
              body: VaultDocumentCard(document: doc, now: _now),
            ),
          ),
        );

        expect(find.byType(VaultDocumentCard), findsOneWidget);
        expect(find.text('Insurance'), findsAtLeastNWidgets(1));
      },
    );
  });
}
