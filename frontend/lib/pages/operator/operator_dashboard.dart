// Operator Dashboard
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../services/order_service.dart';
import '../../services/installation_service.dart'
    show InstallationService, InstallationModel;
import '../../services/return_service.dart' show ReturnService, ReturnModel;
import '../../services/product_service.dart';
import '../../models/order_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/persian_number.dart';
import '../../utils/persian_date.dart';
import '../../utils/product_unit_helper.dart';
import '../../utils/status_labels.dart';
import '../../pages/invoices/invoice_detail_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OperatorDashboard extends StatefulWidget {
  const OperatorDashboard({super.key});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final InstallationService _installationService = InstallationService();
  final ReturnService _returnService = ReturnService();
  final ProductService _productService = ProductService();

  List<OrderModel> _orders = [];
  List<ReturnModel> _returns = [];
  List<ReturnModel> _filteredReturns = [];
  final TextEditingController _returnSearchController = TextEditingController();
  Map<String, dynamic> _tomorrowInstallations = {
    'count': 0,
    'installations': [],
  };
  List<InstallationModel> _allInstallations = [];
  bool _isLoading = false;
  String _selectedTab = 'invoices';

  // Cache for product details: productId -> product data from secure API
  final Map<int, Map<String, dynamic>> _productDetailsCache = {};
  final Map<int, bool> _loadingProductDetails = {};

  // Animation controller for blinking badges
  late AnimationController _badgeAnimationController;
  late Animation<double> _badgeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize badge animation
    _badgeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _badgeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgeAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _badgeAnimationController.repeat(reverse: true);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadOrders(),
      _loadReturns(),
      _loadTomorrowInstallations(),
      _loadAllInstallations(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadAllInstallations() async {
    final startDate = DateTime.now().subtract(const Duration(days: 30));
    final endDate = DateTime.now().add(const Duration(days: 60));
    final installations = await _installationService.getInstallations(
      startDate: startDate,
      endDate: endDate,
    );
    setState(() {
      _allInstallations = installations;
    });
  }

  Future<void> _loadOrders() async {
    final orders = await _orderService.getOrders();
    setState(() {
      _orders = orders;
    });
  }

  Future<void> _loadReturns() async {
    final returns = await _returnService.getReturns();
    setState(() {
      _returns = returns;
      _filteredReturns = returns;
    });
  }

  void _filterReturns(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _filteredReturns = _returns;
      });
      return;
    }

    setState(() {
      _filteredReturns = _returns.where((r) {
        final text = q.toLowerCase();
        final orderMatch = r.orderId.toString().contains(text);
        final reasonMatch = (r.reason ?? '').toLowerCase().contains(text);
        final itemsText = r.items.join(' ').toLowerCase();
        final itemsMatch = itemsText.contains(text);
        // Customer info not available in current model; using available fields.
        return orderMatch || reasonMatch || itemsMatch;
      }).toList();
    });
  }

  Future<void> _loadTomorrowInstallations() async {
    final data = await _installationService.getTomorrowInstallations();
    setState(() {
      _tomorrowInstallations = data;
    });
  }

  Future<void> _confirmOrder(int orderId, {int? companyId}) async {
    final success = await _orderService.confirmOrder(
      orderId,
      companyId: companyId,
    );
    if (success) {
      _loadOrders();
    }
  }

  Future<void> _markOrderRead(int orderId) async {
    await _orderService.markOrderRead(orderId);
    _loadOrders();
  }

  String _getStatusText(String status) {
    return StatusLabels.getOrderStatus(status);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'delivered':
        return AppColors.primaryGreen;
      default:
        return Colors.grey;
    }
  }

  // Get badge counts
  int get _newInvoicesCount => _orders.where((o) => o.isNew).length;
  int get _newReturnsCount => _returns.where((r) => r.isNew).length;
  int get _newInstallationsCount {
    // Use tomorrow installations count from the API response
    return _tomorrowInstallations['count'] as int? ?? 0;
  }

  @override
  void dispose() {
    _badgeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('داشبورد اپراتور'),
          actions: [
            // Tomorrow's installations badge
            if (_tomorrowInstallations['count'] > 0)
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () {
                      setState(() {
                        _selectedTab = 'installations';
                      });
                    },
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_tomorrowInstallations['count']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: SpinKitFadingCircle(color: AppColors.primaryBlue),
              )
            : Column(
                children: [
                  // Tabs
                  Container(
                    color: Colors.grey[200],
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabButton('invoices', 'فاکتورها'),
                        ),
                        Expanded(
                          child: _buildTabButton('returns', 'مرجوعی‌ها'),
                        ),
                        Expanded(
                          child: _buildTabButton('installations', 'نصب‌ها'),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(child: _buildTabContent()),
                ],
              ),
      ),
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isSelected = _selectedTab == tab;

    // Get badge count for this tab
    int badgeCount = 0;
    if (tab == 'invoices') {
      badgeCount = _newInvoicesCount;
    } else if (tab == 'returns') {
      badgeCount = _newReturnsCount;
    } else if (tab == 'installations') {
      badgeCount = _newInstallationsCount;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // Badge
            if (badgeCount > 0)
              Positioned(
                right: -8,
                top: -4,
                child: AnimatedBuilder(
                  animation: _badgeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _badgeAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'invoices':
        return _buildInvoicesTab();
      case 'returns':
        return _buildReturnsTab();
      case 'installations':
        return _buildInstallationsTab();
      default:
        return const Center(child: Text('صفحه یافت نشد'));
    }
  }

  Widget _buildInvoicesTab() {
    final newOrders = _orders.where((o) => o.isNew).toList();
    final allOrders = _orders;

    return Column(
      children: [
        if (newOrders.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.red.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  '${newOrders.length} فاکتور جدید',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allOrders.length,
              itemBuilder: (context, index) {
                final order = allOrders[index];
                return _buildOrderCard(order);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: order.isNew ? Colors.red.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceDetailScreen(invoice: order),
            ),
          ).then((_) => _loadOrders());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: order.isNew ? Colors.red : null,
                    ),
                  ),
                  if (order.isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'جدید',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${PersianNumber.formatPrice(order.totalAmount)} تومان',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order.isNew)
                    TextButton(
                      onPressed: () => _markOrderRead(order.id),
                      child: const Text('خوانده شد'),
                    ),
                  if (order.status == 'pending')
                    ElevatedButton(
                      onPressed: () => _confirmOrder(order.id),
                      child: const Text('تایید'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnsTab() {
    final newReturns = _returns.where((r) => r.isNew).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _returnSearchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'جستجو در مرجوعی‌ها (محصول، کد، سفارش، مشتری، علت...)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: _filterReturns,
          ),
        ),
        if (newReturns.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.red.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  '${newReturns.length} مرجوعی جدید',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadReturns,
            child: _filteredReturns.isEmpty
                ? const Center(child: Text('مرجوعی یافت نشد'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredReturns.length,
                    itemBuilder: (context, index) {
                      final returnItem = _filteredReturns[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: returnItem.isNew
                            ? Colors.red.withValues(alpha: 0.1)
                            : null,
                        child: ExpansionTile(
                          leading: returnItem.isNew
                              ? const Icon(
                                  Icons.new_releases,
                                  color: Colors.red,
                                )
                              : _getStatusIcon(returnItem.status),
                          title: Text('مرجوعی سفارش ${returnItem.orderId}'),
                          subtitle: Text(
                            'تاریخ: ${PersianDate.formatDateTime(returnItem.createdAt)}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: _getStatusBadge(returnItem.status),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Items
                                  if (returnItem.items.isNotEmpty) ...[
                                    const Text(
                                      'آیتم‌های مرجوعی:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...returnItem.items.map((item) {
                                      final itemData =
                                          item as Map<String, dynamic>;
                                      final productId =
                                          itemData['product_id'] as int?;
                                      final variationId =
                                          itemData['variation_id'] as int?;

                                      // Load product details if not already loaded
                                      if (productId != null &&
                                          !_productDetailsCache.containsKey(
                                            productId,
                                          ) &&
                                          _loadingProductDetails[productId] !=
                                              true) {
                                        _loadProductDetails(
                                          productId,
                                          variationId,
                                        );
                                      }

                                      return _buildReturnItemDetail(
                                        itemData,
                                        productId,
                                      );
                                    }),
                                    const Divider(),
                                  ],
                                  // Reason
                                  if (returnItem.reason != null &&
                                      returnItem.reason!.isNotEmpty) ...[
                                    const Text(
                                      'علت مرجوعی:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(returnItem.reason!),
                                    const SizedBox(height: 12),
                                  ],
                                  // Actions for pending returns
                                  if (returnItem.status == 'pending') ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _approveReturn(returnItem.id),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.check),
                                            label: const Text('تایید'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _rejectReturn(returnItem.id),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.close),
                                            label: const Text('رد'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstallationsTab() {
    // Show all installations (not just tomorrow's)
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadTomorrowInstallations(),
          _loadAllInstallations(),
        ]);
      },
      child: _allInstallations.isEmpty
          ? const Center(child: Text('نصبی ثبت نشده است'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allInstallations.length,
              itemBuilder: (context, index) {
                final inst = _allInstallations[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: inst.color != null
                            ? Color(
                                int.parse(
                                  inst.color!.replaceFirst('#', '0xFF'),
                                ),
                              )
                            : AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text('سفارش ${inst.orderId}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تاریخ نصب: ${PersianDate.formatDate(inst.installationDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (inst.notes != null && inst.notes!.isNotEmpty)
                          Text(
                            inst.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: inst.notes != null && inst.notes!.isNotEmpty
                        ? const Icon(Icons.note)
                        : null,
                    onTap: () {
                      if (inst.notes != null && inst.notes!.isNotEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('یادداشت نصب - سفارش ${inst.orderId}'),
                            content: Text(inst.notes!),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('بستن'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
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

  Widget _buildReturnItemDetail(Map<String, dynamic> itemData, int? productId) {
    final productDetails = productId != null
        ? _productDetailsCache[productId]
        : null;
    final isLoadingDetails =
        productId != null && _loadingProductDetails[productId] == true;

    // Get product image
    String? productImage;
    if (productDetails != null) {
      productImage = productDetails['image_url']?.toString();
    }

    // Get brand/album name
    String? brandName;
    if (productDetails != null && productDetails['brand'] != null) {
      brandName = productDetails['brand'].toString();
    }

    // Get variation pattern
    final variationPattern =
        itemData['variation_pattern']?.toString() ??
        itemData['pattern']?.toString();

    // Get variation attributes
    List<dynamic>? attributes;
    if (productDetails != null && productDetails['attributes'] != null) {
      attributes = productDetails['attributes'] as List<dynamic>?;
    }

    final quantity = itemData['quantity'] ?? 0;
    // Determine unit based on category and calculator data
    String? categoryName =
        productDetails?['category_name']?.toString() ??
        productDetails?['category']?.toString();
    final calculator = productDetails?['calculator'] as Map<String, dynamic>?;
    final calculatorUnit =
        calculator?['unit']?.toString() ?? calculator?['method']?.toString();

    final unit = ProductUnitHelper.getDisplayUnit(
      categoryName: categoryName,
      calculatorUnit: calculatorUnit,
      hasRollDimensions:
          calculator?['roll_w'] != null || calculator?['roll_width'] != null,
      hasPackageCoverage:
          calculator?['pkg_cov'] != null ||
          calculator?['package_coverage'] != null,
      hasBranchLength:
          calculator?['branch_l'] != null ||
          calculator?['branch_length'] != null,
    );

    // Calculate area coverage
    double? areaCoverage;
    if (calculator != null) {
      if (ProductUnitHelper.isParquetCategory(categoryName) ||
          ProductUnitHelper.isWallpaperCategory(categoryName)) {
        final packageCoverage =
            calculator['pkg_cov'] ??
            calculator['package_coverage'] ??
            calculator['params']?['pkg_cov'];
        if (packageCoverage != null) {
          areaCoverage = quantity * (packageCoverage as num).toDouble();
        } else if (ProductUnitHelper.isWallpaperCategory(categoryName)) {
          final rollW =
              calculator['roll_w'] ??
              calculator['roll_width'] ??
              calculator['params']?['roll_w'];
          final rollL =
              calculator['roll_l'] ??
              calculator['roll_length'] ??
              calculator['params']?['roll_l'];
          if (rollW != null && rollL != null) {
            final rollArea =
                (rollW as num).toDouble() * (rollL as num).toDouble();
            areaCoverage = quantity * rollArea;
          }
        }
      }
    }

    final productName =
        productDetails?['name']?.toString() ?? 'محصول ${productId ?? 'نامشخص'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            if (productImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: productImage,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 30),
                  ),
                ),
              )
            else if (isLoadingDetails)
              Container(
                width: 70,
                height: 70,
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Container(
                width: 70,
                height: 70,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 30),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (brandName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'برند/آلبوم: $brandName',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                  if (variationPattern != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'کد طرح: $variationPattern',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (attributes != null && attributes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: attributes.take(3).map((attr) {
                        final name = attr['name']?.toString() ?? '';
                        final value = attr['value']?.toString() ?? '';
                        if (name.isEmpty || value.isEmpty)
                          return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '$name: $value',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[800],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'تعداد: ${ProductUnitHelper.formatQuantityWithCoverage(quantity: quantity, unit: unit, areaCoverage: areaCoverage, categoryName: categoryName)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.pending, color: Colors.orange);
      case 'approved':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'rejected':
        return const Icon(Icons.cancel, color: Colors.red);
      default:
        return const Icon(Icons.help_outline);
    }
  }

  Widget _getStatusBadge(String status) {
    String statusText;
    Color statusColor;
    switch (status) {
      case 'pending':
        statusText = 'در انتظار';
        statusColor = Colors.orange;
        break;
      case 'approved':
        statusText = 'تایید شده';
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusText = 'رد شده';
        statusColor = Colors.red;
        break;
      default:
        statusText = status;
        statusColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _approveReturn(int returnId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تایید مرجوعی'),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید این درخواست مرجوعی را تایید کنید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تایید'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _returnService.approveReturn(returnId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مرجوعی با موفقیت تایید شد')),
          );
          _loadReturns();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('خطا در تایید مرجوعی')));
        }
      }
    }
  }

  Future<void> _rejectReturn(int returnId) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رد مرجوعی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('علت رد را وارد کنید (اختیاری):'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'علت رد...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رد'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _returnService.rejectReturn(
        returnId,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('مرجوعی رد شد')));
          _loadReturns();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('خطا در رد مرجوعی')));
        }
      }
    }
  }

  void _showOrderDetails(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(order.orderNumber),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'مبلغ: ${PersianNumber.formatPrice(order.totalAmount)} تومان',
              ),
              Text('وضعیت: ${_getStatusText(order.status)}'),
              if (order.installationDate != null)
                Text(
                  'تاریخ نصب: ${PersianDate.formatDate(order.installationDate!)}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
          if (order.status == 'pending')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmOrder(order.id);
              },
              child: const Text('تایید سفارش'),
            ),
        ],
      ),
    );
  }
}
