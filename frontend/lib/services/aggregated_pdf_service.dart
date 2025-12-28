/// IMPROVED: Aggregated PDF Service - Generates professional brand invoices
/// with full RTL support, Vazir font, and logo support
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';
import '../services/company_service.dart';
import '../utils/persian_number.dart';
import '../utils/persian_date.dart';
import '../config/app_config.dart';

class AggregatedPdfService {
  static pw.Font? _vazirRegular;
  static pw.Font? _vazirBold;

  /// Load Vazir fonts (cached)
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
          break;
        } catch (e) {
          continue;
        }
      }

      if (_vazirRegular == null) {
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
          break;
        } catch (e) {
          continue;
        }
      }

      if (_vazirBold == null) {
        _vazirBold = pw.Font.courier();
      }
    }
  }

  /// Load logo from URL
  static Future<Uint8List?> _loadLogoFromUrl(String? logoPath) async {
    if (logoPath == null || logoPath.isEmpty) return null;

    try {
      final url = '${AppConfig.baseUrl}/uploads/$logoPath';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('⚠️ Error loading logo: $e');
    }
    return null;
  }

  /// Generate single invoice PDF (for invoice detail screen)
  static Future<Uint8List> generateSingleInvoicePdf({
    required OrderModel invoice,
    CompanyModel? company,
  }) async {
    await _loadFonts();

    // Load logo
    Uint8List? logoBytes;
    if (company?.logo != null) {
      logoBytes = await _loadLogoFromUrl(company!.logo);
    }

    // Create PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: _vazirRegular!, bold: _vazirBold!),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildSingleInvoiceHeader(invoice, company, logoBytes),
                  pw.SizedBox(height: 20),

                  // Invoice Info
                  _buildSingleInvoiceInfo(invoice),
                  pw.SizedBox(height: 20),

                  // Customer Info
                  _buildSingleCustomerInfo(invoice),
                  pw.SizedBox(height: 20),

                  // Items table
                  _buildSingleItemsTable(invoice),
                  pw.SizedBox(height: 20),

                  // Totals
                  _buildSingleTotals(invoice),
                  pw.SizedBox(height: 20),

                  // Footer
                  _buildSingleFooter(invoice),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate brand-specific invoice PDF (for invoice detail screen)
  static Future<Uint8List> generateSingleBrandInvoicePdf({
    required OrderModel invoice,
    required String brandName,
    required List<OrderItemModel> brandItems,
    CompanyModel? company,
  }) async {
    await _loadFonts();

    // Load logo
    Uint8List? logoBytes;
    if (company?.logo != null) {
      logoBytes = await _loadLogoFromUrl(company!.logo);
    }

    // Calculate totals for brand-specific items
    final brandSubtotal = brandItems.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final originalTotal = invoice.items.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final proportion = originalTotal > 0 ? brandSubtotal / originalTotal : 0.0;
    final brandTax = invoice.taxAmount * proportion;
    final brandDiscount = invoice.discountAmount * proportion;
    final brandGrandTotal = brandSubtotal + brandTax - brandDiscount;

    // Create PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: _vazirRegular!, bold: _vazirBold!),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header with brand name
                  _buildSingleBrandHeader(brandName, company, logoBytes),
                  pw.SizedBox(height: 20),

                  // Invoice Info
                  _buildSingleInvoiceInfo(invoice),
                  pw.SizedBox(height: 20),

                  // Customer Info
                  _buildSingleCustomerInfo(invoice),
                  pw.SizedBox(height: 20),

                  // Brand-specific Items Table
                  _buildSingleBrandItemsTable(brandItems),
                  pw.SizedBox(height: 20),

                  // Brand-specific Totals
                  _buildSingleBrandTotals(
                    brandSubtotal,
                    brandTax,
                    brandDiscount,
                    brandGrandTotal,
                  ),
                  pw.SizedBox(height: 20),

                  // Footer
                  _buildSingleFooter(invoice),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate aggregated brand invoice PDF (for date range filtering)
  static Future<Uint8List> generateBrandInvoicePdf({
    required String brandName,
    required List<OrderItemModel> items,
    required List<OrderModel> orders,
    required String periodLabel,
    required DateTime periodDate,
    CompanyModel? company,
  }) async {
    await _loadFonts();

    // Load logo
    Uint8List? logoBytes;
    if (company?.logo != null) {
      logoBytes = await _loadLogoFromUrl(company!.logo);
    }

    // Calculate totals
    double totalQuantity = 0;
    double grandTotal = 0;
    final Map<String, double> quantityByUnit = {};

    for (final item in items) {
      totalQuantity += item.quantity;
      grandTotal += item.total;

      final unit = item.unit;
      quantityByUnit[unit] = (quantityByUnit[unit] ?? 0) + item.quantity;
    }

    // Format period date
    final periodDateFormatted = PersianDate.formatDate(periodDate);

    // Create PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: _vazirRegular!, bold: _vazirBold!),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header with logo and brand name
                  _buildHeader(brandName, company, logoBytes),
                  pw.SizedBox(height: 20),

                  // Title
                  _buildTitle(brandName, periodLabel, periodDateFormatted),
                  pw.SizedBox(height: 20),

                  // Items table
                  _buildItemsTable(items, orders),
                  pw.SizedBox(height: 20),

                  // Totals
                  _buildTotals(totalQuantity, quantityByUnit, grandTotal),
                  pw.SizedBox(height: 20),

                  // Footer
                  _buildFooter(company, periodDateFormatted),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    String brandName,
    CompanyModel? company,
    Uint8List? logoBytes,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Brand info (right side in RTL)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                brandName,
                style: pw.TextStyle(
                  font: _vazirBold,
                  fontSize: 24,
                  color: PdfColors.blue700,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
              if (company?.mobile != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'تلفن: ${PersianNumber.toPersian(company!.mobile!)}',
                  style: pw.TextStyle(font: _vazirRegular, fontSize: 12),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ],
          ),
        ),
        // Logo (left side in RTL)
        if (logoBytes != null)
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
          )
        else
          pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildTitle(
    String brandName,
    String periodLabel,
    String periodDate,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue300, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'درخواست موجودی و سفارش کالا از $brandName - دوره: $periodLabel - $periodDate',
        style: pw.TextStyle(
          font: _vazirBold,
          fontSize: 16,
          color: PdfColors.blue900,
        ),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildItemsTable(
    List<OrderItemModel> items,
    List<OrderModel> orders,
  ) {
    // Map item to order number - match by item ID or product ID + quantity
    final itemOrderMap = <int, String>{};
    for (final order in orders) {
      for (final orderItem in order.items) {
        // Find matching item in our items list
        final matchingItem = items.firstWhere(
          (i) =>
              i.id == orderItem.id ||
              (i.productId == orderItem.productId &&
                  i.quantity == orderItem.quantity &&
                  i.price == orderItem.price),
          orElse: () => items.first, // Fallback
        );

        if (items.contains(matchingItem)) {
          itemOrderMap[matchingItem.id] = order.orderNumber;
        }
      }
    }

    // For items not matched, use first order's number as fallback
    final fallbackOrderNumber = orders.isNotEmpty
        ? orders.first.orderNumber
        : 'N/A';

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5), // ردیف
        1: const pw.FlexColumnWidth(2.5), // نام محصول
        2: const pw.FlexColumnWidth(1.0), // تعداد
        3: const pw.FlexColumnWidth(1.2), // قیمت واحد
        4: const pw.FlexColumnWidth(1.2), // مبلغ کل
        5: const pw.FlexColumnWidth(1.0), // شماره سفارش
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('شماره سفارش', isHeader: true),
            _buildTableCell('مبلغ کل', isHeader: true),
            _buildTableCell('قیمت واحد', isHeader: true),
            _buildTableCell('تعداد', isHeader: true),
            _buildTableCell('نام محصول', isHeader: true),
            _buildTableCell('ردیف', isHeader: true),
          ],
        ),
        // Data rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final orderNumber = itemOrderMap[item.id] ?? fallbackOrderNumber;

          return pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              _buildTableCell(PersianNumber.toPersian(orderNumber)),
              _buildTableCell(PersianNumber.formatPrice(item.total)),
              _buildTableCell(PersianNumber.formatPrice(item.price)),
              _buildTableCell(
                '${PersianNumber.formatNumber(item.quantity.toInt())} ${item.unit}',
              ),
              _buildTableCell(item.product?.name ?? 'محصول'),
              _buildTableCell(PersianNumber.formatNumber((index + 1).toInt())),
            ],
          );
        }),
      ],
    );
  }

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
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static pw.Widget _buildTotals(
    double totalQuantity,
    Map<String, double> quantityByUnit,
    double grandTotal,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Quantity by unit
          for (final entry in quantityByUnit.entries)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${PersianNumber.formatNumber(entry.value.toInt())} ${entry.key}',
                    style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.Text(
                    'تعداد کل (${entry.key}):',
                    style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ),
            ),
          pw.Divider(color: PdfColors.black, thickness: 2),
          pw.SizedBox(height: 4),
          // Grand total
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${PersianNumber.formatPrice(grandTotal)} تومان',
                style: pw.TextStyle(
                  font: _vazirBold,
                  fontSize: 16,
                  color: PdfColors.blue700,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.Text(
                'مبلغ کل:',
                style: pw.TextStyle(font: _vazirBold, fontSize: 14),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build total row helper (kept for potential future use)
  // ignore: unused_element
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
            textAlign: pw.TextAlign.right,
          ),
          pw.Text(
            label,
            style: pw.TextStyle(
              font: isGrandTotal ? _vazirBold : _vazirRegular,
              fontSize: isGrandTotal ? 14 : 11,
              color: PdfColors.black,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(CompanyModel? company, String date) {
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
            'تاریخ: $date',
            style: pw.TextStyle(
              font: _vazirRegular,
              fontSize: 10,
              color: PdfColors.grey700,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'با تشکر از خرید شما',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 12,
              color: PdfColors.blue700,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  // ========== Single Invoice PDF Methods (for invoice detail screen) ==========

  static pw.Widget _buildSingleInvoiceHeader(
    OrderModel invoice,
    CompanyModel? company,
    Uint8List? logoBytes,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Shop name (right side in RTL)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'تزئین دکور',
                style: pw.TextStyle(
                  font: _vazirBold,
                  fontSize: 24,
                  color: PdfColors.blue700,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'درخواست از شرکت',
                style: pw.TextStyle(
                  font: _vazirBold,
                  fontSize: 18,
                  color: PdfColors.black,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'این فاکتور برای درخواست از شرکت جهت تامین کالا می‌باشد',
                style: pw.TextStyle(
                  font: _vazirRegular,
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
        ),
        // Logo (left side in RTL)
        if (logoBytes != null)
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
          )
        else
          pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildSingleBrandHeader(
    String brandName,
    CompanyModel? company,
    Uint8List? logoBytes,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Brand info (right side in RTL)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                brandName,
                style: pw.TextStyle(
                  font: _vazirBold,
                  fontSize: 24,
                  color: PdfColors.blue700,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'درخواست از شرکت',
                style: pw.TextStyle(
                  font: _vazirBold,
                  fontSize: 18,
                  color: PdfColors.black,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'این فاکتور برای درخواست از شرکت جهت تامین کالا می‌باشد',
                style: pw.TextStyle(
                  font: _vazirRegular,
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
        ),
        // Logo (left side in RTL)
        if (logoBytes != null)
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
          )
        else
          pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildSingleInvoiceInfo(OrderModel invoice) {
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
              pw.Expanded(
                child: pw.Text(
                  PersianDate.formatDate(invoice.issueDate ?? invoice.createdAt),
                  style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Text(
                'تاریخ:',
                style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  PersianNumber.toPersian(invoice.effectiveInvoiceNumber),
                  style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Text(
                'شماره فاکتور:',
                style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  PersianNumber.toPersian(invoice.orderNumber),
                  style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Text(
                'شماره سفارش:',
                style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSingleCustomerInfo(OrderModel invoice) {
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
            'جزئیات درخواست',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 14,
              color: PdfColors.blue700,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
          pw.SizedBox(height: 8),
          if (invoice.customerName != null) ...[
            pw.Text(
              'نام مشتری: ${invoice.customerName}',
              style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right,
            ),
            pw.SizedBox(height: 4),
          ],
          if (invoice.customerMobile != null) ...[
            pw.Text(
              'شماره تماس: ${PersianNumber.toPersian(invoice.customerMobile!)}',
              style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right,
            ),
            pw.SizedBox(height: 4),
          ],
          if (invoice.customerAddress != null && invoice.customerAddress!.isNotEmpty) ...[
            pw.Text(
              'آدرس: ${invoice.customerAddress}',
              style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right,
            ),
            pw.SizedBox(height: 4),
          ],
          pw.Text(
            'شماره سفارش: ${PersianNumber.toPersian(invoice.orderNumber)}',
            style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSingleItemsTable(OrderModel invoice) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5), // ردیف
        1: const pw.FlexColumnWidth(1.5), // کد محصول
        2: const pw.FlexColumnWidth(1.0), // تعداد با واحد
        3: const pw.FlexColumnWidth(3.0), // نام محصول
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('کد محصول', isHeader: true),
            _buildTableCell('تعداد', isHeader: true),
            _buildTableCell('نام محصول', isHeader: true),
            _buildTableCell('ردیف', isHeader: true),
          ],
        ),
        // Data rows
        ...invoice.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          // Get product SKU/code
          final productSku = item.product?.sku ?? 
                            'SKU-${item.productId}';

          return pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              _buildTableCell(productSku),
              _buildTableCell(
                '${PersianNumber.formatNumber(item.quantity.toInt())} ${item.unit}',
              ),
              _buildTableCell(item.product?.name ?? 'محصول'),
              _buildTableCell(PersianNumber.formatNumber((index + 1).toInt())),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSingleBrandItemsTable(List<OrderItemModel> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5), // ردیف
        1: const pw.FlexColumnWidth(1.5), // کد محصول
        2: const pw.FlexColumnWidth(1.0), // تعداد با واحد
        3: const pw.FlexColumnWidth(3.0), // نام محصول
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('کد محصول', isHeader: true),
            _buildTableCell('تعداد', isHeader: true),
            _buildTableCell('نام محصول', isHeader: true),
            _buildTableCell('ردیف', isHeader: true),
          ],
        ),
        // Data rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          // Get product SKU/code
          final productSku = item.product?.sku ?? 
                            'SKU-${item.productId}';

          return pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              _buildTableCell(productSku),
              _buildTableCell(
                '${PersianNumber.formatNumber(item.quantity.toInt())} ${item.unit}',
              ),
              _buildTableCell(item.product?.name ?? 'محصول'),
              _buildTableCell(PersianNumber.formatNumber((index + 1).toInt())),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSingleTotals(OrderModel invoice) {
    // Calculate total quantity by unit
    final Map<String, double> quantityByUnit = {};
    for (final item in invoice.items) {
      final unit = item.unit;
      quantityByUnit[unit] = (quantityByUnit[unit] ?? 0) + item.quantity;
    }

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
            'خلاصه درخواست',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 14,
              color: PdfColors.blue700,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
          pw.SizedBox(height: 8),
          // Quantity by unit
          for (final entry in quantityByUnit.entries)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${PersianNumber.formatNumber(entry.value.toInt())} ${entry.key}',
                    style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.Text(
                    'تعداد کل (${entry.key}):',
                    style: pw.TextStyle(font: _vazirBold, fontSize: 11),
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 8),
          pw.Text(
            'تعداد کل اقلام: ${PersianNumber.formatNumber(invoice.items.length)}',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 12,
              color: PdfColors.black,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSingleBrandTotals(
    double subtotal,
    double taxAmount,
    double discountAmount,
    double grandTotal,
  ) {
    // This method is kept for compatibility but totals are not shown in company request PDF
    return pw.SizedBox.shrink();
  }

  static pw.Widget _buildSingleFooter(OrderModel invoice) {
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
            'تاریخ: ${PersianDate.formatDate(invoice.issueDate ?? invoice.createdAt)}',
            style: pw.TextStyle(
              font: _vazirRegular,
              fontSize: 10,
              color: PdfColors.grey700,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'این درخواست برای تامین کالا از شرکت می‌باشد',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 12,
              color: PdfColors.blue700,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}
