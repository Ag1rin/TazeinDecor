// Return Service
import 'api_service.dart';
import 'dart:convert';
import '../utils/persian_date.dart';

class ReturnModel {
  final int id;
  final int orderId;
  final String? reason;
  final List<dynamic> items;
  final String status;
  final bool isNew;
  final DateTime createdAt;
  
  ReturnModel({
    required this.id,
    required this.orderId,
    this.reason,
    required this.items,
    required this.status,
    required this.isNew,
    required this.createdAt,
  });
  
  factory ReturnModel.fromJson(Map<String, dynamic> json) {
    List<dynamic> itemsList = [];
    if (json['items'] != null) {
      if (json['items'] is String) {
        try {
          itemsList = jsonDecode(json['items']);
        } catch (e) {
          itemsList = [];
        }
      } else {
        itemsList = json['items'];
      }
    }
    
    return ReturnModel(
      id: json['id'],
      orderId: json['order_id'],
      reason: json['reason'],
      items: itemsList,
      status: json['status'] ?? 'pending',
      isNew: json['is_new'] ?? false,
      createdAt: PersianDate.parseToLocal(json['created_at']),
    );
  }
}

class ReturnService {
  final ApiService _api = ApiService();
  
  Future<List<ReturnModel>> getReturns({int page = 1, int perPage = 20}) async {
    try {
      final response = await _api.get('/returns', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => ReturnModel.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  Future<ReturnModel?> createReturn({
    required int orderId,
    String? reason,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _api.post('/returns', data: {
        'order_id': orderId,
        'reason': reason,
        'items': items,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ReturnModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  Future<bool> markReturnRead(int returnId) async {
    try {
      final response = await _api.put('/returns/$returnId/mark-read');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> approveReturn(int returnId) async {
    try {
      final response = await _api.put('/returns/$returnId/approve');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> rejectReturn(int returnId, {String? reason}) async {
    try {
      final queryParams = reason != null ? {'reason': reason} : null;
      final response = await _api.put(
        '/returns/$returnId/reject',
        queryParameters: queryParams,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

