// Redesigned Wallet History screen for the figma-ui-redesign
// (Tasks 13.1 – 13.7 / Requirements 11.1 – 11.8).
//
// The body is composed from the modular widgets in
// `lib/screens/wallet/_widgets.dart`:
//
//   * OverviewTab       — Recent activity summary above the latest
//                         transactions (Task 13.2).
//   * TransactionsTab   — Filter chip row + transaction list with
//                         type / status mappings (Tasks 13.3, 13.4,
//                         13.6).
//   * InsightsTab       — Lifetime totals + counts by type
//                         (Task 13.2).
//
// The hero balance card renders the current balance through
// `intl.NumberFormat.currency(locale: 'en_MY', symbol: 'RM ')`
// (Task 13.1) and exposes a `Top Up` `AppGradientButton` routed
// through an [InFlightGate] so rapid taps result in one
// `WalletTopUpSheet` per gesture (Task 13.5).
//
// The screen subscribes to `ProfileService.instance` via a
// `ListenableBuilder` so balance + transaction changes trigger a
// rebuild without manual state management. Persistence stays
// untouched — the redesign is purely UI.

import 'package:flutter/material.dart';

import '../core/theme/color_utils.dart';

import '../core/theme/tokens/tokens.dart';
import '../core/util/in_flight_gate.dart';
import '../services/profile_service.dart';
import '../widgets/ui/ui.dart';
import '../widgets/wallet_top_up_sheet.dart';
import 'wallet/_widgets.dart';

/// Redesigned Wallet History screen.
class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({
    super.key,
    this.onTopUpRequested,
    this.transactionsOverride,
    this.balanceOverride,
    this.loading = false,
  });

  /// Stable route name. Preserved verbatim from the legacy
  /// implementation so existing navigation calls continue to resolve.
  static const String routeName = '/wallet-history';

  /// Optional override for the top-up launch flow used by widget
  /// tests. In production the screen calls
  /// [_defaultTopUpRequested] which presents the [WalletTopUpSheet]
  /// via `showModalBottomSheet`. Tests can pass a function that
  /// throws to exercise the failure branch (Requirement 11.6) or a
  /// no-op to exercise the success branch.
  final Future<void> Function(BuildContext context)? onTopUpRequested;

  /// Optional immediate transaction list for tests / previews. When
  /// non-null the screen skips the [ProfileService] subscription and
  /// renders the supplied list verbatim. Production callers leave
  /// this `null`.
  final List<WalletTransaction>? transactionsOverride;

  /// Optional immediate balance for tests / previews. When non-null
  /// the hero card renders this value instead of
  /// `ProfileService.instance.walletBalance`.
  final double? balanceOverride;

  /// When `true`, the affected sections render an [AppSkeletonLoader]
  /// in place of their content (Requirement 11.8).
  final bool loading;

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final InFlightGate _topUpGate = InFlightGate();

  /// Last persistence-launch error. When non-null, an
  /// `AppFeedbackBanner` of kind `error` is rendered above the tab
  /// bar with the documented `wallet_top_up_error_banner` key
  /// (Requirement 11.6).
  String? _topUpError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _topUpGate.addListener(_onGateChange);
  }

  @override
  void dispose() {
    _topUpGate.removeListener(_onGateChange);
    _topUpGate.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onGateChange() {
    if (mounted) setState(() {});
  }

  /// Default production top-up launch: present [WalletTopUpSheet]
  /// via `showModalBottomSheet`. Mirrors the call shape used by the
  /// home-screen wallet/vault row so the two surfaces share the
  /// same launch path (Task 13.5).
  Future<void> _defaultTopUpRequested(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext _) => const WalletTopUpSheet(),
    );
  }

  Future<void> _handleTopUp(BuildContext context) async {
    final Future<void> Function(BuildContext) launcher =
        widget.onTopUpRequested ?? _defaultTopUpRequested;
    await _topUpGate.run<void>(() async {
      try {
        await launcher(context);
        if (mounted) {
          setState(() => _topUpError = null);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _topUpError =
                'Could not open the top-up flow. Please try again.';
          });
        }
      }
    });
  }

  /// Resolve the live transactions list for this build. When
  /// [WalletHistoryScreen.transactionsOverride] is non-null the
  /// override wins; otherwise we project the legacy
  /// `ProfileService.transactions` Map list onto the typed
  /// [WalletTransaction] shape.
  List<WalletTransaction> _resolveTransactions() {
    final List<WalletTransaction>? override = widget.transactionsOverride;
    if (override != null) return override;
    return ProfileService.instance.transactions
        .map<WalletTransaction>(
          (Map<String, dynamic> raw) => WalletTransaction.fromMap(raw),
        )
        .toList(growable: false);
  }

  /// Resolve the live wallet balance for this build.
  double _resolveBalance() {
    return widget.balanceOverride ?? ProfileService.instance.walletBalance;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Widget body = ListenableBuilder(
      listenable: ProfileService.instance,
      builder: (BuildContext context, Widget? _) {
        final double balance = _resolveBalance();
        final List<WalletTransaction> txns = _resolveTransactions();
        return _buildBody(
          balance: balance,
          transactions: txns,
          colors: colors,
          spacing: spacing,
          typography: typography,
        );
      },
    );

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: Text(
          'Wallet',
          style: typography.headline.copyWith(color: colors.foreground),
        ),
      ),
      body: SafeArea(child: body),
    ),);
  }

  Widget _buildBody({
    required double balance,
    required List<WalletTransaction> transactions,
    required AppColorsExt colors,
    required AppSpacingExt spacing,
    required AppTypographyExt typography,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.md,
            spacing.lg,
            spacing.sm,
          ),
          child: widget.loading
              ? AppSkeletonLoader(
                  key: const ValueKey<String>('wallet_hero_skeleton'),
                  child: SizedBox(
                    height: spacing.xxxxl * 3,
                    child: const SizedBox.expand(),
                  ),
                )
              : _HeroBalanceCard(
                  balance: balance,
                  isTopUpInFlight: _topUpGate.isRunning,
                  onTopUp: () => _handleTopUp(context),
                ),
        ),
        if (_topUpError != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: AppFeedbackBanner(
              key: const ValueKey<String>('wallet_top_up_error_banner'),
              kind: FeedbackKind.error,
              message: _topUpError!,
              onDismiss: () => setState(() => _topUpError = null),
            ),
          ),
        SizedBox(height: spacing.sm),
        TabBar(
          key: const ValueKey<String>('wallet_tab_bar'),
          controller: _tabController,
          labelStyle: typography.title,
          labelColor: colors.emerald500,
          unselectedLabelColor: colors.foreground
              .withValues(alpha: colors.surfaceProminent),
          indicatorColor: colors.emerald500,
          tabs: const <Widget>[
            Tab(key: ValueKey<String>('wallet_tab_overview'), text: 'Overview'),
            Tab(
              key: ValueKey<String>('wallet_tab_transactions'),
              text: 'Transactions',
            ),
            Tab(key: ValueKey<String>('wallet_tab_insights'), text: 'Insights'),
          ],
        ),
        Expanded(
          child: widget.loading
              ? AppSkeletonLoader(
                  key: const ValueKey<String>('wallet_body_skeleton'),
                  child: SizedBox.expand(),
                )
              : TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    OverviewTab(
                      balance: balance,
                      transactions: transactions,
                    ),
                    TransactionsTab(transactions: transactions),
                    InsightsTab(transactions: transactions),
                  ],
                ),
        ),
      ],
    );
  }
}

// ===========================================================================
// _HeroBalanceCard
// ===========================================================================

/// Hero balance card rendered above the tab bar.
///
/// Renders the current wallet balance in `AppTypography.display`
/// styling, formatted via the shared [walletCurrencyFormatter] so the
/// locale + symbol stay consistent (Requirement 11.1). The card uses
/// the brand-gradient fill from `AppColors.emerald500 →
/// AppColors.teal400` and exposes a `Top Up` [AppGradientButton]
/// driven by the parent screen's [InFlightGate].
class _HeroBalanceCard extends StatelessWidget {
  final double balance;
  final bool isTopUpInFlight;
  final VoidCallback onTopUp;

  const _HeroBalanceCard({
    required this.balance,
    required this.isTopUpInFlight,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppShadowsExt shadows = theme.extension<AppShadowsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final BorderRadius borderRadius = BorderRadius.circular(radii.large);

    return Container(
      key: const ValueKey<String>('wallet_hero_card'),
      padding: EdgeInsets.all(spacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[colors.emerald500, colors.teal400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: shadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Current balance',
                style:
                    typography.label.copyWith(color: Colors.white),
              ),
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: typography.headline.fontSize,
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  walletCurrencyFormatter.format(balance),
                  key: const ValueKey<String>('wallet_hero_balance'),
                  style: typography.display.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                key: const ValueKey<String>('wallet_top_up_button'),
                onTap: isTopUpInFlight ? null : onTopUp,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.md,
                    vertical: spacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(radii.medium),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isTopUpInFlight)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.emerald500,
                          ),
                        )
                      else ...[
                        Icon(Icons.add, color: colors.emerald500, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Top Up',
                          style: TextStyle(
                            color: colors.emerald500,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
