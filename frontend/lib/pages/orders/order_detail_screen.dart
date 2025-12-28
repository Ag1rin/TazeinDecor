// Order Detail Screen
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../models/order_model.dart';
import '../../utils/persian_number.dart';
import '../../utils/persian_date.dart';
import '../../utils/app_colors.dart';
import '../../utils/product_unit_display_helper.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../pages/returns/return_request_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  final ProductService _productService = ProductService();
  // ignore: unused_field
  bool _isReturning = false;
  // Cache for product details (colleague_price)
  final Map<int, Map<String, dynamic>> _productDetailsCache = {};

  @override
  void initState() {
    super.initState();
    // Load product details (colleague_price) for all items
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    for (final item in widget.order.items) {
      if (!_productDetailsCache.containsKey(item.productId)) {
        final details = await _productService.getProductFromSecureAPI(item.productId);
        if (details != null && mounted) {
          setState(() {
            _productDetailsCache[item.productId] = details;
          });
        }
      }
    }
  }

  double? _getColleaguePrice(int productId) {
    final productDetails = _productDetailsCache[productId];
    if (productDetails?['colleague_price'] != null) {
      final value = productDetails!['colleague_price'];
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value);
      }
    }
    return null;
  }

  // ignore: unused_element
  Future<void> _returnOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مرجوعی سفارش'),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید این سفارش را مرجوع کنید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('بله، مرجوع کن'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isReturning = true;
      });

      final success = await _orderService.returnOrder(widget.order.id);

      if (mounted) {
        setState(() {
          _isReturning = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('سفارش با موفقیت مرجوع شد')),
          );
          Navigator.pop(context, true); // Return true to refresh orders list
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('خطا در مرجوعی سفارش')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('جزئیات سفارش')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شماره سفارش: ${widget.order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تاریخ: ${PersianDate.formatDateTime(widget.order.createdAt)}',
                      ),
                      if (widget.order.installationDate != null)
                        Text(
                          'تاریخ نصب: ${PersianDate.formatDate(widget.order.installationDate!)}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Items
              const Text(
                'آیتم‌های سفارش',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...widget.order.items.map((item) {
                return _buildOrderItem(item);
              }),
              const SizedBox(height: 16),
              // Total
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'جمع کل:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${PersianNumber.formatPrice(widget.order.totalAmount)} تومان',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Return request button (only if not already returned/cancelled)
              if (widget.order.status != 'returned' &&
                  widget.order.status != 'cancelled')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ReturnRequestScreen(order: widget.order),
                        ),
                      );
                      if (result == true && mounted) {
                        Navigator.pop(context, true); // Refresh order list
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.assignment_return),
                    label: const Text(
                      'درخواست مرجوعی',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItemModel item) {
    // Get product image URL - try variation image first, then product image
    String? imageUrl;
    if (item.variationId != null && item.product != null) {
      // Try to get variation image from product
      imageUrl = item.product!.imageUrl;
    } else if (item.product != null) {
      imageUrl = item.product!.imageUrl;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_not_supported),
              ),
            const SizedBox(width: 12),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product?.name ?? 'محصول',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      // Get product details from cache
                      final productDetails = _productDetailsCache[item.productId];
                      
                      // Get unit directly from secure API response
                      final unit = ProductUnitDisplayHelper.getUnitFromAPI(productDetails);
                      
                      return Text(
                        ProductUnitDisplayHelper.formatQuantityWithCoverage(
                          quantity: item.quantity,
                          unit: unit,
                          productDetails: productDetails,
                        ),
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      );
                    },
                  ),
                  if (item.variationPattern != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'کد طرح: ${item.variationPattern}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      // Get colleague_price from secure API
                      final colleaguePrice = _getColleaguePrice(item.productId);
                      final quantity = item.quantity;
                      final lineTotal = colleaguePrice != null
                          ? quantity * colleaguePrice
                          : null;
                      
                      if (lineTotal != null) {
                        return Text(
                          '${PersianNumber.formatPrice(lineTotal)} تومان',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        );
                      } else {
                        return const Text(
                          'قیمت در دسترس نیست',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
