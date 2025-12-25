/// Utility to determine product unit based on category and calculator data
class ProductUnitHelper {
  /// Determine if product is in parquet/flooring category
  /// Categories: پارکت, پارکت لمینت, کفپوش
  static bool isParquetCategory(String? categoryName) {
    if (categoryName == null) return false;
    final name = categoryName.toLowerCase();
    return name.contains('پارکت') || 
           name.contains('parquet') || 
           name.contains('کفپوش') ||
           name.contains('flooring');
  }

  /// Determine if product is in wallpaper category
  /// Categories: کاغذ دیواری
  static bool isWallpaperCategory(String? categoryName) {
    if (categoryName == null) return false;
    final name = categoryName.toLowerCase();
    return name.contains('کاغذ') || 
           name.contains('دیواری') ||
           name.contains('wallpaper');
  }

  /// Determine if product is in parquet tools/skirting category
  /// Categories: ابزار پارکت, ابزار های پارکت, قرنیز, نوار
  static bool isParquetToolsCategory(String? categoryName) {
    if (categoryName == null) return false;
    final name = categoryName.toLowerCase();
    return name.contains('ابزار') || 
           name.contains('tools') ||
           name.contains('قرنیز') ||
           name.contains('skirting') ||
           name.contains('نوار') ||
           name.contains('profile');
  }

  /// Get display unit based on category and calculator data
  /// Returns: 'بسته' (package), 'رول' (roll), or 'شاخه' (branch)
  static String getDisplayUnit({
    String? categoryName,
    String? calculatorUnit,
    bool? hasRollDimensions,
    bool? hasPackageCoverage,
    bool? hasBranchLength,
  }) {
    // Priority 1: Category-based determination
    if (isParquetCategory(categoryName)) {
      return 'بسته';
    }
    if (isWallpaperCategory(categoryName)) {
      return 'رول';
    }
    if (isParquetToolsCategory(categoryName)) {
      return 'شاخه';
    }

    // Priority 2: Calculator-based determination
    if (hasRollDimensions == true || calculatorUnit == 'roll' || calculatorUnit == 'رول') {
      return 'رول';
    }
    if (hasPackageCoverage == true || calculatorUnit == 'package' || calculatorUnit == 'بسته') {
      return 'بسته';
    }
    if (hasBranchLength == true || calculatorUnit == 'branch' || calculatorUnit == 'شاخه') {
      return 'شاخه';
    }

    // Default fallback
    return 'بسته';
  }

  /// Format quantity with unit and area/length coverage
  /// Example: "132 رول - متراژ کل: ۶۹۹ متر مربع" or "132 بسته - متراژ کل: ۲۶۴ متر مربع"
  static String formatQuantityWithCoverage({
    required double quantity,
    required String unit,
    double? areaCoverage,
    double? lengthCoverage,
    String? categoryName,
  }) {
    final quantityStr = quantity.toStringAsFixed(0).split('.')[0];
    final formattedQuantity = _formatPersianNumber(quantityStr);
    
    String coverageStr = '';
    if (isParquetCategory(categoryName) || isWallpaperCategory(categoryName)) {
      // Show area coverage for parquet and wallpaper
      if (areaCoverage != null && areaCoverage > 0) {
        final areaStr = areaCoverage.toStringAsFixed(0).split('.')[0];
        coverageStr = ' - متراژ کل: ${_formatPersianNumber(areaStr)} متر مربع';
      }
    } else if (isParquetToolsCategory(categoryName)) {
      // Show length coverage for tools/skirting
      if (lengthCoverage != null && lengthCoverage > 0) {
        final lengthStr = lengthCoverage.toStringAsFixed(0).split('.')[0];
        coverageStr = ' - پوشش ${_formatPersianNumber(lengthStr)} متر طول';
      }
    }

    return '$formattedQuantity $unit$coverageStr';
  }

  /// Format number to Persian digits
  static String _formatPersianNumber(String number) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return number.split('').map((digit) {
      final intDigit = int.tryParse(digit);
      return intDigit != null ? persianDigits[intDigit] : digit;
    }).join();
  }
}
