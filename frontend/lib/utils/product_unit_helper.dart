/// Utility to determine product unit based on calculator data
import '../models/product_model.dart';
import 'persian_number.dart';

class ProductUnitHelper {
  /// Format quantity with unit and area/length coverage
  /// Example: "132 رول - متراژ کل: ۶۹۹ متر مربع" or "132 بسته - متراژ کل: ۲۶۴ متر مربع"
  static String formatQuantityWithCoverage({
    required double quantity,
    required String unit, // Display unit of the quantity (e.g., 'بسته', 'رول', 'شاخه')
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
    String? effectiveCalculationUnit;

    if (productModel?.calculator != null) {
      effectiveCalculationUnit = productModel?.calculator?.detectedUnit;
    }

    // Determine which type of coverage to display based on the calculated coverage type
    // or the primary unit itself if no specific calculation unit is detected.
    if (finalAreaCoverage > 0 &&
        (effectiveCalculationUnit == 'roll' ||
         effectiveCalculationUnit == 'package' ||
         effectiveCalculationUnit == 'tile' ||
         effectiveCalculationUnit == 'square_meter' ||
         unit.toLowerCase().contains('متر مربع') || // Fallback if unit string implies area
         unit.toLowerCase().contains('m2'))) {
      final formattedArea = PersianNumber.formatDecimal(finalAreaCoverage, decimalDigits: 2);
      coverageStr = ' - متراژ کل: $formattedArea متر مربع';
    } else if (finalLengthCoverage > 0 &&
               (effectiveCalculationUnit == 'branch' ||
                effectiveCalculationUnit == 'length' ||
                unit.toLowerCase().contains('متر طول') || // Fallback if unit string implies length
                (unit.toLowerCase().contains('m') && !unit.toLowerCase().contains('m2')))) { // Avoid matching 'm' in 'm2'
      final formattedLength = PersianNumber.formatDecimal(finalLengthCoverage, decimalDigits: 2);
      coverageStr = ' - پوشش $formattedLength متر طول';
    }

    return '$formattedQuantity $unit$coverageStr';
  }
}
