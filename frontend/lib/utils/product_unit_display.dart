/// Utility to display product quantity and area coverage based on unit from secure API
/// Uses ONLY the unit field from the secure midia API response
/// No category-based logic - relies entirely on API unit field
import '../models/product_model.dart';

class ProductUnitDisplay {
  /// Get display unit in Persian from API unit field
  /// Handles both Persian and English unit values from API
  static String getDisplayUnit(String? apiUnit) {
    if (apiUnit == null || apiUnit.isEmpty) {
      return 'بسته'; // Default fallback
    }

    final normalized = apiUnit.toLowerCase().trim();
    
    // Handle Persian units
    if (normalized == 'رول') return 'رول';
    if (normalized == 'بسته') return 'بسته';
    if (normalized == 'شاخه') return 'شاخه';
    if (normalized == 'تایل') return 'تایل';
    
    // Handle English units
    if (normalized == 'roll') return 'رول';
    if (normalized == 'package') return 'بسته';
    if (normalized == 'branch') return 'شاخه';
    if (normalized == 'tile') return 'تایل';
    
    // Default fallback
    return 'بسته';
  }

  /// Calculate total area coverage based on unit and calculator specs
  /// Returns area in square meters (متر مربع)
  static double? calculateAreaCoverage({
    required double quantity,
    required String? apiUnit,
    Map<String, dynamic>? calculator,
  }) {
    if (apiUnit == null || calculator == null) return null;

    final normalized = apiUnit.toLowerCase().trim();
    
    // For roll (رول): area = quantity × (roll_width × roll_length)
    if (normalized == 'roll' || normalized == 'رول') {
      final rollW = calculator['roll_w'] ?? 
                   calculator['roll_width'] ?? 
                   calculator['params']?['roll_w'];
      final rollL = calculator['roll_l'] ?? 
                   calculator['roll_length'] ?? 
                   calculator['params']?['roll_l'];
      if (rollW != null && rollL != null) {
        final rollArea = (rollW as num).toDouble() * (rollL as num).toDouble();
        return quantity * rollArea;
      }
    }
    
    // For package (بسته): area = quantity × package_coverage
    if (normalized == 'package' || normalized == 'بسته') {
      final packageCoverage = calculator['pkg_cov'] ?? 
                              calculator['package_coverage'] ?? 
                              calculator['params']?['pkg_cov'] ??
                              calculator['package_area'] ??
                              calculator['params']?['package_area'];
      if (packageCoverage != null) {
        return quantity * (packageCoverage as num).toDouble();
      }
    }
    
    // For tile (تایل): area = quantity × tile_area
    if (normalized == 'tile' || normalized == 'تایل') {
      final tileArea = calculator['tile_area'] ?? 
                      calculator['params']?['tile_area'];
      if (tileArea != null) {
        return quantity * (tileArea as num).toDouble();
      }
      // Try calculating from tile dimensions
      final tileW = calculator['tile_w'] ?? 
                   calculator['tile_width'] ?? 
                   calculator['params']?['tile_w'];
      final tileL = calculator['tile_l'] ?? 
                   calculator['tile_length'] ?? 
                   calculator['params']?['tile_l'];
      if (tileW != null && tileL != null) {
        final area = (tileW as num).toDouble() * (tileL as num).toDouble();
        return quantity * area;
      }
    }
    
    // For branch (شاخه): length coverage, not area
    // This is handled separately in formatQuantityWithCoverage
    
    return null;
  }

  /// Calculate length coverage for branch units
  static double? calculateLengthCoverage({
    required double quantity,
    required String? apiUnit,
    Map<String, dynamic>? calculator,
  }) {
    if (apiUnit == null || calculator == null) return null;

    final normalized = apiUnit.toLowerCase().trim();
    
    // For branch (شاخه): length = quantity × branch_length
    if (normalized == 'branch' || normalized == 'شاخه') {
      final branchLength = calculator['branch_l'] ?? 
                          calculator['branch_length'] ?? 
                          calculator['params']?['branch_l'];
      if (branchLength != null) {
        return quantity * (branchLength as num).toDouble();
      }
    }
    
    return null;
  }

  /// Format quantity with unit and area/length coverage
  /// Example: "132 رول - متراژ کل: ۶۹۹ متر مربع"
  /// Example: "50 شاخه - پوشش ۱۵۰ متر طول"
  static String formatQuantityWithCoverage({
    required double quantity,
    required String? apiUnit,
    Map<String, dynamic>? calculator,
  }) {
    final quantityStr = quantity.toStringAsFixed(0).split('.')[0];
    final formattedQuantity = _formatPersianNumber(quantityStr);
    
    final displayUnit = getDisplayUnit(apiUnit);
    
    // Calculate coverage based on unit type
    final normalized = apiUnit?.toLowerCase().trim() ?? '';
    String coverageStr = '';
    
    // For branch units, show length coverage
    if (normalized == 'branch' || normalized == 'شاخه') {
      final lengthCoverage = calculateLengthCoverage(
        quantity: quantity,
        apiUnit: apiUnit,
        calculator: calculator,
      );
      if (lengthCoverage != null && lengthCoverage > 0) {
        final lengthStr = lengthCoverage.toStringAsFixed(0).split('.')[0];
        coverageStr = ' - پوشش ${_formatPersianNumber(lengthStr)} متر طول';
      }
    } else {
      // For other units (roll, package, tile), show area coverage
      final areaCoverage = calculateAreaCoverage(
        quantity: quantity,
        apiUnit: apiUnit,
        calculator: calculator,
      );
      if (areaCoverage != null && areaCoverage > 0) {
        final areaStr = areaCoverage.toStringAsFixed(0).split('.')[0];
        coverageStr = ' - متراژ کل: ${_formatPersianNumber(areaStr)} متر مربع';
      }
    }

    return '$formattedQuantity $displayUnit$coverageStr';
  }

  /// Format number to Persian digits
  static String _formatPersianNumber(String number) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return number.split('').map((digit) {
      final intDigit = int.tryParse(digit);
      return intDigit != null ? persianDigits[intDigit] : digit;
    }).join();
  }

  /// Get unit from calculator object (handles both ProductCalculator and Map formats)
  static String? getUnitFromCalculator(dynamic calculator) {
    if (calculator == null) return null;
    
    // If it's a ProductCalculator object
    if (calculator is ProductCalculator) {
      return calculator.unit;
    }
    
    // If it's a Map (from secure API response)
    if (calculator is Map<String, dynamic>) {
      return calculator['unit']?.toString() ?? 
             calculator['method']?.toString();
    }
    
    return null;
  }
}

