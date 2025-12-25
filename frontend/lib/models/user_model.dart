// User model
class UserModel {
  final int id;
  final String username;
  final String fullName;
  final String mobile;
  final String role;
  final double credit;
  final String? storeAddress;
  final bool isActive;
  final double? discountPercentage;
  final List<int>? discountCategoryIds;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.mobile,
    required this.role,
    required this.credit,
    this.storeAddress,
    required this.isActive,
    this.discountPercentage,
    this.discountCategoryIds,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      mobile: json['mobile'],
      role: json['role'],
      credit: (json['credit'] ?? 0).toDouble(),
      storeAddress: json['store_address'],
      isActive: json['is_active'] ?? true,
      discountPercentage: json['discount_percentage'] != null
          ? (json['discount_percentage'] as num).toDouble()
          : null,
      discountCategoryIds: json['discount_category_ids'] != null
          ? List<int>.from(json['discount_category_ids'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'mobile': mobile,
      'role': role,
      'credit': credit,
      'store_address': storeAddress,
      'is_active': isActive,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isOperator => role == 'operator';
  bool get isModerator => role == 'moderator' || role == 'operator';
  bool get isStoreManager => role == 'store_manager';
  bool get isSeller => role == 'seller';
}

