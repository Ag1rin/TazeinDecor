// Installation Service
import 'api_service.dart';

class InstallationModel {
  final int id;
  final int orderId;
  final DateTime installationDate;
  final String? notes;
  final String? color;
  final DateTime createdAt;
  
  InstallationModel({
    required this.id,
    required this.orderId,
    required this.installationDate,
    this.notes,
    this.color,
    required this.createdAt,
  });
  
  factory InstallationModel.fromJson(Map<String, dynamic> json) {
    return InstallationModel(
      id: json['id'],
      orderId: json['order_id'],
      installationDate: DateTime.parse(json['installation_date']),
      notes: json['notes'],
      color: json['color'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class InstallationService {
  final ApiService _api = ApiService();
  
  Future<List<InstallationModel>> getInstallations({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      
      final response = await _api.get('/installations', queryParameters: queryParams);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => InstallationModel.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  Future<Map<String, dynamic>> getTomorrowInstallations() async {
    try {
      final response = await _api.get('/installations/tomorrow');
      if (response.statusCode == 200) {
        return response.data;
      }
      return {'count': 0, 'installations': []};
    } catch (e) {
      return {'count': 0, 'installations': []};
    }
  }
  
  Future<bool> deleteInstallation(int installationId) async {
    try {
      final response = await _api.delete('/installations/$installationId');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  Future<InstallationModel?> updateInstallation({
    required int installationId,
    required DateTime installationDate,
    String? notes,
    String? color,
  }) async {
    try {
      final response = await _api.put('/installations/$installationId', data: {
        'order_id': 0, // Will be ignored
        'installation_date': installationDate.toIso8601String(),
        'notes': notes,
        'color': color,
      });
      if (response.statusCode == 200) {
        return InstallationModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

