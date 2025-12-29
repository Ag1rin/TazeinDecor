// Invoices Screen - Display all orders as invoices with state filtering
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../utils/persian_date.dart';
import '../../utils/app_colors.dart';
import '../../utils/status_labels.dart';
import '../../utils/jalali_date.dart';
import '../../widgets/jalali_date_picker.dart';
import '../../services/order_service.dart';
import '../../services/aggregated_pdf_service.dart';
import '../../services/company_service.dart';
import 'invoice_detail_screen.dart';
import 'package:printing/printing.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:typed_data';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OrderService _orderService = OrderService();
  final CompanyService _companyService = CompanyService();
  String? _selectedStatus;
  JalaliDate? _startDate;
  JalaliDate? _endDate;
  bool _isGeneratingPdfs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final invoiceProvider = Provider.of<InvoiceProvider>(
      context,
      listen: false,
    );
    await invoiceProvider.loadInvoices(status: _selectedStatus);
  }

  Future<void> _searchInvoices() async {
    final invoiceProvider = Provider.of<InvoiceProvider>(
      context,
      listen: false,
    );
    await invoiceProvider.searchInvoices(
      query: _searchController.text.isEmpty ? null : _searchController.text,
      status: _selectedStatus,
      startDate: _startDate?.toDateTime().toIso8601String(),
      endDate: _endDate?.toDateTime().toIso8601String(),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_completion':
        return Colors.white;
      case 'in_progress':
        return Colors.yellow;
      case 'settled':
        return Colors.purple;
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'returned':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
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
          title: const Text('فاکتورها'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => _buildSearchDialog(),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Status filter chips
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('همه', _selectedStatus == null),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'در انتظار تکمیل',
                      _selectedStatus == 'pending_completion',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'در حال انجام',
                      _selectedStatus == 'in_progress',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip('تسویه شده', _selectedStatus == 'settled'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Invoices list
            Expanded(
              child: Consumer<InvoiceProvider>(
                builder: (context, invoiceProvider, _) {
                  if (invoiceProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (invoiceProvider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            invoiceProvider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadInvoices,
                            child: const Text('تلاش مجدد'),
                          ),
                        ],
                      ),
                    );
                  }

                  final invoices = invoiceProvider.invoices;
                  if (invoices.isEmpty) {
                    return const Center(child: Text('فاکتوری یافت نشد'));
                  }

                  return RefreshIndicator(
                    onRefresh: _loadInvoices,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = invoices[index];
                        return _buildInvoiceCard(invoice);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // FAB for date selection and aggregated PDF generation - visible for Operator and Admin roles
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.user;
            // Debug logging
            print(
              '🔍 FAB check - user: ${user?.fullName}, role: ${user?.role}, isOperator: ${user?.isOperator}, isAdmin: ${user?.isAdmin}',
            );

            // Show FAB if user is Operator or Admin
            if (user == null) {
              print('   ❌ FAB hidden: user is null');
              return const SizedBox.shrink();
            }
            if (user.isOperator != true && user.isAdmin != true) {
              print('   ❌ FAB hidden: user is not operator or admin');
              return const SizedBox.shrink(); // Hide FAB for non-operators/admins
            }
            print('   ✅ FAB visible for ${user.role}');
            return FloatingActionButton(
              onPressed: _isGeneratingPdfs
                  ? null
                  : () {
                      print('🔍 FAB pressed - showing date filter dialog');
                      _showDateFilterDialog();
                    },
              backgroundColor: _isGeneratingPdfs
                  ? Colors.grey
                  : AppColors.primaryBlue,
              tooltip: 'فیلتر بر اساس تاریخ و تولید PDF',
              child: _isGeneratingPdfs
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.filter_alt),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (label == 'همه') {
            _selectedStatus = null;
          } else {
            switch (label) {
              case 'در انتظار تکمیل':
                _selectedStatus = 'pending_completion';
                break;
              case 'در حال انجام':
                _selectedStatus = 'in_progress';
                break;
              case 'تسویه شده':
                _selectedStatus = 'settled';
                break;
            }
          }
        });
        _loadInvoices();
      },
      selectedColor: AppColors.primaryBlue,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildInvoiceCard(OrderModel invoice) {
    final statusColor = _getStatusColor(invoice.status);
    final isDarkStatus =
        invoice.status == 'settled' ||
        invoice.status == 'delivered' ||
        invoice.status == 'returned';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceDetailScreen(invoice: invoice),
            ),
          ).then((_) => _loadInvoices());
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: statusColor, width: 4)),
          ),
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
                            'فاکتور: ${invoice.effectiveInvoiceNumber}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (invoice.issueDate != null)
                            Text(
                              'تاریخ صدور: ${PersianDate.formatDate(invoice.issueDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                        border: invoice.status == 'pending_completion'
                            ? Border.all(color: Colors.grey.shade300)
                            : null,
                      ),
                      child: Text(
                        _getStatusText(invoice.status),
                        style: TextStyle(
                          color: isDarkStatus ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (invoice.dueDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تاریخ سررسید:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        PersianDate.formatDate(invoice.dueDate!),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchDialog() {
    return AlertDialog(
      title: const Text('جستجوی فاکتور'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'شماره فاکتور، مشتری یا...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final now = JalaliDate.now();
                      final date = await showJalaliDatePicker(
                        context: context,
                        initialDate: _startDate ?? now,
                        firstDate: JalaliDate(1400, 1, 1),
                        lastDate: now, // Only allow dates up to today
                      );
                      if (date != null) {
                        setState(() {
                          _startDate = date;
                        });
                      }
                    },
                    child: Text(
                      _startDate != null
                          ? _startDate!.formatPersian()
                          : 'از تاریخ',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final now = JalaliDate.now();
                      final date = await showJalaliDatePicker(
                        context: context,
                        initialDate: _endDate ?? now,
                        firstDate: _startDate ?? JalaliDate(1400, 1, 1),
                        lastDate: now, // Only allow dates up to today
                      );
                      if (date != null) {
                        setState(() {
                          _endDate = date;
                        });
                      }
                    },
                    child: Text(
                      _endDate != null ? _endDate!.formatPersian() : 'تا تاریخ',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _searchController.clear();
              _startDate = null;
              _endDate = null;
            });
            Navigator.pop(context);
            _loadInvoices();
          },
          child: const Text('پاک کردن'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('لغو'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _searchInvoices();
          },
          child: const Text('جستجو'),
        ),
      ],
    );
  }

  /// NEW: Show date filter dialog (Today/Yesterday)
  Future<void> _showDateFilterDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتخاب دوره'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('امروز'),
              onTap: () => Navigator.pop(context, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('دیروز'),
              onTap: () => Navigator.pop(context, 'yesterday'),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      await _generateAggregatedPdfs(selected);
    }
  }

  /// NEW: Generate aggregated PDFs for selected date period
  Future<void> _generateAggregatedPdfs(String period) async {
    if (_isGeneratingPdfs) return; // Prevent multiple simultaneous generations

    setState(() {
      _isGeneratingPdfs = true;
    });

    try {
      // Calculate date range
      // Use UTC to match backend expectations
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      DateTime startDate, endDate;
      String periodLabel;

      if (period == 'today') {
        // Today: from 00:00:00 UTC to 23:59:59.999 UTC
        startDate = today;
        endDate = DateTime.utc(
          today.year,
          today.month,
          today.day,
          23,
          59,
          59,
          999, // Include milliseconds
        );
        periodLabel = 'امروز';
      } else {
        // Yesterday: 00:00:00 UTC to 23:59:59.999 UTC
        startDate = today.subtract(const Duration(days: 1));
        endDate = DateTime.utc(
          startDate.year,
          startDate.month,
          startDate.day,
          23,
          59,
          59,
          999, // Include milliseconds
        );
        periodLabel = 'دیروز';
      }

      // Debug logging
      print('🔍 Date range for $periodLabel:');
      print('   - Local time now: ${DateTime.now()}');
      print('   - UTC time now: ${now}');
      print('   - startDate (UTC): ${startDate.toIso8601String()}');
      print('   - endDate (UTC): ${endDate.toIso8601String()}');

      // Fetch orders in date range
      print('🔍 Fetching orders with date range:');
      print('   - startDate: ${startDate.toIso8601String()}');
      print('   - endDate: ${endDate.toIso8601String()}');

      final orders = await _orderService.searchInvoices(
        startDate: startDate.toIso8601String(),
        endDate: endDate.toIso8601String(),
        perPage: 1000, // Get all orders
      );

      print('🔍 Found ${orders.length} orders in date range');
      if (orders.isNotEmpty) {
        print(
          '   - First order: ID=${orders.first.id}, created_at=${orders.first.createdAt}',
        );
      }

      if (orders.isEmpty) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'سفارشی در این دوره ($periodLabel) یافت نشد',
            toastLength: Toast.LENGTH_LONG,
          );
        }
        return;
      }

      // Group orders by brand/company
      final Map<String, List<OrderItemModel>> brandItems = {};
      final Map<String, int?> brandCompanyIds =
          {}; // Track company ID for each brand
      final Map<String, List<OrderModel>> brandOrders =
          {}; // Track orders for each brand

      for (final order in orders) {
        for (final item in order.items) {
          final brand = item.effectiveBrand ?? 'بدون برند';

          if (!brandItems.containsKey(brand)) {
            brandItems[brand] = [];
            brandCompanyIds[brand] = order.companyId;
            brandOrders[brand] = [];
          }

          brandItems[brand]!.add(item);
          // Add order if not already added for this brand
          if (!brandOrders[brand]!.any((o) => o.id == order.id)) {
            brandOrders[brand]!.add(order);
          }
        }
      }

      if (brandItems.isEmpty) {
        if (mounted) {
          Fluttertoast.showToast(msg: 'آیتمی برای تولید PDF یافت نشد');
        }
        return;
      }

      // Get all companies for logo loading
      final companies = await _companyService.getCompanies();
      final companyMap = {for (var c in companies) c.name: c};

      // Generate PDF for each brand
      final List<Uint8List> pdfs = [];
      final List<String> brandNames = [];

      for (final entry in brandItems.entries) {
        final brandName = entry.key;
        final items = entry.value;
        final companyId = brandCompanyIds[brandName];

        // Find company by name or ID
        CompanyModel? company;
        if (companyId != null) {
          company = companies.firstWhere(
            (c) => c.id == companyId,
            orElse: () =>
                companyMap[brandName] ??
                companies.firstWhere(
                  (c) => c.name == brandName,
                  orElse: () => CompanyModel(
                    id: 0,
                    name: brandName,
                    createdAt: DateTime.now(),
                  ),
                ),
          );
        } else {
          company = companyMap[brandName];
        }

        // Generate PDF
        final brandOrdersList = brandOrders[brandName] ?? [];
        final pdfBytes = await AggregatedPdfService.generateBrandInvoicePdf(
          brandName: brandName,
          items: items,
          orders: brandOrdersList,
          periodLabel: periodLabel,
          periodDate: period == 'today' ? today : startDate,
          company: company,
        );

        pdfs.add(pdfBytes);
        brandNames.add(brandName);
      }

      // Show PDF preview/share dialog
      if (mounted && pdfs.isNotEmpty) {
        await _showPdfPreviewDialog(pdfs, brandNames, periodLabel);
      }
    } catch (e) {
      print('❌ Error generating aggregated PDFs: $e');
      if (mounted) {
        Fluttertoast.showToast(msg: 'خطا در تولید PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdfs = false;
        });
      }
    }
  }

  /// NEW: Show PDF preview/share dialog
  Future<void> _showPdfPreviewDialog(
    List<Uint8List> pdfs,
    List<String> brandNames,
    String periodLabel,
  ) async {
    if (pdfs.isEmpty) return;

    // Show first PDF in preview, allow sharing all
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF های تولید شده ($periodLabel)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: PdfPreview(
            build: (format) => pdfs.first,
            allowPrinting: true,
            allowSharing: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
          if (pdfs.length > 1)
            TextButton(
              onPressed: () async {
                // Share all PDFs
                for (int i = 0; i < pdfs.length; i++) {
                  await Printing.sharePdf(
                    bytes: pdfs[i],
                    filename: 'فاکتور_${brandNames[i]}_$periodLabel.pdf',
                  );
                  // Small delay between shares
                  await Future.delayed(const Duration(milliseconds: 500));
                }
                if (mounted) {
                  Navigator.pop(context);
                  Fluttertoast.showToast(
                    msg: 'تمام PDF ها به اشتراک گذاشته شدند',
                  );
                }
              },
              child: const Text('اشتراک‌گذاری همه'),
            ),
        ],
      ),
    );
  }
}
