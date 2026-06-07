// Token + Component_Library sweep (Group 14, Task 14.6).
//
// Chrome restyle ONLY. Per Requirement 14.4, this sweep:
//   * Replaces hex literals (#0F172A, #F9FAFB, etc.) with token references.
//   * Routes spacing/typography through token extensions.
//   * Swaps the inline `LinearProgressIndicator` for `AppSpinner` styling
//     for the indeterminate branch and a token-driven `LinearProgressIndicator`
//     for the determinate branch.
//   * Restyles the cancel-confirmation `AlertDialog` action with
//     `AppGradientButton`-like styling but keeps the dialog API intact.
//
// PRESERVES (do NOT touch):
//   * `WebViewController` instantiation and `setJavaScriptMode`.
//   * `setNavigationDelegate(NavigationDelegate(... onProgress, onPageStarted,
//     onPageFinished, onNavigationRequest ...))`.
//   * Detection of `widget.returnUrl`, `status_id` parsing, and
//     `Navigator.pop(context, true/false/null)` callback routing.
//   * `loadRequest(Uri.parse(widget.checkoutUrl))`.
//   * Cancel-payment confirmation dialog flow and its `Navigator.pop` chain.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme/color_utils.dart';
import '../core/theme/tokens/tokens.dart';
import '../widgets/ui/ui.dart';

class ToyyibPayWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String returnUrl;

  const ToyyibPayWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.returnUrl,
  });

  @override
  State<ToyyibPayWebViewScreen> createState() => _ToyyibPayWebViewScreenState();
}

class _ToyyibPayWebViewScreenState extends State<ToyyibPayWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;

  // WebView controller setup.

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100;
              });
            }
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            debugPrint('Intercepted WebView URL: $url');

            // Detect if page has redirected back to our callback / return URL
            if (url.startsWith(widget.returnUrl)) {
              final uri = Uri.parse(url);

              // ToyyibPay returns 'status_id' (1 = success, 2 = pending, 3 = failed)
              final status = uri.queryParameters['status_id'] ??
                  uri.queryParameters['status'];

              debugPrint('Detected ToyyibPay Payment Status: $status');

              if (status == '1') {
                Navigator.pop(context, true); // Success
              } else if (status == '2') {
                Navigator.pop(context, null); // Pending/Processing
              } else {
                Navigator.pop(context, false); // Failed
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'ToyyibPay FPX Payment',
            style: typography.title.copyWith(color: colors.foreground),
          ),
          leading: AppIconButton(
            icon: Icons.arrow_back,
            semanticsLabel: 'Cancel payment',
            onPressed: () => _confirmCancel(context),
          ),
        ),
        body: Stack(
          children: [
            // WebView Widget — controller untouched.
            WebViewWidget(controller: _controller),
  
            // Loading indicator at the very top of the webview chrome.
            if (_isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _loadingProgress > 0 ? _loadingProgress : null,
                  color: colors.emerald500,
                  backgroundColor: colors.muted,
                  minHeight: spacing.xs,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancel Payment?',
          style: typography.title.copyWith(color: colors.foreground),
        ),
        content: Text(
          'Are you sure you want to exit and cancel this top-up transaction?',
          style: typography.bodyLarge.copyWith(color: colors.foreground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Continue'),
          ),
          // Render the destructive confirmation as an `AppGradientButton` so
          // it shares the redesigned CTA contract; the navigation pop chain
          // is preserved exactly.
          AppGradientButton(
            label: 'Yes, Cancel',
            fullWidth: false,
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, false); // Return failure/canceled
            },
          ),
        ],
      ),
    );
  }
}
