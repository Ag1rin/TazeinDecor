// Utility for calculating order/invoice totals consistently across the app
// This ensures all screens show the same total amount as the Invoice Detail Screen

import '../models/order_model.dart';

class OrderTotalCalculator {
  /// Calculate the grand total for an order/invoice
  /// Uses cooperation_total_amount from database (calculated from calculator) if available
  /// Otherwise calculates: sum of item.total + tax - discount
  /// 
  /// This ensures consistency across all screens (list views, detail views, etc.)
  static double calculateGrandTotal(OrderModel order) {
    // First, try to use cooperation_total_amount from database (calculated from calculator)
    if (order.cooperationTotalAmount != null && order.cooperationTotalAmount! > 0) {
      return order.cooperationTotalAmount!;
    }
    
    // Fallback: Calculate from item totals (cooperation prices from backend)
    double calculatedSubtotal = 0.0;
    
    if (order.items.isNotEmpty) {
      // Sum all item totals (which are cooperation price totals from backend)
      // item.total stores wholesale_item_total (cooperation price × quantity) from backend
      calculatedSubtotal = order.items.fold<double>(
        0.0,
        (sum, item) => sum + item.total,
      );
    }
    
    // Use calculated subtotal if available, otherwise fall back to wholesaleAmount only
    // Never use retail price (totalAmount) - only cooperation price
    final baseAmount = calculatedSubtotal > 0 
        ? calculatedSubtotal 
        : (order.wholesaleAmount ?? 0.0);
    
    // Calculate final total: baseAmount + tax - discount (same as invoice detail screen)
    // Note: order.discountAmount is order-level discount, not user percentage discount
    // User percentage discounts are already applied in item.total from the backend
    final grandTotal = baseAmount + order.taxAmount - order.discountAmount;
    
    return grandTotal;
  }
  
  /// Get the payable amount (cooperation price total)
  /// This is the amount before tax and discount adjustments
  static double calculatePayableAmount(OrderModel order) {
    // Calculate subtotal from item totals (cooperation prices from backend)
    double calculatedSubtotal = 0.0;
    
    if (order.items.isNotEmpty) {
      calculatedSubtotal = order.items.fold<double>(
        0.0,
        (sum, item) => sum + item.total,
      );
    }
    
    // Use calculated subtotal if available, otherwise fall back to wholesaleAmount only
    // Never use retail price (totalAmount) - only cooperation price
    return calculatedSubtotal > 0 
        ? calculatedSubtotal 
        : (order.wholesaleAmount ?? 0.0);
  }
}

