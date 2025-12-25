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
}

