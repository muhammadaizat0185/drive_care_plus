import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import 'package:intl/intl.dart';

class WalletHistoryScreen extends StatelessWidget {
  const WalletHistoryScreen({super.key});

  static const routeName = '/wallet-history';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Transactions'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF022C22)]
                : [const Color(0xFFEFFDF5), const Color(0xFFF9FAFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: ProfileService.instance,
            builder: (context, child) {
              final profile = ProfileService.instance;
              final txns = profile.transactions;

              return Column(
                children: [
                  // Elegant Balance Banner
                  Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RM ${profile.walletBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 40,
                          color: primaryColor.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),

                  // History List Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transaction History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${txns.length} records',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // History List
                  Expanded(
                    child: txns.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No transactions recorded yet.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            itemCount: txns.length,
                            itemBuilder: (context, index) {
                              final txn = txns[index];
                              final double amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
                              final String type = txn['type'] ?? 'top_up';
                              final String desc = txn['description'] ?? '';
                              final String dateStr = txn['date'] ?? '';

                              final isTopUp = type == 'top_up';
                              final displayAmount = isTopUp ? '+ RM ${amount.toStringAsFixed(2)}' : '- RM ${amount.toStringAsFixed(2)}';
                              final amountColor = isTopUp ? const Color(0xFF10B981) : Colors.redAccent;
                              final iconBgColor = isTopUp ? const Color(0xFF10B981).withOpacity(0.1) : Colors.redAccent.withOpacity(0.1);
                              final iconColor = isTopUp ? const Color(0xFF10B981) : Colors.redAccent;

                              String formattedDate = '';
                              try {
                                final parsedDate = DateTime.parse(dateStr);
                                formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(parsedDate);
                              } catch (_) {
                                formattedDate = dateStr;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isTopUp ? Icons.add_card_outlined : Icons.payments_outlined,
                                        color: iconColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            desc,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formattedDate,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      displayAmount,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: amountColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
