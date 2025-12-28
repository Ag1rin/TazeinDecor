// Return Request Screen - Select items to return
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../models/order_model.dart';
import '../../services/return_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/persian_number.dart';
import '../../utils/persian_date.dart';
import '../../utils/product_unit_display_helper.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReturnRequestScreen extends StatefulWidget {
  final OrderModel order;

  const ReturnRequestScreen({super.key, required this.order});

  @override
  State<ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends State<ReturnRequestScreen> {
  final ReturnService _returnService = ReturnService();
  final OrderService _orderService = OrderService();
  final ProductService _productService = ProductService();
  final TextEditingController _reasonController = TextEditingController();
  final Map<int, double> _selectedItems =
      {}; // order_item_id -> quantity to return
  bool _isSubmitting = false;
  OrderModel? _fullOrder;
  // Cache for product details: productId -> product data from secure API
  final Map<int, Map<String, dynamic>> _productDetailsCache = {};
  final Map<int, bool> _loadingProductDetails = {};

  @override
  void initState() {
    super.initState();
    _loadFullOrder();
  }

  Future<void> _loadFullOrder() async {
    final order = await _orderService.getOrder(widget.order.id);
    if (mounted && order != null) {
      setState(() {
        _fullOrder = order;
      });
      // Load product details for all items
      for (var item in order.items) {
        _loadProductDetails(item.productId, item.variationId);
      }
    }
  }

  Future<void> _loadProductDetails(int productId, int? variationId) async {
    if (_productDetailsCache.containsKey(productId) ||
        _loadingProductDetails[productId] == true) {
      return; // Already loaded or loading
    }

    setState(() {
      _loadingProductDetails[productId] = true;
    });

    try {
      // Fetch from secure API
      final data = await _productService.getProductFromSecureAPI(productId);
      if (mounted && data != null) {
        setState(() {
          _productDetailsCache[productId] = data;
          _loadingProductDetails[productId] = false;
        });
      } else {
        setState(() {
          _loadingProductDetails[productId] = false;
        });
      }
    } catch (e) {
      print('Error loading product details for $productId: $e');
      if (mounted) {
        setState(() {
          _loadingProductDetails[productId] = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _toggleItemSelection(OrderItemModel item) {
    setState(() {
      if (_selectedItems.containsKey(item.id)) {
        _selectedItems.remove(item.id);
      } else {
        // Select full quantity by default
        _selectedItems[item.id] = item.quantity;
      }
    });
  }

  void _updateReturnQuantity(OrderItemModel item, double quantity) {
    setState(() {
      if (quantity <= 0) {
        _selectedItems.remove(item.id);
      } else {
        // Ensure quantity doesn't exceed original
        final maxQuantity = item.quantity;
        _selectedItems[item.id] = quantity > maxQuantity
            ? maxQuantity
            : quantity;
      }
    });
  }

  Future<void> _submitReturn() async {
    if (_selectedItems.isEmpty) {
      Fluttertoast.showToast(
        msg: 'لطفا حداقل یک آیتم را برای مرجوعی انتخاب کنید',
        toastLength: Toast.LENGTH_SHORT,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Prepare items for return
      final returnItems = _selectedItems.entries.map((entry) {
        OrderItemModel? item;
        try {
          item = _fullOrder?.items.firstWhere((i) => i.id == entry.key);
        } catch (_) {
          try {
            item = widget.order.items.firstWhere((i) => i.id == entry.key);
          } catch (_) {
            item = null;
          }
        }

        if (item == null) {
          throw Exception('Item ${entry.key} not found in order');
        }

        return {
          'order_item_id': entry.key,
          'product_id': item.productId,
          'quantity': entry.value,
          'unit': item.unit,
          'price': item.price,
        };
      }).toList();

      final returnRequest = await _returnService.createReturn(
        orderId: widget.order.id,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
        items: returnItems,
      );

      if (mounted) {
        if (returnRequest != null) {
          Fluttertoast.showToast(
            msg: 'درخواست مرجوعی با موفقیت ثبت شد و در انتظار تایید است',
            toastLength: Toast.LENGTH_LONG,
          );
          Navigator.pop(context, true);
        } else {
          Fluttertoast.showToast(
            msg: 'خطا در ثبت درخواست مرجوعی',
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'خطا: $e', toastLength: Toast.LENGTH_SHORT);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _fullOrder ?? widget.order;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('درخواست مرجوعی')),
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
                        'شماره سفارش: ${order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تاریخ سفارش: ${PersianDate.formatDateTime(order.createdAt)}',
                      ),
                      Text(
                        'مبلغ کل: ${PersianNumber.formatPrice(order.totalAmount)} تومان',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Items selection
              const Text(
                'انتخاب آیتم‌های مرجوعی',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'آیتم‌هایی که می‌خواهید مرجوع کنید را انتخاب کنید:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ...order.items.map((item) => _buildItemSelector(item)),
              const SizedBox(height: 24),
              // Reason
              const Text(
                'علت مرجوعی (اختیاری)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  hintText: 'علت مرجوعی را وارد کنید...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'ارسال درخواست مرجوعی',
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

  Widget _buildItemSelector(OrderItemModel item) {
    final isSelected = _selectedItems.containsKey(item.id);
    final returnQuantity = _selectedItems[item.id] ?? 0.0;
    final maxQuantity = item.quantity;
    final productDetails = _productDetailsCache[item.productId];
    final isLoadingDetails = _loadingProductDetails[item.productId] == true;

    // Get product image - try variation image, then secure API, then product image
    String? productImage;
    if (item.variationId != null && productDetails != null) {
      // Try to get variation image from variations list
      // For now, use secure API image or product image
      productImage = productDetails['image_url']?.toString();
    }
    if (productImage == null && productDetails != null) {
      productImage = productDetails['image_url']?.toString();
    }
    if (productImage == null && item.product != null) {
      productImage = item.product!.imageUrl;
    }

    // Get brand/album name
    String? brandName;
    if (productDetails != null && productDetails['brand'] != null) {
      brandName = productDetails['brand'].toString();
    } else if (item.product?.brand != null) {
      brandName = item.product!.brand;
    }

    // Get variation attributes
    List<dynamic>? attributes;
    if (productDetails != null && productDetails['attributes'] != null) {
      attributes = productDetails['attributes'] as List<dynamic>?;
    } else if (item.product?.attributes.isNotEmpty == true) {
      // Convert ProductAttribute to map format
      attributes = item.product!.attributes
          .map((attr) => {'name': attr.name, 'value': attr.value})
          .toList();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? AppColors.primaryRed.withOpacity(0.1) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleItemSelection(item),
                ),
                // Product image
                if (productImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: productImage,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 40),
                      ),
                    ),
                  )
                else if (isLoadingDetails)
                  Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 40),
                  ),
                const SizedBox(width: 12),
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
                      if (brandName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'برند/آلبوم: $brandName',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (attributes != null && attributes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: attributes.map((attr) {
                            final name = attr['name']?.toString() ?? '';
                            final value = attr['value']?.toString() ?? '';
                            if (name.isEmpty || value.isEmpty)
                              return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$name: $value',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[800],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          // Get product details from cache
                          final productDetails =
                              _productDetailsCache[item.productId];
                          
                          // Get unit directly from secure API response
                          final unit = ProductUnitDisplayHelper.getUnitFromAPI(productDetails);
                          
                          return Text(
                            'تعداد: ${ProductUnitDisplayHelper.formatQuantityWithCoverage(
                              quantity: maxQuantity,
                              unit: unit,
                              productDetails: productDetails,
                            )}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'قیمت: ${PersianNumber.formatPrice(item.total)} تومان',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const Divider(),
              Builder(
                builder: (context) {
                  // Get product details from cache
                  final productDetails = _productDetailsCache[item.productId];
                  
                  // Get unit directly from secure API response
                  final unit = ProductUnitDisplayHelper.getUnitFromAPI(productDetails);

                  return Row(
                    children: [
                      const Text('تعداد مرجوعی: '),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: 'تعداد',
                            border: const OutlineInputBorder(),
                            suffixText: unit,
                          ),
                          onChanged: (value) {
                            final qty = double.tryParse(value) ?? 0.0;
                            _updateReturnQuantity(item, qty);
                          },
                          controller: TextEditingController(
                            text: returnQuantity.toStringAsFixed(1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ ${PersianNumber.formatNumberString(maxQuantity.toStringAsFixed(1))}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
