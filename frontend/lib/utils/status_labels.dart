/// Persian status labels for orders and invoices
/// Converts English status codes to user-friendly Persian labels

class StatusLabels {
  /// Order/Invoice status labels in Persian
  static const Map<String, String> orderStatus = {
    // Order statuses
    'pending': 'در انتظار تأیید',
    'confirmed': 'تأیید شده',
    'processing': 'در حال پردازش',
    'delivered': 'تحویل شده',
    'returned': 'مرجوع شده',
    'cancelled': 'لغو شده',
    // Invoice statuses
    'pending_completion': 'در انتظار تکمیل',
    'in_progress': 'در حال پردازش',
    'settled': 'تسویه شده',
  };

  /// Payment method labels in Persian
  static const Map<String, String> paymentMethod = {
    'online': 'پرداخت آنلاین',
    'credit': 'پرداخت اعتباری',
    'invoice': 'ارسال فاکتور',
  };

  /// Delivery method labels in Persian
  static const Map<String, String> deliveryMethod = {
    'in_person': 'تحویل حضوری',
    'to_customer': 'ارسال به آدرس مشتری',
    'to_store': 'ارسال به فروشگاه',
  };

  /// Return request status labels in Persian
  static const Map<String, String> returnStatus = {
    'pending': 'در انتظار بررسی',
    'approved': 'تأیید شده',
    'rejected': 'رد شده',
  };

  /// Get Persian label for order status
  static String getOrderStatus(String? status) {
    if (status == null || status.isEmpty) return 'نامشخص';
    return orderStatus[status.toLowerCase()] ?? status;
  }

  /// Get Persian label for payment method
  static String getPaymentMethod(String? method) {
    if (method == null || method.isEmpty) return 'نامشخص';
    return paymentMethod[method.toLowerCase()] ?? method;
  }

  /// Get Persian label for delivery method
  static String getDeliveryMethod(String? method) {
    if (method == null || method.isEmpty) return 'نامشخص';
    return deliveryMethod[method.toLowerCase()] ?? method;
  }

  /// Get Persian label for return status
  static String getReturnStatus(String? status) {
    if (status == null || status.isEmpty) return 'نامشخص';
    return returnStatus[status.toLowerCase()] ?? status;
  }

  /// Get status color based on status
  static int getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 0xFFFFA000; // Orange
      case 'confirmed':
        return 0xFF4CAF50; // Green
      case 'processing':
        return 0xFF2196F3; // Blue
      case 'delivered':
        return 0xFF4CAF50; // Green
      case 'returned':
        return 0xFFF44336; // Red
      case 'cancelled':
        return 0xFF9E9E9E; // Gray
      case 'pending_completion':
        return 0xFFFFFFFF; // White
      case 'in_progress':
        return 0xFFFFEB3B; // Yellow
      case 'settled':
        return 0xFF9C27B0; // Purple
      default:
        return 0xFFE0E0E0; // Light Gray
    }
  }

  /// Get status background color (lighter version)
  static int getStatusBackgroundColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 0xFFFFF3E0; // Light Orange
      case 'confirmed':
        return 0xFFE8F5E9; // Light Green
      case 'processing':
        return 0xFFE3F2FD; // Light Blue
      case 'delivered':
        return 0xFFE8F5E9; // Light Green
      case 'returned':
        return 0xFFFFEBEE; // Light Red
      case 'cancelled':
        return 0xFFF5F5F5; // Light Gray
      case 'pending_completion':
        return 0xFFFFFDE7; // Light Yellow
      case 'in_progress':
        return 0xFFFFFDE7; // Light Yellow
      case 'settled':
        return 0xFFF3E5F5; // Light Purple
      default:
        return 0xFFF5F5F5; // Light Gray
    }
  }
}

