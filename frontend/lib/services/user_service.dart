// User Service
import 'api_service.dart';
import '../models/user_model.dart';

class UserService {
  final ApiService _api = ApiService();

  Future<List<UserModel>> getUsers({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      final response = await _api.get('/users', queryParameters: queryParams);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => UserModel.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<UserModel?> createUser({
    required String username,
    required String password,
    required String fullName,
    required String mobile,
    required String role,
    String? nationalId,
    String? storeAddress,
    double? discountPercentage,
    List<int>? discountCategoryIds,
  }) async {
    try {
      final data = <String, dynamic>{
        'username': username,
        'password': password,
        'full_name': fullName,
        'mobile': mobile,
        'role': role,
        'national_id': nationalId,
        'store_address': storeAddress,
      };

      // Add discount fields if provided (only for sellers and store managers)
      if (discountPercentage != null &&
          discountPercentage > 0 &&
          (role == 'seller' || role == 'store_manager')) {
        data['discount_percentage'] = discountPercentage;
        if (discountCategoryIds != null) {
          data['discount_category_ids'] = discountCategoryIds;
        }
      }

      final response = await _api.post('/users', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UserModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<UserModel?> updateUser(
    int userId, {
    String? fullName,
    String? mobile,
    String? role,
    double? credit,
    String? storeAddress,
    bool? isActive,
    double? discountPercentage,
    List<int>? discountCategoryIds,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['full_name'] = fullName;
      if (mobile != null) data['mobile'] = mobile;
      if (role != null) data['role'] = role;
      if (credit != null) data['credit'] = credit;
      if (storeAddress != null) data['store_address'] = storeAddress;
      if (isActive != null) data['is_active'] = isActive;

      // Add discount fields if provided (only for sellers and store managers, admin only)
      if (discountPercentage != null || discountCategoryIds != null) {
        if (discountPercentage != null) {
          data['discount_percentage'] = discountPercentage;
        }
        if (discountCategoryIds != null) {
          data['discount_category_ids'] = discountCategoryIds;
        }
      }

      final response = await _api.put('/users/$userId', data: data);
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> uploadBusinessCard(int userId, String imagePath) async {
    try {
      final response = await _api.postFile(
        '/users/$userId/business-card',
        imagePath,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> uploadAvatar(int userId, String imagePath) async {
    try {
      final response = await _api.postFile('/users/$userId/avatar', imagePath);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUser(int userId) async {
    try {
      final response = await _api.delete('/users/$userId');
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
}
