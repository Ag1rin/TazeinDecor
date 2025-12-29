// Order Service
import '../models/order_model.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';

class OrderService {
  final ApiService _api = ApiService();

  Future<OrderModel?> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _api.post('/orders', data: orderData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return OrderModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create pending order for online payment (WooCommerce only, not in local DB)
  /// Returns order data with woo_order_id for payment processing
  Future<Map<String, dynamic>?> createPendingOrderForPayment(
    Map<String, dynamic> orderData,
  ) async {
    try {
      final response = await _api.post('/orders/pending-payment', data: orderData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Error creating pending order for payment: $e');
      if (e is DioException) {
        final errorMessage =
            e.response?.data?['detail'] ??
            e.response?.data?['message'] ??
            e.message ??
            'خطا در ثبت سفارش';
        print('❌ Error detail: $errorMessage');
        throw Exception(errorMessage);
      }
      return null;
    }
  }

  /// Verify payment and register order in local DB after successful payment
  Future<OrderModel?> verifyPaymentAndRegisterOrder(
    int wooOrderId,
    Map<String, dynamic> orderData,
    int customerId,
    double totalAmount,
    double wholesaleAmount,
  ) async {
    try {
      final verifyData = {
        'woo_order_id': wooOrderId,
        'order_data': orderData,
        'customer_id': customerId,
        'total_amount': totalAmount,
        'wholesale_amount': wholesaleAmount,
      };
      
      final response = await _api.post('/orders/verify-payment', data: verifyData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return OrderModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('❌ Error verifying payment and registering order: $e');
      if (e is DioException) {
        final errorMessage =
            e.response?.data?['detail'] ??
            e.response?.data?['message'] ??
            e.message ??
            'خطا در تایید پرداخت';
        print('❌ Error detail: $errorMessage');
        throw Exception(errorMessage);
      }
      return null;
    }
  }

  /// Cancel pending order if payment fails
  Future<bool> cancelPendingOrder(int wooOrderId) async {
    try {
      final response = await _api.delete('/orders/pending-payment/$wooOrderId');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error cancelling pending order: $e');
      return false;
    }
  }

  /// Create order and return raw response data (for online payment flow)
  /// DEPRECATED: Use createPendingOrderForPayment instead
  @Deprecated('Use createPendingOrderForPayment instead')
  Future<Map<String, dynamic>?> createOrderForPayment(
    Map<String, dynamic> orderData,
  ) async {
    try {
      final response = await _api.post('/orders', data: orderData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;

        // Extract woo_order_id from order_number (format: ORD-YYYYMMDD-{woo_order_id})
        final orderNumber = data['order_number'] as String?;
        if (orderNumber != null) {
          final parts = orderNumber.split('-');
          if (parts.length >= 3) {
            data['woo_order_id'] = int.tryParse(parts.last);
          }
        }

        return data;
      }
      return null;
    } catch (e) {
      print('❌ Error creating order for payment: $e');
      return null;
    }
  }

  Future<List<OrderModel>> getOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'per_page': perPage};
      if (status != null) queryParams['status'] = status;

      final response = await _api.get('/orders', queryParameters: queryParams);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => OrderModel.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<OrderModel?> getOrder(int orderId) async {
    try {
      final response = await _api.get('/orders/$orderId');
      if (response.statusCode == 200) {
        return OrderModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> confirmOrder(int orderId, {int? companyId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (companyId != null) queryParams['company_id'] = companyId;

      final response = await _api.put(
        '/orders/$orderId/confirm',
        queryParameters: queryParams,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await _api.put(
        '/orders/$orderId/status',
        queryParameters: {'status': status},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markOrderRead(int orderId) async {
    try {
      final response = await _api.put('/orders/$orderId/mark-read');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> returnOrder(int orderId) async {
    try {
      final response = await _api.put('/orders/$orderId/return');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Invoice management methods
  Future<bool> updateInvoiceStatus(int orderId, String status) async {
    try {
      final response = await _api.put(
        '/orders/$orderId/invoice-status',
        queryParameters: {'status': status},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error updating invoice status: $e');
      if (e is DioException) {
        final errorMessage =
            e.response?.data?['detail'] ??
            e.response?.data?['message'] ??
            e.message ??
            'خطا در ارتباط با سرور';
        print('❌ Error detail: $errorMessage');
        throw Exception(errorMessage);
      }
      throw Exception('خطا در به‌روزرسانی وضعیت فاکتور');
    }
  }

  Future<bool> updateInvoice(
    int orderId,
    Map<String, dynamic> invoiceData,
  ) async {
    try {
      final response = await _api.put(
        '/orders/$orderId/invoice',
        data: invoiceData,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveInvoiceEdit(
    int orderId,
    Map<String, dynamic> invoiceData,
  ) async {
    try {
      final response = await _api.put(
        '/orders/$orderId/approve-edit',
        data: invoiceData,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<OrderModel>> searchInvoices({
    String? query,
    String? status,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'per_page': perPage};
      if (query != null && query.isNotEmpty) queryParams['q'] = query;
      if (status != null) queryParams['status'] = status;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      print('🔍 searchInvoices called with params: $queryParams');
      
      final response = await _api.get(
        '/orders/search',
        queryParameters: queryParams,
      );
      
      print('🔍 searchInvoices response status: ${response.statusCode}');
      print('🔍 searchInvoices response data type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          print('🔍 searchInvoices found ${data.length} orders');
          return data
              .map((json) => OrderModel.fromJson(json))
              .toList();
        } else {
          print('⚠️ searchInvoices: response.data is not a List: $data');
          return [];
        }
      }
      print('⚠️ searchInvoices: status code is not 200: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ searchInvoices error: $e');
      if (e is DioException) {
        print('❌ DioException details:');
        print('   - Status code: ${e.response?.statusCode}');
        print('   - Response data: ${e.response?.data}');
        print('   - Message: ${e.message}');
      }
      return [];
    }
  }

  Future<bool> deleteOrder(int orderId) async {
    try {
      final response = await _api.delete('/orders/$orderId');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error deleting order: $e');
      return false;
    }
  }
}
