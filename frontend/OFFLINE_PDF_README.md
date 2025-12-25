# Offline PDF Invoice Generator

Complete offline PDF invoice generator for Flutter with full Persian/Farsi RTL support.

## Features

✅ **100% Offline** - No server, no internet required  
✅ **Full RTL Support** - Proper Persian text direction and alignment  
✅ **Persian Font** - Uses Vazir font for beautiful Persian text rendering  
✅ **Professional Design** - Clean, print-ready invoice layout  
✅ **Persian Numbers** - All numbers displayed in Persian digits (۰۱۲۳...)  
✅ **Jalali Dates** - Dates shown in Persian calendar format  

## Dependencies

Already included in `pubspec.yaml`:
```yaml
dependencies:
  pdf: ^3.10.7
  printing: ^5.12.0
```

## Font Setup

Ensure Vazir fonts are in `assets/fonts/`:
- `Vazirmatn-Regular.ttf` (or `Vazir-Regular.ttf`)
- `Vazirmatn-Bold.ttf` (or `Vazir-Bold.ttf`)

The fonts are already declared in `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/fonts/
```

## Usage

### Basic Example

```dart
import 'package:printing/printing.dart';
import 'package:your_app/services/offline_pdf_service.dart';

// Create invoice data
final invoiceData = InvoiceData(
  shopName: 'تزئین دکور',
  invoiceNumber: 'INV-2024-001',
  invoiceDate: DateTime.now(),
  customerName: 'علی احمدی',
  items: [
    InvoiceItem(
      rowNumber: 1,
      productName: 'کاغذ دیواری',
      quantity: '5 رول',
      unitPrice: 500000,
      total: 2500000,
    ),
  ],
  subtotal: 2500000,
  grandTotal: 2500000,
);

// Generate PDF
final pdfBytes = await OfflinePdfService.generateInvoicePdf(invoiceData);

// Preview/Print
await Printing.layoutPdf(
  onLayout: (PdfPageFormat format) async => pdfBytes,
);
```

### From OrderModel

```dart
// Convert OrderModel to InvoiceData
final invoiceData = InvoiceData(
  shopName: 'تزئین دکور',
  invoiceNumber: order.invoiceNumber ?? order.orderNumber,
  invoiceDate: order.issueDate ?? order.createdAt,
  orderNumber: order.orderNumber,
  customerName: customer.name,
  customerPhone: customer.phone,
  items: order.items.asMap().entries.map((entry) {
    final index = entry.key;
    final item = entry.value;
    return InvoiceItem(
      rowNumber: index + 1,
      productName: item.product?.name ?? 'محصول',
      quantity: '${item.quantity} ${item.unit}',
      unitPrice: item.price,
      total: item.total,
    );
  }).toList(),
  subtotal: order.subtotal ?? order.totalAmount,
  taxAmount: order.taxAmount,
  discountAmount: order.discountAmount,
  grandTotal: order.grandTotal,
);

final pdfBytes = await OfflinePdfService.generateInvoicePdf(invoiceData);
```

### Share PDF

```dart
final pdfBytes = await OfflinePdfService.generateInvoicePdf(invoiceData);

await Printing.sharePdf(
  bytes: pdfBytes,
  filename: 'invoice_${invoiceData.invoiceNumber}.pdf',
);
```

### Save to File

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

final pdfBytes = await OfflinePdfService.generateInvoicePdf(invoiceData);

final directory = await getApplicationDocumentsDirectory();
final file = File('${directory.path}/invoice_${invoiceData.invoiceNumber}.pdf');
await file.writeAsBytes(pdfBytes);
```

## Invoice Structure

The invoice includes:

1. **Header**
   - Shop name and logo (optional)
   - Invoice title "فاکتور خرید"

2. **Invoice Info**
   - Invoice number
   - Invoice date (Jalali)
   - Order number (optional)

3. **Customer Info**
   - Customer name
   - Phone (optional)
   - Address (optional)

4. **Items Table**
   - Columns: ردیف, نام کالا, تعداد, قیمت واحد, مبلغ
   - All right-aligned for RTL

5. **Totals**
   - Subtotal
   - Shipping cost (if any)
   - Tax (if any)
   - Discount (if any)
   - Grand total

6. **Additional Sections** (optional)
   - Payment terms
   - Notes

7. **Footer**
   - Thank you message
   - Shop contact info

## RTL Support

The PDF uses:
- `pw.Directionality(textDirection: pw.TextDirection.rtl)` for the entire page
- Right-aligned text with `textAlign: pw.TextAlign.right`
- Proper table column ordering for RTL
- Persian font (Vazir) for correct letter shaping

## Persian Numbers

All numbers are automatically converted to Persian digits using `PersianNumber` utility:
- Prices: `formatPrice(1000000)` → "۱,۰۰۰,۰۰۰"
- Quantities: `formatNumber(5)` → "۵"
- Dates: Automatically formatted in Jalali calendar

## Notes

- The service is completely offline - no network calls
- Fonts are cached after first load for performance
- PDF is generated in memory (Uint8List)
- Compatible with both Vazir and Vazirmatn font names
- Fallback to Courier font if Vazir not found (with warning)

## Troubleshooting

**Font not loading?**
- Check font files exist in `assets/fonts/`
- Verify `pubspec.yaml` includes `assets/fonts/` in assets
- Run `flutter pub get` and rebuild

**Persian text not displaying correctly?**
- Ensure Vazir font is loaded (check console logs)
- Verify `textDirection: pw.TextDirection.rtl` is set
- Check font file is not corrupted

**PDF too large?**
- Reduce image sizes if using logo
- Consider compressing images before adding to PDF

