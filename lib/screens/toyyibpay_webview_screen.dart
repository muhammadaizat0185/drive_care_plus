import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
              final status = uri.queryParameters['status_id'] ?? uri.queryParameters['status'];
              
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'ToyyibPay FPX Payment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Confirm exit before canceling payment
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Payment?'),
                content: const Text('Are you sure you want to exit and cancel this top-up transaction?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('No, Continue'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context, false); // Return failure/canceled
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Yes, Cancel'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          // WebView Widget
          WebViewWidget(controller: _controller),
          
          // Premium loading bar indicator
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadingProgress > 0 ? _loadingProgress : null,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
                minHeight: 4,
              ),
            ),
        ],
      ),
    );
  }
}
