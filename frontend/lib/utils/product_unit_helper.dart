/// Utility to determine product unit based on category and calculator data
import 'package:frontend/utils/persian_number.dart';

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
    required String unit, // Display unit of the quantity (e.g., 'بسته', 'رول', 'شاخه')
    String? categoryName,
    ProductModel? productModel, // Optional: for calculating coverage if not provided
    double? explicitAreaCoverage, // Explicitly provided total area coverage
    double? explicitLengthCoverage, // Explicitly provided total length coverage
  }) {
    // Use PersianNumber.formatDecimal for quantities, allowing decimals and removing trailing zeros if integer
    final formattedQuantity = PersianNumber.formatDecimal(quantity);
    
    double finalAreaCoverage = explicitAreaCoverage ?? 0.0;
    double finalLengthCoverage = explicitLengthCoverage ?? 0.0;

    // If explicit coverages are not provided, try to calculate from productModel
    if (productModel != null && productModel.calculator != null) {
      final calculator = productModel.calculator!;
      final String? calculationUnit = calculator.detectedUnit;

      if (calculationUnit == 'roll' && calculator.rollWidth != null && calculator.rollLength != null) {
        finalAreaCoverage = quantity * calculator.rollWidth! * calculator.rollLength!;
      } else if (calculationUnit == 'package' && calculator.packageCoverage != null) {
        finalAreaCoverage = quantity * calculator.packageCoverage!;
      } else if (calculationUnit == 'branch' && calculator.branchLength != null) {
        finalLengthCoverage = quantity * calculator.branchLength!;
      } else if (calculationUnit == 'tile' && calculator.tileArea != null) {
        finalAreaCoverage = quantity * calculator.tileArea!;
      } else if (calculationUnit == 'square_meter') {
        // If the product's base unit is square_meter, the quantity itself represents the area coverage
        finalAreaCoverage = quantity;
      } else if (calculationUnit == 'length') {
        // If the product's base unit is length, the quantity itself represents the length coverage
        finalLengthCoverage = quantity;
      }
    }

    String coverageStr = '';
    // Determine which type of coverage to display based on category or if it's explicitly a meter unit
    if (isParquetCategory(categoryName) || isWallpaperCategory(categoryName) || unit.toLowerCase() == 'متر مربع' || unit.toLowerCase() == 'm2') {
      if (finalAreaCoverage > 0) {
        final formattedArea = PersianNumber.formatDecimal(finalAreaCoverage, decimalDigits: 2);
        coverageStr = ' - متراژ کل: $formattedArea متر مربع';
      }
    } else if (isParquetToolsCategory(categoryName) || unit.toLowerCase() == 'متر طول' || unit.toLowerCase() == 'm') {
      if (finalLengthCoverage > 0) {
        final formattedLength = PersianNumber.formatDecimal(finalLengthCoverage, decimalDigits: 2);
        coverageStr = ' - پوشش $formattedLength متر طول';
      }
    }

    return '$formattedQuantity $unit$coverageStr';
  }
}
