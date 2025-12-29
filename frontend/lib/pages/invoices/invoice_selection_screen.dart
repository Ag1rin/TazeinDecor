// Invoice Selection Screen - For Operator to select invoices and generate PDFs
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/invoice_provider.dart';
import '../../models/order_model.dart';
import '../../services/company_service.dart';
import '../../services/product_service.dart';
import '../../services/aggregated_pdf_service.dart';
import '../../utils/persian_date.dart';
import '../../utils/app_colors.dart';
import 'package:printing/printing.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class InvoiceSelectionScreen extends StatefulWidget {
  const InvoiceSelectionScreen({super.key});

  @override
  State<InvoiceSelectionScreen> createState() => _InvoiceSelectionScreenState();
}

class _InvoiceSelectionScreenState extends State<InvoiceSelectionScreen> {
  final CompanyService _companyService = CompanyService();
  final ProductService _productService = ProductService();
  
  Set<int> _selectedInvoiceIds = {};
  Map<int, OrderModel> _invoices = {};
  bool _isLoading = false;
  bool _isGeneratingPdfs = false;
  
  // Brand selection
  Map<String, bool> _selectedBrands = {};
  Map<String, CompanyModel?> _brandToCompany = {};
  List<String> _availableBrands = [];
  
  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }
  
  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final invoiceProvider = Provider.of<InvoiceProvider>(
        context,
        listen: false,
      );
      await invoiceProvider.loadInvoices();
      
      final invoices = invoiceProvider.invoices;
      setState(() {
        _invoices = {for (var inv in invoices) inv.id: inv};
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Fluttertoast.showToast(msg: 'خطا در بارگذاری فاکتورها: $e');
      }
    }
  }
  
  void _selectAllToday() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    setState(() {
      _selectedInvoiceIds.clear();
      for (final invoice in _invoices.values) {
        final invoiceDate = invoice.createdAt;
        if (invoiceDate.isAfter(todayStart) && invoiceDate.isBefore(todayEnd)) {
          _selectedInvoiceIds.add(invoice.id);
        }
      }
    });
  }
  
  void _toggleInvoice(int invoiceId) {
    setState(() {
      if (_selectedInvoiceIds.contains(invoiceId)) {
        _selectedInvoiceIds.remove(invoiceId);
      } else {
        _selectedInvoiceIds.add(invoiceId);
      }
    });
  }
  
  Future<void> _extractBrands() async {
    if (_selectedInvoiceIds.isEmpty) {
      Fluttertoast.showToast(msg: 'لطفا حداقل یک فاکتور انتخاب کنید');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final Set<String> brands = {};
      final Map<String, CompanyModel?> brandToCompany = {};
      
      // Get all companies
      final companies = await _companyService.getCompanies();
      
      // Extract brands from selected invoices
      for (final invoiceId in _selectedInvoiceIds) {
        final invoice = _invoices[invoiceId];
        if (invoice == null) continue;
        
        for (final item in invoice.items) {
          // Get brand from product
          String? brand;
          
          // Try to get brand from secure API
          try {
            final productData = await _productService.getProductFromSecureAPI(
              item.productId,
            );
            if (productData != null && productData['brand'] != null) {
              brand = productData['brand'].toString();
            }
          } catch (e) {
            print('⚠️ Error fetching brand for product ${item.productId}: $e');
          }
          
          // Fallback to item.effectiveBrand
          brand ??= item.effectiveBrand;
          brand ??= 'بدون برند';
          
          if (!brands.contains(brand)) {
            brands.add(brand);
            
            // Find company for this brand
            // Check if company name matches brand, or if brand is in company notes
            // Notes can contain brands separated by comma, semicolon, or newline
            CompanyModel? company;
            for (final comp in companies) {
              // Check if company name matches brand
              if (comp.name.toLowerCase() == brand.toLowerCase()) {
                company = comp;
                break;
              }
              
              // Check if brand is in company notes (supports comma, semicolon, newline separated)
              if (comp.notes != null && comp.notes!.isNotEmpty) {
                final notesLower = comp.notes!.toLowerCase();
                final brandLower = brand.toLowerCase();
                
                // Split by common separators
                final brandList = notesLower
                    .split(RegExp(r'[,;\n\r]+'))
                    .map((b) => b.trim())
                    .where((b) => b.isNotEmpty)
                    .toList();
                
                // Check if brand matches any in the list
                if (brandList.any((b) => b == brandLower || b.contains(brandLower))) {
                  company = comp;
                  break;
                }
              }
            }
            brandToCompany[brand] = company;
          }
        }
      }
      
      setState(() {
        _availableBrands = brands.toList()..sort();
        _brandToCompany = brandToCompany;
        _selectedBrands = {for (var brand in _availableBrands) brand: true};
        _isLoading = false;
      });
      
      // Show brand selection dialog
      _showBrandSelectionDialog();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Fluttertoast.showToast(msg: 'خطا در استخراج برندها: $e');
      }
    }
  }
  
  void _showBrandSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتخاب برندها'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableBrands.length,
            itemBuilder: (context, index) {
              final brand = _availableBrands[index];
              final company = _brandToCompany[brand];
              
              return CheckboxListTile(
                title: Text(brand),
                subtitle: company != null
                    ? Text('شرکت: ${company.name}')
                    : const Text('شرکت یافت نشد', style: TextStyle(color: Colors.orange)),
                value: _selectedBrands[brand] ?? false,
                onChanged: (value) {
                  setState(() {
                    _selectedBrands[brand] = value ?? false;
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var brand in _availableBrands) {
                  _selectedBrands[brand] = false;
                }
              });
            },
            child: const Text('لغو انتخاب همه'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (var brand in _availableBrands) {
                  _selectedBrands[brand] = true;
                }
              });
            },
            child: const Text('انتخاب همه'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _generatePdfs();
            },
            child: const Text('تولید PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _generatePdfs() async {
    final selectedBrands = _selectedBrands.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    
    if (selectedBrands.isEmpty) {
      Fluttertoast.showToast(msg: 'لطفا حداقل یک برند انتخاب کنید');
      return;
    }
    
    setState(() {
      _isGeneratingPdfs = true;
    });
    
    try {
      // Get selected invoices
      final selectedInvoices = _selectedInvoiceIds
          .map((id) => _invoices[id])
          .where((inv) => inv != null)
          .cast<OrderModel>()
          .toList();
      
      if (selectedInvoices.isEmpty) {
        Fluttertoast.showToast(msg: 'فاکتوری انتخاب نشده است');
        return;
      }
      
      // Group items by brand
      final Map<String, List<OrderItemModel>> brandItems = {};
      final Map<String, List<OrderModel>> brandOrders = {};
      
      for (final invoice in selectedInvoices) {
        for (final item in invoice.items) {
          String? brand;
          
          // Try to get brand from secure API
          try {
            final productData = await _productService.getProductFromSecureAPI(
              item.productId,
            );
            if (productData != null && productData['brand'] != null) {
              brand = productData['brand'].toString();
            }
          } catch (e) {
            // Fallback
          }
          
          brand ??= item.effectiveBrand;
          brand ??= 'بدون برند';
          
          // Only process selected brands
          if (!selectedBrands.contains(brand)) continue;
          
          if (!brandItems.containsKey(brand)) {
            brandItems[brand] = [];
            brandOrders[brand] = [];
          }
          
          brandItems[brand]!.add(item);
          if (!brandOrders[brand]!.any((o) => o.id == invoice.id)) {
            brandOrders[brand]!.add(invoice);
          }
        }
      }
      
      // Generate PDF for each selected brand
      final List<Uint8List> pdfs = [];
      final List<String> brandNames = [];
      
      for (final brand in selectedBrands) {
        if (!brandItems.containsKey(brand)) continue;
        
        final items = brandItems[brand]!;
        final orders = brandOrders[brand]!;
        final company = _brandToCompany[brand];
        
        // Generate period label
        final dates = orders.map((o) => o.createdAt).toList()..sort();
        final startDate = dates.first;
        final endDate = dates.last;
        final periodLabel = startDate.year == endDate.year &&
                startDate.month == endDate.month &&
                startDate.day == endDate.day
            ? PersianDate.formatDate(startDate)
            : '${PersianDate.formatDate(startDate)} تا ${PersianDate.formatDate(endDate)}';
        
        // Generate PDF
        final pdfBytes = await AggregatedPdfService.generateBrandInvoicePdf(
          brandName: brand,
          items: items,
          orders: orders,
          periodLabel: periodLabel,
          periodDate: startDate,
          company: company,
        );
        
        pdfs.add(pdfBytes);
        brandNames.add(brand);
      }
      
      // Show PDF preview/share dialog
      if (mounted && pdfs.isNotEmpty) {
        await _showPdfPreviewDialog(pdfs, brandNames);
      }
    } catch (e) {
      print('❌ Error generating PDFs: $e');
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
  
  Future<void> _showPdfPreviewDialog(
    List<Uint8List> pdfs,
    List<String> brandNames,
  ) async {
    if (pdfs.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF های تولید شده (${pdfs.length} فایل)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: PdfPreview(
            build: (format) => pdfs.first,
          ),
        ),
        actions: [
          if (pdfs.length > 1)
            TextButton(
              onPressed: () async {
                // Share all PDFs
                for (int i = 0; i < pdfs.length; i++) {
                  final tempDir = await getTemporaryDirectory();
                  final file = File(
                    '${tempDir.path}/فاکتور_${brandNames[i]}_${DateTime.now().millisecondsSinceEpoch}.pdf',
                  );
                  await file.writeAsBytes(pdfs[i]);
                  await Share.shareXFiles(
                    [XFile(file.path)],
                    text: 'فاکتور ${brandNames[i]}',
                  );
                }
                if (mounted) {
                  Fluttertoast.showToast(
                    msg: 'تمام PDF ها به اشتراک گذاشته شدند',
                  );
                }
              },
              child: const Text('اشتراک‌گذاری همه'),
            ),
          TextButton(
            onPressed: () async {
              // Share first PDF
              final tempDir = await getTemporaryDirectory();
              final file = File(
                '${tempDir.path}/فاکتور_${brandNames.first}_${DateTime.now().millisecondsSinceEpoch}.pdf',
              );
              await file.writeAsBytes(pdfs.first);
              await Share.shareXFiles(
                [XFile(file.path)],
                text: 'فاکتور ${brandNames.first}',
              );
            },
            child: const Text('اشتراک‌گذاری'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('انتخاب فاکتورها'),
          actions: [
            if (_selectedInvoiceIds.isNotEmpty)
              TextButton(
                onPressed: _extractBrands,
                child: const Text('ادامه'),
              ),
          ],
        ),
        body: Column(
          children: [
            // Selection controls
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primaryBlue.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedInvoiceIds.length} فاکتور انتخاب شده',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _selectAllToday,
                        icon: const Icon(Icons.today),
                        label: const Text('انتخاب امروز'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedInvoiceIds.clear();
                          });
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('پاک کردن'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Invoices list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _invoices.isEmpty
                      ? const Center(child: Text('فاکتوری یافت نشد'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _invoices.values.elementAt(index);
                            return _buildInvoiceCard(invoice);
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: _isGeneratingPdfs
            ? FloatingActionButton(
                onPressed: null,
                backgroundColor: Colors.grey,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : _selectedInvoiceIds.isNotEmpty
                ? FloatingActionButton(
                    onPressed: _extractBrands,
                    backgroundColor: AppColors.primaryBlue,
                    child: const Icon(Icons.picture_as_pdf),
                  )
                : null,
      ),
    );
  }
  
  Widget _buildInvoiceCard(OrderModel invoice) {
    final isSelected = _selectedInvoiceIds.contains(invoice.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      color: isSelected
          ? AppColors.primaryBlue.withOpacity(0.1)
          : Colors.white,
      child: CheckboxListTile(
        title: Text('فاکتور: ${invoice.effectiveInvoiceNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('شماره سفارش: ${invoice.orderNumber}'),
            Text('تاریخ: ${PersianDate.formatDate(invoice.createdAt)}'),
            Text('تعداد اقلام: ${invoice.items.length}'),
          ],
        ),
        value: isSelected,
        onChanged: (value) => _toggleInvoice(invoice.id),
        secondary: const Icon(Icons.receipt_long),
      ),
    );
  }
}

