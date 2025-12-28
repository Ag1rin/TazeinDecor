/// Utility to display product quantity and area coverage based on unit from secure API
/// Uses ONLY the 'unit' field from the secure midia API response
class ProductUnitDisplayHelper {
  /// Get unit from secure API response
  /// Returns the unit field directly from productDetails, or null if not available
  /// Checks both 'unit' and 'method' fields (API may use 'method' instead of 'unit')
  static String? getUnitFromAPI(Map<String, dynamic>? productDetails) {
    if (productDetails == null) return null;
    
    // Get unit directly from API response (top level)
    // Check 'unit' first, then fallback to 'method' (API uses 'method' instead of 'unit' sometimes)
    final unitValue = productDetails['unit'] ?? productDetails['method'];
    if (unitValue != null) {
      final unit = unitValue.toString().trim();
      if (unit.isNotEmpty) {
        return unit;
      }
    }
    
    // Check in calculator object
    final calculator = productDetails['calculator'] as Map<String, dynamic>?;
    if (calculator != null) {
      // Check 'unit' first, then fallback to 'method'
      final calcUnitValue = calculator['unit'] ?? calculator['method'];
      if (calcUnitValue != null) {
        final calcUnit = calcUnitValue.toString().trim();
        if (calcUnit.isNotEmpty) {
          return calcUnit;
        }
      }
    }
    
    return null;
  }

  /// Calculate total area coverage based on unit and product specs
  /// Returns total area in square meters, or null if cannot be calculated
  static double? calculateTotalAreaCoverage({
    required double quantity,
    required String? unit,
    Map<String, dynamic>? productDetails,
  }) {
    if (unit == null || productDetails == null) return null;

    // Normalize unit to handle both Persian and English
    final normalizedUnit = _normalizeUnit(unit);
    
    // Get calculator data
    final calculator = productDetails['calculator'] as Map<String, dynamic>?;
    
    switch (normalizedUnit) {
      case 'roll':
      case 'رول':
        // For rolls, calculate from roll dimensions
        final rollW = _getNumericValue(
          calculator?['roll_w'] ?? 
          calculator?['roll_width'] ?? 
          productDetails['roll_w'] ?? 
          productDetails['roll_width'],
        );
        final rollL = _getNumericValue(
          calculator?['roll_l'] ?? 
          calculator?['roll_length'] ?? 
          productDetails['roll_l'] ?? 
          productDetails['roll_length'],
        );
        
        if (rollW != null && rollL != null && rollW > 0 && rollL > 0) {
          final rollArea = rollW * rollL;
          return quantity * rollArea;
        }
        break;
        
      case 'package':
      case 'بسته':
        // For packages, use package coverage
        final packageCoverage = _getNumericValue(
          calculator?['pkg_cov'] ?? 
          calculator?['package_coverage'] ?? 
          calculator?['params']?['pkg_cov'] ??
          productDetails['pkg_cov'] ?? 
          productDetails['package_coverage'],
        );
        
        if (packageCoverage != null && packageCoverage > 0) {
          return quantity * packageCoverage;
        }
        
        // Fallback to package area if coverage not available
        final packageArea = _getNumericValue(
          calculator?['package_area'] ?? 
          productDetails['package_area'],
        );
        
        if (packageArea != null && packageArea > 0) {
          return quantity * packageArea;
        }
        break;
        
      case 'branch':
      case 'شاخه':
        // For branches, calculate length coverage
        final branchLength = _getNumericValue(
          calculator?['branch_l'] ?? 
          calculator?['branch_length'] ?? 
          calculator?['params']?['branch_l'] ??
          productDetails['branch_l'] ?? 
          productDetails['branch_length'],
        );
        
        if (branchLength != null && branchLength > 0) {
          // Return as area (length * 1 meter width assumption, or just length for display)
          // For now, return null as length coverage is handled separately
          return null;
        }
        break;
        
      case 'tile':
      case 'تایل':
        // For tiles, calculate from tile area or dimensions
        final tileArea = _getNumericValue(
          calculator?['tile_area'] ?? 
          productDetails['tile_area'],
        );
        
        if (tileArea != null && tileArea > 0) {
          return quantity * tileArea;
        }
        
        // Calculate from dimensions if area not available
        final tileW = _getNumericValue(
          calculator?['tile_w'] ?? 
          calculator?['tile_width'] ?? 
          productDetails['tile_w'] ?? 
          productDetails['tile_width'],
        );
        final tileL = _getNumericValue(
          calculator?['tile_l'] ?? 
          calculator?['tile_length'] ?? 
          productDetails['tile_l'] ?? 
          productDetails['tile_length'],
        );
        
        if (tileW != null && tileL != null && tileW > 0 && tileL > 0) {
          final area = tileW * tileL;
          return quantity * area;
        }
        break;
    }
    
    return null;
  }

  /// Calculate length coverage for branch units
  static double? calculateLengthCoverage({
    required double quantity,
    required String? unit,
    Map<String, dynamic>? productDetails,
  }) {
    if (unit == null || productDetails == null) return null;

    final normalizedUnit = _normalizeUnit(unit);
    
    if (normalizedUnit == 'branch' || normalizedUnit == 'شاخه') {
      final calculator = productDetails['calculator'] as Map<String, dynamic>?;
      final branchLength = _getNumericValue(
        calculator?['branch_l'] ?? 
        calculator?['branch_length'] ?? 
        calculator?['params']?['branch_l'] ??
        productDetails['branch_l'] ?? 
        productDetails['branch_length'],
      );
      
      if (branchLength != null && branchLength > 0) {
        return quantity * branchLength;
      }
    }
    
    return null;
  }

  /// Format quantity with unit and total area coverage
  /// Example: "132 رول - متراژ کل: ۶۹۹ متر مربع"
  static String formatQuantityWithCoverage({
    required double quantity,
    required String? unit,
    Map<String, dynamic>? productDetails,
  }) {
    final quantityStr = quantity.toStringAsFixed(0).split('.')[0];
    final formattedQuantity = _formatPersianNumber(quantityStr);
    
    // Get display unit (use as-is from API, or fallback)
    final displayUnit = unit ?? 'بسته';
    
    // Calculate total area coverage
    final areaCoverage = calculateTotalAreaCoverage(
      quantity: quantity,
      unit: unit,
      productDetails: productDetails,
    );
    
    // Calculate length coverage for branches
    final lengthCoverage = calculateLengthCoverage(
      quantity: quantity,
      unit: unit,
      productDetails: productDetails,
    );
    
    String coverageStr = '';
    if (areaCoverage != null && areaCoverage > 0) {
      final areaStr = areaCoverage.toStringAsFixed(0).split('.')[0];
      coverageStr = ' - متراژ کل: ${_formatPersianNumber(areaStr)} متر مربع';
    } else if (lengthCoverage != null && lengthCoverage > 0) {
      final lengthStr = lengthCoverage.toStringAsFixed(0).split('.')[0];
      coverageStr = ' - پوشش ${_formatPersianNumber(lengthStr)} متر طول';
    }
    
    return '$formattedQuantity $displayUnit$coverageStr';
  }

  /// Normalize unit string (handle both Persian and English)
  static String _normalizeUnit(String unit) {
    final normalized = unit.toLowerCase().trim();
    if (normalized == 'رول') return 'roll';
    if (normalized == 'بسته') return 'package';
    if (normalized == 'شاخه') return 'branch';
    if (normalized == 'تایل') return 'tile';
    return normalized;
  }

  /// Get numeric value from various types
  static double? _getNumericValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
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

