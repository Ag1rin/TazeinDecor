// Authentication Provider
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  
  AuthProvider() {
    checkAuth();
  }
  
  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();
    
    final user = await _authService.getCurrentUser();
    final isLoggedIn = await _authService.isLoggedIn();
    
    _user = user;
    _isAuthenticated = isLoggedIn && user != null;
    _isLoading = false;
    notifyListeners();
  }
  
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final result = await _authService.login(username, password);
      
      if (result['success'] == true) {
        _user = result['user'];
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
  
  void updateUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  /// Refresh user data from backend (for real-time credit updates)
  Future<void> refreshUser() async {
    final user = await _authService.refreshCurrentUser();
    if (user != null) {
      _user = user;
      notifyListeners();
    }
  }

  /// Update credit locally (for real-time updates without backend call)
  void updateCredit(double newCredit) {
    if (_user != null) {
      _user = UserModel(
        id: _user!.id,
        username: _user!.username,
        fullName: _user!.fullName,
        mobile: _user!.mobile,
        role: _user!.role,
        credit: newCredit,
        storeAddress: _user!.storeAddress,
        isActive: _user!.isActive,
        discountPercentage: _user!.discountPercentage,
        discountCategoryIds: _user!.discountCategoryIds,
      );
      notifyListeners();
    }
  }
}

