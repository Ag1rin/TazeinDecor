/// Product Detail Screen
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/persian_number.dart';
import '../../utils/product_unit_helper.dart';
import '../../widgets/product_calculator_widget.dart';
import '../../widgets/smart_quantity_calculator.dart';
import '../../widgets/image_viewer.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../pages/cart/cart_order_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentImageIndex = 0;
  double _quantity = 1;
  String _unit = 'package';
  final TextEditingController _areaController = TextEditingController();
  final ProductService _productService = ProductService();
  String? _brandName;
  List<ProductAttribute> _attributes = const [];

  List<Map<String, dynamic>> _variations = [];
  Map<String, dynamic>? _selectedVariation;
  bool _isLoadingVariations = false;

  // Secure API data
  Map<String, dynamic>? _secureProductData;

  // Cached images list to prevent rebuilds during loading
  List<String>? _cachedImages;

  // Old calculator controllers (kept for backward compatibility but not used)
  final TextEditingController _roomWidthController = TextEditingController();
  final TextEditingController _roomHeightController = TextEditingController();
  final TextEditingController _rollsCountController = TextEditingController();

  // Price reveal state
  bool _isPriceRevealed = false;
  Timer? _priceRevealTimer;

  // Calculator auto-update state
  bool _quantityAutoUpdated =
      false; // Track if quantity was auto-set from calculator
  Timer? _quantityUpdateMessageTimer; // Timer to hide update message

  // Error and loading states
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _brandName = widget.product.brand;
    _attributes = widget.product.attributes;
    _loadImages();
    _initializeData();

    // Calculator inputs are now handled by ProductCalculatorWidget
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Load data in parallel but handle errors gracefully
      await Future.wait([
        _loadVariations().catchError((e) {
          print('⚠️ Error loading variations: $e');
          // Continue even if variations fail
        }),
        _loadSecureProductData().catchError((e) {
          print('⚠️ Error loading secure data: $e');
          // Continue even if secure API fails
        }),
      ]);
    } catch (e) {
      print('❌ Critical error initializing product data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'خطا در بارگذاری اطلاعات محصول';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadVariations() async {
    if (!mounted) return;
    setState(() {
      _isLoadingVariations = true;
    });

    try {
      final variations = await _productService.getProductVariations(
        widget.product.wooId,
      );
      if (!mounted) return;

      // Batch state update to prevent flashing
      setState(() {
        _variations = variations;
        if (variations.isNotEmpty && _selectedVariation == null) {
          _selectedVariation = variations.first;
        }
        _isLoadingVariations = false;
      });
    } catch (e) {
      print('❌ Error loading variations: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingVariations = false;
        // Don't set error state - variations are optional
        _variations = [];
      });
    }
  }

  Future<void> _loadSecureProductData() async {
    if (!mounted) return;

    try {
      final data = await _productService.getProductFromSecureAPI(
        widget.product.wooId,
      );
      if (!mounted) return;

      // Batch all state updates into a single setState to prevent flashing
      if (data != null) {
        // Debug: Log the entire API response structure
        print('🔍 Secure API Response for product ${widget.product.wooId}:');
        print('   Full response keys: ${data.keys.toList()}');
        if (data['calculator'] != null) {
          print(
            '   Calculator object keys: ${(data['calculator'] as Map).keys.toList()}',
          );
          print('   Calculator data: ${data['calculator']}');
        } else {
          print('   ⚠️ No calculator object in response');
          // Check if calculator fields are at top level
          if (data.containsKey('roll_w') ||
              data.containsKey('roll_l') ||
              data.containsKey('pkg_cov')) {
            print('   ✅ Found calculator fields at top level:');
            print('      roll_w: ${data['roll_w']}, roll_l: ${data['roll_l']}');
            print('      pkg_cov: ${data['pkg_cov']}');
          }
        }

        if (mounted) {
          setState(() {
            try {
              _secureProductData = data;
              // Update brand if available
              if (data['brand'] != null) {
                _brandName = data['brand'].toString();
              }
              // Clear cached images so they refresh with new data
              _cachedImages = null;
            } catch (e) {
              print('❌ Error processing secure product data: $e');
              // Continue with partial data
            }
          });
        }
      }
    } catch (e) {
      print('❌ Error loading secure product data: $e');
      // Log error for debugging
      print('❌ Product ID: ${widget.product.wooId}');
      print('❌ Error type: ${e.runtimeType}');
      // Silently fail - product will show with default data
      // Don't set error state as this is optional data
      if (mounted) {
        setState(() {
          _secureProductData = null;
        });
      }
    }
  }

  void _loadImages() {
    if (widget.product.images != null && widget.product.images!.isNotEmpty) {
      setState(() {
        _currentImageIndex = 0;
      });
    }
  }

  List<String> get _images {
    try {
      // Use cached images if available to prevent rebuilds
      if (_cachedImages != null) {
        return _cachedImages!;
      }

      // Priority: secure API image > variation image > product images
      String? secureImage;
      try {
        if (_secureProductData != null &&
            _secureProductData!['image_url'] != null) {
          secureImage = _secureProductData!['image_url'].toString();
        }
      } catch (e) {
        print('⚠️ Error getting secure image: $e');
      }

      // If a variation is selected and has an image, show that first
      try {
        if (_selectedVariation != null &&
            _selectedVariation!['image'] != null &&
            _selectedVariation!['image'].toString().isNotEmpty) {
          final variationImage = _selectedVariation!['image'].toString();
          final baseImages = secureImage != null
              ? [secureImage]
              : (widget.product.images != null &&
                        widget.product.images!.isNotEmpty
                    ? widget.product.images!
                    : (widget.product.imageUrl != null
                          ? [widget.product.imageUrl!]
                          : []));
          // Put variation image first
          _cachedImages = [variationImage, ...baseImages];
          return _cachedImages!;
        }
      } catch (e) {
        print('⚠️ Error getting variation image: $e');
      }

      // Use secure API image if available
      if (secureImage != null) {
        _cachedImages = [secureImage];
        return _cachedImages!;
      }

      // Fallback to product images
      if (widget.product.images != null && widget.product.images!.isNotEmpty) {
        _cachedImages = widget.product.images!;
        return _cachedImages!;
      } else if (widget.product.imageUrl != null) {
        _cachedImages = [widget.product.imageUrl!];
        return _cachedImages!;
      }

      // No images available - return empty list
      _cachedImages = [];
      return _cachedImages!;
    } catch (e) {
      print('❌ Critical error in _images getter: $e');
      // Return empty list on error to prevent crashes
      return [];
    }
  }

  double? get _displayPrice {
    // ONLY use colleague_price from secure API - never show other prices
    if (_secureProductData != null &&
        _secureProductData!['colleague_price'] != null) {
      final price = _secureProductData!['colleague_price'];
      if (price is num && price > 0) {
        return price.toDouble();
      } else if (price is String) {
        final parsed = double.tryParse(price);
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }
    // Return null if no colleague_price - price should be hidden
    return null;
  }

  ProductCalculator? get _calculator {
    if (_secureProductData != null) {
      // Check if calculator data is nested in 'calculator' object
      if (_secureProductData!['calculator'] != null) {
        print('🔍 Using calculator from nested object');
      return ProductCalculator.fromJson(_secureProductData!['calculator']);
      }

      // Check if calculator fields are at top level (roll_w, roll_l, pkg_cov, etc.)
      if (_secureProductData!.containsKey('roll_w') ||
          _secureProductData!.containsKey('roll_l') ||
          _secureProductData!.containsKey('pkg_cov') ||
          _secureProductData!.containsKey('roll_width') ||
          _secureProductData!.containsKey('roll_length') ||
          _secureProductData!.containsKey('package_coverage')) {
        print('🔍 Using calculator from top-level fields');
        // Build calculator object from top-level fields
        final calculatorData = <String, dynamic>{
          'is_active':
              _secureProductData!['is_active'] ??
              _secureProductData!['calculator_is_active'] ??
              false,
          'unit':
              _secureProductData!['unit'] ??
              _secureProductData!['calculator_unit'],
          'roll_w': _secureProductData!['roll_w'],
          'roll_l': _secureProductData!['roll_l'],
          'roll_width': _secureProductData!['roll_width'],
          'roll_length': _secureProductData!['roll_length'],
          'pkg_cov': _secureProductData!['pkg_cov'],
          'package_coverage': _secureProductData!['package_coverage'],
          'package_area': _secureProductData!['package_area'],
          'waste_percentage': _secureProductData!['waste_percentage'],
          'pattern_repeat': _secureProductData!['pattern_repeat'],
        };
        print('   Built calculator data: $calculatorData');
        return ProductCalculator.fromJson(calculatorData);
      }
    }
    return widget.product.calculator;
  }

  void _convertAreaToPackages() {
    if (widget.product.packageArea != null && _areaController.text.isNotEmpty) {
      try {
        final area = double.parse(_areaController.text);
        final packages = area / widget.product.packageArea!;
        setState(() {
          _quantity = packages;
          _unit = 'package';
        });
      } catch (e) {
        Fluttertoast.showToast(msg: 'لطفا عدد معتبر وارد کنید');
      }
    }
  }

  void _addToCart() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addToCart(
      widget.product,
      quantity: _quantity,
      unit: _unit,
      variationId: _selectedVariation?['id'],
      variationPattern: _selectedVariation?['pattern'],
      variationImage: _selectedVariation?['image'],
    );

    // Navigate to cart page immediately (no snackbar)
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartOrderScreen()),
    );
  }

  Color _getStockStatusColor(int stockQuantity) {
    if (stockQuantity == 0) {
      return Colors.red;
    } else if (stockQuantity < 5) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getStockStatusText(int stockQuantity) {
    if (stockQuantity == 0) {
      return 'ناموجود';
    } else if (stockQuantity < 5) {
      return 'موجودی محدود';
    } else {
      return 'نمایش قیمت';
    }
  }

  Widget _buildSpecificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          if (_attributes.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'ویژگی‌های محصول',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ..._attributes.map((attr) => _buildSpecRow(attr.name, attr.value)),
            const Divider(height: 24),
          ],
          // Stock status (no exact number)
          _buildSpecRow(
            'وضعیت موجودی',
            _getStockStatusText(widget.product.stockQuantity),
          ),
          // SKU
          if (widget.product.sku != null)
            _buildSpecRow('کد محصول', widget.product.sku!),
          // Album code
          if (widget.product.albumCode != null)
            _buildSpecRow('کد آلبوم', widget.product.albumCode!),
          // Brand
          if (_brandName != null) _buildSpecRow('برند', _brandName!),
          // Design code
          if (widget.product.designCode != null)
            _buildSpecRow('کد طراحی', widget.product.designCode!),
          // Package area
          if (widget.product.packageArea != null)
            _buildSpecRow(
              'مساحت بسته',
              '${PersianNumber.formatNumber(widget.product.packageArea!.toInt())} متر مربع',
            ),
          // Roll count
          if (widget.product.rollCount != null)
            _buildSpecRow(
              'تعداد رول',
              PersianNumber.formatNumber(widget.product.rollCount!),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Old calculator methods removed - now handled by ProductCalculatorWidget

  // Helper function to normalize unit names (handle both Persian and English)
  bool _isSupportedUnit(String? unit) {
    if (unit == null) return false;
    final normalized = unit.toLowerCase().trim();
    // Check for roll/رول
    if (normalized == 'roll' || normalized == 'رول') return true;
    // Check for package/بسته
    if (normalized == 'package' || normalized == 'بسته') return true;
    // Check for tile/تایل
    if (normalized == 'tile' || normalized == 'تایل') return true;
    // Check for branch/شاخه (parquet tools/skirting)
    if (normalized == 'branch' || normalized == 'شاخه') return true;
    return false;
  }

  Widget _buildCalculatorTab() {
    // Debug logging
    print('🔍 _buildCalculatorTab called:');
    print('   - _calculator: ${_calculator != null ? "exists" : "null"}');
    if (_calculator != null) {
      print('   - isActive: ${_calculator!.isActive}');
      print('   - detectedUnit: ${_calculator!.detectedUnit}');
      print('   - unit field: ${_calculator!.unit}');
    }

    // Show calculator if it exists (even if not active - user can still use input fields)
    if (_calculator != null) {
      final detectedUnit = _calculator!.detectedUnit;

      // Use smart calculator for roll, package, tile units (handle both Persian and English)
      if (_isSupportedUnit(detectedUnit)) {
        print('   ✅ Showing SmartQuantityCalculator for unit: $detectedUnit');
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SmartQuantityCalculator(
            calculator: _calculator!,
            colleaguePrice: _displayPrice,
            onQuantityCalculated: _onSmartCalculatorQuantityCalculated,
          ),
        );
      }

      // Use full calculator for other modes
      print('   ✅ Showing ProductCalculatorWidget for unit: $detectedUnit');
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ProductCalculatorWidget(
          calculator: _calculator!,
          colleaguePrice: _displayPrice,
          onCalculationComplete: _onCalculatorQuantityCalculated,
        ),
      );
    }

    // Fallback: Price summary (only if colleague_price is available)
    if (_displayPrice == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calculate_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'ماشین حساب برای این محصول فعال نیست',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'برای اطلاع از قیمت تماس بگیرید',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final totalPrice = _displayPrice! * _quantity;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'محاسبه قیمت نهایی',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Base price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('قیمت واحد:'),
              Text(
                '${PersianNumber.formatPrice(_displayPrice!)} تومان',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quantity with area coverage
          Builder(
            builder: (context) {
              // Get category from secure product data
              String? categoryName;
              if (_secureProductData != null) {
                categoryName =
                    _secureProductData!['category_name']?.toString() ??
                    _secureProductData!['category']?.toString();
              }

              // Get calculator data
              final calculator = _calculator;
              String? unit;
              double? areaCoverage;

              if (calculator != null) {
                // Determine unit based on category
                unit = ProductUnitHelper.getDisplayUnit(
                  categoryName: categoryName,
                  calculatorUnit: calculator.unit ?? calculator.detectedUnit,
                  hasRollDimensions:
                      calculator.rollWidth != null &&
                      calculator.rollLength != null,
                  hasPackageCoverage:
                      calculator.packageCoverage != null ||
                      calculator.packageArea != null,
                  hasBranchLength: calculator.branchLength != null,
                );

                // Calculate area coverage
                if (ProductUnitHelper.isParquetCategory(categoryName) ||
                    ProductUnitHelper.isWallpaperCategory(categoryName)) {
                  if (calculator.packageCoverage != null) {
                    areaCoverage = _quantity * calculator.packageCoverage!;
                  } else if (calculator.packageArea != null) {
                    areaCoverage = _quantity * calculator.packageArea!;
                  } else if (ProductUnitHelper.isWallpaperCategory(
                        categoryName,
                      ) &&
                      calculator.rollWidth != null &&
                      calculator.rollLength != null) {
                    final rollArea =
                        calculator.rollWidth! * calculator.rollLength!;
                    areaCoverage = _quantity * rollArea;
                  }
                }
              } else {
                // Fallback unit
                unit = 'بسته';
              }

              return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('تعداد:'),
              Text(
                    ProductUnitHelper.formatQuantityWithCoverage(
                      quantity: _quantity,
                      unit: unit,
                      areaCoverage: areaCoverage,
                      categoryName: categoryName,
                    ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
              );
            },
          ),
          const Divider(height: 32),
          // Total
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'قیمت نهایی:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${PersianNumber.formatPrice(totalPrice)} تومان',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onCalculatorQuantityCalculated(int quantity) {
    // Update quantity from calculator result
    setState(() {
      _quantity = quantity.toDouble();
      _quantityAutoUpdated = true;
    });

    // Show message briefly
    _quantityUpdateMessageTimer?.cancel();
    _quantityUpdateMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _quantityAutoUpdated = false;
        });
      }
    });
  }

  void _onSmartCalculatorQuantityCalculated(double quantity, String unit) {
    // Update quantity and unit from smart calculator result
    setState(() {
      _quantity = quantity;
      // Convert Persian unit labels to internal unit values
      if (unit == 'رول') {
        _unit = 'roll';
      } else if (unit == 'بسته') {
        _unit = 'package';
      } else if (unit == 'تایل') {
        _unit = 'tile';
      } else if (unit == 'شاخه') {
        _unit = 'branch';
      }
      _quantityAutoUpdated = true;
    });

    // Show message briefly
    _quantityUpdateMessageTimer?.cancel();
    _quantityUpdateMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _quantityAutoUpdated = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _areaController.dispose();
    _roomWidthController.dispose();
    _roomHeightController.dispose();
    _rollsCountController.dispose();
    _priceRevealTimer?.cancel();
    _quantityUpdateMessageTimer?.cancel();
    super.dispose();
  }

  void _revealPriceTemporarily() {
    // Cancel existing timer if any
    _priceRevealTimer?.cancel();

    // Reveal price
    setState(() {
      _isPriceRevealed = true;
    });

    // Hide price after 2 seconds
    _priceRevealTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isPriceRevealed = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show error state if critical error occurred
    if (_hasError && !_isLoading) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('جزئیات محصول')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'خطا در بارگذاری محصول',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      _initializeData();
                    },
                    child: const Text('تلاش مجدد'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text('بازگشت'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Determine content state
    final bool showLoading = _isLoading;
    final bool hasProductData = widget.product.name.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('جزئیات محصول')),
        body: showLoading && !hasProductData
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Image slider
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image slider - full size
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: _images.isNotEmpty
                                ? PageView.builder(
                                    itemCount: _images.length,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentImageIndex = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      return InteractiveViewer(
                                        minScale: 0.5,
                                        maxScale: 3.0,
                                        child: GestureDetector(
                                          onLongPress: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ImageViewer(
                                                      images: _images,
                                                      initialIndex: index,
                                                    ),
                                              ),
                                            );
                                          },
                                        child: CachedNetworkImage(
                                          imageUrl: _images[index],
                                          fit: BoxFit.contain,
                                          placeholder: (context, url) =>
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            errorWidget:
                                                (context, url, error) =>
                                              Container(
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.image,
                                                  size: 100,
                                                      ),
                                                ),
                                              ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 100),
                                  ),
                          ),
                          if (_images.length > 1)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: SizedBox(
                                height: 16,
                                child: Center(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(
                                        _images.length,
                                        (index) => Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _currentImageIndex == index
                                                ? AppColors.primaryBlue
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Product info
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.product.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Stock status - prominent badge
                                GestureDetector(
                                  onTap: () {
                                    _revealPriceTemporarily();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStockStatusColor(
                                        widget.product.stockQuantity,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getStockStatusColor(
                                            widget.product.stockQuantity,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          widget.product.stockQuantity == 0
                                              ? Icons.cancel_outlined
                                              : widget.product.stockQuantity < 5
                                              ? Icons.warning_amber_rounded
                                              : Icons.check_circle_outline,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _getStockStatusText(
                                            widget.product.stockQuantity,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Only show price if colleague_price is available
                                if (_displayPrice != null)
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _isPriceRevealed
                                        ? Text(
                                            '${PersianNumber.formatPrice(_displayPrice!)} تومان',
                                            key: const ValueKey('price'),
                                            style: const TextStyle(
                                              fontSize: 24,
                                              color: AppColors.primaryBlue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : const Text(
                                            '••••••',
                                            key: ValueKey('hidden'),
                                            style: TextStyle(
                                              fontSize: 24,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          color: Colors.orange[700],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'تماس بگیرید',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_brandName != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.purple.shade50,
                                          Colors.purple.shade100,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.purple.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.business,
                                          size: 18,
                                          color: Colors.purple.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _brandName!,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.purple.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                // Selected variation pattern
                                if (_selectedVariation != null &&
                                    _selectedVariation!['pattern'] != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.primaryBlue,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.palette,
                                          color: AppColors.primaryBlue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'طرح انتخاب‌شده: ${_selectedVariation!['pattern']}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Stock status for selected variation
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      final stockStatus =
                                          _selectedVariation!['stock_status']
                                              ?.toString()
                                              .toLowerCase() ??
                                          'instock';
                                      final isInStock =
                                          stockStatus == 'instock' ||
                                          stockStatus == 'onbackorder';

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isInStock
                                              ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.red.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isInStock
                                                ? Colors.green
                                                : Colors.red,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isInStock
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              color: isInStock
                                                  ? Colors.green[700]
                                                  : Colors.red[700],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isInStock ? 'موجود' : 'ناموجود',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isInStock
                                                    ? Colors.green[700]
                                                    : Colors.red[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                                // Brand from secure API
                                if (_secureProductData != null &&
                                    _secureProductData!['brand'] != null &&
                                    _secureProductData!['brand']
                                        .toString()
                                        .isNotEmpty &&
                                    _secureProductData!['brand'].toString() !=
                                        _brandName) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.purple.shade50,
                                          Colors.purple.shade100,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.purple.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.business,
                                          size: 18,
                                          color: Colors.purple.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _secureProductData!['brand']
                                              .toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.purple.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (widget.product.sku != null) ...[
                                  const SizedBox(height: 8),
                                  Text('کد محصول: ${widget.product.sku}'),
                                ],
                                if (widget.product.albumCode != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'کد آلبوم: ${widget.product.albumCode}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                                if (widget.product.designCode != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'کد طراحی: ${widget.product.designCode}',
                                  ),
                                ],
                                if (widget.product.rollCount != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'تعداد رول: ${PersianNumber.formatNumber(widget.product.rollCount!)}',
                                  ),
                                ],
                                if (widget.product.packageArea != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'مساحت هر بسته: ${PersianNumber.formatNumber(widget.product.packageArea!.toInt())} متر مربع',
                                  ),
                                ],
                                // Variation selector
                                if (_variations.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'انتخاب طرح:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_isLoadingVariations)
                                    const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _variations.map((variation) {
                                        final pattern =
                                            variation['pattern'] ?? 'بدون طرح';
                                        final isSelected =
                                            _selectedVariation?['id'] ==
                                            variation['id'];
                                        final variationImage =
                                            variation['image'];
                                        final hasImage =
                                            variationImage != null &&
                                            variationImage
                                                .toString()
                                                .isNotEmpty;
                                        // Get stock status from variation
                                        final stockStatus =
                                            variation['stock_status']
                                                ?.toString()
                                                .toLowerCase() ??
                                            'instock';
                                        final isInStock =
                                            stockStatus == 'instock' ||
                                            stockStatus == 'onbackorder';

                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedVariation = variation;
                                              _currentImageIndex =
                                                  0; // Reset to first image (variation image)
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.primaryBlue
                                                        .withValues(alpha: 0.1)
                                                  : Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.primaryBlue
                                                    : (!isInStock
                                                          ? Colors.red[300]!
                                                          : Colors.grey[400]!),
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: Stack(
                                              children: [
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                              children: [
                                                // Variation image/swatch
                                                if (hasImage)
                                                  Container(
                                                    width: 60,
                                                    height: 60,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? AppColors
                                                                  .primaryBlue
                                                                : Colors
                                                                      .grey[300]!,
                                                        width: isSelected
                                                            ? 2
                                                            : 1,
                                                      ),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                          child: GestureDetector(
                                                            onLongPress: () {
                                                              // Show full-screen viewer
                                                              final allImages = [
                                                                variationImage
                                                                    .toString(),
                                                                ..._images,
                                                              ];
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (
                                                                        context,
                                                                      ) => ImageViewer(
                                                                        images:
                                                                            allImages,
                                                                        initialIndex:
                                                                            0,
                                                                      ),
                                                                ),
                                                              );
                                                            },
                                                      child: CachedNetworkImage(
                                                              imageUrl:
                                                                  variationImage
                                                            .toString(),
                                                        fit: BoxFit.cover,
                                                        placeholder:
                                                            (
                                                              context,
                                                              url,
                                                            ) => Container(
                                                              color: Colors
                                                                  .grey[200],
                                                              child: const Center(
                                                                      child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                              ),
                                                            ),
                                                        errorWidget:
                                                            (
                                                              context,
                                                              url,
                                                              error,
                                                            ) => Container(
                                                              color: Colors
                                                                  .grey[200],
                                                              child: const Icon(
                                                                      Icons
                                                                          .image,
                                                                size: 24,
                                                                    ),
                                                              ),
                                                            ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    width: 60,
                                                    height: 60,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                          color:
                                                              Colors.grey[300],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? AppColors
                                                                  .primaryBlue
                                                                : Colors
                                                                      .grey[400]!,
                                                        width: isSelected
                                                            ? 2
                                                            : 1,
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.palette,
                                                      size: 24,
                                                    ),
                                                  ),
                                                // Pattern code text
                                                Text(
                                                  pattern,
                                                  style: TextStyle(
                                                    color: isSelected
                                                            ? AppColors
                                                                  .primaryBlue
                                                            : (!isInStock
                                                                  ? Colors
                                                                        .red[700]
                                                                  : Colors
                                                                        .black87),
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    fontSize: 12,
                                                  ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                                // Stock status badge
                                                Positioned(
                                                  top: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isInStock
                                                          ? Colors.green
                                                          : Colors.red,
                                                      borderRadius:
                                                          const BorderRadius.only(
                                                            topRight:
                                                                Radius.circular(
                                                                  12,
                                                                ),
                                                            bottomLeft:
                                                                Radius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      isInStock
                                                          ? Icons.check_circle
                                                          : Icons.cancel,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          // Package calculator (legacy - only if no wallpaper calculator)
                          // Note: Main calculator is now in the "ماشین حساب" tab
                          if (widget.product.packageArea != null &&
                              (_calculator == null || !_calculator!.isActive))
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'محاسبه بسته',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _areaController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'مساحت (متر مربع)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: _convertAreaToPackages,
                                        child: const Text('تبدیل'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'تعداد بسته: ${PersianNumber.formatNumberString(_quantity.toStringAsFixed(1).split('.')[0])}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          // Tabs
                          TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(text: 'توضیحات'),
                              Tab(text: 'مشخصات'),
                              Tab(text: 'ماشین حساب'),
                            ],
                          ),
                          SizedBox(
                            height: 260,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                // Description
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Html(
                                    data:
                                        widget.product.description ??
                                        '<p>توضیحاتی ثبت نشده است</p>',
                                    style: {
                                      'body': Style(
                                        margin: Margins.zero,
                                        padding: HtmlPaddings.zero,
                                        fontSize: FontSize(14),
                                        lineHeight: LineHeight(1.6),
                                      ),
                                    },
                                  ),
                                ),
                                // Specifications
                                _buildSpecificationsTab(),
                                // Calculator
                                _buildCalculatorTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Add to cart section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Auto-update message
                        if (_quantityAutoUpdated) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[300]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'تعداد به ${PersianNumber.formatNumber(_quantity.toInt())} به‌روزرسانی شد',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          children: [
                            // Quantity selector
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _quantityAutoUpdated
                                      ? Colors.green[400]!
                                      : Colors.grey,
                                  width: _quantityAutoUpdated ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      if (_quantity > 1) {
                                        setState(() {
                                          _quantity--;
                                          _quantityAutoUpdated =
                                              false; // Reset flag on manual change
                                        });
                                      }
                                    },
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      PersianNumber.formatNumberString(
                                        _quantity
                                            .toStringAsFixed(1)
                                            .split('.')[0],
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: _quantityAutoUpdated
                                            ? Colors.green[700]
                                            : null,
                                        fontWeight: _quantityAutoUpdated
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      setState(() {
                                        _quantity++;
                                        _quantityAutoUpdated =
                                            false; // Reset flag on manual change
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Add to cart button
                            Expanded(
                              child: ElevatedButton(
                                onPressed: widget.product.stockQuantity == 0
                                    ? null
                                    : _addToCart,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'افزودن به سبد',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
