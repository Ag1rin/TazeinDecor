/// Smart Quantity Calculator Widget
/// Auto-detects unit type (roll, package, tile) and shows appropriate calculator
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import '../models/product_model.dart';
import '../utils/persian_number.dart';

class SmartQuantityCalculator extends StatefulWidget {
  final ProductCalculator calculator;
  final double? colleaguePrice;
  final Function(double quantity, String unit)? onQuantityCalculated;

  const SmartQuantityCalculator({
    super.key,
    required this.calculator,
    this.colleaguePrice,
    this.onQuantityCalculated,
  });

  @override
  State<SmartQuantityCalculator> createState() =>
      _SmartQuantityCalculatorState();
}

class _SmartQuantityCalculatorState extends State<SmartQuantityCalculator> {
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();

  String? _detectedUnit;
  Map<String, dynamic>? _calculationResult;
  Timer? _calculationTimer;
  int _inputMode = 0; // 0 = length×width, 1 = direct area

  // Helper function to normalize unit names (handle both Persian and English)
  bool _isSupportedUnit(String? unit) {
    if (unit == null) return false;
    final normalized = unit.toLowerCase().trim();
    // Check for roll/رول
    if (normalized == 'roll' || normalized == 'رول') return true;
    // Check for package/بسته
    if (normalized == 'package' || normalized == 'بسته') return true;
    // Check for tile/تایل
    if (normalized == 'tile' || normalized == 'تایل') return true;
    // Check for branch/شاخه (parquet tools/skirting)
    if (normalized == 'branch' || normalized == 'شاخه') return true;
    return false;
  }

  // Normalize unit to English for internal use
  String? _normalizeUnit(String? unit) {
    if (unit == null) return null;
    final normalized = unit.toLowerCase().trim();
    if (normalized == 'رول') return 'roll';
    if (normalized == 'بسته') return 'package';
    if (normalized == 'تایل') return 'tile';
    if (normalized == 'شاخه') return 'branch';
    return normalized; // Already in English or unknown
  }

  @override
  void initState() {
    super.initState();
    final rawUnit = widget.calculator.detectedUnit;
    // Normalize unit to English for internal use
    _detectedUnit = _normalizeUnit(rawUnit) ?? rawUnit;

    // Add listeners for real-time calculation
    _lengthController.addListener(_onInputChanged);
    _widthController.addListener(_onInputChanged);
    _areaController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _calculationTimer?.cancel();
    _lengthController.dispose();
    _widthController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    // Debounce calculation to avoid too many updates
    _calculationTimer?.cancel();
    _calculationTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _calculationResult = _performCalculation();
          _notifyQuantityChange();
        });
      }
    });
  }

  void _notifyQuantityChange() {
    if (_calculationResult != null &&
        _calculationResult!['error'] == null &&
        _calculationResult!['quantity'] != null) {
      final quantity = (_calculationResult!['quantity'] as num).toDouble();
      final unit = _calculationResult!['unit'] as String;
      widget.onQuantityCalculated?.call(quantity, unit);
    }
  }

  Map<String, dynamic>? _performCalculation() {
    if (_detectedUnit == null) {
      return {'error': 'نوع واحد محصول مشخص نیست'};
    }

    try {
      switch (_detectedUnit) {
        case 'roll':
          return _calculateRoll();
        case 'package':
          return _calculatePackage();
        case 'tile':
          return _calculateTile();
        case 'branch':
          return _calculateBranch();
        default:
          return {'error': 'نوع واحد پشتیبانی نمی‌شود'};
      }
    } catch (e) {
      return {'error': 'خطا در محاسبه: $e'};
    }
  }

  Map<String, dynamic>? _calculateRoll() {
    double? wallArea;

    if (_inputMode == 0) {
      // Mode 1: Length × Width
      final lengthStr = _lengthController.text.trim();
      final widthStr = _widthController.text.trim();

      if (lengthStr.isEmpty || widthStr.isEmpty) return null;

      final length = double.tryParse(lengthStr);
      final width = double.tryParse(widthStr);

      if (length == null || width == null || length <= 0 || width <= 0) {
        return null;
      }

      // Wall area = length × width
      wallArea = length * width;
    } else {
      // Mode 2: Direct area input
      final areaStr = _areaController.text.trim();
      if (areaStr.isEmpty) return null;

      wallArea = double.tryParse(areaStr);
      if (wallArea == null || wallArea <= 0) {
        return null;
      }
    }

    if (widget.calculator.rollWidth == null ||
        widget.calculator.rollLength == null) {
      return {'error': 'ابعاد رول مشخص نیست'};
    }

    final rollWidth = widget.calculator.rollWidth!;
    final rollLength = widget.calculator.rollLength!;

    // Roll area = roll_width × roll_length
    final rollArea = rollWidth * rollLength;

    if (rollArea <= 0) {
      return {'error': 'ابعاد رول نامعتبر است'};
    }

    // Add 1.5 meters extra for waste/pattern matching
    final areaWithWaste = wallArea + 1.5;

    // Required quantity = ceil((wall area + 1.5) / roll area)
    final quantity = (areaWithWaste / rollArea).ceil();

    double? totalCost;
    if (widget.colleaguePrice != null && widget.colleaguePrice! > 0) {
      totalCost = quantity * widget.colleaguePrice!;
    }

    return {
      'quantity': quantity.toDouble(),
      'unit': 'رول',
      'area': wallArea,
      'totalCost': totalCost,
    };
  }

  Map<String, dynamic>? _calculatePackage() {
    double? floorArea;

    if (_inputMode == 0) {
      // Mode 1: Length × Width
      final lengthStr = _lengthController.text.trim();
      final widthStr = _widthController.text.trim();

      if (lengthStr.isEmpty || widthStr.isEmpty) return null;

      final length = double.tryParse(lengthStr);
      final width = double.tryParse(widthStr);

      if (length == null || width == null || length <= 0 || width <= 0) {
        return null;
      }

      // Floor area = length × width
      floorArea = length * width;
    } else {
      // Mode 2: Direct area input
      final areaStr = _areaController.text.trim();
      if (areaStr.isEmpty) return null;

      floorArea = double.tryParse(areaStr);
      if (floorArea == null || floorArea <= 0) {
        return null;
      }
    }

    // Use package_coverage if available, otherwise use packageArea
    final packageCoverage =
        widget.calculator.packageCoverage ?? widget.calculator.packageArea;

    if (packageCoverage == null || packageCoverage <= 0) {
      return {'error': 'پوشش بسته مشخص نیست'};
    }

    // Required quantity = ceil(floor area / package_coverage)
    final quantity = (floorArea / packageCoverage).ceil();

    double? totalCost;
    if (widget.colleaguePrice != null && widget.colleaguePrice! > 0) {
      totalCost = quantity * widget.colleaguePrice!;
    }

    return {
      'quantity': quantity.toDouble(),
      'unit': 'بسته',
      'area': floorArea,
      'totalCost': totalCost,
    };
  }

  Map<String, dynamic>? _calculateTile() {
    double? area;

    if (_inputMode == 0) {
      // Mode 1: Length × Width
      final lengthStr = _lengthController.text.trim();
      final widthStr = _widthController.text.trim();

      if (lengthStr.isEmpty || widthStr.isEmpty) return null;

      final length = double.tryParse(lengthStr);
      final width = double.tryParse(widthStr);

      if (length == null || width == null || length <= 0 || width <= 0) {
        return null;
      }

      // Area = length × width
      area = length * width;
    } else {
      // Mode 2: Direct area input
      final areaStr = _areaController.text.trim();
      if (areaStr.isEmpty) return null;

      area = double.tryParse(areaStr);
      if (area == null || area <= 0) {
        return null;
      }
    }

    // Get tile area - prefer tileArea, otherwise calculate from tileWidth × tileLength
    double? tileArea = widget.calculator.tileArea;
    if (tileArea == null) {
      final tileWidth = widget.calculator.tileWidth;
      final tileLength = widget.calculator.tileLength;
      if (tileWidth != null && tileLength != null) {
        tileArea = tileWidth * tileLength;
      }
    }

    if (tileArea == null || tileArea <= 0) {
      return {'error': 'ابعاد تایل مشخص نیست'};
    }

    // Required quantity = ceil(area / tile_area)
    final quantity = (area / tileArea).ceil();

    double? totalCost;
    if (widget.colleaguePrice != null && widget.colleaguePrice! > 0) {
      totalCost = quantity * widget.colleaguePrice!;
    }

    return {
      'quantity': quantity.toDouble(),
      'unit': 'تایل',
      'area': area,
      'totalCost': totalCost,
    };
  }

  Map<String, dynamic>? _calculateBranch() {
    final lengthStr = _lengthController.text.trim();

    if (lengthStr.isEmpty) return null;

    final wallLength = double.tryParse(lengthStr);

    if (wallLength == null || wallLength <= 0) {
      return null;
    }

    if (widget.calculator.branchLength == null || widget.calculator.branchLength! <= 0) {
      return {'error': 'طول شاخه مشخص نیست'};
    }

    final branchLength = widget.calculator.branchLength!;

    // Required quantity = ceil(wall length / branch length)
    final quantity = (wallLength / branchLength).ceil();

    double? totalCost;
    if (widget.colleaguePrice != null && widget.colleaguePrice! > 0) {
      totalCost = quantity * widget.colleaguePrice!;
    }

    return {
      'quantity': quantity.toDouble(),
      'unit': 'شاخه',
      'length': wallLength,
      'totalCost': totalCost,
    };
  }

  String _getLengthLabel() {
    switch (_detectedUnit) {
      case 'roll':
        return 'طول دیوار (متر)';
      case 'package':
        return 'طول کف (متر)';
      case 'tile':
        return 'طول (متر)';
      default:
        return 'طول (متر)';
    }
  }

  String _getWidthLabel() {
    switch (_detectedUnit) {
      case 'roll':
        return 'عرض دیوار (متر)';
      case 'package':
        return 'عرض کف (متر)';
      case 'tile':
        return 'عرض (متر)';
      default:
        return 'عرض (متر)';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging
    print('🔍 SmartQuantityCalculator build:');
    print('   - isActive: ${widget.calculator.isActive}');
    print('   - detectedUnit: $_detectedUnit');
    print('   - unit field: ${widget.calculator.unit}');
    print('   - rollWidth: ${widget.calculator.rollWidth}, rollLength: ${widget.calculator.rollLength}');
    print('   - packageCoverage: ${widget.calculator.packageCoverage}, packageArea: ${widget.calculator.packageArea}');
    print('   - tileWidth: ${widget.calculator.tileWidth}, tileLength: ${widget.calculator.tileLength}');
    
    // Always show if we have a detected unit, even if not active
    // This ensures the calculator tab always shows input fields
    if (_detectedUnit == null) {
      print('   ❌ Hiding calculator: detectedUnit is null');
      return const SizedBox.shrink();
    }

    // Only show for roll, package, tile, and branch units (handle both Persian and English)
    if (!_isSupportedUnit(_detectedUnit)) {
      print('   ❌ Hiding calculator: detectedUnit "$_detectedUnit" is not roll/package/tile/branch');
      return const SizedBox.shrink();
    }
    
    // Normalize unit for internal use
    final normalizedUnit = _normalizeUnit(_detectedUnit);
    if (normalizedUnit != null) {
      _detectedUnit = normalizedUnit; // Update to normalized version
    }
    
    // Show warning if calculator is not active, but still display it
    if (!widget.calculator.isActive) {
      print('   ⚠️ Calculator is not active, but showing anyway for user input');
    } else {
      print('   ✅ Showing calculator for unit: $_detectedUnit');
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue[300]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue[200]!.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calculate,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'محاسبه مقدار مورد نیاز',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Input mode selector (only for roll, package, tile - not for branch)
            if (_detectedUnit != 'branch') ...[
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('طول × عرض'),
                    icon: Icon(Icons.aspect_ratio),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('متراژ کلی'),
                    icon: Icon(Icons.square_foot),
                  ),
                ],
                selected: {_inputMode},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _inputMode = newSelection.first;
                    // Clear opposite mode inputs when switching
                    if (_inputMode == 0) {
                      _areaController.clear();
                    } else {
                      _lengthController.clear();
                      _widthController.clear();
                    }
                    _calculationResult = _performCalculation();
                    _notifyQuantityChange();
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Input fields based on mode
            if (_detectedUnit == 'branch') ...[
              // Branch mode: only wall length
              TextField(
                controller: _lengthController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'طول دیوار (متر)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.straighten),
                  helperText: 'طول کل دیوار را وارد کنید',
                ),
              ),
            ] else if (_inputMode == 0) ...[
              // Mode 1: Length × Width
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lengthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _getLengthLabel(),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.straighten),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _widthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _getWidthLabel(),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.width_wide),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Mode 2: Direct area input
              TextField(
                controller: _areaController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'متراژ کلی (متر مربع)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.square_foot),
                  helperText: 'مساحت کل را به متر مربع وارد کنید',
                ),
              ),
            ],

            // Show product specs
            const SizedBox(height: 12),
            _buildProductSpecs(),

            // Calculation result
            if (_calculationResult != null) ...[
              const SizedBox(height: 20),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductSpecs() {
    String? specText;

    switch (_detectedUnit) {
      case 'roll':
        if (widget.calculator.rollWidth != null &&
            widget.calculator.rollLength != null) {
          specText =
              'هر رول: ${PersianNumber.formatNumberString(widget.calculator.rollWidth!.toStringAsFixed(2))} × ${PersianNumber.formatNumberString(widget.calculator.rollLength!.toStringAsFixed(0))} متر';
        }
        break;
      case 'package':
        final coverage =
            widget.calculator.packageCoverage ?? widget.calculator.packageArea;
        if (coverage != null) {
          specText =
              'پوشش هر بسته: ${PersianNumber.formatNumberString(coverage.toStringAsFixed(2))} متر مربع';
        }
        break;
      case 'tile':
        if (widget.calculator.tileArea != null) {
          specText =
              'مساحت هر تایل: ${PersianNumber.formatNumberString(widget.calculator.tileArea!.toStringAsFixed(2))} متر مربع';
        } else if (widget.calculator.tileWidth != null &&
            widget.calculator.tileLength != null) {
          specText =
              'ابعاد تایل: ${PersianNumber.formatNumberString(widget.calculator.tileWidth!.toStringAsFixed(2))} × ${PersianNumber.formatNumberString(widget.calculator.tileLength!.toStringAsFixed(2))} متر';
        }
        break;
    }

    if (specText == null) return const SizedBox.shrink();

    return Text(
      specText,
      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
    );
  }

  Widget _buildResultCard() {
    if (_calculationResult == null) return const SizedBox.shrink();

    if (_calculationResult!['error'] != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _calculationResult!['error'] as String,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final quantity = _calculationResult!['quantity'] as num;
    final unit = _calculationResult!['unit'] as String;
    final area = _calculationResult!['area'] as num?;
    final totalCost = _calculationResult!['totalCost'] as double?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue[300]!.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'شما به ${PersianNumber.formatNumber(quantity.ceil())} $unit نیاز دارید',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (area != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.square_foot, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'متراژ کل: ${PersianNumber.formatNumberString(area.toStringAsFixed(2))} متر مربع',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Show length for branch products
          if (_calculationResult!['length'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.straighten, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'طول: ${PersianNumber.formatNumberString((_calculationResult!['length'] as num).toStringAsFixed(2))} متر',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (totalCost != null && widget.colleaguePrice != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'هزینه تخمینی:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    '${PersianNumber.formatPrice(totalCost)} تومان',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
