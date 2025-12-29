// Invoice Detail Screen - Full invoice view with PDF generation
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../utils/persian_number.dart';
import '../../utils/persian_date.dart';
import '../../utils/app_colors.dart';
import '../../utils/product_unit_display.dart';
import '../../utils/status_labels.dart';
import '../../services/aggregated_pdf_service.dart';
import '../../services/company_service.dart';
import '../../services/product_service.dart';
import '../../services/order_service.dart';
import '../../pages/returns/return_request_screen.dart';
import 'invoice_edit_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import 'dart:typed_data';

class InvoiceDetailScreen extends StatefulWidget {
  final OrderModel invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  bool _isGeneratingPdf = false;
  bool _isLoadingBrands = false;
  bool _isLoadingInvoice = false;
  OrderModel? _currentInvoice;
  final ProductService _productService = ProductService();

  // Cache for brand data per product
  final Map<int, String?> _productBrandCache = {};
  // Cache for full product details
  final Map<int, Map<String, dynamic>> _productDetailsCache = {};
  final Map<int, bool> _loadingProductDetails = {};

  /// Get unique brands from order items
  Future<Map<String, List<OrderItemModel>>> _getItemsByBrand() async {
    final Map<String, List<OrderItemModel>> brandItems = {};

    for (final item in widget.invoice.items) {
      String? brand = item.effectiveBrand;

      // If no brand, try to fetch from secure API
      if (brand == null && !_productBrandCache.containsKey(item.productId)) {
        try {
          final data = await _productService.getProductFromSecureAPI(
            item.productId,
          );
          if (data != null && data['brand'] != null) {
            brand = data['brand'].toString();
            _productBrandCache[item.productId] = brand;
          } else {
            _productBrandCache[item.productId] = null;
          }
        } catch (e) {
          print('⚠️ Error fetching brand for product ${item.productId}: $e');
          _productBrandCache[item.productId] = null;
        }
      } else if (_productBrandCache.containsKey(item.productId)) {
        brand = _productBrandCache[item.productId];
      }

      // Use a default brand name if still null
      final brandKey = brand ?? 'بدون برند';

      if (!brandItems.containsKey(brandKey)) {
        brandItems[brandKey] = [];
      }
      brandItems[brandKey]!.add(item.copyWithBrand(brand));
    }

    return brandItems;
  }

  Future<void> _shareInvoiceAsPdf() async {
    setState(() {
      _isLoadingBrands = true;
    });

    try {
      // Get items grouped by brand
      final brandItems = await _getItemsByBrand();

      setState(() {
        _isLoadingBrands = false;
      });

      // If only one brand, generate PDF directly
      if (brandItems.length == 1) {
        await _generateAndSharePdf(
          brandItems.keys.first,
          brandItems.values.first,
        );
        return;
      }

      // Multiple brands - show selection dialog
      if (!mounted) return;

      final selectedBrand = await showDialog<String>(
        context: context,
        builder: (context) => _buildBrandSelectionDialog(brandItems),
      );

      if (selectedBrand != null && mounted) {
        await _generateAndSharePdf(selectedBrand, brandItems[selectedBrand]!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBrands = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری اطلاعات برند: $e')),
        );
      }
    }
  }

  Widget _buildBrandSelectionDialog(
    Map<String, List<OrderItemModel>> brandItems,
  ) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.business, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('انتخاب برند برای فاکتور'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'این فاکتور شامل محصولات چند برند است. لطفاً برند مورد نظر را برای تولید فاکتور انتخاب کنید:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...brandItems.entries.map((entry) {
                final brand = entry.key;
                final items = entry.value;
                final itemCount = items.length;
                final totalAmount = items.fold<double>(
                  0,
                  (sum, item) => sum + item.total,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                      child: const Icon(
                        Icons.category,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    title: Text(
                      brand,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '$itemCount محصول - ${PersianNumber.formatPrice(totalAmount)} تومان',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.pop(context, brand),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, '__ALL__'),
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('همه برندها'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSharePdf(
    String brandName,
    List<OrderItemModel> items,
  ) async {
    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      // Get company info for logo
      CompanyModel? company;
      if (widget.invoice.companyId != null) {
        final companyService = CompanyService();
        final companies = await companyService.getCompanies();
        company = companies.firstWhere(
          (c) => c.id == widget.invoice.companyId,
          orElse: () => CompanyModel(
            id: 0,
            name: brandName == '__ALL__' ? 'تزئین دکور' : brandName,
            createdAt: DateTime.now(),
          ),
        );
      }

      final Uint8List pdfBytes;
      final String fileName;

      if (brandName == '__ALL__') {
        // Generate full invoice with all items using improved service
        pdfBytes = await AggregatedPdfService.generateSingleInvoicePdf(
          invoice: widget.invoice,
          company: company,
        );
        fileName = 'invoice_${widget.invoice.effectiveInvoiceNumber}.pdf';
      } else {
        // Generate brand-specific invoice using improved service
        pdfBytes = await AggregatedPdfService.generateSingleBrandInvoicePdf(
          invoice: widget.invoice,
          brandName: brandName,
          brandItems: items,
          company: company,
        );
        // Sanitize brand name for filename
        final safeBrandName = brandName.replaceAll(
          RegExp(r'[^\w\u0600-\u06FF]'),
          '_',
        );
        fileName =
            'invoice_${widget.invoice.effectiveInvoiceNumber}_$safeBrandName.pdf';
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      // Verify file was created
      if (!await file.exists()) {
        throw Exception('فایل PDF ایجاد نشد');
      }

      // Share the file
      final shareText = brandName == '__ALL__'
          ? 'فاکتور ${widget.invoice.effectiveInvoiceNumber}'
          : 'فاکتور ${widget.invoice.effectiveInvoiceNumber} - $brandName';

      // Share the file - this will open the system share dialog
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
      );
      
      // Note: Share.shareXFiles doesn't return a result in all versions
      // The file is successfully created and shared if no exception is thrown
    } catch (e) {
      print('❌ PDF generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text('خطا در تولید PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<void> _updateInvoiceStatus(String status) async {
    final invoiceProvider = Provider.of<InvoiceProvider>(
      context,
      listen: false,
    );

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('در حال به‌روزرسانی...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final success = await invoiceProvider.updateInvoiceStatus(
      widget.invoice.id,
      status,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('وضعیت فاکتور به‌روزرسانی شد'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload invoice data
        final updatedInvoice = await invoiceProvider.getInvoice(
          widget.invoice.id,
        );
        if (updatedInvoice != null && mounted) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final errorMessage = invoiceProvider.error ?? 'خطای نامشخص';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _editInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceEditScreen(invoice: widget.invoice),
      ),
    ).then((_) {
      if (mounted) {
        // Reload invoice
        final invoiceProvider = Provider.of<InvoiceProvider>(
          context,
          listen: false,
        );
        invoiceProvider.getInvoice(widget.invoice.id).then((_) {
          setState(() {});
        });
      }
    });
  }

  Future<void> _deleteInvoice() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فاکتور'),
        content: const Text(
          'آیا از حذف این فاکتور اطمینان دارید؟ این عمل قابل بازگشت نیست.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('در حال حذف...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final orderService = OrderService();
      final success = await orderService.deleteOrder(widget.invoice.id);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فاکتور با موفقیت حذف شد'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return to previous screen
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطا در حذف فاکتور'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_completion':
        return Colors.white;
      case 'in_progress':
        return Colors.yellow;
      case 'settled':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    return StatusLabels.getOrderStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('فاکتور ${invoice.effectiveInvoiceNumber}'),
          actions: [
            IconButton(
              icon: (_isGeneratingPdf || _isLoadingBrands)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              onPressed: (_isGeneratingPdf || _isLoadingBrands)
                  ? null
                  : _shareInvoiceAsPdf,
              tooltip: 'اشتراک‌گذاری PDF',
            ),
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final user = authProvider.user;
                if (user == null) return const SizedBox.shrink();

                // Show edit and delete buttons for Clerk (operator) or admin
                if (user.isOperator || user.isAdmin) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _editInvoice,
                    tooltip: 'ویرایش فاکتور',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: _deleteInvoice,
                        tooltip: 'حذف فاکتور',
                        color: Colors.red,
                      ),
                    ],
                  );
                }

                // Show edit request button for Seller/Manager
                if (user.isSeller || user.isStoreManager) {
                  return IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _editInvoice,
                    tooltip: 'درخواست ویرایش',
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and action buttons
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  final user = authProvider.user;
                  if (user == null) return const SizedBox.shrink();

                  // Clerk (operator) actions
                  if (user.isOperator || user.isAdmin) {
                    return _buildClerkActions();
                  }

                  // Seller/Manager view
                  if (user.isSeller || user.isStoreManager) {
                    return Column(
                      children: [
                        _buildSellerManagerView(),
                        const SizedBox(height: 12),
                        // Return request button
                        if (invoice.status != 'returned' &&
                            invoice.status != 'cancelled')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReturnRequestScreen(
                                      order: widget.invoice,
                                    ),
                                  ),
                                );
                                if (result == true && mounted) {
                                  Navigator.pop(context, true);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 16),

              // Invoice Header
              _buildInvoiceHeader(),
              const SizedBox(height: 16),

              // Show loading indicator if refreshing invoice data
              if (_isLoadingInvoice)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Customer Info
              _buildCustomerInfo(),
              const SizedBox(height: 16),

              // Items Table
              _buildItemsTable(),
              const SizedBox(height: 16),

              // Totals
              _buildTotals(),
              const SizedBox(height: 16),

              // Payment Terms and Notes
              if (invoice.paymentTerms != null || invoice.notes != null)
                _buildPaymentTermsAndNotes(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClerkActions() {
    return Card(
      color: AppColors.primaryBlue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'عملیات فاکتور',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _updateInvoiceStatus('pending_completion'),
                  icon: const Icon(Icons.pending, size: 18),
                  label: const Text('در انتظار تکمیل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _updateInvoiceStatus('in_progress'),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('تایید سفارش'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _updateInvoiceStatus('settled'),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('تسویه شده'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerManagerView() {
    return Card(
      color: Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'وضعیت: ${_getStatusText(invoice.status)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (invoice.editRequestedBy != null)
                    Text(
                      'درخواست ویرایش در انتظار تایید',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _editInvoice,
              icon: const Icon(Icons.edit),
              label: const Text('درخواست ویرایش'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شماره فاکتور: ${invoice.effectiveInvoiceNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (invoice.issueDate != null)
                        Text(
                          'تاریخ صدور: ${PersianDate.formatDate(invoice.issueDate!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      if (invoice.dueDate != null)
                        Text(
                          'تاریخ سررسید: ${PersianDate.formatDate(invoice.dueDate!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(invoice.status),
                    borderRadius: BorderRadius.circular(8),
                    border: invoice.status == 'pending_completion'
                        ? Border.all(color: Colors.grey.shade300)
                        : null,
                  ),
                  child: Text(
                    _getStatusText(invoice.status),
                    style: TextStyle(
                      color: invoice.status == 'settled'
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اطلاعات مشتری و سفارش',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Customer Details Section - Always show section, even if some fields are null
            const Text(
              'اطلاعات مشتری:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'نام و نام خانوادگی:',
              invoice.customerName ?? 'نامشخص',
            ),
            _buildInfoRow('شماره تماس:', invoice.customerMobile ?? 'نامشخص'),
            _buildInfoRow('آدرس:', invoice.customerAddress ?? 'آدرس ثبت نشده'),
            const SizedBox(height: 16),

            // Order Details Section
            const Text(
              'جزئیات سفارش:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('شماره سفارش:', invoice.orderNumber),
            _buildInfoRow(
              'تاریخ ایجاد:',
              PersianDate.formatDateTime(invoice.createdAt),
            ),

            // Installation Date - Always show
            const SizedBox(height: 8),
            _buildInfoRow(
              'تاریخ نصب:',
              invoice.installationDate != null
                  ? PersianDate.formatDate(invoice.installationDate!)
                  : 'تعیین نشده',
            ),

            // Payment Method - Always show
            const SizedBox(height: 8),
            _buildInfoRow(
              'شیوه پرداخت:',
              invoice.paymentMethod != null
                  ? StatusLabels.getPaymentMethod(invoice.paymentMethod)
                  : 'نامشخص',
            ),

            // Delivery Method - Always show
            const SizedBox(height: 8),
            _buildInfoRow(
              'شیوه ارسال:',
              invoice.deliveryMethod != null
                  ? StatusLabels.getDeliveryMethod(invoice.deliveryMethod)
                  : 'نامشخص',
            ),

            // Installation Notes
            if (invoice.installationNotes != null &&
                invoice.installationNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow('یادداشت نصب:', invoice.installationNotes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;

    // Always ensure we have items from the original invoice
    print(
      '🔍 initState - widget.invoice.items.length: ${widget.invoice.items.length}',
    );

    // Load fresh invoice data to get customer details and all fields
    _loadInvoiceData();

    // Load product details for all items using secure API to get colleague_price and complete info
    // Use original invoice items to ensure they're always available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print(
        '🔍 PostFrameCallback - Loading product details for ${widget.invoice.items.length} items',
      );
      if (widget.invoice.items.isEmpty) {
        print('   ⚠️  No items in widget.invoice, will load after _loadInvoiceData completes');
        return;
      }
      for (final item in widget.invoice.items) {
        print('   - Loading details for product ${item.productId}');
        // Always load product details from secure API to get colleague_price and complete product information
        _loadProductDetails(item.productId, item.variationId);
      }
    });
  }

  Future<void> _loadInvoiceData() async {
    setState(() {
      _isLoadingInvoice = true;
    });

    try {
      final invoiceProvider = Provider.of<InvoiceProvider>(
        context,
        listen: false,
      );
      final updatedInvoice = await invoiceProvider.getInvoice(
        widget.invoice.id,
      );

      print('🔍 Invoice data loaded:');
      print('   - updatedInvoice: ${updatedInvoice != null}');
      if (updatedInvoice != null) {
        print('   - items count: ${updatedInvoice.items.length}');
        print('   - customerName: ${updatedInvoice.customerName}');
        print('   - paymentMethod: ${updatedInvoice.paymentMethod}');
        print('   - deliveryMethod: ${updatedInvoice.deliveryMethod}');
      }

      if (updatedInvoice != null && mounted) {
        // If updated invoice has no items but original has items, preserve original items
        final itemsToUse = updatedInvoice.items.isNotEmpty
            ? updatedInvoice.items
            : widget.invoice.items;

        print('   - Using items: ${itemsToUse.length} items');

        // Create invoice with preserved items if needed
        final finalInvoice = updatedInvoice.items.isNotEmpty
            ? updatedInvoice
            : OrderModel(
                id: updatedInvoice.id,
                orderNumber: updatedInvoice.orderNumber,
                sellerId: updatedInvoice.sellerId,
                customerId: updatedInvoice.customerId,
                companyId: updatedInvoice.companyId,
                status: updatedInvoice.status,
                paymentMethod: updatedInvoice.paymentMethod,
                deliveryMethod: updatedInvoice.deliveryMethod,
                installationDate: updatedInvoice.installationDate,
                installationNotes: updatedInvoice.installationNotes,
                totalAmount: updatedInvoice.totalAmount,
                wholesaleAmount: updatedInvoice.wholesaleAmount,
                notes: updatedInvoice.notes,
                isNew: updatedInvoice.isNew,
                createdAt: updatedInvoice.createdAt,
                items: widget.invoice.items, // Preserve original items
                invoiceNumber: updatedInvoice.invoiceNumber,
                issueDate: updatedInvoice.issueDate,
                dueDate: updatedInvoice.dueDate,
                subtotal: updatedInvoice.subtotal,
                taxAmount: updatedInvoice.taxAmount,
                discountAmount: updatedInvoice.discountAmount,
                paymentTerms: updatedInvoice.paymentTerms,
                editRequestedBy: updatedInvoice.editRequestedBy,
                editRequestedAt: updatedInvoice.editRequestedAt,
                editApprovedBy: updatedInvoice.editApprovedBy,
                editApprovedAt: updatedInvoice.editApprovedAt,
                customerName: updatedInvoice.customerName,
                customerMobile: updatedInvoice.customerMobile,
                customerAddress: updatedInvoice.customerAddress,
              );

        setState(() {
          _currentInvoice = finalInvoice;
          _isLoadingInvoice = false;
        });

        // Always load product details for all items from original invoice
        // This ensures we fetch colleague_price, brand, SKU, image from secure API
        // Use itemsToUse (which may be from updatedInvoice or widget.invoice)
        print(
          '   🔄 Loading product details for ${itemsToUse.length} items',
        );
        for (final item in itemsToUse) {
          print('   - Loading details for product ${item.productId}');
          _loadProductDetails(item.productId, item.variationId);
        }
      } else {
        setState(() {
          _isLoadingInvoice = false;
        });
      }
    } catch (e) {
      print('❌ Error loading invoice data: $e');
      if (mounted) {
        setState(() {
          _isLoadingInvoice = false;
        });
      }
    }
  }

  OrderModel get invoice {
    // CRITICAL: Always use original invoice items to ensure they're always available
    // The backend might not return items in the refreshed invoice, so we always preserve original items
    final itemsToUse = widget.invoice.items.isNotEmpty
        ? widget.invoice.items
        : (_currentInvoice?.items ?? []);

    print('🔍 Invoice getter:');
    print('   - widget.invoice.items.length: ${widget.invoice.items.length}');
    print(
      '   - _currentInvoice?.items.length: ${_currentInvoice?.items.length ?? 0}',
    );
    print('   - itemsToUse.length: ${itemsToUse.length}');

    // If we have a refreshed invoice, merge its data but always use original items
    if (_currentInvoice != null) {
      return OrderModel(
        id: _currentInvoice!.id,
        orderNumber: _currentInvoice!.orderNumber,
        sellerId: _currentInvoice!.sellerId,
        customerId: _currentInvoice!.customerId,
        companyId: _currentInvoice!.companyId,
        status: _currentInvoice!.status,
        paymentMethod: _currentInvoice!.paymentMethod,
        deliveryMethod: _currentInvoice!.deliveryMethod,
        installationDate: _currentInvoice!.installationDate,
        installationNotes: _currentInvoice!.installationNotes,
        totalAmount: _currentInvoice!.totalAmount,
        wholesaleAmount: _currentInvoice!.wholesaleAmount,
        notes: _currentInvoice!.notes,
        isNew: _currentInvoice!.isNew,
        createdAt: _currentInvoice!.createdAt,
        items: itemsToUse, // Always use original items from widget.invoice
        invoiceNumber: _currentInvoice!.invoiceNumber,
        issueDate: _currentInvoice!.issueDate,
        dueDate: _currentInvoice!.dueDate,
        subtotal: _currentInvoice!.subtotal,
        taxAmount: _currentInvoice!.taxAmount,
        discountAmount: _currentInvoice!.discountAmount,
        paymentTerms: _currentInvoice!.paymentTerms,
        editRequestedBy: _currentInvoice!.editRequestedBy,
        editRequestedAt: _currentInvoice!.editRequestedAt,
        editApprovedBy: _currentInvoice!.editApprovedBy,
        editApprovedAt: _currentInvoice!.editApprovedAt,
        customerName: _currentInvoice!.customerName,
        customerMobile: _currentInvoice!.customerMobile,
        customerAddress: _currentInvoice!.customerAddress,
      );
    }
    // If no refreshed invoice, return original (which should always have items)
    return widget.invoice;
  }

  /// Load product details from secure WooCommerce API
  ///
  /// This method fetches complete product information from the secure API endpoint:
  /// GET /wp-json/hooshmate/v1/product/{PRODUCT_ID}
  /// with header: x-api-key: midia@2025_SecureKey_#98765
  ///
  /// The fetched data includes:
  /// - Product name
  /// - Wholesale/cooperation price (colleague_price)
  /// - Brand
  /// - Product code/SKU
  /// - Product image (image_url)
  /// - Calculator data (if available)
  /// - Any other relevant fields
  ///
  /// The data is cached in _productDetailsCache to avoid redundant API calls.
  Future<void> _loadProductDetails(int productId, int? variationId) async {
    if (_productDetailsCache.containsKey(productId) ||
        _loadingProductDetails[productId] == true) {
      print('   ⏭️  Skipping product $productId - already loaded or loading');
      return; // Already loaded or loading
    }

    print('   🔄 Loading product details for productId: $productId');
    setState(() {
      _loadingProductDetails[productId] = true;
    });

    try {
      // Fetch from secure API: GET /wp-json/hooshmate/v1/product/{PRODUCT_ID}
      // with header: x-api-key: midia@2025_SecureKey_#98765
      final data = await _productService.getProductFromSecureAPI(productId);
      print(
        '   📦 Received data for product $productId: ${data?.keys.toList()}',
      );
      if (mounted && data != null) {
        print('   ✅ Caching product $productId data');
        setState(() {
          _productDetailsCache[productId] = data;
          _loadingProductDetails[productId] = false;
          // Also cache brand if available
          if (data['brand'] != null) {
            _productBrandCache[productId] = data['brand'].toString();
          }
          if (data['colleague_price'] != null) {
            print('   💰 Found colleague_price: ${data['colleague_price']}');
          }
        });
      } else {
        print('   ⚠️  No data received for product $productId');
        setState(() {
          _loadingProductDetails[productId] = false;
        });
      }
    } catch (e) {
      print('❌ Error loading product details for $productId: $e');
      if (mounted) {
        setState(() {
          _loadingProductDetails[productId] = false;
        });
      }
    }
  }

  Widget _buildItemsTable() {
    // Debug logging
    print('🔍 _buildItemsTable called');
    print('   - invoice.items.length: ${invoice.items.length}');
    print(
      '   - _productDetailsCache keys: ${_productDetailsCache.keys.toList()}',
    );

    if (invoice.items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'محصولی در این سفارش وجود ندارد',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
              'جدول محصولات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${invoice.items.length} محصول',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Use ListView for better display with full product details
          ...invoice.items.map((item) {
            print('   - Building card for product ${item.productId}');
            return _buildItemCard(item);
          }),
        ],
      ),
    );
  }

  Widget _buildItemCard(OrderItemModel item) {
    // Get product details from cache or item
    final productDetails = _productDetailsCache[item.productId];
    final isLoadingDetails = _loadingProductDetails[item.productId] == true;

    // Get product name - prefer from cache, then from item, then fallback
    final productName =
        productDetails?['name']?.toString() ??
        item.product?.name ??
        'محصول ${item.productId}';

    // Get brand - prefer from cache, then from item
    final brand = productDetails?['brand']?.toString() ?? item.effectiveBrand;

    // Get variation pattern
    final variationPattern = item.variationPattern;

    // Get product image - prefer from cache, then from item
    String? productImageUrl =
        productDetails?['image_url']?.toString() ??
        productDetails?['image']?.toString() ??
        item.product?.imageUrl;

    // Get variation image if available
    if (productDetails != null && productDetails['variations'] != null) {
      final variations = productDetails['variations'] as List<dynamic>?;
      if (variations != null && item.variationId != null) {
        final variation = variations.firstWhere(
          (v) => v['id'] == item.variationId,
          orElse: () => null,
        );
        if (variation != null && variation['image'] != null) {
          productImageUrl = variation['image'].toString();
        }
      }
    }

    // Get SKU/Product Code
    final productSku =
        productDetails?['sku']?.toString() ??
        item.product?.sku ??
        'SKU-${item.productId}';

    // Get wholesale/cooperation price (colleague_price) from secure API
    // Safely convert to double (handles both num and String types)
    // Also try to get from item.product.colleaguePrice as fallback
    double? colleaguePrice;
    if (productDetails?['colleague_price'] != null) {
      final value = productDetails!['colleague_price'];
      if (value is num) {
        colleaguePrice = value.toDouble();
      } else if (value is String) {
        colleaguePrice = double.tryParse(value);
      }
    } else if (item.product?.colleaguePrice != null) {
      // Fallback to item.product.colleaguePrice if not in cache yet
      colleaguePrice = item.product!.colleaguePrice;
    } else if (item.price > 0) {
      // Final fallback: use item.price (which should be cooperation price from backend)
      colleaguePrice = item.price;
    }

    final quantity = item.quantity;

    // Get calculator data from secure API response
    final calculator = productDetails?['calculator'] as Map<String, dynamic>?;
    final apiUnit = ProductUnitDisplay.getUnitFromCalculator(calculator);

    // Note: Line total will be calculated in the Consumer below with user discounts applied
    // This ensures consistency with the totals calculation

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        final isAdminOrOperator =
            user?.isOperator == true || user?.isAdmin == true;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 2,
          child: Padding(
      padding: const EdgeInsets.all(12),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image - larger size for better visibility
          if (isLoadingDetails)
            Container(
                        width: 100,
                        height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                            width: 24,
                            height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (productImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                productImageUrl,
                          width: 100,
                          height: 100,
                fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 100,
                                height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                                  size: 40,
                  ),
                ),
              ),
            )
          else
            Container(
                        width: 100,
                        height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
                        child: const Icon(
                          Icons.inventory_2,
                          color: Colors.grey,
                          size: 40,
                        ),
            ),
          const SizedBox(width: 12),
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                          // Product name
                Text(
                  productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                              fontSize: 16,
                  ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                ),
                          const SizedBox(height: 8),
                // Brand
                if (brand != null && brand.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                  Text(
                    'برند: $brand',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // SKU/Product Code
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.qr_code,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'کد محصول: $productSku',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                  ),
                // Variation pattern (کد ویژگی/طرح)
                          if (variationPattern != null &&
                              variationPattern.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.pattern,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                  Text(
                    'کد ویژگی/طرح: $variationPattern',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Quantity
                          Builder(
                            builder: (context) {
                              final coverageStr = ProductUnitDisplay.formatCoverage(
                                quantity: quantity,
                                apiUnit: apiUnit,
                                calculator: calculator,
                              );
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Unit row
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.shopping_cart,
                                          size: 14,
                                          color: AppColors.primaryBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'تعداد: ${ProductUnitDisplay.formatQuantityWithUnit(quantity: quantity, apiUnit: apiUnit)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryBlue,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Coverage row (متراژ) - only show if available
                                    if (coverageStr != null && coverageStr.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 18.0, top: 4.0),
                                        child: Text(
                                          coverageStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.primaryBlue.withOpacity(0.8),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Price information section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Unit price section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                            'قیمت واحد:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // ALWAYS use colleague_price if available, otherwise hide price
                          if (colleaguePrice != null)
                            Text(
                              PersianNumber.formatPrice(colleaguePrice),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            const Text(
                              'قیمت در دسترس نیست',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          // Show wholesale/cooperation price label for admin/operator (already using colleaguePrice above)
                          if (isAdminOrOperator && colleaguePrice != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green[300]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'قیمت همکاری (واحد):',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    PersianNumber.formatPrice(colleaguePrice),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
              ],
            ),
          ),
                    const SizedBox(width: 16),
                    // Line total section
                    Expanded(
                      child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                            'جمع کل:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // ALWAYS use lineTotal calculated from colleaguePrice with discounts
                          if (colleaguePrice != null)
                            Builder(
                              builder: (context) {
                                // Apply discount if user has discount percentage (same as totals calculation)
                                if (colleaguePrice == null) {
                                  return Text(
                                    PersianNumber.formatPrice(item.total),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue,
                                    ),
                                  );
                                }
                                double finalPrice = colleaguePrice;
                                if (user?.discountPercentage != null && user!.discountPercentage! > 0) {
                                  final discountAmount = colleaguePrice * (user.discountPercentage! / 100.0);
                                  finalPrice = colleaguePrice - discountAmount;
                                }
                                final adjustedLineTotal = finalPrice * quantity;
                                
                                return Text(
                                  PersianNumber.formatPrice(adjustedLineTotal),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryBlue,
                                  ),
                                );
                              },
                            )
                          else
                            const Text(
                              'قیمت در دسترس نیست',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          // Show wholesale line total label for admin/operator (already using lineTotal above)
                          if (isAdminOrOperator && colleaguePrice != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green[300]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
              Text(
                                    'جمع کل همکاری:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Builder(
                                    builder: (context) {
                                      // Apply discount if user has discount percentage (same as totals calculation)
                                      if (colleaguePrice == null) {
                                        return Text(
                                          PersianNumber.formatPrice(item.total),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }
                                      double finalPrice = colleaguePrice;
                                      if (user?.discountPercentage != null && user!.discountPercentage! > 0) {
                                        final discountAmount = colleaguePrice * (user.discountPercentage! / 100.0);
                                        finalPrice = colleaguePrice - discountAmount;
                                      }
                                      final adjustedLineTotal = finalPrice * quantity;
                                      
                                      return Text(
                                        PersianNumber.formatPrice(adjustedLineTotal),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotals() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        
        // Calculate the sum of all line items using colleaguePrice (cooperation price)
        // This ensures the grand total matches the sum of displayed line item totals
        double calculatedSubtotal = 0.0;
        for (final item in invoice.items) {
          final productDetails = _productDetailsCache[item.productId];
          double? colleaguePrice;
          
          // Get colleague_price from cache (same as used in line items)
          if (productDetails?['colleague_price'] != null) {
            final value = productDetails!['colleague_price'];
            if (value is num) {
              colleaguePrice = value.toDouble();
            } else if (value is String) {
              colleaguePrice = double.tryParse(value);
            }
          }
          
          // Calculate line total (same logic as in _buildItemCard)
          if (colleaguePrice != null) {
            // Apply discount if user has discount percentage (same as cart screen)
            double finalPrice = colleaguePrice;
            if (user?.discountPercentage != null && user!.discountPercentage! > 0) {
              final discountAmount = colleaguePrice * (user.discountPercentage! / 100.0);
              finalPrice = colleaguePrice - discountAmount;
            }
            calculatedSubtotal += finalPrice * item.quantity;
          } else {
            // Fallback to item.total if colleaguePrice not available
            calculatedSubtotal += item.total;
          }
        }
        
        // Use calculated subtotal (sum of line items) as the base amount
        // Only use wholesaleAmount (cooperation price), never retail price
        final baseAmount = calculatedSubtotal > 0 ? calculatedSubtotal : (invoice.wholesaleAmount ?? 0.0);
        final taxAmount = invoice.taxAmount;
        final discountAmount = invoice.discountAmount;
        
        // Calculate final total: baseAmount (sum of line items) + tax - discount
        // Note: If discounts are already applied in line items (via user discountPercentage),
        // then discountAmount here should be 0 or already accounted for
        final grandTotal = baseAmount + taxAmount - discountAmount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTotalRow('جمع کل:', baseAmount),
            if (taxAmount > 0)
              _buildTotalRow('مالیات:', taxAmount, isPositive: true),
            if (discountAmount > 0)
              _buildTotalRow('تخفیف:', discountAmount, isPositive: false),
            const Divider(),
            _buildTotalRow('مبلغ نهایی:', grandTotal, isGrandTotal: true),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isPositive = true,
    bool isGrandTotal = false,
    bool isWholesale = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isGrandTotal ? 18 : 14,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${isPositive ? '+' : '-'}${PersianNumber.formatPrice(amount)} تومان',
            style: TextStyle(
              fontSize: isGrandTotal ? 18 : 14,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
              color: isGrandTotal
                  ? AppColors.primaryBlue
                  : (isWholesale ? Colors.green[700] : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTermsAndNotes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invoice.paymentTerms != null) ...[
              const Text(
                'شرایط پرداخت',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                invoice.paymentTerms!,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              if (invoice.notes != null) const SizedBox(height: 16),
            ],
            if (invoice.notes != null) ...[
              const Text(
                'یادداشت‌ها',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                invoice.notes!,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
