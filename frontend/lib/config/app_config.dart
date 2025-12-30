// Application configuration
import 'package:flutter/foundation.dart';

class AppConfig {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 FORCE PRODUCTION MODE IN DEBUG BUILDS
  // ═══════════════════════════════════════════════════════════════════════════
  // Set this to TRUE when testing on a physical Android device
  // to make the debug build behave exactly like a release build.
  //
  // When true:
  //   - Uses production API URL (not localhost)
  //   - Disables verbose debug logging
  //   - Payment, PDF, brand detection, referrals all work like production
  //
  // Set to FALSE only when developing with local backend
  // ═══════════════════════════════════════════════════════════════════════════
  static const bool forceProductionMode = true;

  // ═══════════════════════════════════════════════════════════════════════════
  // Determines if we should use production configuration
  // Returns true if: release mode OR forceProductionMode is enabled
  // ═══════════════════════════════════════════════════════════════════════════
  static bool get isProductionConfig => !kDebugMode || forceProductionMode;

  // ═══════════════════════════════════════════════════════════════════════════
  // Determines if verbose logging should be enabled
  // Only enabled in debug mode AND when not forcing production mode
  // ═══════════════════════════════════════════════════════════════════════════
  static bool get enableVerboseLogging => kDebugMode && !forceProductionMode;

  // API Configuration
  static const String _productionUrl = 'https://tazeindecor.liara.run';
  static const String _developmentUrl = 'http://localhost:8000';

  static String get baseUrl {
    if (isProductionConfig) {
      // Production configuration (release mode or forced production)
      return _productionUrl;
    } else {
      // Development - use localhost (only when explicitly developing locally)
      if (enableVerboseLogging) {
        debugPrint('🔧 [DEV] Using local baseUrl: $_developmentUrl');
      }
      return _developmentUrl;
    }
  }

  static const String apiVersion = '/api';

  // App Info
  static const String appName = 'تزئین دکور';
  static const String appVersion = '1.0.1';

  // Colors
  static const int primaryBlue = 0xFF2196F3;
  static const int primaryGreen = 0xFF4CAF50;
  static const int primaryRed = 0xFFF44336;
  static const int primaryOrange = 0xFFFF9800;

  // WooCommerce
  static const String wooCommerceUrl = 'https://tazeindecor.com';

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper for conditional logging - only logs when verbose logging is enabled
  // ═══════════════════════════════════════════════════════════════════════════
  static void log(String message) {
    if (enableVerboseLogging) {
      debugPrint(message);
    }
  }
}
