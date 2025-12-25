/// Offline PDF Invoice Generator for Flutter
/// 
/// Generates professional Persian/Farsi invoices completely offline
/// with full RTL support, proper text shaping, and clean design.
/// 
/// Requirements:
/// - pdf: ^3.10.7
/// - printing: ^5.12.0
/// - Vazir font in assets/fonts/Vazir-Regular.ttf and Vazir-Bold.ttf
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/persian_number.dart';
import '../utils/persian_date.dart';

/// Invoice data structure
class InvoiceData {
  // Shop/Company Info
  final String shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? shopEmail;
  final Uint8List? logoBytes; // Optional logo image bytes
  
  // Invoice Info
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String? orderNumber;
  
  // Customer Info
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  
  // Items
  final List<InvoiceItem> items;
  
  // Totals
  final double subtotal;
  final double shippingCost;
  final double taxAmount;
  final double discountAmount;
  final double grandTotal;
  
  // Additional Info
  final String? notes;
  final String? paymentTerms;
  
  InvoiceData({
    required this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.shopEmail,
    this.logoBytes,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.orderNumber,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.items,
    required this.subtotal,
    this.shippingCost = 0.0,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    required this.grandTotal,
    this.notes,
    this.paymentTerms,
  });
  
  /// Create from Map (for easy integration)
  factory InvoiceData.fromMap(Map<String, dynamic> map) {
    return InvoiceData(
      shopName: map['shop_name'] ?? 'تزئین دکور',
      shopAddress: map['shop_address'],
      shopPhone: map['shop_phone'],
      shopEmail: map['shop_email'],
      logoBytes: map['logo_bytes'] as Uint8List?,
      invoiceNumber: map['invoice_number'] ?? '',
      invoiceDate: map['invoice_date'] is DateTime 
          ? map['invoice_date'] as DateTime
          : DateTime.parse(map['invoice_date'] as String),
      orderNumber: map['order_number'],
      customerName: map['customer_name'] ?? '',
      customerPhone: map['customer_phone'],
      customerAddress: map['customer_address'],
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => InvoiceItem.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      shippingCost: (map['shipping_cost'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grand_total'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      paymentTerms: map['payment_terms'],
    );
  }
}

/// Invoice item structure
class InvoiceItem {
  final int rowNumber; // ردیف
  final String productName; // نام کالا
  final String quantity; // تعداد (e.g., "2 بسته" or "5 متر")
  final double unitPrice; // قیمت واحد
  final double total; // مبلغ
  
  InvoiceItem({
    required this.rowNumber,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
  
  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      rowNumber: map['row_number'] as int? ?? 0,
      productName: map['product_name'] ?? '',
      quantity: map['quantity'] ?? '',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Offline PDF Service - Generates invoices completely offline
class OfflinePdfService {
  // Font cache
  static pw.Font? _vazirRegular;
  static pw.Font? _vazirBold;
  
  /// Load Vazir fonts (cached for performance)
  /// Tries multiple font paths for compatibility
  static Future<void> _loadFonts() async {
    if (_vazirRegular == null) {
      final fontPaths = [
        'assets/fonts/Vazir-Regular.ttf',
        'assets/fonts/Vazirmatn-Regular.ttf',
      ];
      
      for (final path in fontPaths) {
        try {
          final regularData = await rootBundle.load(path);
          _vazirRegular = pw.Font.ttf(regularData);
          print('✅ Loaded Vazir Regular font from: $path');
          break;
        } catch (e) {
          continue;
        }
      }
      
      if (_vazirRegular == null) {
        print('⚠️ Could not load Vazir Regular font, using fallback');
        _vazirRegular = pw.Font.courier();
      }
    }
    
    if (_vazirBold == null) {
      final fontPaths = [
        'assets/fonts/Vazir-Bold.ttf',
        'assets/fonts/Vazirmatn-Bold.ttf',
      ];
      
      for (final path in fontPaths) {
        try {
          final boldData = await rootBundle.load(path);
          _vazirBold = pw.Font.ttf(boldData);
          print('✅ Loaded Vazir Bold font from: $path');
          break;
        } catch (e) {
          continue;
        }
      }
      
      if (_vazirBold == null) {
        print('⚠️ Could not load Vazir Bold font, using fallback');
        _vazirBold = pw.Font.courier();
      }
    }
  }
  
  /// Generate invoice PDF
  /// 
  /// Returns PDF bytes that can be saved, shared, or printed
  static Future<Uint8List> generateInvoicePdf(InvoiceData invoice) async {
    // Load fonts
    await _loadFonts();
    
    // Create PDF document
    final pdf = pw.Document();
    
    // Add page with RTL direction
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(invoice),
                pw.SizedBox(height: 30),
                
                // Invoice Info Section
                _buildInvoiceInfo(invoice),
                pw.SizedBox(height: 20),
                
                // Customer Info Section
                _buildCustomerInfo(invoice),
                pw.SizedBox(height: 20),
                
                // Items Table
                _buildItemsTable(invoice),
                pw.SizedBox(height: 20),
                
                // Totals Section
                _buildTotals(invoice),
                
                // Notes and Payment Terms (if any)
                if (invoice.notes != null || invoice.paymentTerms != null) ...[
                  pw.SizedBox(height: 20),
                  if (invoice.paymentTerms != null) _buildPaymentTerms(invoice),
                  if (invoice.notes != null) _buildNotes(invoice),
                ],
                
                // Footer
                pw.Spacer(),
                _buildFooter(invoice),
              ],
            ),
          );
        },
      ),
    );
    
    // Return PDF bytes
    return pdf.save();
  }
  
  /// Build header with logo and shop name
  static pw.Widget _buildHeader(InvoiceData invoice) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Shop name and title (right side in RTL)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                invoice.shopName,
                style: pw.TextStyle(
                  font: _vazirBold,
                  fontSize: 24,
                  color: PdfColors.blue700,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'فاکتور خرید',
                style: pw.TextStyle(
                  font: _vazirBold,
                  fontSize: 18,
                  color: PdfColors.black,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
        ),
        
        // Logo (left side in RTL)
        if (invoice.logoBytes != null)
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Image(
              pw.MemoryImage(invoice.logoBytes!),
              fit: pw.BoxFit.contain,
            ),
          )
        else
          pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Center(
              child: pw.Text(
                'لوگو',
                style: pw.TextStyle(
                  font: _vazirRegular,
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ),
      ],
    );
  }
  
  /// Build invoice info section
  static pw.Widget _buildInvoiceInfo(InvoiceData invoice) {
    final invoiceDate = PersianDate.formatDate(invoice.invoiceDate);
    final invoiceNum = PersianNumber.formatNumberString(invoice.invoiceNumber);
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                invoiceDate,
                style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.Text(
                'تاریخ:',
                style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                invoiceNum,
                style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.Text(
                'شماره فاکتور:',
                style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
          if (invoice.orderNumber != null) ...[
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  PersianNumber.formatNumberString(invoice.orderNumber!),
                  style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'شماره سفارش:',
                  style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  /// Build customer info section
  static pw.Widget _buildCustomerInfo(InvoiceData invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'اطلاعات مشتری',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 14,
              color: PdfColors.blue700,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  invoice.customerName,
                  style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Text(
                'نام:',
                style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
          if (invoice.customerPhone != null) ...[
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  invoice.customerPhone!,
                  style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'تلفن:',
                  style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ],
          if (invoice.customerAddress != null) ...[
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    invoice.customerAddress!,
                    style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Text(
                  'آدرس:',
                  style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  /// Build items table
  static pw.Widget _buildItemsTable(InvoiceData invoice) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5), // ردیف
        1: const pw.FlexColumnWidth(2.5), // نام کالا
        2: const pw.FlexColumnWidth(1.0), // تعداد
        3: const pw.FlexColumnWidth(1.2), // قیمت واحد
        4: const pw.FlexColumnWidth(1.2), // مبلغ
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('مبلغ', isHeader: true),
            _buildTableCell('قیمت واحد', isHeader: true),
            _buildTableCell('تعداد', isHeader: true),
            _buildTableCell('نام کالا', isHeader: true),
            _buildTableCell('ردیف', isHeader: true),
          ],
        ),
        // Data rows
        ...invoice.items.map((item) => pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            _buildTableCell(PersianNumber.formatPrice(item.total)),
            _buildTableCell(PersianNumber.formatPrice(item.unitPrice)),
            _buildTableCell(item.quantity),
            _buildTableCell(item.productName),
            _buildTableCell(PersianNumber.formatNumber(item.rowNumber)),
          ],
        )),
      ],
    );
  }
  
  /// Build table cell helper
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: isHeader ? _vazirBold : _vazirRegular,
          fontSize: isHeader ? 11 : 10,
          color: isHeader ? PdfColors.black : PdfColors.grey800,
        ),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right,
      ),
    );
  }
  
  /// Build totals section
  static pw.Widget _buildTotals(InvoiceData invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _buildTotalRow('جمع کل:', invoice.subtotal),
          if (invoice.shippingCost > 0)
            _buildTotalRow('هزینه ارسال:', invoice.shippingCost),
          if (invoice.taxAmount > 0)
            _buildTotalRow('مالیات:', invoice.taxAmount),
          if (invoice.discountAmount > 0)
            _buildTotalRow('تخفیف:', -invoice.discountAmount, isDiscount: true),
          pw.Divider(color: PdfColors.black, thickness: 2),
          pw.SizedBox(height: 4),
          _buildTotalRow(
            'مبلغ نهایی:',
            invoice.grandTotal,
            isGrandTotal: true,
          ),
        ],
      ),
    );
  }
  
  /// Build total row helper
  static pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isGrandTotal = false,
    bool isDiscount = false,
  }) {
    final amountText = isDiscount
        ? '-${PersianNumber.formatPrice(amount.abs())}'
        : PersianNumber.formatPrice(amount);
    
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            amountText,
            style: pw.TextStyle(
              font: isGrandTotal ? _vazirBold : _vazirRegular,
              fontSize: isGrandTotal ? 14 : 11,
              color: PdfColors.black,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.Text(
            label,
            style: pw.TextStyle(
              font: isGrandTotal ? _vazirBold : _vazirRegular,
              fontSize: isGrandTotal ? 14 : 11,
              color: PdfColors.black,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }
  
  /// Build payment terms section
  static pw.Widget _buildPaymentTerms(InvoiceData invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'شرایط پرداخت',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 12,
              color: PdfColors.blue700,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            invoice.paymentTerms!,
            style: pw.TextStyle(
              font: _vazirRegular,
              fontSize: 10,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }
  
  /// Build notes section
  static pw.Widget _buildNotes(InvoiceData invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'یادداشت‌ها',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 12,
              color: PdfColors.blue700,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            invoice.notes!,
            style: pw.TextStyle(
              font: _vazirRegular,
              fontSize: 10,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }
  
  /// Build footer
  static pw.Widget _buildFooter(InvoiceData invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'با تشکر از خرید شما',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 12,
              color: PdfColors.blue700,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          if (invoice.shopAddress != null || invoice.shopPhone != null) ...[
            pw.SizedBox(height: 8),
            if (invoice.shopAddress != null)
              pw.Text(
                invoice.shopAddress!,
                style: pw.TextStyle(
                  font: _vazirRegular,
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
            if (invoice.shopPhone != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'تلفن: ${invoice.shopPhone}',
                style: pw.TextStyle(
                  font: _vazirRegular,
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
            ],
            if (invoice.shopEmail != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'ایمیل: ${invoice.shopEmail}',
                style: pw.TextStyle(
                  font: _vazirRegular,
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

