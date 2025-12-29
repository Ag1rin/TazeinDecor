// Cart and Order Screen
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../models/order_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/persian_number.dart';
import '../../utils/product_unit_display.dart';
import '../../services/product_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../utils/persian_date.dart';
import '../../utils/jalali_date.dart';
import '../../widgets/jalali_date_picker.dart';
import '../../config/app_config.dart';
import '../payment/payment_webview_screen.dart';

class CartOrderScreen extends StatefulWidget {
  const CartOrderScreen({super.key});

  @override
  State<CartOrderScreen> createState() => _CartOrderScreenState();
}

class _CartOrderScreenState extends State<CartOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerMobileController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _notesController = TextEditingController();
  final _installationNotesController = TextEditingController();
  final _referralCodeController = TextEditingController();

  String? _paymentMethod;
  String? _deliveryMethod;
  DateTime? _installationDate;
  final TextEditingController _installationDateController =
      TextEditingController();
  bool _isSubmitting = false;

  final OrderService _orderService = OrderService();
  final ProductService _productService = ProductService();
  final Map<int, Map<String, dynamic>> _productDetailsCache = {};
  final Map<int, bool> _loadingProductDetails = {};

  @override
  void initState() {
    super.initState();
    // Set default installation date to today
    _setDefaultInstallationDate();
    // Load product details for cart items
    _loadCartProductDetails();
  }

  Future<void> _loadCartProductDetails() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    for (final item in cartProvider.items) {
      if (!_productDetailsCache.containsKey(item.product.id) &&
          _loadingProductDetails[item.product.id] != true) {
        _loadingProductDetails[item.product.id] = true;
        try {
          final data = await _productService.getProductFromSecureAPI(
            item.product.wooId,
          );
          if (mounted && data != null) {
            setState(() {
              _productDetailsCache[item.product.id] = data;
              _loadingProductDetails[item.product.id] = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _loadingProductDetails[item.product.id] = false;
            });
          }
        }
      }
    }
  }

  void _setDefaultInstallationDate() {
    final today = JalaliDate.now();
    _installationDate = today.toDateTime();
    _installationDateController.text = today.formatPersian();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _customerAddressController.dispose();
    _notesController.dispose();
    _installationNotesController.dispose();
    _installationDateController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _selectInstallationDate() async {
    final now = JalaliDate.now();

    // Determine initial date for picker
    JalaliDate initialDate;
    if (_installationDate != null) {
      initialDate = JalaliDate.fromDateTime(_installationDate!);
    } else {
      initialDate = now;
    }

    try {
      final result = await showJalaliDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: now, // Can't select past dates
        lastDate: now.addMonths(12), // Up to 1 year in the future
        helpText: 'انتخاب تاریخ نصب',
        confirmText: 'تایید',
        cancelText: 'لغو',
      );

      if (result != null && mounted) {
        setState(() {
          _installationDate = result.toDateTime();
          _installationDateController.text = result.formatPersian();
        });
      }
    } catch (e) {
      debugPrint('Error showing date picker: $e');
      // If picker fails, show a toast
      if (mounted) {
        Fluttertoast.showToast(msg: 'خطا در نمایش تقویم');
      }
    }
  }

  void _clearInstallationDate() {
    setState(() {
      _installationDate = null;
      _installationDateController.clear();
    });
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paymentMethod == null || _deliveryMethod == null) {
      Fluttertoast.showToast(msg: 'لطفا روش پرداخت و تحویل را انتخاب کنید');
      return;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isEmpty) {
      Fluttertoast.showToast(msg: 'سبد خرید خالی است');
      return;
    }

    // Check if all products have cooperation price (colleaguePrice)
    // First, try to get price from cache if product doesn't have colleaguePrice
    final itemsWithoutPrice = cartProvider.items.where((item) {
      // First check if product has colleaguePrice
      if (item.product.displayPrice != null && item.product.displayPrice! > 0) {
        return false;
      }
      
      // If not, check cache
      final cachedData = _productDetailsCache[item.product.id];
      if (cachedData != null) {
        final colleaguePrice = cachedData['colleague_price'];
        if (colleaguePrice != null) {
          final price = colleaguePrice is num ? colleaguePrice.toDouble() : 
                       (colleaguePrice is String ? double.tryParse(colleaguePrice) : null);
          if (price != null && price > 0) {
            return false; // Price found in cache
          }
        }
      }
      
      // No price found
      return true;
    }).toList();
    
    if (itemsWithoutPrice.isNotEmpty) {
      // Try to load missing prices before showing error
      bool allLoaded = true;
      for (final item in itemsWithoutPrice) {
        if (!_productDetailsCache.containsKey(item.product.id) &&
            _loadingProductDetails[item.product.id] != true) {
          allLoaded = false;
          break;
        }
      }
      
      if (!allLoaded) {
        // Still loading, wait a bit and show message
        Fluttertoast.showToast(
          msg: 'در حال دریافت قیمت‌های همکاری... لطفا چند لحظه صبر کنید.',
          toastLength: Toast.LENGTH_LONG,
        );
        // Wait for prices to load
        await Future.delayed(const Duration(seconds: 2));
        // Retry check
        final retryItemsWithoutPrice = cartProvider.items.where((item) {
          if (item.product.displayPrice != null && item.product.displayPrice! > 0) {
            return false;
          }
          final cachedData = _productDetailsCache[item.product.id];
          if (cachedData != null) {
            final colleaguePrice = cachedData['colleague_price'];
            if (colleaguePrice != null) {
              final price = colleaguePrice is num ? colleaguePrice.toDouble() : 
                           (colleaguePrice is String ? double.tryParse(colleaguePrice) : null);
              if (price != null && price > 0) {
                return false;
              }
            }
          }
          return true;
        }).toList();
        
        if (retryItemsWithoutPrice.isNotEmpty) {
          Fluttertoast.showToast(
            msg: 'برخی محصولات قیمت همکاری ندارند. لطفا صفحه را رفرش کنید و دوباره تلاش کنید.',
            toastLength: Toast.LENGTH_LONG,
          );
          return;
        }
      } else {
        Fluttertoast.showToast(
          msg: 'برخی محصولات قیمت همکاری ندارند. لطفا صفحه را رفرش کنید و دوباره تلاش کنید.',
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final orderData = {
        'customer_name': _customerNameController.text.trim(),
        'customer_mobile': _customerMobileController.text.trim(),
        'customer_address': _customerAddressController.text.trim(),
        'payment_method': _paymentMethod,
        'delivery_method': _deliveryMethod,
        'installation_date': _installationDate?.toIso8601String(),
        'installation_notes': _installationNotesController.text.trim(),
        'notes': _notesController.text.trim(),
        'referral_code': _referralCodeController.text.trim().isNotEmpty
            ? _referralCodeController.text.trim().toUpperCase()
            : null,
        'items': cartProvider.items.map((item) {
          // Ensure we always send a valid cooperation price
          // First try product.displayPrice, then check cache
          double? price = item.product.displayPrice;
          
          if (price == null || price <= 0) {
            // Try to get from cache
            final cachedData = _productDetailsCache[item.product.id];
            if (cachedData != null) {
              final colleaguePrice = cachedData['colleague_price'];
              if (colleaguePrice != null) {
                price = colleaguePrice is num ? colleaguePrice.toDouble() : 
                       (colleaguePrice is String ? double.tryParse(colleaguePrice) : null);
              }
            }
          }
          
          if (price == null || price <= 0) {
            throw Exception('قیمت همکاری برای محصول ${item.product.name} یافت نشد');
          }
          
          return {
            // Use local DB product id (not WooCommerce id)
            'product_id': item.localProductId,
            'quantity': item.quantity,
            'unit': item.unit,
            'price': price, // Always send valid cooperation price
            'variation_id': item.variationId,
            'variation_pattern': item.variationPattern,
          };
        }).toList(),
      };

      // Check if online payment is selected
      if (_paymentMethod == 'online') {
        // Create pending order in WooCommerce (not in local DB yet)
        final pendingOrderData = await _orderService.createPendingOrderForPayment(orderData);

        if (!mounted) return;

        if (pendingOrderData != null) {
          await _processOnlinePayment(pendingOrderData, orderData);
        } else {
          Fluttertoast.showToast(msg: 'خطا در ثبت سفارش');
        }
      } else {
        // Regular order creation
        final order = await _orderService.createOrder(orderData);

        if (!mounted) return;

        if (order != null) {
          cartProvider.clearCart();
          
          // Update credit in real-time if payment was with credit
          if (_paymentMethod == 'credit') {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            // Refresh user data from backend to get updated credit
            await authProvider.refreshUser();
          }
          
          Fluttertoast.showToast(
            msg: 'سفارش با موفقیت ثبت شد',
            toastLength: Toast.LENGTH_LONG,
          );
          Navigator.of(context).pop();
        } else {
          Fluttertoast.showToast(msg: 'خطا در ثبت سفارش');
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'خطا: ${e.toString()}');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// Process online payment via WebView
  Future<void> _processOnlinePayment(
    Map<String, dynamic> pendingOrder,
    Map<String, dynamic> originalOrderData,
  ) async {
    // Get the WooCommerce order ID from the response
    final wooOrderId = pendingOrder['woo_order_id'];
    final orderKey = pendingOrder['order_key'] ?? '';
    final customerId = pendingOrder['customer_id'];
    final totalAmount = pendingOrder['total_amount'] ?? 0.0;
    final wholesaleAmount = pendingOrder['wholesale_amount'] ?? 0.0;

    if (wooOrderId == null) {
      Fluttertoast.showToast(msg: 'خطا در دریافت شناسه سفارش');
      return;
    }

    // Build the checkout URL
    // WooCommerce checkout URL format: /checkout/order-pay/{order_id}/?pay_for_order=true&key=wc_order_xxx
    String checkoutUrl;
    if (orderKey.isNotEmpty) {
      checkoutUrl =
          '${AppConfig.wooCommerceUrl}/checkout/order-pay/$wooOrderId/?pay_for_order=true&key=$orderKey';
    } else {
      checkoutUrl =
          '${AppConfig.wooCommerceUrl}/checkout/order-pay/$wooOrderId/?pay_for_order=true';
    }

    print('🔗 Opening payment URL: $checkoutUrl');

    // Navigate to payment WebView
    final result = await Navigator.of(context).push<PaymentResultData>(
      MaterialPageRoute(
        builder: (context) =>
            PaymentWebViewScreen(checkoutUrl: checkoutUrl, orderId: wooOrderId),
      ),
    );

    if (!mounted) return;

    // Handle payment result
    if (result != null) {
      switch (result.result) {
        case PaymentResult.success:
          // Payment successful - verify and register order
          await _handlePaymentSuccess(
            wooOrderId,
            originalOrderData,
            customerId,
            totalAmount,
            wholesaleAmount,
            result,
          );
          break;
        case PaymentResult.failed:
          // Payment failed - cancel pending order
          await _handlePaymentFailed(wooOrderId, result);
          break;
        case PaymentResult.cancelled:
          // Payment cancelled by user - cancel pending order
          await _handlePaymentCancelled(wooOrderId);
          break;
      }
    } else {
      // User closed without completing payment - cancel pending order
      await _handlePaymentCancelled(wooOrderId);
    }
  }

  /// Handle successful payment - verify and register order
  Future<void> _handlePaymentSuccess(
    int wooOrderId,
    Map<String, dynamic> originalOrderData,
    int customerId,
    double totalAmount,
    double wholesaleAmount,
    PaymentResultData result,
  ) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Verify payment and register order
      final order = await _orderService.verifyPaymentAndRegisterOrder(
        wooOrderId,
        originalOrderData,
        customerId,
        totalAmount,
        wholesaleAmount,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (order != null) {
        // Order successfully registered
        cartProvider.clearCart();
        
        // Update credit in real-time if payment was with credit
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        // Check if original order was credit payment
        final originalPaymentMethod = originalOrderData['payment_method'];
        if (originalPaymentMethod == 'credit') {
          // Refresh user data from backend to get updated credit
          await authProvider.refreshUser();
        }
        
        _showPaymentSuccessDialog(result, order);
      } else {
        // Verification failed
        Fluttertoast.showToast(
          msg: 'خطا در تایید پرداخت. لطفا با پشتیبانی تماس بگیرید.',
          toastLength: Toast.LENGTH_LONG,
        );
        Navigator.of(context).pop(); // Go back to cart
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      Fluttertoast.showToast(
        msg: 'خطا در تایید پرداخت: ${e.toString()}',
        toastLength: Toast.LENGTH_LONG,
      );
      Navigator.of(context).pop(); // Go back to cart
    }
  }

  /// Handle failed payment - cancel pending order
  Future<void> _handlePaymentFailed(
    int wooOrderId,
    PaymentResultData result,
  ) async {
    try {
      // Cancel pending order in WooCommerce
      await _orderService.cancelPendingOrder(wooOrderId);
    } catch (e) {
      print('⚠️ Error cancelling pending order: $e');
    }

    if (!mounted) return;
    _showPaymentFailedDialog(result);
  }

  /// Handle cancelled payment - cancel pending order
  Future<void> _handlePaymentCancelled(int wooOrderId) async {
    try {
      // Cancel pending order in WooCommerce
      await _orderService.cancelPendingOrder(wooOrderId);
    } catch (e) {
      print('⚠️ Error cancelling pending order: $e');
    }

    if (!mounted) return;
    
    Fluttertoast.showToast(
      msg: 'پرداخت لغو شد. سفارش ثبت نشد.',
      toastLength: Toast.LENGTH_LONG,
    );
    Navigator.of(context).pop(); // Go back to cart
  }

  void _showPaymentSuccessDialog(PaymentResultData result, [OrderModel? order]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'پرداخت موفق',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                result.message ?? 'پرداخت شما با موفقیت انجام شد',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              if (order != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'شماره سفارش: ${order.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ] else if (result.orderId != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'شماره سفارش: ${result.orderId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Close cart screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'بازگشت به صفحه اصلی',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentFailedDialog(PaymentResultData result) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[600],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'پرداخت ناموفق',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                result.message ??
                    'پرداخت با مشکل مواجه شد. لطفاً مجدداً تلاش کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pop(); // Close cart screen
                      },
                      child: const Text('بازگشت'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        _submitOrder(); // Retry
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('تلاش مجدد'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سبد خرید و ثبت سفارش')),
        body: Consumer<CartProvider>(
          builder: (context, cartProvider, _) {
            if (cartProvider.items.isEmpty) {
              return const Center(child: Text('سبد خرید خالی است'));
            }

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cart items
                    const Text(
                      'آیتم‌های سبد خرید',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...cartProvider.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildCartItem(index, item, cartProvider);
                    }),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Total Payable Amount - Prominently displayed
                    if (cartProvider.items.any(
                      (item) => item.product.colleaguePrice != null,
                    ))
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, _) {
                          final user = authProvider.user;
                          // Calculate total with discounts applied (same calculation as backend)
                          final total = cartProvider.items.fold<double>(
                            0.0,
                            (sum, item) {
                              final basePrice = item.product.displayPrice ?? 0.0;
                              // Apply discount if user has discount percentage
                              double finalPrice = basePrice;
                              if (user?.discountPercentage != null && user!.discountPercentage! > 0) {
                                final discountAmount = basePrice * (user.discountPercentage! / 100.0);
                                finalPrice = basePrice - discountAmount;
                              }
                              return sum + (finalPrice * item.quantity);
                            },
                          );
                          
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryBlue,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      color: AppColors.primaryBlue,
                                      size: 28,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'مبلغ قابل پرداخت:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${PersianNumber.formatPrice(total)} تومان',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                    if (user?.discountPercentage != null && user!.discountPercentage! > 0) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${user.discountPercentage!.toStringAsFixed(0)}% تخفیف اعمال شده',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 24),
                    // Customer info
                    const Text(
                      'اطلاعات مشتری',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'نام و نام خانوادگی',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'لطفا نام را وارد کنید';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerMobileController,
                      decoration: const InputDecoration(
                        labelText: 'شماره تماس',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'لطفا شماره تماس را وارد کنید';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerAddressController,
                      decoration: const InputDecoration(
                        labelText: 'آدرس',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    // Delivery method - Horizontal layout
                    const Text(
                      'روش تحویل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMethodCard(
                            title: 'حضوری',
                            value: 'in_person',
                            groupValue: _deliveryMethod,
                            icon: Icons.store,
                            onTap: () {
                              setState(() {
                                _deliveryMethod = 'in_person';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMethodCard(
                            title: 'به آدرس مشتری',
                            value: 'to_customer',
                            groupValue: _deliveryMethod,
                            icon: Icons.home,
                            onTap: () {
                              setState(() {
                                _deliveryMethod = 'to_customer';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMethodCard(
                            title: 'به فروشگاه',
                            value: 'to_store',
                            groupValue: _deliveryMethod,
                            icon: Icons.shop,
                            onTap: () {
                              setState(() {
                                _deliveryMethod = 'to_store';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Payment method - Horizontal layout
                    const Text(
                      'روش پرداخت',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMethodCard(
                            title: 'پرداخت آنلاین',
                            value: 'online',
                            groupValue: _paymentMethod,
                            icon: Icons.payment,
                            onTap: () {
                              setState(() {
                                _paymentMethod = 'online';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              final user = authProvider.user;
                              // Show credit option for sellers and store managers
                              final isSellerOrStoreManager = user?.isSeller == true || user?.isStoreManager == true;
                              final creditBalance = user?.credit ?? 0.0;
                              final cartProvider = Provider.of<CartProvider>(
                                context,
                                listen: false,
                              );
                              // Calculate total with discounts applied (cooperation price after discount)
                              final total = cartProvider.items.fold<double>(
                                0.0,
                                (sum, item) {
                                  final basePrice = item.product.displayPrice ?? 0.0;
                                  // Apply discount if user has discount percentage
                                  double finalPrice = basePrice;
                                  if (user?.discountPercentage != null && user!.discountPercentage! > 0) {
                                    final discountAmount = basePrice * (user.discountPercentage! / 100.0);
                                    finalPrice = basePrice - discountAmount;
                                  }
                                  return sum + (finalPrice * item.quantity);
                                },
                              );
                              final hasEnoughCredit = creditBalance >= total;

                              // Only show credit option for sellers and store managers
                              if (!isSellerOrStoreManager) {
                                return const SizedBox.shrink();
                              }

                              return _buildMethodCard(
                                title: 'پرداخت اعتباری',
                                subtitle: hasEnoughCredit
                                    ? 'موجودی: ${PersianNumber.formatPrice(creditBalance)}'
                                    : 'اعتبار کافی نیست',
                                value: 'credit',
                                groupValue: _paymentMethod,
                                icon: Icons.credit_card,
                                isDisabled: !hasEnoughCredit,
                                onTap: hasEnoughCredit
                                    ? () {
                                        setState(() {
                                          _paymentMethod = 'credit';
                                        });
                                      }
                                    : () {
                                        Fluttertoast.showToast(
                                          msg: 'اعتبار کافی نیست',
                                          toastLength: Toast.LENGTH_SHORT,
                                        );
                                      },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMethodCard(
                            title: 'ارسال فاکتور',
                            value: 'invoice',
                            groupValue: _paymentMethod,
                            icon: Icons.receipt,
                            onTap: () {
                              setState(() {
                                _paymentMethod = 'invoice';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Installation date
                    const Text(
                      'تاریخ نصب',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _installationDateController,
                      readOnly: true,
                      onTap: _selectInstallationDate,
                      decoration: InputDecoration(
                        labelText: 'تاریخ نصب',
                        hintText: 'برای انتخاب تاریخ کلیک کنید',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: _installationDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearInstallationDate,
                              )
                            : null,
                      ),
                    ),
                    if (_installationDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'تاریخ انتخاب شده: ${PersianDate.formatDate(_installationDate!)}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _installationNotesController,
                      decoration: const InputDecoration(
                        labelText: 'یادداشت نصب',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'یادداشت (اختیاری)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    // Referral code field
                    TextFormField(
                      controller: _referralCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'کد معرف (اختیاری)',
                        hintText: 'کد معرف را وارد کنید',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.card_giftcard),
                        helperText:
                            'کد معرف را از فروشنده یا مدیر فروشگاه دریافت کنید',
                        helperStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'ثبت سفارش',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required String title,
    String? subtitle,
    required String value,
    required String? groupValue,
    required IconData icon,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    final isSelected = groupValue == value;
    return InkWell(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryBlue.withValues(alpha: 0.1)
                : Colors.grey[100],
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryBlue
                  : (isDisabled ? Colors.grey[300]! : Colors.grey[300]!),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primaryBlue
                    : (isDisabled ? Colors.grey[400]! : Colors.grey[600]),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : (isDisabled ? Colors.grey[500] : Colors.grey[800]),
                  fontSize: 12,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primaryBlue.withValues(alpha: 0.8)
                        : Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(int index, CartItem item, CartProvider cartProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image - use variation image if available, otherwise product image
            (item.variationImage != null && item.variationImage!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: item.variationImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        item.product.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: item.product.imageUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image),
                          ),
                  )
                : item.product.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.product.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image),
                  ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.variationPattern != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'طرح انتخاب‌شده: ${item.variationPattern}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  // Only show cooperation price (colleaguePrice) if it exists
                  // If no cooperation price, hide price completely
                  if (item.product.colleaguePrice != null) ...[
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final user = Provider.of<AuthProvider>(context, listen: false).user;
                        final basePrice = item.product.colleaguePrice!;
                        double finalPrice = basePrice;
                        String? discountText;
                        
                        // Apply discount if user has discount percentage
                        if (user?.discountPercentage != null && user!.discountPercentage! > 0) {
                          final discountAmount = basePrice * (user.discountPercentage! / 100.0);
                          finalPrice = basePrice - discountAmount;
                          discountText = '(${user.discountPercentage!.toStringAsFixed(0)}% تخفیف)';
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'قیمت همکاری: ${PersianNumber.formatPrice(finalPrice)} تومان',
                              style: const TextStyle(color: AppColors.primaryBlue),
                            ),
                            if (discountText != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                discountText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Quantity display with area coverage
                  Builder(
                    builder: (context) {
                      final productDetails =
                          _productDetailsCache[item.product.id];

                      // Get calculator data from secure API response
                      final calculator =
                          productDetails?['calculator']
                              as Map<String, dynamic>?;
                      final apiUnit = ProductUnitDisplay.getUnitFromCalculator(calculator);

                      final coverageStr = ProductUnitDisplay.formatCoverage(
                        quantity: item.quantity,
                        apiUnit: apiUnit,
                        calculator: calculator,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quantity controls - Unit row
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  if (item.quantity > 1) {
                                    cartProvider.updateQuantity(
                                      index,
                                      item.quantity - 1,
                                    );
                                  } else {
                                    cartProvider.removeFromCart(index);
                                  }
                                },
                              ),
                              Flexible(
                                child: Text(
                                  ProductUnitDisplay.formatQuantityWithUnit(
                                    quantity: item.quantity,
                                    apiUnit: apiUnit,
                                  ),
                                  style: const TextStyle(fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  cartProvider.updateQuantity(
                                    index,
                                    item.quantity + 1,
                                  );
                                },
                              ),
                            ],
                          ),
                          // Coverage row (متراژ) - only show if available
                          if (coverageStr != null && coverageStr.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 48.0),
                              child: Text(
                                coverageStr,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            // Remove button
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                cartProvider.removeFromCart(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}
