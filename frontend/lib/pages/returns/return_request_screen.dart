// Return Request Screen - Select items to return
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../services/return_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/persian_number.dart';
import '../../utils/persian_date.dart';
import '../../utils/product_unit_display.dart';
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
  // Controllers for quantity fields: order_item_id -> TextEditingController
  final Map<int, TextEditingController> _quantityControllers = {};
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
        // Use wooId if available, otherwise use productId
        final wooId = item.product?.wooId ?? item.productId;
        _loadProductDetails(item.productId, wooId, item.variationId);
      }
    }
  }

  Future<void> _loadProductDetails(int productId, int wooId, int? variationId) async {
    if (_productDetailsCache.containsKey(productId) ||
        _loadingProductDetails[productId] == true) {
      return; // Already loaded or loading
    }

    setState(() {
      _loadingProductDetails[productId] = true;
    });

    try {
      // Fetch from secure API using wooId
      final data = await _productService.getProductFromSecureAPI(wooId);
      if (mounted && data != null) {
        setState(() {
          _productDetailsCache[productId] = data;
          _loadingProductDetails[productId] = false;
        });
        print('✅ Loaded product details for productId=$productId, wooId=$wooId, name=${data['name']}');
      } else {
        print('⚠️ No data received for productId=$productId, wooId=$wooId');
        setState(() {
          _loadingProductDetails[productId] = false;
        });
      }
    } catch (e) {
      print('❌ Error loading product details for productId=$productId, wooId=$wooId: $e');
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
    // Dispose all quantity controllers
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    _quantityControllers.clear();
    super.dispose();
  }

  void _toggleItemSelection(OrderItemModel item) {
    setState(() {
      if (_selectedItems.containsKey(item.id)) {
        // Deselect item
        _selectedItems.remove(item.id);
        // Dispose controller if exists
        _quantityControllers[item.id]?.dispose();
        _quantityControllers.remove(item.id);
      } else {
        // Select item and auto-fill with max quantity
        final maxQuantity = item.quantity;
        _selectedItems[item.id] = maxQuantity;
        
        // Create and initialize controller with max quantity
        final controller = TextEditingController(
          text: maxQuantity.toStringAsFixed(1),
        );
        _quantityControllers[item.id] = controller;
      }
    });
  }

  void _updateReturnQuantity(OrderItemModel item, double quantity, {bool updateController = false}) {
    setState(() {
      final maxQuantity = item.quantity;
      
      if (quantity <= 0) {
        // Remove selection if quantity is 0 or negative
        _selectedItems.remove(item.id);
        _quantityControllers[item.id]?.dispose();
        _quantityControllers.remove(item.id);
      } else {
        // Clamp quantity to max (enforce max limit)
        final clampedQuantity = quantity > maxQuantity ? maxQuantity : quantity;
        _selectedItems[item.id] = clampedQuantity;
        
        // Only update controller text if explicitly requested (e.g., when clamping)
        // Don't update during normal typing to avoid clearing user input
        if (updateController) {
          final controller = _quantityControllers[item.id];
          if (controller != null) {
            final newText = clampedQuantity.toStringAsFixed(1);
            if (controller.text != newText) {
              controller.text = newText;
              controller.selection = TextSelection.collapsed(
                offset: newText.length,
              );
            }
          }
        }
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
                      // Use grand total (cooperation price with tax/discount) for consistency
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
              const SizedBox(height: 16),
              // Total Returnable Amount Display
              if (_selectedItems.isNotEmpty)
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final user = authProvider.user;
                    // Calculate total returnable amount based on cooperation prices with discounts
                    double totalReturnable = 0.0;
                    
                    for (final entry in _selectedItems.entries) {
                      final itemId = entry.key;
                      final returnQuantity = entry.value;
                      
                      // Find the item
                      final item = order.items.firstWhere(
                        (i) => i.id == itemId,
                        orElse: () => order.items.first,
                      );
                      
                      // Get colleague price from cache
                      final productDetails = _productDetailsCache[item.productId];
                      double? colleaguePrice;
                      
                      if (productDetails?['colleague_price'] != null) {
                        final value = productDetails!['colleague_price'];
                        if (value is num) {
                          colleaguePrice = value.toDouble();
                        } else if (value is String) {
                          colleaguePrice = double.tryParse(value);
                        }
                      } else if (item.product?.colleaguePrice != null) {
                        colleaguePrice = item.product!.colleaguePrice;
                      }
                      
                      if (colleaguePrice != null) {
                        // Apply discount if user has discount percentage
                        double finalPrice = colleaguePrice;
                        if (user?.discountPercentage != null && user!.discountPercentage! > 0) {
                          final discountAmount = colleaguePrice * (user.discountPercentage! / 100.0);
                          finalPrice = colleaguePrice - discountAmount;
                        }
                        totalReturnable += finalPrice * returnQuantity;
                      } else {
                        // Fallback to item total if colleague price not available
                        totalReturnable += (item.total / item.quantity) * returnQuantity;
                      }
                    }
                    
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryRed,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.assignment_return,
                                color: AppColors.primaryRed,
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'مبلغ قابل مرجوعی:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryRed,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${PersianNumber.formatPrice(totalReturnable)} تومان',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryRed,
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
                                      fontWeight: FontWeight.w500,
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

    // Get cooperation price (colleague_price) from secure API
    double? colleaguePrice;
    if (productDetails?['colleague_price'] != null) {
      final value = productDetails!['colleague_price'];
      if (value is num) {
        colleaguePrice = value.toDouble();
      } else if (value is String) {
        colleaguePrice = double.tryParse(value);
      }
    } else if (item.product?.colleaguePrice != null) {
      colleaguePrice = item.product!.colleaguePrice;
    }

    // Get product name - prefer from cache, then from item, then fallback with productId
    String productName = 'محصول ${item.productId}';
    if (productDetails != null && productDetails['name'] != null) {
      productName = productDetails['name'].toString();
      print('✅ Product name from cache: $productName');
    } else if (item.product?.name != null && item.product!.name.isNotEmpty) {
      productName = item.product!.name;
      print('✅ Product name from item.product: $productName');
    } else {
      print('⚠️ Product name not found, using fallback: $productName');
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
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 40),
                      ),
                    ),
                  )
                else if (isLoadingDetails)
                  Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 40),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product name (full title)
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Cooperation price / Partner price - prominently displayed
                      if (colleaguePrice != null && colleaguePrice > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primaryBlue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'قیمت همکاری: ${PersianNumber.formatPrice(colleaguePrice)} تومان',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ] else if (!isLoadingDetails) ...[
                        // Show order price if colleague price not available
                        Text(
                          'قیمت: ${PersianNumber.formatPrice(item.total)} تومان',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (brandName != null) ...[
                        Text(
                          'برند/آلبوم: $brandName',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                          // Get calculator data from secure API response
                          final productDetails =
                              _productDetailsCache[item.productId];
                          final calculator =
                              productDetails?['calculator']
                                  as Map<String, dynamic>?;
                          final apiUnit = ProductUnitDisplay.getUnitFromCalculator(calculator);
                          final coverageStr = ProductUnitDisplay.formatCoverage(
                            quantity: maxQuantity,
                            apiUnit: apiUnit,
                            calculator: calculator,
                          );
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Unit row
                              Text(
                                'تعداد: ${ProductUnitDisplay.formatQuantityWithUnit(
                                  quantity: maxQuantity,
                                  apiUnit: apiUnit,
                                )}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              // Coverage row (متراژ) - only show if available
                              if (coverageStr != null && coverageStr.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  coverageStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const Divider(),
              Builder(
                builder: (context) {
                  // Get calculator data from secure API response
                  final productDetails = _productDetailsCache[item.productId];
                  final calculator =
                      productDetails?['calculator'] as Map<String, dynamic>?;
                  final apiUnit = ProductUnitDisplay.getUnitFromCalculator(calculator);
                  final unit = ProductUnitDisplay.getDisplayUnit(apiUnit);

                  // Get or create controller for this item
                  if (!_quantityControllers.containsKey(item.id)) {
                    _quantityControllers[item.id] = TextEditingController(
                      text: returnQuantity.toStringAsFixed(1),
                    );
                  }
                  final quantityController = _quantityControllers[item.id]!;
                  
                  return Row(
                    children: [
                      const Text('تعداد مرجوعی: '),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: 'تعداد',
                            border: const OutlineInputBorder(),
                            suffixText: unit,
                            helperText: 'حداکثر: ${PersianNumber.formatNumberString(maxQuantity.toStringAsFixed(1))}',
                            helperMaxLines: 1,
                          ),
                          onChanged: (value) {
                            // Allow user to type freely - only update when value is valid
                            // Don't interfere with user input by updating controller
                            if (value.isNotEmpty) {
                              final qty = double.tryParse(value);
                              if (qty != null && qty >= 0) {
                                // Update selected quantity without touching controller
                                // This allows user to continue typing
                                final maxQuantity = item.quantity;
                                final clampedQuantity = qty > maxQuantity ? maxQuantity : qty;
                                _selectedItems[item.id] = clampedQuantity;
                              }
                            }
                          },
                          // Enforce max value by validating input
                          inputFormatters: [
                            // Custom formatter to limit to maxQuantity
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) {
                                if (newValue.text.isEmpty) {
                                  return newValue;
                                }
                                final parsed = double.tryParse(newValue.text);
                                if (parsed == null) {
                                  return oldValue;
                                }
                                if (parsed > maxQuantity) {
                                  // Clamp to max and update controller
                                  final maxText = maxQuantity.toStringAsFixed(1);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (quantityController.text != maxText) {
                                      quantityController.text = maxText;
                                      quantityController.selection = TextSelection.collapsed(
                                        offset: maxText.length,
                                      );
                                    }
                                    _updateReturnQuantity(item, maxQuantity, updateController: false);
                                  });
                                  return TextEditingValue(
                                    text: maxText,
                                    selection: TextSelection.collapsed(
                                      offset: maxText.length,
                                    ),
                                  );
                                }
                                return newValue;
                              },
                            ),
                          ],
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
