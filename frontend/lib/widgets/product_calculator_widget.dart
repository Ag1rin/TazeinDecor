/// Full-featured Product Calculator Widget
/// Supports 6 calculation modes: Roll, Package, Branch, Square Meter, Tile, Length
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/product_model.dart';
import '../utils/persian_number.dart';

class ProductCalculatorWidget extends StatefulWidget {
  final ProductCalculator calculator;
  final double? colleaguePrice; // Price from secure API
  final Function(int)?
  onCalculationComplete; // Callback when calculation completes with quantity

  const ProductCalculatorWidget({
    super.key,
    required this.calculator,
    this.colleaguePrice,
    this.onCalculationComplete,
  });

  @override
  State<ProductCalculatorWidget> createState() =>
      _ProductCalculatorWidgetState();
}

class _ProductCalculatorWidgetState extends State<ProductCalculatorWidget> {
  String _selectedMode = 'roll';

  // Input controllers for different modes
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _wallLengthController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();

  // Calculation result
  Map<String, dynamic>? _calculationResult;
  int?
  _lastReportedQuantity; // Track last quantity we reported to avoid duplicate callbacks

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.calculator.defaultMode;

    // Add listeners for real-time calculation
    _widthController.addListener(_calculate);
    _heightController.addListener(_calculate);
    _areaController.addListener(_calculate);
    _wallLengthController.addListener(_calculate);
    _lengthController.addListener(_calculate);
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _areaController.dispose();
    _wallLengthController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() {
      _calculationResult = _performCalculation();
    });

    // Call callback when calculation completes with a valid quantity
    if (_calculationResult != null &&
        _calculationResult!['error'] == null &&
        _calculationResult!['quantity'] != null) {
      final quantity = (_calculationResult!['quantity'] as num).ceil();

      // Only call callback if quantity changed (avoid duplicate calls)
      if (quantity != _lastReportedQuantity && quantity > 0) {
        _lastReportedQuantity = quantity;
        // Use a small delay to ensure calculation is stable
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted &&
              _calculationResult != null &&
              _calculationResult!['error'] == null &&
              (_calculationResult!['quantity'] as num).ceil() == quantity) {
            widget.onCalculationComplete?.call(quantity);
          }
        });
      }
    } else if (_calculationResult == null ||
        _calculationResult!['error'] != null) {
      // Reset last reported quantity if calculation is invalid
      _lastReportedQuantity = null;
    }
  }

  Map<String, dynamic>? _performCalculation() {
    try {
      switch (_selectedMode) {
        case 'roll':
          return _calculateRollBased();
        case 'package':
          return _calculatePackageBased();
        case 'branch':
          return _calculateBranchBased();
        case 'square_meter':
          return _calculateSquareMeter();
        case 'tile':
          return _calculateTileBased();
        case 'length':
          return _calculateLengthBased();
        default:
          return null;
      }
    } catch (e) {
      print('❌ Calculation error: $e');
      return null;
    }
  }

  Map<String, dynamic>? _calculateRollBased() {
    final widthStr = _widthController.text.trim();
    final heightStr = _heightController.text.trim();

    if (widthStr.isEmpty || heightStr.isEmpty) return null;

    final width = double.tryParse(widthStr);
    final height = double.tryParse(heightStr);

    if (width == null || height == null || width <= 0 || height <= 0)
      return null;
    if (widget.calculator.rollWidth == null ||
        widget.calculator.rollLength == null)
      return null;

    final rollWidth = widget.calculator.rollWidth!;
    final rollLength = widget.calculator.rollLength!;
    final wastePercentage = widget.calculator.wastePercentage ?? 0.1;

    // Roll-based calculation for wallpaper
    // Formula: rolls = ceil((width * height) / (roll_width * roll_length)) + waste
    // This calculates based on total wall area
    final wallArea = width * height;
    final rollArea = rollWidth * rollLength;

    if (rollArea <= 0) return null;

    // Calculate base rolls needed (always round up)
    final baseRolls = (wallArea / rollArea).ceil();

    // Add waste percentage (always round up to next whole number)
    final rollsWithWaste = baseRolls * (1 + wastePercentage);
    final totalRolls = rollsWithWaste.ceil();

    // Calculate covered area (actual area that will be covered by rolls)
    final coveredArea = totalRolls * rollArea;

    // Calculate total cost
    double? totalCost;
    if (widget.colleaguePrice != null && widget.colleaguePrice! > 0) {
      totalCost = totalRolls * widget.colleaguePrice!;
    }

    return {
      'quantity': totalRolls,
      'unit': 'رول',
      'area': coveredArea,
      'totalCost': totalCost,
    };
  }

  Map<String, dynamic>? _calculatePackageBased() {
    final areaStr = _areaController.text.trim();

    if (areaStr.isEmpty) return null;

    final area = double.tryParse(areaStr);
    if (area == null || area <= 0) return null;

    final packageArea = widget.calculator.packageArea;
    if (packageArea == null || packageArea <= 0) return null;

    final packages = (area / packageArea).ceil();
    final wastePercentage = widget.calculator.wastePercentage ?? 0.1;
    final totalPackages = (packages * (1 + wastePercentage)).ceil();

    double? totalCost;
    if (widget.colleaguePrice != null) {
      totalCost = totalPackages * widget.colleaguePrice!;
    }

    return {
      'quantity': totalPackages,
      'unit': 'بسته',
      'area': area,
      'totalCost': totalCost,
    };
  }

  Map<String, dynamic>? _calculateBranchBased() {
    final wallLengthStr = _wallLengthController.text.trim();

    if (wallLengthStr.isEmpty) return null;

    final wallLength = double.tryParse(wallLengthStr);
    if (wallLength == null || wallLength <= 0) return null;

    final branchLength = widget.calculator.branchLength;
    if (branchLength == null || branchLength <= 0) return null;

    final branches = (wallLength / branchLength).ceil();
    final wastePercentage =
        widget.calculator.wastePercentage ?? 0.05; // 5% for branches
    final totalBranches = (branches * (1 + wastePercentage)).ceil();

    double? totalCost;
    if (widget.colleaguePrice != null) {
      totalCost = totalBranches * widget.colleaguePrice!;
    }

    return {
      'quantity': totalBranches,
      'unit': 'شاخه',
      'area': wallLength,
      'totalCost': totalCost,
    };
  }

  Map<String, dynamic>? _calculateSquareMeter() {
    final widthStr = _widthController.text.trim();
    final heightStr = _heightController.text.trim();

    if (widthStr.isEmpty || heightStr.isEmpty) return null;

    final width = double.tryParse(widthStr);
    final height = double.tryParse(heightStr);

    if (width == null || height == null || width <= 0 || height <= 0)
      return null;

    final area = width * height;

    double? totalCost;
    if (widget.colleaguePrice != null) {
      totalCost = area * widget.colleaguePrice!;
    }

    return {
      'quantity': area,
      'unit': 'متر مربع',
      'area': area,
      'totalCost': totalCost,
    };
  }

  Map<String, dynamic>? _calculateTileBased() {
    final widthStr = _widthController.text.trim();
    final heightStr = _heightController.text.trim();

    if (widthStr.isEmpty || heightStr.isEmpty) return null;

    final width = double.tryParse(widthStr);
    final height = double.tryParse(heightStr);

    if (width == null || height == null || width <= 0 || height <= 0)
      return null;

    final area = width * height;

    // Get tile area
    double? tileArea = widget.calculator.tileArea;
    if (tileArea == null) {
      final tileWidth = widget.calculator.tileWidth;
      final tileLength = widget.calculator.tileLength;
      if (tileWidth != null && tileLength != null) {
        tileArea = tileWidth * tileLength;
      }
    }

    if (tileArea == null || tileArea <= 0) return null;

    final tiles = (area / tileArea).ceil();
    final wastePercentage = widget.calculator.wastePercentage ?? 0.1;
    final totalTiles = (tiles * (1 + wastePercentage)).ceil();

    double? totalCost;
    if (widget.colleaguePrice != null) {
      totalCost = totalTiles * widget.colleaguePrice!;
    }

    return {
      'quantity': totalTiles,
      'unit': 'تایل',
      'area': area,
      'totalCost': totalCost,
    };
  }

  Map<String, dynamic>? _calculateLengthBased() {
    final lengthStr = _lengthController.text.trim();

    if (lengthStr.isEmpty) return null;

    final length = double.tryParse(lengthStr);
    if (length == null || length <= 0) return null;

    final unitPrice = widget.colleaguePrice ?? widget.calculator.unitPrice;
    if (unitPrice == null) return null;

    final totalCost = length * unitPrice;

    return {
      'quantity': length,
      'unit': 'متر',
      'area': length,
      'totalCost': totalCost,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green[300]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.green[200]!.withValues(alpha: 0.3),
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
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calculate,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ماشین حساب محصول',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Calculation mode selector
            const Text(
              'نوع محاسبه:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChip('roll', 'محاسبه رولی'),
                _buildModeChip('package', 'محاسبه بسته ای'),
                _buildModeChip('branch', 'محاسبه شاخه ای'),
                _buildModeChip('square_meter', 'محاسبه متر مربعی'),
                _buildModeChip('tile', 'محاسبه تایلی'),
                _buildModeChip('length', 'محاسبه طولی'),
              ],
            ),
            const SizedBox(height: 24),

            // Input fields based on selected mode
            _buildInputFields(),

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

  Widget _buildModeChip(String mode, String label) {
    final isSelected = _selectedMode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedMode = mode;
            // Clear inputs when mode changes
            _widthController.clear();
            _heightController.clear();
            _areaController.clear();
            _wallLengthController.clear();
            _lengthController.clear();
            _calculationResult = null;
          });
        }
      },
      selectedColor: Colors.green[200],
      checkmarkColor: Colors.green[800],
      labelStyle: TextStyle(
        color: isSelected ? Colors.green[900] : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildInputFields() {
    switch (_selectedMode) {
      case 'roll':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'عرض دیوار (متر)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.width_wide),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'ارتفاع دیوار (متر)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.height),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.calculator.rollWidth != null &&
                widget.calculator.rollLength != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'هر رول: ${PersianNumber.formatNumberString(widget.calculator.rollWidth!.toStringAsFixed(2))} × ${PersianNumber.formatNumberString(widget.calculator.rollLength!.toStringAsFixed(0))} متر',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
          ],
        );

      case 'package':
        return Column(
          children: [
            TextField(
              controller: _areaController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'مساحت (متر مربع)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.square_foot),
              ),
            ),
            if (widget.calculator.packageArea != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'پوشش هر بسته: ${PersianNumber.formatNumberString(widget.calculator.packageArea!.toStringAsFixed(2))} متر مربع',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
          ],
        );

      case 'branch':
        return Column(
          children: [
            TextField(
              controller: _wallLengthController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'طول دیوار (متر)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten),
              ),
            ),
            if (widget.calculator.branchLength != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'طول هر شاخه: ${PersianNumber.formatNumberString(widget.calculator.branchLength!.toStringAsFixed(2))} متر',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
          ],
        );

      case 'square_meter':
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _widthController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'عرض (متر)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.width_wide),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'طول (متر)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.height),
                ),
              ),
            ),
          ],
        );

      case 'tile':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'عرض (متر)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.width_wide),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'طول (متر)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.height),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.calculator.tileArea != null ||
                (widget.calculator.tileWidth != null &&
                    widget.calculator.tileLength != null))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  widget.calculator.tileArea != null
                      ? 'مساحت هر تایل: ${PersianNumber.formatNumberString(widget.calculator.tileArea!.toStringAsFixed(2))} متر مربع'
                      : 'ابعاد تایل: ${PersianNumber.formatNumberString(widget.calculator.tileWidth!.toStringAsFixed(2))} × ${PersianNumber.formatNumberString(widget.calculator.tileLength!.toStringAsFixed(2))} متر',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
          ],
        );

      case 'length':
        return Column(
          children: [
            TextField(
              controller: _lengthController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'طول (متر)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten),
              ),
            ),
            if (widget.colleaguePrice != null ||
                widget.calculator.unitPrice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'قیمت هر متر: ${PersianNumber.formatPrice((widget.colleaguePrice ?? widget.calculator.unitPrice)!)} تومان',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
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
                _calculationResult!['error'],
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
          colors: [Colors.green[400]!, Colors.green[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green[300]!.withValues(alpha: 0.5),
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
                    'متراژ نهایی: ${PersianNumber.formatNumberString(area.toStringAsFixed(2))} متر مربع',
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
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    '${PersianNumber.formatPrice(totalCost)} تومان',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
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
