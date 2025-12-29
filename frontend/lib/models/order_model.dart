// Order model (also used as Invoice)
import '../models/product_model.dart';
import '../utils/persian_date.dart';

/// Helper function to safely convert dynamic value to double
/// Handles both num and String types
double _safeToDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed ?? defaultValue;
  }
  return defaultValue;
}

class OrderModel {
  final int id;
  final String orderNumber;
  final int sellerId;
  final int customerId;
  final int? companyId;
  final String status;
  final String? paymentMethod;
  final String? deliveryMethod;
  final DateTime? installationDate;
  final String? installationNotes;
  final double totalAmount;  // Retail price (customer price)
  final double? wholesaleAmount;  // Wholesale/cooperation price (seller payment)
  final double? cooperationTotalAmount;  // Calculated total from calculator (sum of item.total + tax - discount)
  final String? notes;
  final bool isNew;
  final DateTime createdAt;
  final List<OrderItemModel> items;
  // Invoice fields
  final String? invoiceNumber;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final double? subtotal;
  final double taxAmount;
  final double discountAmount;
  final String? paymentTerms;
  // Edit approval fields
  final int? editRequestedBy;
  final DateTime? editRequestedAt;
  final int? editApprovedBy;
  final DateTime? editApprovedAt;
  // Customer details (for admin/operator view)
  final String? customerName;
  final String? customerMobile;
  final String? customerAddress;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.sellerId,
    required this.customerId,
    this.companyId,
    required this.status,
    this.paymentMethod,
    this.deliveryMethod,
    this.installationDate,
    this.installationNotes,
    required this.totalAmount,
    this.wholesaleAmount,
    this.cooperationTotalAmount,
    this.notes,
    required this.isNew,
    required this.createdAt,
    this.items = const [],
    this.invoiceNumber,
    this.issueDate,
    this.dueDate,
    this.subtotal,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    this.paymentTerms,
    this.editRequestedBy,
    this.editRequestedAt,
    this.editApprovedBy,
    this.editApprovedAt,
    this.customerName,
    this.customerMobile,
    this.customerAddress,
  });

  // Get invoice status color
  int get statusColor {
    switch (status) {
      case 'pending_completion':
        return 0xFFFFFFFF; // White
      case 'in_progress':
        return 0xFFFFFF00; // Yellow
      case 'settled':
        return 0xFF9C27B0; // Purple
      default:
        return 0xFFE0E0E0; // Gray
    }
  }

  // Check if status is an invoice status
  bool get isInvoiceStatus {
    return ['pending_completion', 'in_progress', 'settled'].contains(status);
  }

  // Get effective invoice number
  String get effectiveInvoiceNumber {
    return invoiceNumber ?? orderNumber;
  }

  // Get invoice number with date format: "فاکتور X در تاریخ Y"
  String get effectiveInvoiceNumberWithDate {
    final invNumber = effectiveInvoiceNumber;
    final date = issueDate ?? createdAt;
    final dateStr = PersianDate.formatDate(date);
    return 'فاکتور $invNumber در تاریخ $dateStr';
  }

  // Calculate grand total
  // ALWAYS use wholesaleAmount (cooperation price) as the base for calculations
  // This ensures consistency with what the seller actually pays
  double get grandTotal {
    // Use wholesaleAmount if available (cooperation price), otherwise fall back to totalAmount
    final baseAmount = wholesaleAmount ?? totalAmount;
    final sub = subtotal ?? baseAmount;
    return sub + taxAmount - discountAmount;
  }
  
  // Get the payable amount (cooperation price with discounts applied)
  // Use cooperation_total_amount (calculated from calculator) if available
  double get payableAmount {
    return cooperationTotalAmount ?? wholesaleAmount ?? totalAmount;
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert to int
    int _safeToInt(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    }
    
    return OrderModel(
      id: _safeToInt(json['id']),
      orderNumber: json['order_number']?.toString() ?? '',
      sellerId: _safeToInt(json['seller_id']),
      customerId: _safeToInt(json['customer_id']),
      companyId: json['company_id'] != null ? _safeToInt(json['company_id']) : null,
      status: json['status'],
      paymentMethod: json['payment_method'],
      deliveryMethod: json['delivery_method'],
      installationDate: json['installation_date'] != null
          ? DateTime.parse(json['installation_date'])
          : null,
      installationNotes: json['installation_notes'],
      totalAmount: _safeToDouble(json['total_amount']),
      wholesaleAmount: json['wholesale_amount'] != null
          ? _safeToDouble(json['wholesale_amount'])
          : null,
      cooperationTotalAmount: json['cooperation_total_amount'] != null
          ? _safeToDouble(json['cooperation_total_amount'])
          : null,
      notes: json['notes'],
      isNew: json['is_new'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItemModel.fromJson(item))
              .toList() ??
          [],
      invoiceNumber: json['invoice_number'],
      issueDate: json['issue_date'] != null
          ? DateTime.parse(json['issue_date'])
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      subtotal: json['subtotal'] != null
          ? _safeToDouble(json['subtotal'])
          : null,
      taxAmount: _safeToDouble(json['tax_amount']),
      discountAmount: _safeToDouble(json['discount_amount']),
      paymentTerms: json['payment_terms'],
      editRequestedBy: json['edit_requested_by'] != null ? _safeToInt(json['edit_requested_by']) : null,
      editRequestedAt: json['edit_requested_at'] != null
          ? DateTime.parse(json['edit_requested_at'])
          : null,
      editApprovedBy: json['edit_approved_by'] != null ? _safeToInt(json['edit_approved_by']) : null,
      editApprovedAt: json['edit_approved_at'] != null
          ? DateTime.parse(json['edit_approved_at'])
          : null,
      customerName: json['customer_name'],
      customerMobile: json['customer_mobile'],
      customerAddress: json['customer_address'],
    );
  }
}

// Order item model
class OrderItemModel {
  final int id;
  final int productId;
  final double quantity;
  final String unit;
  final double price;
  final double total;
  final int? variationId;
  final String? variationPattern;
  final ProductModel? product;
  // Brand can be set from secure API data
  String? brand;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.total,
    this.variationId,
    this.variationPattern,
    this.product,
    this.brand,
  });

  // Get effective brand - from direct brand field or product
  String? get effectiveBrand => brand ?? product?.brand;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert to int
    int _safeToInt(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    }
    
    return OrderItemModel(
      id: _safeToInt(json['id']),
      productId: _safeToInt(json['product_id']),
      quantity: _safeToDouble(json['quantity']),
      unit: json['unit'] ?? 'package',
      price: _safeToDouble(json['price']),
      total: _safeToDouble(json['total']),
      variationId: json['variation_id'] != null ? _safeToInt(json['variation_id']) : null,
      variationPattern: json['variation_pattern'],
      product: json['product'] != null
          ? ProductModel.fromJson(json['product'])
          : null,
      brand: json['brand'],
    );
  }

  // Create a copy with updated brand
  OrderItemModel copyWithBrand(String? newBrand) {
    return OrderItemModel(
      id: id,
      productId: productId,
      quantity: quantity,
      unit: unit,
      price: price,
      total: total,
      variationId: variationId,
      variationPattern: variationPattern,
      product: product,
      brand: newBrand,
    );
  }
}
