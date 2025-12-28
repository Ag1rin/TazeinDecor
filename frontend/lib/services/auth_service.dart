// Authentication Service
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      if (AppConfig.enableVerboseLogging) {
        print('🔐 Starting login for: $username');
      }

      final response = await _api.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final prefs = await SharedPreferences.getInstance();

        // Save token IMMEDIATELY and wait for it to complete
        final token = data['access_token'] as String;

        // Save all data
        await prefs.setString('access_token', token);
        await prefs.setString('user', jsonEncode(data['user']));
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_password', password);

        // CRITICAL: Force commit by reading back immediately
        // This ensures SharedPreferences has written the data
        final savedToken = prefs.getString('access_token');
        int retryCount = 0;
        while (savedToken != token && retryCount < 5) {
          if (AppConfig.enableVerboseLogging) {
            print(
              '⚠️  Token not saved yet, retrying... (attempt ${retryCount + 1})',
            );
          }
          await prefs.setString('access_token', token);
          await Future.delayed(const Duration(milliseconds: 50));
          final checkToken = prefs.getString('access_token');
          if (checkToken == token) break;
          retryCount++;
        }

        // Final verification
        final finalToken = prefs.getString('access_token');
        if (finalToken != token) {
          if (AppConfig.enableVerboseLogging) {
            print('❌ CRITICAL ERROR: Token still not saved after retries!');
            print('❌ Expected: ${token.substring(0, 30)}...');
            print('❌ Got: ${finalToken?.substring(0, 30) ?? "NULL"}...');
          }
        }

        if (AppConfig.enableVerboseLogging) {
          print('✅ Login successful!');
          print('✅ Token saved: ${token.substring(0, 30)}...');
          print('✅ Token verified in storage: ${savedToken != null}');
          print('✅ Credentials saved for auto re-login');
        }

        return {
          'success': true,
          'user': UserModel.fromJson(data['user']),
          'token': token,
        };
      }

      if (AppConfig.enableVerboseLogging) {
        print('❌ Login failed: Status ${response.statusCode}');
      }
      return {'success': false, 'message': 'Login failed'};
    } catch (e) {
      if (AppConfig.enableVerboseLogging) {
        print('❌ Login error: $e');
      }
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Automatically re-login using saved credentials
  /// Uses direct HTTP call to avoid circular dependency with ApiService interceptor
  Future<bool> autoRelogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('saved_username');
      final password = prefs.getString('saved_password');

      if (username == null || password == null) {
        if (AppConfig.enableVerboseLogging) {
          print('❌ Auto re-login: No saved credentials found');
        }
        return false;
      }

      if (AppConfig.enableVerboseLogging) {
        print('🔄 Auto re-login: Attempting login for $username...');
      }

      // Use direct HTTP call to bypass ApiService interceptor
      final dio = Dio(
        BaseOptions(
          baseUrl: '${AppConfig.baseUrl}${AppConfig.apiVersion}',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['access_token'] as String;

        // Save token IMMEDIATELY
        await prefs.setString('access_token', token);
        await prefs.setString('user', jsonEncode(data['user']));

        if (AppConfig.enableVerboseLogging) {
          print('✅ Auto re-login successful!');
          print('✅ New token saved: ${token.substring(0, 30)}...');
        }
        return true;
      }

      if (AppConfig.enableVerboseLogging) {
        print('❌ Auto re-login failed: Status ${response.statusCode}');
      }
      return false;
    } catch (e) {
      if (AppConfig.enableVerboseLogging) {
        print('❌ Auto re-login error: $e');
      }
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user');
    // Optionally clear saved credentials for security
    // await prefs.remove('saved_username');
    // await prefs.remove('saved_password');

    if (AppConfig.enableVerboseLogging) {
      print('🔓 Logged out - token and user data cleared');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        return UserModel.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _api.post(
        '/auth/change-password',
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<String> getAppVersion() async {
    try {
      final response = await _api.get('/auth/version');
      return response.data['version'] ?? AppConfig.appVersion;
    } catch (e) {
      return AppConfig.appVersion;
    }
  }

  /// Get current user from backend (refreshed data including updated credit)
  Future<UserModel?> refreshCurrentUser() async {
    try {
      final response = await _api.get('/auth/me');
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        // Update stored user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(response.data));
        return user;
      }
      return null;
    } catch (e) {
      print('❌ Error refreshing user: $e');
      return null;
    }
  }
}
