import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/profile_service.dart';
import '../services/toyyibpay_service.dart';
import '../screens/toyyibpay_webview_screen.dart';
import '../services/notification_service.dart';

class WalletTopUpSheet extends StatefulWidget {
  const WalletTopUpSheet({super.key});

  @override
  State<WalletTopUpSheet> createState() => _WalletTopUpSheetState();
}

class _WalletTopUpSheetState extends State<WalletTopUpSheet> {
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _startTopUp() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final payerName = user?.displayName ?? 'DriveCare Driver';
    final payerEmail = user?.email ?? 'driver@drivecareplus.com';
    final payerPhone = ProfileService.instance.phone.replaceAll(RegExp(r'[^\d]'), '');

    // Step 1: Request ToyyibPay to create a checkout bill on Sandbox
    final billCode = await ToyyibPayService.createBill(
      amount: amount,
      payerName: payerName,
      payerEmail: payerEmail,
      payerPhone: payerPhone,
    );

    if (billCode == null) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error creating ToyyibPay bill. Please check your Sandbox Secret Key and Category Code!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Step 2: Open Sandbox checkout URL inside WebView
    final checkoutUrl = 'https://dev.toyyibpay.com/$billCode';
    if (mounted) {
      final result = await Navigator.push<bool?>(
        context,
        MaterialPageRoute(
          builder: (context) => ToyyibPayWebViewScreen(
            checkoutUrl: checkoutUrl,
            returnUrl: ToyyibPayService.returnUrl,
          ),
        ),
      );

      setState(() {
        _isProcessing = false;
      });

      // Step 3: Handle navigation return status and update ledger accordingly
      if (result == true) {
        // Success
        await ProfileService.instance.addWalletTransaction(
          amount, 
          'top_up', 
          'Wallet Top-up via ToyyibPay (Bill: $billCode)'
        );
        try {
          await NotificationService.instance.showMoneyFlowNotification(
            title: 'Wallet Top-up Successful',
            body: 'RM ${amount.toStringAsFixed(2)} successfully added to your wallet.',
          );
        } catch (e) {
          debugPrint('Error triggering top-up notification: $e');
        }
        
        if (mounted) {
          Navigator.pop(context); // Close the bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Top-up successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (result == false) {
        // Failed / Canceled
        await ProfileService.instance.addWalletTransaction(
          amount, 
          'top_up', 
          'Wallet Top-up Failed (Bill: $billCode)',
          status: 'failed',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment failed or canceled.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Pending (status_id = 2)
        await ProfileService.instance.addWalletTransaction(
          amount, 
          'top_up', 
          'Wallet Top-up Pending (Bill: $billCode)',
          status: 'pending',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment is pending processing.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top-up Wallet (ToyyibPay)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter the amount you wish to add to your DriveCare+ Wallet via local FPX bank transfer.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 12),
                child: Text('RM', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAmountBtn('50'),
              _buildQuickAmountBtn('100'),
              _buildQuickAmountBtn('200'),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _isProcessing ? null : _startTopUp,
              child: _isProcessing 
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Text(
                    'Proceed to ToyyibPay FPX',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountBtn(String amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : Colors.black87,
        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        setState(() {
          _amountController.text = amount;
        });
      },
      child: Text('+ RM $amount'),
    );
  }
}
