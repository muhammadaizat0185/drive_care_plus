// Modular building blocks for the redesigned Wallet History screen
// (`lib/screens/wallet_history_screen.dart`).
//
// This module hosts the typed value classes, mapping helpers, the
// pure transaction filter, and the three primary tab bodies of the
// redesigned screen (Tasks 13.1 – 13.7 / Requirements 11.1 – 11.8):
//
//   * [WalletTransaction]          — Value type for a single saved
//                                    transaction row carrying amount,
//                                    type, status, description, and
//                                    date.
//   * [WalletTransactionType]      — `topUp / payment / refund` enum
//                                    used by the leading-icon color
//                                    map.
//   * [WalletTransactionStatus]    — `completed / pending / failed`
//                                    enum used by the trailing badge.
//   * [iconColorForType]           — Pure mapper from a
//                                    [WalletTransactionType] onto the
//                                    `success / info / warning` token
//                                    color (Requirement 11.3).
//   * [badgeKindForStatus]         — Pure mapper from a
//                                    [WalletTransactionStatus] onto a
//                                    `BadgeKind` (Requirement 11.3).
//   * [iconForType]                — Pure mapper from a
//                                    [WalletTransactionType] onto the
//                                    leading Material icon.
//   * [kWalletFilterLabels]        — `All / Top-up / Payment / Refund`
//                                    chip-row labels.
//   * [filterTransactions]         — Pure filter applied locally over
//                                    already-loaded transactions
//                                    (Requirement 11.4).
//   * [OverviewTab]                — Overview-tab body summarizing
//                                    balance + recent activity.
//   * [TransactionsTab]            — Transactions-tab body wiring the
//                                    chip filter row, transaction
//                                    list, and empty-state branch.
//   * [InsightsTab]                — Insights-tab body summarizing
//                                    in/out totals.
//
// Visual constants flow from the design-token extensions on
// `Theme.of(context)`; no hex colors, spacing, radii, or typography
// literals from the Token_Sets are inlined (Requirement 3.11).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../core/util/single_select_controller.dart';
import '../../widgets/ui/ui.dart';

// ===========================================================================
// WalletTransactionType
// ===========================================================================

/// Type of a single wallet transaction row.
///
/// Three distinct values are mapped one-to-one onto the leading-icon
/// color (Requirement 11.3):
///
///   * `topUp`   → `success` token color.
///   * `payment` → `info`    token color.
///   * `refund`  → `warning` token color.
///
/// The legacy `ProfileService.transactions` stores the type as a
/// stringly-typed value (`'top_up' / 'payment' / 'refund'`); the
/// [parse] helper accepts the legacy strings and returns the typed
/// enum.
enum WalletTransactionType { topUp, payment, refund }

/// Parse the legacy stringly-typed transaction type into the typed
/// enum. Accepts `'top_up'`, `'payment'`, `'refund'`. Anything else
/// (legacy `'subscription'` or any unknown value) falls back to
/// [WalletTransactionType.payment] so the row still renders rather
/// than being dropped.
WalletTransactionType parseTransactionType(String? raw) {
  switch (raw) {
    case 'top_up':
    case 'topup':
    case 'top-up':
      return WalletTransactionType.topUp;
    case 'refund':
      return WalletTransactionType.refund;
    case 'payment':
    case 'deduction':
      return WalletTransactionType.payment;
    default:
      return WalletTransactionType.payment;
  }
}

// ===========================================================================
// WalletTransactionStatus
// ===========================================================================

/// Status of a single wallet transaction row.
///
/// Three distinct values are mapped one-to-one onto a [BadgeKind]
/// (Requirement 11.3):
///
///   * `completed` → `BadgeKind.success`.
///   * `pending`   → `BadgeKind.warning`.
///   * `failed`    → `BadgeKind.error`.
///
/// The legacy data set may not write a `status` field today; missing
/// values are treated as [WalletTransactionStatus.completed] per the
/// Group 13 task brief.
enum WalletTransactionStatus { completed, pending, failed }

/// Parse the legacy stringly-typed transaction status into the typed
/// enum. Missing or unknown values default to
/// [WalletTransactionStatus.completed] so legacy rows still render.
WalletTransactionStatus parseTransactionStatus(String? raw) {
  switch (raw) {
    case 'pending':
      return WalletTransactionStatus.pending;
    case 'failed':
      return WalletTransactionStatus.failed;
    case 'completed':
    default:
      return WalletTransactionStatus.completed;
  }
}

// ===========================================================================
// WalletTransaction
// ===========================================================================

/// Single saved wallet transaction.
///
/// The legacy `ProfileService.transactions` API is `Map<String, dynamic>`
/// based, so [fromMap] / [toMap] are provided so the redesigned tile,
/// the filter helper, and the tests can share one typed shape while
/// the underlying persistence stays untouched.
@immutable
class WalletTransaction {
  /// Signed amount in ringgit. Positive for credits (top-ups,
  /// refunds), negative for debits (payments). The legacy data
  /// stores credits as positives and debits as negatives, which the
  /// transactions tile renders with `+ RM` / `- RM` formatting.
  final double amount;

  /// Typed transaction type used by the leading-icon mapping.
  final WalletTransactionType type;

  /// Typed transaction status used by the trailing badge.
  final WalletTransactionStatus status;

  /// Free-form description rendered as the tile's title line.
  final String description;

  /// Transaction date. Parsed from the legacy ISO-8601 string when
  /// available; falls back to `DateTime.fromMillisecondsSinceEpoch(0)`
  /// if the legacy row carries no parseable date.
  final DateTime date;

  const WalletTransaction({
    required this.amount,
    required this.type,
    required this.status,
    required this.description,
    required this.date,
  });

  /// Parse a `Map<String, dynamic>` produced by the legacy
  /// `ProfileService.transactions` API into a [WalletTransaction].
  /// Tolerates missing fields by falling back to safe defaults; the
  /// legacy seed data uses string keys with no schema versioning.
  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    final num? rawAmount = map['amount'] as num?;
    final String? rawDate = map['date'] as String?;
    DateTime parsedDate;
    if (rawDate == null || rawDate.isEmpty) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      parsedDate = DateTime.tryParse(rawDate) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return WalletTransaction(
      amount: rawAmount?.toDouble() ?? 0.0,
      type: parseTransactionType(map['type'] as String?),
      status: parseTransactionStatus(map['status'] as String?),
      description: (map['description'] as String?) ?? '',
      date: parsedDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletTransaction &&
        other.amount == amount &&
        other.type == type &&
        other.status == status &&
        other.description == description &&
        other.date == date;
  }

  @override
  int get hashCode =>
      Object.hash(amount, type, status, description, date);

  @override
  String toString() => 'WalletTransaction(amount: $amount, type: $type, '
      'status: $status, description: "$description", date: $date)';
}

// ===========================================================================
// Type → color / icon mappers
// ===========================================================================

/// Pure mapper from a [WalletTransactionType] onto the leading-icon
/// color from the active token set (Requirement 11.3).
///
///   * `topUp`   → `colors.success`
///   * `payment` → `colors.info`
///   * `refund`  → `colors.warning`
Color iconColorForType(WalletTransactionType type, AppColorsExt colors) {
  switch (type) {
    case WalletTransactionType.topUp:
      return colors.success;
    case WalletTransactionType.payment:
      return colors.info;
    case WalletTransactionType.refund:
      return colors.warning;
  }
}

/// Pure mapper from a [WalletTransactionType] onto a leading Material
/// icon used by the transactions tile.
IconData iconForType(WalletTransactionType type) {
  switch (type) {
    case WalletTransactionType.topUp:
      return Icons.add_card_outlined;
    case WalletTransactionType.payment:
      return Icons.payments_outlined;
    case WalletTransactionType.refund:
      return Icons.undo_outlined;
  }
}

/// Pure mapper from a [WalletTransactionStatus] onto a [BadgeKind]
/// (Requirement 11.3).
///
///   * `completed` → `BadgeKind.success`
///   * `pending`   → `BadgeKind.warning`
///   * `failed`    → `BadgeKind.error`
BadgeKind badgeKindForStatus(WalletTransactionStatus status) {
  switch (status) {
    case WalletTransactionStatus.completed:
      return BadgeKind.success;
    case WalletTransactionStatus.pending:
      return BadgeKind.warning;
    case WalletTransactionStatus.failed:
      return BadgeKind.error;
  }
}

/// Human-readable label rendered inside the trailing status badge.
String labelForStatus(WalletTransactionStatus status) {
  switch (status) {
    case WalletTransactionStatus.completed:
      return 'Completed';
    case WalletTransactionStatus.pending:
      return 'Pending';
    case WalletTransactionStatus.failed:
      return 'Failed';
  }
}

// ===========================================================================
// Filter labels + filter helper
// ===========================================================================

/// Chip-row labels rendered above the transactions list. The first
/// entry is the `All` sentinel that disables the per-row type check
/// inside [filterTransactions]; the remaining three match the
/// design's transaction types exactly (Requirement 11.4).
const List<String> kWalletFilterLabels = <String>[
  'All',
  'Top-up',
  'Payment',
  'Refund',
];

/// Maps a chip-row label onto the [WalletTransactionType] it filters
/// for. The `All` sentinel returns `null` to signal "no filter".
WalletTransactionType? typeForFilterLabel(String label) {
  switch (label) {
    case 'Top-up':
      return WalletTransactionType.topUp;
    case 'Payment':
      return WalletTransactionType.payment;
    case 'Refund':
      return WalletTransactionType.refund;
    case 'All':
    default:
      return null;
  }
}

/// Pure filter applied locally over already-loaded transactions
/// (Requirement 11.4). Returns a new list preserving the original
/// order.
///
///   * When [filterLabel] is `All` (or any unrecognised label) every
///     row in [all] is returned in input order.
///   * Otherwise rows whose [WalletTransaction.type] matches the
///     filter label's mapped type are returned in input order.
///
/// The input list is not mutated. The screen feeds the chip-row
/// label produced by `SingleSelectController<String>` directly so
/// the filter contract is locked at the predicate level.
List<WalletTransaction> filterTransactions(
  List<WalletTransaction> all,
  String filterLabel,
) {
  final WalletTransactionType? wanted = typeForFilterLabel(filterLabel);
  if (wanted == null) {
    return List<WalletTransaction>.unmodifiable(all);
  }
  return List<WalletTransaction>.unmodifiable(
    all.where((WalletTransaction t) => t.type == wanted),
  );
}

// ===========================================================================
// Currency formatter
// ===========================================================================

/// Cached `intl` formatter for displaying ringgit amounts via
/// `NumberFormat.currency(locale: 'en_MY', symbol: 'RM ')`. Kept at
/// the module level so the formatter is constructed once and reused
/// across rebuilds instead of allocating a new instance per frame
/// (Requirement 11.1).
final NumberFormat walletCurrencyFormatter = NumberFormat.currency(
  locale: 'en_MY',
  symbol: 'RM ',
);

/// Format a signed transaction amount for the trailing column of the
/// transactions tile. Credits are prefixed with `+`, debits with `-`,
/// and the absolute value is rendered through
/// [walletCurrencyFormatter] so locale + symbol stay consistent.
String formatTransactionAmount(double amount) {
  final String prefix = amount >= 0 ? '+' : '-';
  return '$prefix ${walletCurrencyFormatter.format(amount.abs())}';
}

// ===========================================================================
// WalletTransactionTile
// ===========================================================================

/// Single transaction tile rendered by the Transactions tab.
///
/// Renders [transaction] inside an [AppCard] containing:
///
///   * a leading icon whose color is driven by [iconColorForType]
///     (Requirement 11.3);
///   * a description line styled with `AppTypography.title`;
///   * a formatted date line styled with `AppTypography.body`;
///   * a trailing status [AppBadge] driven by [badgeKindForStatus]
///     (Requirement 11.3);
///   * a signed-currency amount line below the badge using
///     [formatTransactionAmount].
class WalletTransactionTile extends StatelessWidget {
  final WalletTransaction transaction;

  const WalletTransactionTile({
    super.key,
    required this.transaction,
  });

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Color iconColor = iconColorForType(transaction.type, colors);
    final IconData icon = iconForType(transaction.type);
    final BadgeKind badgeKind = badgeKindForStatus(transaction.status);
    final String dateText = _formatDate(transaction.date);
    final String amountText = formatTransactionAmount(transaction.amount);
    final Color amountColor =
        transaction.amount >= 0 ? colors.success : colors.error;

    return AppCard(
      child: AppListTile(
        leading: Container(
          width: spacing.xxxxl,
          height: spacing.xxxxl,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: colors.surfaceMedium),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            key: const ValueKey<String>('wallet_transaction_leading_icon'),
            color: iconColor,
            size: typography.title.fontSize,
          ),
        ),
        title: Text(
          transaction.description.isEmpty
              ? 'Transaction'
              : transaction.description,
          key: const ValueKey<String>('wallet_transaction_title'),
          style: typography.title.copyWith(color: colors.foreground),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: dateText.isEmpty
            ? null
            : Text(
                dateText,
                key: const ValueKey<String>('wallet_transaction_date'),
                style: typography.body.copyWith(
                  color: colors.foreground
                      .withValues(alpha: colors.surfaceProminent),
                ),
              ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppBadge(
              key: const ValueKey<String>('wallet_transaction_status_badge'),
              text: labelForStatus(transaction.status),
              kind: badgeKind,
            ),
            SizedBox(height: spacing.xs),
            Text(
              amountText,
              key: const ValueKey<String>('wallet_transaction_amount'),
              style: typography.title.copyWith(color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// OverviewTab
// ===========================================================================

/// Overview-tab body for the redesigned Wallet History screen.
///
/// Summarises the most recent activity above a short list of the
/// latest [transactions]. The tab does not own its own filter chip
/// row — the chip row is part of the Transactions tab per
/// Requirement 11.4 — so changing the filter chip never affects the
/// overview body.
class OverviewTab extends StatelessWidget {
  final double balance;
  final List<WalletTransaction> transactions;

  const OverviewTab({
    super.key,
    required this.balance,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final List<WalletTransaction> recent =
        transactions.take(3).toList(growable: false);

    return ListView(
      key: const ValueKey<String>('wallet_overview_tab'),
      padding: EdgeInsets.all(spacing.lg),
      children: <Widget>[
        Text(
          'Recent activity',
          style: typography.headline.copyWith(color: colors.foreground),
        ),
        SizedBox(height: spacing.md),
        if (recent.isEmpty)
          AppEmptyState(
            key: const ValueKey<String>('wallet_overview_empty_state'),
            icon: Icons.receipt_long_outlined,
            title: 'No activity yet',
            message:
                'Top up your wallet to see your latest transactions here.',
          )
        else
          for (final WalletTransaction t in recent) ...<Widget>[
            WalletTransactionTile(transaction: t),
            SizedBox(height: spacing.md),
          ],
      ],
    );
  }
}

// ===========================================================================
// TransactionsTab
// ===========================================================================

/// Transactions-tab body for the redesigned Wallet History screen.
///
/// Owns its own [SingleSelectController] for the chip row so the
/// filter selection is preserved while the tab is mounted. The tab
/// rebuilds locally when the chip selection changes; the parent
/// screen does not re-fetch (Requirement 11.4).
///
/// When the filtered list is empty, an [AppEmptyState] is rendered
/// while the chip row stays interactive (Requirement 11.7).
class TransactionsTab extends StatefulWidget {
  /// Already-loaded transactions to filter locally. The parent
  /// screen subscribes to `ProfileService.instance` and pipes the
  /// snapshot into this list.
  final List<WalletTransaction> transactions;

  const TransactionsTab({
    super.key,
    required this.transactions,
  });

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  late final SingleSelectController<String> _filterController;

  @override
  void initState() {
    super.initState();
    _filterController = SingleSelectController<String>(
      values: kWalletFilterLabels,
      initial: kWalletFilterLabels.first,
    );
    _filterController.addListener(_onChange);
  }

  @override
  void dispose() {
    _filterController.removeListener(_onChange);
    _filterController.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    final String activeLabel =
        _filterController.selected ?? kWalletFilterLabels.first;
    final List<WalletTransaction> filtered =
        filterTransactions(widget.transactions, activeLabel);

    return Column(
      key: const ValueKey<String>('wallet_transactions_tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            itemCount: kWalletFilterLabels.length,
            separatorBuilder: (BuildContext _, int _) =>
                SizedBox(width: spacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final String label = kWalletFilterLabels[index];
              return AppCategoryChip(
                key: ValueKey<String>('wallet_filter_chip_$label'),
                label: label,
                selected: activeLabel == label,
                onTap: () => _filterController.select(label),
              );
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? AppEmptyState(
                  key: const ValueKey<String>(
                      'wallet_transactions_empty_state'),
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions',
                  message:
                      'No transactions match the "$activeLabel" filter.',
                )
              : ListView.separated(
                  key: const ValueKey<String>('wallet_transactions_list'),
                  padding: EdgeInsets.all(spacing.lg),
                  itemCount: filtered.length,
                  separatorBuilder: (BuildContext _, int _) =>
                      SizedBox(height: spacing.md),
                  itemBuilder: (BuildContext context, int index) {
                    final WalletTransaction t = filtered[index];
                    return WalletTransactionTile(
                      key: ValueKey<String>(
                          'wallet_transaction_tile_${t.date.toIso8601String()}_$index'),
                      transaction: t,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ===========================================================================
// InsightsTab
// ===========================================================================

/// Insights-tab body for the redesigned Wallet History screen.
///
/// Summarises lifetime totals broken down by type so the user can
/// see at a glance how much they have topped up vs spent. Empty
/// input renders an [AppEmptyState] placeholder.
class InsightsTab extends StatelessWidget {
  final List<WalletTransaction> transactions;

  const InsightsTab({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    if (transactions.isEmpty) {
      return AppEmptyState(
        key: const ValueKey<String>('wallet_insights_empty_state'),
        icon: Icons.insights_outlined,
        title: 'No insights yet',
        message:
            'Insights will appear here once you have wallet activity.',
      );
    }

    double totalIn = 0;
    double totalOut = 0;
    int topUpCount = 0;
    int paymentCount = 0;
    int refundCount = 0;
    for (final WalletTransaction t in transactions) {
      if (t.amount >= 0) {
        totalIn += t.amount;
      } else {
        totalOut += t.amount.abs();
      }
      switch (t.type) {
        case WalletTransactionType.topUp:
          topUpCount++;
          break;
        case WalletTransactionType.payment:
          paymentCount++;
          break;
        case WalletTransactionType.refund:
          refundCount++;
          break;
      }
    }

    return ListView(
      key: const ValueKey<String>('wallet_insights_tab'),
      padding: EdgeInsets.all(spacing.lg),
      children: <Widget>[
        Text(
          'Lifetime totals',
          style: typography.headline.copyWith(color: colors.foreground),
        ),
        SizedBox(height: spacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InsightsRow(
                label: 'Money in',
                valueText: walletCurrencyFormatter.format(totalIn),
                valueColor: colors.success,
              ),
              SizedBox(height: spacing.md),
              _InsightsRow(
                label: 'Money out',
                valueText: walletCurrencyFormatter.format(totalOut),
                valueColor: colors.error,
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.lg),
        Text(
          'Counts by type',
          style: typography.headline.copyWith(color: colors.foreground),
        ),
        SizedBox(height: spacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InsightsRow(
                label: 'Top-ups',
                valueText: '$topUpCount',
                valueColor: colors.success,
              ),
              SizedBox(height: spacing.md),
              _InsightsRow(
                label: 'Payments',
                valueText: '$paymentCount',
                valueColor: colors.info,
              ),
              SizedBox(height: spacing.md),
              _InsightsRow(
                label: 'Refunds',
                valueText: '$refundCount',
                valueColor: colors.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightsRow extends StatelessWidget {
  final String label;
  final String valueText;
  final Color valueColor;

  const _InsightsRow({
    required this.label,
    required this.valueText,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: typography.bodyLarge.copyWith(
            color: colors.foreground
                .withValues(alpha: colors.surfaceProminent),
          ),
        ),
        Text(
          valueText,
          style: typography.title.copyWith(color: valueColor),
        ),
      ],
    );
  }
}
