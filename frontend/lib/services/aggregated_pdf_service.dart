/// IMPROVED: Aggregated PDF Service - Generates professional brand invoices
/// with full RTL support, Vazir font, and logo support
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';
import '../services/company_service.dart';
import '../services/brand_service.dart';
import '../utils/persian_number.dart';
import '../utils/persian_date.dart';
import '../utils/product_unit_display.dart';
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

    // Load company logo
    Uint8List? logoBytes;
    if (company?.logo != null) {
      logoBytes = await _loadLogoFromUrl(company!.logo);
    }

    // Try to load brand thumbnail from cache
    Uint8List? brandLogoBytes;
    try {
      final brandService = BrandService();
      final brand = await brandService.getBrandByName(brandName);
      if (brand?.thumbnailUrl != null) {
        brandLogoBytes = await _loadLogoFromUrl(brand!.thumbnailUrl);
      }
    } catch (e) {
      print('⚠️ Error loading brand logo: $e');
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
                  // Header with brand name and logo
                  _buildSingleBrandHeader(brandName, company, logoBytes, brandLogoBytes),
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

    // Load company logo
    Uint8List? logoBytes;
    if (company?.logo != null) {
      logoBytes = await _loadLogoFromUrl(company!.logo);
    }

    // Try to load brand thumbnail from cache
    Uint8List? brandLogoBytes;
    try {
      final brandService = BrandService();
      final brand = await brandService.getBrandByName(brandName);
      if (brand?.thumbnailUrl != null) {
        brandLogoBytes = await _loadLogoFromUrl(brand!.thumbnailUrl);
      }
    } catch (e) {
      print('⚠️ Error loading brand logo: $e');
    }

    // Format period date - ensure we use local timezone
    final localPeriodDate = periodDate.isUtc ? periodDate.toLocal() : periodDate;
    final periodDateFormatted = PersianDate.formatDate(localPeriodDate);

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
                  _buildHeader(brandName, company, logoBytes, brandLogoBytes),
                  pw.SizedBox(height: 20),

                  // Title
                  _buildTitle(brandName, periodLabel, periodDateFormatted),
                  pw.SizedBox(height: 20),

                  // Items table
                  _buildItemsTable(items, orders),
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
    Uint8List? brandLogoBytes,
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
        // Logos (left side in RTL) - Brand logo takes priority, then company logo
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (brandLogoBytes != null)
              pw.Container(
                width: 80,
                height: 80,
                margin: const pw.EdgeInsets.only(left: 8),
                child: pw.Image(pw.MemoryImage(brandLogoBytes), fit: pw.BoxFit.contain),
              )
            else if (logoBytes != null)
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
        'درخواست موجودی و سفارش کالا از $brandName - تاریخ: $periodDate',
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

  /// Extract album name from product name or attributes
  static String? _extractAlbumName(OrderItemModel item) {
    // First try albumCode from product
    if (item.product?.albumCode != null && item.product!.albumCode!.isNotEmpty) {
      return item.product!.albumCode;
    }
    
    // Try to find album code in attributes
    if (item.product?.attributes != null) {
      for (final attr in item.product!.attributes) {
        final attrName = attr.name.toLowerCase();
        if (attrName.contains('آلبوم') || 
            attrName.contains('album') || 
            attrName.contains('album_code')) {
          return attr.value;
        }
      }
    }
    
    // Try to extract from product name (if it contains album info)
    final productName = item.product?.name ?? '';
    // Look for patterns like "آلبوم X" or "Album X" in the name
    final albumMatch = RegExp(r'(آلبوم|Album)[\s:]+([^\s]+)', caseSensitive: false)
        .firstMatch(productName);
    if (albumMatch != null) {
      return albumMatch.group(2);
    }
    
    return null;
  }

  /// Extract design code or feature code from product
  static String? _extractDesignCode(OrderItemModel item) {
    // First try variation pattern (this is the design code for variable products)
    if (item.variationPattern != null && item.variationPattern!.isNotEmpty) {
      return item.variationPattern;
    }
    
    // Then try designCode from product
    if (item.product?.designCode != null && item.product!.designCode!.isNotEmpty) {
      return item.product!.designCode;
    }
    
    // Try to find design code or feature code in attributes
    if (item.product?.attributes != null) {
      for (final attr in item.product!.attributes) {
        final attrName = attr.name.toLowerCase();
        if (attrName.contains('کد طرح') || 
            attrName.contains('کد طراحی') ||
            attrName.contains('design') || 
            attrName.contains('design_code') ||
            attrName.contains('کد ویژگی') ||
            attrName.contains('feature_code')) {
          return attr.value;
        }
      }
    }
    
    return null;
  }

  static pw.Widget _buildItemsTable(
    List<OrderItemModel> items,
    List<OrderModel> orders,
  ) {
    // Debug: Log items to verify product details
    print('📋 Building items table with ${items.length} items');
    for (final item in items.take(3)) {
      print('   - Item ${item.productId}: product=${item.product != null}, name=${item.product?.name ?? "N/A"}, albumCode=${item.product?.albumCode ?? "N/A"}, designCode=${item.product?.designCode ?? "N/A"}, attributes=${item.product?.attributes.length ?? 0}');
    }
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5), // ردیف
        1: const pw.FlexColumnWidth(2.5), // نام کالا
        2: const pw.FlexColumnWidth(1.5), // نام آلبوم
        3: const pw.FlexColumnWidth(1.5), // کد طرح/ویژگی
        4: const pw.FlexColumnWidth(1.0), // تعداد
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('تعداد', isHeader: true),
            _buildTableCell('کد طرح', isHeader: true),
            _buildTableCell('نام آلبوم', isHeader: true),
            _buildTableCell('نام کالا', isHeader: true),
            _buildTableCell('ردیف', isHeader: true),
          ],
        ),
        // Data rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          // Extract product name from item.product or order
          String productName = item.product?.name ?? 'محصول';
          if (productName == 'محصول' || productName.isEmpty) {
            // Try to find in orders
            for (final order in orders) {
              final orderItem = order.items.firstWhere(
                (oi) => oi.id == item.id || 
                       (oi.productId == item.productId && oi.quantity == item.quantity),
                orElse: () => item,
              );
              if (orderItem.product?.name != null && orderItem.product!.name.isNotEmpty) {
                productName = orderItem.product!.name;
                break;
              }
            }
          }
          
          // Extract album name
          String albumName = _extractAlbumName(item) ?? '-';
          if (albumName == '-') {
            // Try to find in orders
            for (final order in orders) {
              final orderItem = order.items.firstWhere(
                (oi) => oi.id == item.id || 
                       (oi.productId == item.productId && oi.quantity == item.quantity),
                orElse: () => item,
              );
              final extracted = _extractAlbumName(orderItem);
              if (extracted != null && extracted.isNotEmpty) {
                albumName = extracted;
                break;
              }
            }
          }
          
          // Extract design/feature code
          String designCode = _extractDesignCode(item) ?? '-';
          if (designCode == '-') {
            // Try to find in orders
            for (final order in orders) {
              final orderItem = order.items.firstWhere(
                (oi) => oi.id == item.id || 
                       (oi.productId == item.productId && oi.quantity == item.quantity),
                orElse: () => item,
              );
              final extracted = _extractDesignCode(orderItem);
              if (extracted != null && extracted.isNotEmpty) {
                designCode = extracted;
                break;
              }
            }
          }
          
          // Get quantity with unit
          final quantity = item.quantity;
          
          // Get unit from order item, or from product calculator, or from product details
          String unit = item.unit;
          if (unit.isEmpty || unit == 'package') {
            // Try to get from product calculator
            if (item.product?.calculator != null) {
              final calc = item.product!.calculator!;
              final calcUnit = ProductUnitDisplay.getUnitFromCalculator(calc);
              if (calcUnit != null && calcUnit.isNotEmpty) {
                unit = calcUnit;
              }
            }
            // If still empty, try from product details cache (if available in orders)
            if (unit.isEmpty || unit == 'package') {
              for (final order in orders) {
                final orderItem = order.items.firstWhere(
                  (oi) => oi.id == item.id || 
                         (oi.productId == item.productId && oi.quantity == item.quantity),
                  orElse: () => item,
                );
                if (orderItem.product?.calculator != null) {
                  final calc = orderItem.product!.calculator!;
                  final calcUnit = ProductUnitDisplay.getUnitFromCalculator(calc);
                  if (calcUnit != null && calcUnit.isNotEmpty) {
                    unit = calcUnit;
                    break;
                  }
                }
              }
            }
            // Default fallback
            if (unit.isEmpty) {
              unit = 'package';
            }
          }
          
          // Convert unit to Persian using ProductUnitDisplay
          final unitPersian = ProductUnitDisplay.getDisplayUnit(unit);
          final quantityText = '${PersianNumber.formatNumber(quantity.toInt())} $unitPersian';

          return pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              _buildTableCell(quantityText),
              _buildTableCell(designCode),
              _buildTableCell(albumName),
              _buildTableCell(productName),
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
    Uint8List? brandLogoBytes,
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
        // Logos (left side in RTL) - Brand logo takes priority, then company logo
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (brandLogoBytes != null)
              pw.Container(
                width: 80,
                height: 80,
                margin: const pw.EdgeInsets.only(left: 8),
                child: pw.Image(pw.MemoryImage(brandLogoBytes), fit: pw.BoxFit.contain),
              )
            else if (logoBytes != null)
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
              pw.Text(
                PersianDate.formatDate(invoice.issueDate ?? invoice.createdAt),
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
                PersianNumber.toPersian(invoice.effectiveInvoiceNumberWithDate),
                style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                PersianNumber.toPersian(invoice.orderNumber),
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
            'اطلاعات مشتری',
            style: pw.TextStyle(
              font: _vazirBold,
              fontSize: 14,
              color: PdfColors.blue700,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'شماره سفارش: ${PersianNumber.toPersian(invoice.orderNumber)}',
            style: pw.TextStyle(font: _vazirRegular, fontSize: 11),
            textDirection: pw.TextDirection.rtl,
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
        1: const pw.FlexColumnWidth(2.0), // نام محصول
        2: const pw.FlexColumnWidth(1.2), // کد طرح
        3: const pw.FlexColumnWidth(1.0), // تعداد
        4: const pw.FlexColumnWidth(1.2), // قیمت واحد
        5: const pw.FlexColumnWidth(1.2), // مبلغ کل
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('مبلغ کل', isHeader: true),
            _buildTableCell('قیمت واحد', isHeader: true),
            _buildTableCell('تعداد', isHeader: true),
            _buildTableCell('کد طرح', isHeader: true),
            _buildTableCell('نام محصول', isHeader: true),
            _buildTableCell('ردیف', isHeader: true),
          ],
        ),
        // Data rows
        ...invoice.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final designCode = _extractDesignCode(item) ?? '-';

          return pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              _buildTableCell(PersianNumber.formatPrice(item.total)),
              _buildTableCell(PersianNumber.formatPrice(item.price)),
              _buildTableCell(
                '${PersianNumber.formatNumber(item.quantity.toInt())} ${item.unit}',
              ),
              _buildTableCell(designCode),
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
        1: const pw.FlexColumnWidth(2.0), // نام محصول
        2: const pw.FlexColumnWidth(1.2), // کد طرح
        3: const pw.FlexColumnWidth(1.0), // تعداد
        4: const pw.FlexColumnWidth(1.2), // قیمت واحد
        5: const pw.FlexColumnWidth(1.2), // مبلغ کل
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('مبلغ کل', isHeader: true),
            _buildTableCell('قیمت واحد', isHeader: true),
            _buildTableCell('تعداد', isHeader: true),
            _buildTableCell('کد طرح', isHeader: true),
            _buildTableCell('نام محصول', isHeader: true),
            _buildTableCell('ردیف', isHeader: true),
          ],
        ),
        // Data rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final designCode = _extractDesignCode(item) ?? '-';

          return pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              _buildTableCell(PersianNumber.formatPrice(item.total)),
              _buildTableCell(PersianNumber.formatPrice(item.price)),
              _buildTableCell(
                '${PersianNumber.formatNumber(item.quantity.toInt())} ${item.unit}',
              ),
              _buildTableCell(designCode),
              _buildTableCell(item.product?.name ?? 'محصول'),
              _buildTableCell(PersianNumber.formatNumber((index + 1).toInt())),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSingleTotals(OrderModel invoice) {
    // ALWAYS use wholesaleAmount (cooperation price) for calculations
    // This ensures PDF invoices show the actual amount the seller pays
    // Never use retail price (totalAmount) - only cooperation price
    final baseAmount = invoice.wholesaleAmount ?? 0.0;
    final subtotal = invoice.subtotal ?? baseAmount;
    final grandTotal = invoice.grandTotal; // This now uses wholesaleAmount internally

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _buildTotalRow('جمع کل:', subtotal),
          if (invoice.taxAmount > 0)
            _buildTotalRow('مالیات:', invoice.taxAmount),
          if (invoice.discountAmount > 0)
            _buildTotalRow('تخفیف:', -invoice.discountAmount, isDiscount: true),
          pw.Divider(color: PdfColors.black, thickness: 2),
          pw.SizedBox(height: 4),
          _buildTotalRow('مبلغ نهایی:', grandTotal, isGrandTotal: true),
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
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _buildTotalRow('جمع کل (این برند):', subtotal),
          if (taxAmount > 0) _buildTotalRow('مالیات (نسبی):', taxAmount),
          if (discountAmount > 0)
            _buildTotalRow('تخفیف (نسبی):', -discountAmount, isDiscount: true),
          pw.Divider(color: PdfColors.black, thickness: 2),
          pw.SizedBox(height: 4),
          _buildTotalRow(
            'مبلغ نهایی (این برند):',
            grandTotal,
            isGrandTotal: true,
          ),
        ],
      ),
    );
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
          ),
        ],
      ),
    );
  }
}
