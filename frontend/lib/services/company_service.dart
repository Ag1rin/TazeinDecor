// Company Service
import 'api_service.dart';

class CompanyModel {
  final int id;
  final String name;
  final String? mobile;
  final String? address;
  final String? logo;
  final String? notes;
  final String? brandName;  // Brand name to match with product brands
  final String? brandThumbnail;  // Thumbnail image for the brand
  final DateTime createdAt;
  
  CompanyModel({
    required this.id,
    required this.name,
    this.mobile,
    this.address,
    this.logo,
    this.notes,
    this.brandName,
    this.brandThumbnail,
    required this.createdAt,
  });
  
  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      mobile: json['mobile'],
      address: json['address'],
      logo: json['logo'],
      notes: json['notes'],
      brandName: json['brand_name'],
      brandThumbnail: json['brand_thumbnail'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now(), // Fallback for virtual companies from brands
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobile': mobile,
      'address': address,
      'logo': logo,
      'notes': notes,
      'brand_name': brandName,
      'brand_thumbnail': brandThumbnail,
    };
  }
}

class CompanyService {
  final ApiService _api = ApiService();
  
  Future<List<CompanyModel>> getCompanies() async {
    try {
      final response = await _api.get('/companies');
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => CompanyModel.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  Future<CompanyModel?> createCompany(CompanyModel company) async {
    try {
      final response = await _api.post('/companies', data: company.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CompanyModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  Future<CompanyModel?> updateCompany(int companyId, CompanyModel company) async {
    try {
      final response = await _api.put('/companies/$companyId', data: company.toJson());
      if (response.statusCode == 200) {
        return CompanyModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  Future<bool> uploadLogo(int companyId, String logoPath) async {
    try {
      final response = await _api.postFile('/companies/$companyId/logo', logoPath);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> uploadBrandThumbnail(int companyId, String thumbnailPath) async {
    try {
      final response = await _api.postFile('/companies/$companyId/brand-thumbnail', thumbnailPath);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// NEW: Delete company
  Future<bool> deleteCompany(int companyId) async {
    try {
      final response = await _api.delete('/companies/$companyId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
}

