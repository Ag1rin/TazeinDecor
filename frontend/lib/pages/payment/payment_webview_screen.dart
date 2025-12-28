// Payment WebView Screen - Opens WooCommerce checkout for ZarinPal payment
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:webview_flutter/webview_flutter.dart';
import '../../utils/app_colors.dart';

/// Result of the payment process
enum PaymentResult { success, failed, cancelled }

/// Payment result with optional order details
class PaymentResultData {
  final PaymentResult result;
  final String? orderId;
  final String? message;

  PaymentResultData({required this.result, this.orderId, this.message});
}

class PaymentWebViewScreen extends StatefulWidget {
  /// The checkout URL to load
  final String checkoutUrl;

  /// Success URL pattern to detect successful payment
  final String successUrlPattern;

  /// Failure/Cancel URL pattern to detect failed payment
  final String failureUrlPattern;

  /// Order ID (WooCommerce order ID)
  final int? orderId;

  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    this.successUrlPattern = '/checkout/order-received/',
    this.failureUrlPattern = '/checkout/order-pay/',
    this.orderId,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            _checkPaymentStatus(url);
          },
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _checkPaymentStatus(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: ${error.description}');
            if (!_paymentCompleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطا در بارگذاری صفحه: ${error.description}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _checkPaymentStatus(String url) {
    if (_paymentCompleted) return;

    // Check for success URL pattern
    // WooCommerce success URL pattern: /checkout/order-received/{order_id}/?key=wc_order_xxx
    if (url.contains(widget.successUrlPattern) ||
        url.contains('order-received') ||
        url.contains('wc-api/WC_Gateway') && url.contains('success')) {
      _paymentCompleted = true;
      _handlePaymentSuccess(url);
      return;
    }

    // Check for failure/cancel patterns
    // ZarinPal typically redirects back to checkout on failure
    if (url.contains('cancel') ||
        url.contains('failed') ||
        (url.contains('checkout') &&
            url.contains('order-pay') &&
            url.contains('pay_for_order=true'))) {
      // This might be a retry or cancel - don't auto-close, let user try again
      print('⚠️ Payment might have failed or cancelled: $url');
    }
  }

  void _handlePaymentSuccess(String url) {
    // Extract order ID from URL if possible
    String? orderId;
    final orderReceivedMatch = RegExp(r'order-received/(\d+)').firstMatch(url);
    if (orderReceivedMatch != null) {
      orderId = orderReceivedMatch.group(1);
    }

    // Show success and close
    if (mounted) {
      Navigator.of(context).pop(
        PaymentResultData(
          result: PaymentResult.success,
          orderId: orderId ?? widget.orderId?.toString(),
          message: 'پرداخت با موفقیت انجام شد',
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_paymentCompleted) return true;

    // Ask user to confirm exit
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('خروج از پرداخت'),
            ],
          ),
          content: const Text(
            'آیا مطمئن هستید که می‌خواهید از صفحه پرداخت خارج شوید؟\n\nپرداخت شما ناتمام خواهد ماند.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ادامه پرداخت'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );

    if (shouldExit == true && mounted) {
      Navigator.of(context).pop(
        PaymentResultData(
          result: PaymentResult.cancelled,
          message: 'پرداخت لغو شد',
        ),
      );
    }

    return false; // We handle the pop ourselves
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('پرداخت آنلاین'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _onWillPop,
              tooltip: 'انصراف از پرداخت',
            ),
            actions: [
              // Reload button
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _controller.reload();
                },
                tooltip: 'بارگذاری مجدد',
              ),
            ],
            bottom: _isLoading
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(4),
                    child: LinearProgressIndicator(
                      value: _loadingProgress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBlue,
                      ),
                    ),
                  )
                : null,
          ),
          body: Stack(
            children: [
              // WebView
              WebViewWidget(controller: _controller),

              // Loading overlay for initial load
              if (_isLoading && _loadingProgress < 0.3)
                Container(
                  color: Colors.white,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'در حال بارگذاری صفحه پرداخت...',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'لطفاً صبر کنید',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // Bottom info bar
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, size: 18, color: Colors.green[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'پرداخت امن از طریق درگاه',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                // Security badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user,
                        size: 14,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'SSL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
