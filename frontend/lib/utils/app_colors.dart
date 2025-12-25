// App Colors
import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryRed = Color(0xFFF44336);
  static const Color primaryOrange = Color(0xFFFF9800);

  static const Color available = primaryGreen;
  static const Color unavailable = primaryRed;
  static const Color limited = primaryOrange;

  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
