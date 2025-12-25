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

  /// Create order and return raw response data (for online payment flow)
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

      final response = await _api.get(
        '/orders/search',
        queryParameters: queryParams,
      );
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
