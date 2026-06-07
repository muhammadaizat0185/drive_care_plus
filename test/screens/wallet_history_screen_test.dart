// Feature: figma-ui-redesign — Widget + integration tests for the
// redesigned `WalletHistoryScreen` (Task 13.7).
//
// Validates:
//   * Requirement 11.1 — Hero balance card renders the wallet balance
//                        currency-formatted via
//                        `intl.NumberFormat.currency(locale: 'en_MY',
//                        symbol: 'RM ')`.
//   * Requirement 11.2 — Top tab switcher exposes Overview /
//                        Transactions / Insights with Overview as the
//                        default on first open.
//   * Requirement 11.3 — Type→color and status→badge maps are
//                        one-to-one onto three distinct treatments.
//   * Requirement 11.4 — Filter chip row applies locally over the
//                        already-loaded transactions; no fetch is
//                        triggered when the chip changes.
//   * Requirement 11.5 — Tapping the hero `Top Up` button invokes the
//                        existing top-up flow exactly once per user
//                        gesture, even with rapid taps (the
//                        InFlightGate single-effect contract).
//   * Requirement 11.6 — Top-up launch failure surfaces an
//                        `AppFeedbackBanner` of kind `error` keyed
//                        `wallet_top_up_error_banner`; the active tab
//                        and chip filter are preserved across the
//                        failure.
//   * Requirement 11.7 — Empty filtered result renders an
//                        `AppEmptyState` while the chip row stays
//                        interactive.
//   * Requirement 11.8 — Loading state renders an `AppSkeletonLoader`
//                        for the affected sections; no partial /
//                        stale rendering.
//
// Why an injected `onTopUpRequested`:
//   * The production binding presents the [WalletTopUpSheet] via
//     `showModalBottomSheet`, which transitively constructs a
//     [TextField] that touches Firebase plugin channels and the
//     ToyyibPay HTTP client. The flutter_test process has no Firebase
//     plugin channels, so widget tests inject a deterministic
//     launcher (`onTopUpRequested`) instead — a no-op for the happy
//     path and a thrower for the failure path.
//
// Why `transactionsOverride`:
//   * The screen subscribes to `ProfileService.instance` via a
//     `ListenableBuilder`. Passing an explicit `transactionsOverride`
//     short-circuits `_resolveTransactions` so the rendered list is
//     deterministic and decoupled from the singleton's contents.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/wallet/_widgets.dart';
import 'package:drive_care_plus/screens/wallet_history_screen.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test fixtures.
// ---------------------------------------------------------------------------

/// Fixture covering each of the three [WalletTransactionType] values
/// and each of the three [WalletTransactionStatus] values so the
/// type→color and status→badge mapping tests have at least one row
/// per branch.
final List<WalletTransaction> _fixtures = <WalletTransaction>[
  WalletTransaction(
    amount: 100.00,
    type: WalletTransactionType.topUp,
    status: WalletTransactionStatus.completed,
    description: 'Wallet top-up via ToyyibPay',
    date: DateTime(2025, 6, 1, 10, 30),
  ),
  WalletTransaction(
    amount: -25.50,
    type: WalletTransactionType.payment,
    status: WalletTransactionStatus.pending,
    description: 'Workshop booking deposit',
    date: DateTime(2025, 6, 5, 14, 15),
  ),
  WalletTransaction(
    amount: 12.30,
    type: WalletTransactionType.refund,
    status: WalletTransactionStatus.failed,
    description: 'Refund for cancelled booking',
    date: DateTime(2025, 6, 8, 9, 0),
  ),
];

// ---------------------------------------------------------------------------
// Test harness.
// ---------------------------------------------------------------------------

/// Token-themed `MaterialApp` shell so the screen's
/// `Theme.of(context).extension<...>()` look-ups resolve. Mirrors the
/// pattern used by `document_vault_screen_test`.
class _WalletHarness extends StatelessWidget {
  final Future<void> Function(BuildContext context)? onTopUpRequested;
  final List<WalletTransaction>? transactionsOverride;
  final double? balanceOverride;
  final bool loading;
  final Brightness brightness;

  const _WalletHarness({
    this.onTopUpRequested,
    this.transactionsOverride,
    this.balanceOverride,
    this.loading = false,
    this.brightness = Brightness.light,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(AppColors.emerald500, brightness),
      home: WalletHistoryScreen(
        onTopUpRequested: onTopUpRequested,
        transactionsOverride: transactionsOverride,
        balanceOverride: balanceOverride,
        loading: loading,
      ),
    );
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Future<void> Function(BuildContext context)? onTopUpRequested,
  List<WalletTransaction>? transactions,
  double balance = 250.0,
  bool loading = false,
  Brightness brightness = Brightness.light,
}) async {
  // Bump the viewport so the chip row and tab bar do not overflow
  // during interaction.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _WalletHarness(
      onTopUpRequested: onTopUpRequested,
      transactionsOverride: transactions ?? _fixtures,
      balanceOverride: balance,
      loading: loading,
      brightness: brightness,
    ),
  );
  await tester.pump();
}

void main() {
  // ---------------------------------------------------------------------
  // Hero balance card (Requirement 11.1).
  // ---------------------------------------------------------------------
  group('Hero balance card', () {
    testWidgets(
      'renders balance currency-formatted via en_MY locale',
      (WidgetTester tester) async {
        await _pumpScreen(tester, balance: 1234.56);

        // The `intl` package's en_MY currency formatter prints
        // `RM 1,234.56` (with a non-breaking thousands separator).
        // We assert the prefix and the cents portion so the test is
        // robust to locale-data tweaks.
        final Finder balanceFinder =
            find.byKey(const ValueKey<String>('wallet_hero_balance'));
        expect(balanceFinder, findsOneWidget);
        final Text balanceText = tester.widget<Text>(balanceFinder);
        expect(balanceText.data, isNotNull);
        expect(balanceText.data!.startsWith('RM'), isTrue);
        expect(balanceText.data!.endsWith('.56'), isTrue);
      },
    );

    testWidgets(
      'hero card and Top Up button are mounted with stable keys',
      (WidgetTester tester) async {
        await _pumpScreen(tester);

        expect(
          find.byKey(const ValueKey<String>('wallet_hero_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('wallet_top_up_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders correctly in dark mode (token resolution check)',
      (WidgetTester tester) async {
        await _pumpScreen(tester, brightness: Brightness.dark);

        // Hero card and balance label resolve from token extensions
        // without throwing in either brightness.
        expect(
          find.byKey(const ValueKey<String>('wallet_hero_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('wallet_hero_balance')),
          findsOneWidget,
        );
      },
    );
  });

  // ---------------------------------------------------------------------
  // Default tab is Overview (Requirement 11.2).
  // ---------------------------------------------------------------------
  group('Tab default', () {
    testWidgets(
      'first open lands on Overview, mounting wallet_overview_tab',
      (WidgetTester tester) async {
        await _pumpScreen(tester);

        expect(
          find.byKey(const ValueKey<String>('wallet_overview_tab')),
          findsOneWidget,
        );
        // The other tab bodies are inactive; the TabBarView keeps
        // them in the tree but only the Overview body is the visible
        // one. We assert the tab labels themselves are reachable.
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Transactions'), findsOneWidget);
        expect(find.text('Insights'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------
  // Type → color / status → badge mappings (Requirement 11.3).
  // ---------------------------------------------------------------------
  group('Type / status mappers', () {
    test(
      'iconColorForType is one-to-one onto success / info / warning',
      () {
        const AppColorsExt colors = AppColorsExt.light();
        final Color topUp =
            iconColorForType(WalletTransactionType.topUp, colors);
        final Color payment =
            iconColorForType(WalletTransactionType.payment, colors);
        final Color refund =
            iconColorForType(WalletTransactionType.refund, colors);

        expect(topUp, equals(colors.success));
        expect(payment, equals(colors.info));
        expect(refund, equals(colors.warning));

        // Three distinct colors (Requirement 11.3).
        expect(<Color>{topUp, payment, refund}.length, equals(3));
      },
    );

    test(
      'badgeKindForStatus is one-to-one onto success / warning / error',
      () {
        expect(
          badgeKindForStatus(WalletTransactionStatus.completed),
          equals(BadgeKind.success),
        );
        expect(
          badgeKindForStatus(WalletTransactionStatus.pending),
          equals(BadgeKind.warning),
        );
        expect(
          badgeKindForStatus(WalletTransactionStatus.failed),
          equals(BadgeKind.error),
        );

        // Three distinct kinds (Requirement 11.3).
        final Set<BadgeKind> kinds = <BadgeKind>{
          badgeKindForStatus(WalletTransactionStatus.completed),
          badgeKindForStatus(WalletTransactionStatus.pending),
          badgeKindForStatus(WalletTransactionStatus.failed),
        };
        expect(kinds.length, equals(3));
      },
    );
  });

  // ---------------------------------------------------------------------
  // Filter chip row — local-only filtering (Requirement 11.4).
  // ---------------------------------------------------------------------
  group('Transactions filter', () {
    test('filterTransactions(All) preserves order and contents', () {
      final List<WalletTransaction> filtered =
          filterTransactions(_fixtures, 'All');
      expect(filtered.length, equals(_fixtures.length));
      for (int i = 0; i < _fixtures.length; i++) {
        expect(filtered[i], equals(_fixtures[i]));
      }
    });

    test('filterTransactions(Top-up) returns only top-up rows', () {
      final List<WalletTransaction> filtered =
          filterTransactions(_fixtures, 'Top-up');
      expect(filtered.length, equals(1));
      expect(filtered.single.type, equals(WalletTransactionType.topUp));
    });

    test('filterTransactions(Payment) returns only payment rows', () {
      final List<WalletTransaction> filtered =
          filterTransactions(_fixtures, 'Payment');
      expect(filtered.length, equals(1));
      expect(filtered.single.type, equals(WalletTransactionType.payment));
    });

    test('filterTransactions(Refund) returns only refund rows', () {
      final List<WalletTransaction> filtered =
          filterTransactions(_fixtures, 'Refund');
      expect(filtered.length, equals(1));
      expect(filtered.single.type, equals(WalletTransactionType.refund));
    });

    testWidgets(
      'tapping a chip filters locally without invoking the launcher',
      (WidgetTester tester) async {
        int launcherCalls = 0;
        await _pumpScreen(
          tester,
          onTopUpRequested: (BuildContext _) async {
            launcherCalls++;
          },
        );

        // Switch to the Transactions tab.
        await tester.tap(find.text('Transactions'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('wallet_transactions_tab')),
          findsOneWidget,
        );

        // Tap the Top-up chip.
        await tester.tap(
          find.byKey(const ValueKey<String>('wallet_filter_chip_Top-up')),
        );
        await tester.pumpAndSettle();

        // The local list should be filtered to a single row (the
        // top-up fixture).
        expect(
          find.text('Wallet top-up via ToyyibPay'),
          findsOneWidget,
        );
        expect(
          find.text('Workshop booking deposit'),
          findsNothing,
        );
        expect(
          find.text('Refund for cancelled booking'),
          findsNothing,
        );

        // No top-up launcher invocation should have been triggered
        // by the chip tap (Requirement 11.4 — local-only filtering).
        expect(launcherCalls, equals(0));
      },
    );
  });

  // ---------------------------------------------------------------------
  // Empty filtered state (Requirement 11.7).
  // ---------------------------------------------------------------------
  group('Empty filtered state', () {
    testWidgets(
      'filtering to an empty subset shows AppEmptyState; chips remain',
      (WidgetTester tester) async {
        // Drop the refund row from the fixture so the Refund filter
        // yields an empty subset.
        final List<WalletTransaction> truncated = <WalletTransaction>[
          _fixtures[0],
          _fixtures[1],
        ];
        await _pumpScreen(tester, transactions: truncated);

        await tester.tap(find.text('Transactions'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('wallet_filter_chip_Refund')),
        );
        await tester.pumpAndSettle();

        // Empty state present.
        expect(
          find.byKey(
            const ValueKey<String>('wallet_transactions_empty_state'),
          ),
          findsOneWidget,
        );

        // Chip row still interactive — tapping `All` should clear the
        // filter and bring the rows back.
        await tester.tap(
          find.byKey(const ValueKey<String>('wallet_filter_chip_All')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey<String>('wallet_transactions_empty_state'),
          ),
          findsNothing,
        );
        expect(find.text('Wallet top-up via ToyyibPay'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------
  // Top Up flow (Requirements 11.5, 11.6).
  // ---------------------------------------------------------------------
  group('Top Up flow', () {
    testWidgets(
      'tapping Top Up invokes the launcher exactly once on success',
      (WidgetTester tester) async {
        int launcherCalls = 0;
        await _pumpScreen(
          tester,
          onTopUpRequested: (BuildContext _) async {
            launcherCalls++;
          },
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('wallet_top_up_button')),
        );
        await tester.pumpAndSettle();

        expect(launcherCalls, equals(1));
        // No error banner on the success branch.
        expect(
          find.byKey(
            const ValueKey<String>('wallet_top_up_error_banner'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'rapid taps yield exactly one launcher invocation '
      '(InFlightGate single-effect)',
      (WidgetTester tester) async {
        int launcherCalls = 0;
        // Hold the launcher in flight until we explicitly release.
        bool released = false;
        await _pumpScreen(
          tester,
          onTopUpRequested: (BuildContext _) async {
            launcherCalls++;
            // Wait until the test releases by polling on micro-pump.
            while (!released) {
              await Future<void>.delayed(const Duration(milliseconds: 1));
            }
          },
        );

        // Fire 5 rapid taps on the Top Up button.
        for (int i = 0; i < 5; i++) {
          await tester.tap(
            find.byKey(const ValueKey<String>('wallet_top_up_button')),
            warnIfMissed: false,
          );
        }
        // Pump one frame so the gate's `notifyListeners` flips
        // `isRunning = true` and the button enters its loading
        // state.
        await tester.pump();

        // Release the launcher and let the gate complete.
        released = true;
        await tester.pumpAndSettle();

        expect(
          launcherCalls,
          equals(1),
          reason:
              'Rapid taps during in-flight should produce exactly one '
              'launcher invocation per user gesture (Requirement 11.5 / '
              'InFlightGate single-effect).',
        );
      },
    );

    testWidgets(
      'launcher failure surfaces wallet_top_up_error_banner; '
      'tab + filter preserved',
      (WidgetTester tester) async {
        await _pumpScreen(
          tester,
          onTopUpRequested: (BuildContext _) async {
            throw StateError('Forced launcher failure for test.');
          },
        );

        // Switch to Transactions tab and select the Top-up chip
        // before tapping Top Up so we can assert preservation
        // (Requirement 11.6).
        await tester.tap(find.text('Transactions'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('wallet_filter_chip_Top-up')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('wallet_top_up_button')),
        );
        await tester.pumpAndSettle();

        // Error banner with the documented key + kind.
        final Finder bannerFinder = find.byKey(
          const ValueKey<String>('wallet_top_up_error_banner'),
        );
        expect(bannerFinder, findsOneWidget);
        final AppFeedbackBanner banner =
            tester.widget<AppFeedbackBanner>(bannerFinder);
        expect(banner.kind, equals(FeedbackKind.error));

        // Transactions tab still active — its chip filter row is
        // still mounted.
        expect(
          find.byKey(const ValueKey<String>('wallet_transactions_tab')),
          findsOneWidget,
        );
        // Top-up chip selection survived (the only visible row is
        // the top-up fixture).
        expect(
          find.text('Wallet top-up via ToyyibPay'),
          findsOneWidget,
        );
        expect(
          find.text('Workshop booking deposit'),
          findsNothing,
        );
      },
    );
  });

  // ---------------------------------------------------------------------
  // Loading state (Requirement 11.8).
  // ---------------------------------------------------------------------
  group('Loading state', () {
    testWidgets(
      'loading=true renders the hero and body skeletons; '
      'no partial rendering',
      (WidgetTester tester) async {
        await _pumpScreen(tester, loading: true);

        expect(
          find.byKey(const ValueKey<String>('wallet_hero_skeleton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('wallet_body_skeleton')),
          findsOneWidget,
        );

        // The hero card and tab bodies must not render concurrently
        // with the skeletons (no partial / stale rendering).
        expect(
          find.byKey(const ValueKey<String>('wallet_hero_card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('wallet_overview_tab')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('wallet_transactions_tab')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('wallet_insights_tab')),
          findsNothing,
        );
      },
    );
  });
}
