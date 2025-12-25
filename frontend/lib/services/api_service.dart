// API Service for making HTTP requests
// ignore: unused_import
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class ApiService {
  late Dio _dio;
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${AppConfig.baseUrl}${AppConfig.apiVersion}',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Skip token for login endpoint
          final isLoginEndpoint = options.path.contains('/auth/login');

          if (!isLoginEndpoint) {
            // Always get fresh token from storage
            final prefs = await SharedPreferences.getInstance();
            var token = prefs.getString('access_token');

            // If token is null, try reading again (sometimes SharedPreferences needs a moment)
            if (token == null) {
              await Future.delayed(const Duration(milliseconds: 50));
              token = prefs.getString('access_token');
            }

            if (AppConfig.enableVerboseLogging) {
              print('═══════════════════════════════════════');
              print('🔑 API Request: ${options.method} ${options.path}');
              print('🔑 Token exists: ${token != null}');
              if (token != null) {
                print('🔑 Token preview: ${token.substring(0, 30)}...');
                print('🔑 Token length: ${token.length}');
              } else {
                print('❌ CRITICAL: Token is NULL in SharedPreferences!');
                // Double-check by reading again
                token = prefs.getString('access_token');
                print('🔑 Token after re-read: ${token != null}');
              }
            }

            // If no token, try auto re-login BEFORE making the request
            if (token == null) {
              if (AppConfig.enableVerboseLogging) {
                print('⚠️  No token found - attempting auto re-login...');
              }

              try {
                final authService = AuthService();
                final reloginSuccess = await authService.autoRelogin();

                if (reloginSuccess) {
                  // Get fresh token after re-login
                  token = prefs.getString('access_token');
                  if (AppConfig.enableVerboseLogging) {
                    print('✅ Auto re-login successful! Token retrieved.');
                  }
                } else {
                  if (AppConfig.enableVerboseLogging) {
                    print('❌ Auto re-login failed - no credentials saved');
                  }
                }
              } catch (e) {
                if (AppConfig.enableVerboseLogging) {
                  print('❌ Auto re-login error: $e');
                }
              }
            }

            // ALWAYS add token to headers if we have one
            if (token != null && token.isNotEmpty) {
              // Ensure header is set correctly
              options.headers['Authorization'] = 'Bearer $token';

              // Verify it was set
              final authHeader = options.headers['Authorization'];
              if (AppConfig.enableVerboseLogging) {
                print('✅ Token added to Authorization header');
                print('🔑 Header set: ${authHeader != null}');
                print(
                  '🔑 Header value: ${authHeader?.substring(0, authHeader.length > 50 ? 50 : authHeader.length)}...',
                );
              }

              // Double-check the header is correct
              if (authHeader == null || !authHeader.startsWith('Bearer ')) {
                if (AppConfig.enableVerboseLogging) {
                  print('❌ CRITICAL: Authorization header not set correctly!');
                  print('❌ Attempting to set again...');
                }
                options.headers['Authorization'] = 'Bearer $token';
              }
            } else {
              if (AppConfig.enableVerboseLogging) {
                print(
                  '❌ WARNING: No token available - request will likely fail with 401',
                );
                print('❌ This means token was not saved or was cleared');
              }
            }

            if (AppConfig.enableVerboseLogging) {
              print('═══════════════════════════════════════');
            }
          } else {
            if (AppConfig.enableVerboseLogging) {
              print('🔓 Login endpoint - skipping token');
            }
          }

          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 Unauthorized - Auto re-login and retry
          if (error.response?.statusCode == 401) {
            if (AppConfig.enableVerboseLogging) {
              print('═══════════════════════════════════════');
              print('🔄 401 Unauthorized detected!');
              print('🔄 Path: ${error.requestOptions.path}');
              print('🔄 Attempting auto re-login...');
            }

            // Prevent infinite loop - don't retry if this is already a retry
            final retryCount = error.requestOptions.extra['retryCount'] ?? 0;
            if (retryCount < 1) {
              try {
                // Mark this as a retry attempt
                error.requestOptions.extra['retryCount'] = retryCount + 1;

                // Try to auto re-login
                final authService = AuthService();
                final reloginSuccess = await authService.autoRelogin();

                if (reloginSuccess) {
                  if (AppConfig.enableVerboseLogging) {
                    print('✅ Auto re-login successful!');
                  }

                  // Get fresh token after re-login
                  final prefs = await SharedPreferences.getInstance();
                  final newToken = prefs.getString('access_token');

                  if (newToken != null && newToken.isNotEmpty) {
                    if (AppConfig.enableVerboseLogging) {
                      print(
                        '✅ New token retrieved: ${newToken.substring(0, 30)}...',
                      );
                      print('🔄 Retrying original request...');
                    }

                    // Update the request with new token
                    error.requestOptions.headers['Authorization'] =
                        'Bearer $newToken';

                    // Retry the request
                    final opts = Options(
                      method: error.requestOptions.method,
                      headers: error.requestOptions.headers,
                      extra: error.requestOptions.extra,
                    );

                    final cloneReq = await _dio.request(
                      error.requestOptions.path,
                      options: opts,
                      data: error.requestOptions.data,
                      queryParameters: error.requestOptions.queryParameters,
                    );

                    if (AppConfig.enableVerboseLogging) {
                      print('✅ Request retry successful!');
                      print('═══════════════════════════════════════');
                    }

                    return handler.resolve(cloneReq);
                  } else {
                    if (AppConfig.enableVerboseLogging) {
                      print('❌ Token not found after re-login');
                      print('═══════════════════════════════════════');
                    }
                  }
                } else {
                  if (AppConfig.enableVerboseLogging) {
                    print('❌ Auto re-login failed');
                    print('═══════════════════════════════════════');
                  }
                }
              } catch (e) {
                if (AppConfig.enableVerboseLogging) {
                  print('❌ Auto re-login error: $e');
                  print('═══════════════════════════════════════');
                }
              }
            } else {
              if (AppConfig.enableVerboseLogging) {
                print(
                  '⚠️  Skipping auto re-login: Already retried ($retryCount times)',
                );
                print('═══════════════════════════════════════');
              }
            }
          }

          // Log all errors for debugging
          if (AppConfig.enableVerboseLogging) {
            print(
              '❌ API Error: ${error.requestOptions.method} ${error.requestOptions.path}',
            );
            print('❌ Status: ${error.response?.statusCode}');
            print('❌ Error: ${error.message}');
            if (error.response != null) {
              print('❌ Response: ${error.response?.data}');
            }
            if (error.response?.statusCode == 401) {
              print(
                '❌ Authorization header: ${error.requestOptions.headers['Authorization'] ?? 'MISSING'}',
              );
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.delete(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> postFile(
    String path,
    String filePath, {
    String fieldName = 'file',
  }) async {
    try {
      FormData formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
      });
      return await _dio.post(path, data: formData);
    } catch (e) {
      rethrow;
    }
  }
}
