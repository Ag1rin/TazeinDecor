// Report Service
import 'api_service.dart';

class ReportService {
  final ApiService _api = ApiService();
  
  Future<Map<String, dynamic>> getSalesReport({
    DateTime? startDate,
    DateTime? endDate,
    String period = 'day', // day, month, year
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'period': period,
      };
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      
      final response = await _api.get('/reports/sales', queryParameters: queryParams);
      if (response.statusCode == 200) {
        return response.data;
      }
      return {'period': period, 'data': []};
    } catch (e) {
      return {'period': period, 'data': []};
    }
  }
  
  Future<Map<String, dynamic>> getSellerPerformance({
    int? sellerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sellerId != null) {
        queryParams['seller_id'] = sellerId;
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      
      final response = await _api.get('/reports/seller-performance', queryParameters: queryParams);
      if (response.statusCode == 200) {
        return response.data;
      }
      return {'sellers': []};
    } catch (e) {
      return {'sellers': []};
    }
  }
}

