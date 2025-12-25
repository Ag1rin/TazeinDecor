// Product model
import 'dart:convert';

class ProductModel {
  final int id;
  final int wooId;
  final String name;
  final String? slug;
  final String? sku;
  final String? description;
  final String? shortDescription;
  final double price;
  final double? regularPrice;
  final double? salePrice;
  final int stockQuantity;
  final String status; // available, unavailable, limited
  final double? packageArea;
  final String? designCode;
  final String? albumCode;
  final int? rollCount;
  final String? imageUrl;
  final List<String>? images;
  final int? categoryId;
  final int? companyId;
  final double? localPrice;
  final int? localStock;
  final String? brand;
  final List<ProductAttribute> attributes;
  final double? colleaguePrice; // Special price for sellers
  final ProductCalculator? calculator; // Wallpaper calculator data

  ProductModel({
    required this.id,
    required this.wooId,
    required this.name,
    this.slug,
    this.sku,
    this.description,
    this.shortDescription,
    required this.price,
    this.regularPrice,
    this.salePrice,
    required this.stockQuantity,
    required this.status,
    this.packageArea,
    this.designCode,
    this.albumCode,
    this.rollCount,
    this.imageUrl,
    this.images,
    this.categoryId,
    this.companyId,
    this.localPrice,
    this.localStock,
    this.brand,
    this.attributes = const [],
    this.colleaguePrice,
    this.calculator,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<String>? imagesList;
    if (json['images'] != null) {
      if (json['images'] is String) {
        try {
          imagesList = List<String>.from(
            (jsonDecode(json['images']) as List).map((x) => x.toString()),
          );
        } catch (e) {
          imagesList = null;
        }
      } else if (json['images'] is List) {
        imagesList = List<String>.from(json['images']);
      }
    }

    return ProductModel(
      id: json['id'],
      wooId: json['woo_id'],
      name: json['name'],
      slug: json['slug'],
      sku: json['sku'],
      description: json['description'],
      shortDescription: json['short_description'],
      price: (json['price'] ?? 0).toDouble(),
      regularPrice: json['regular_price']?.toDouble(),
      salePrice: json['sale_price']?.toDouble(),
      stockQuantity: json['stock_quantity'] ?? 0,
      status: json['status'] ?? 'available',
      packageArea: json['package_area']?.toDouble(),
      designCode: json['design_code'],
      albumCode: json['album_code'],
      rollCount: json['roll_count'],
      imageUrl: json['image_url'],
      images: imagesList,
      categoryId: json['category_id'],
      companyId: json['company_id'],
      localPrice: json['local_price']?.toDouble(),
      localStock: json['local_stock'],
      brand:
          json['brand'] ??
          (json['brands'] is List && (json['brands'] as List).isNotEmpty
              ? (json['brands'] as List).first['name']
              : null),
      attributes: json['attributes'] != null && json['attributes'] is List
          ? (json['attributes'] as List)
                .map((attr) => ProductAttribute.fromJson(attr))
                .toList()
          : const [],
      colleaguePrice: json['colleague_price']?.toDouble(),
      calculator: json['calculator'] != null
          ? ProductCalculator.fromJson(json['calculator'])
          : null,
    );
  }

  // ONLY use colleague_price - never show regular price to authenticated users
  double? get displayPrice => colleaguePrice;
  int get displayStock => localStock ?? stockQuantity;

  bool get isAvailable => status == 'available';
  bool get isUnavailable => status == 'unavailable';
  bool get isLimited => status == 'limited';
}

class ProductCalculator {
  final bool isActive;
  final String?
  calculationMode; // 'roll', 'package', 'branch', 'square_meter', 'tile', 'length'
  final String? unit; // 'roll', 'package', 'tile' - from API

  // Roll-based parameters (wallpaper)
  final double? rollWidth; // in meters
  final double? rollLength; // in meters
  final double? patternRepeat; // in meters
  final double? wastePercentage; // waste percentage (e.g., 0.1 for 10%)

  // Package-based parameters (parquet/flooring)
  final double? packageArea; // coverage per package in m²
  final double?
  packageCoverage; // coverage per package in m² (new field from API)
  final double? packageWidth; // package width in meters
  final double? packageLength; // package length in meters

  // Branch-based parameters (skirting/tools)
  final double? branchLength; // length per branch in meters

  // Tile-based parameters
  final double? tileArea; // area per tile in m²
  final double? tileWidth; // tile width in meters
  final double? tileLength; // tile length in meters

  // Length-only parameters
  final double? unitPrice; // price per meter/unit

  ProductCalculator({
    required this.isActive,
    this.calculationMode,
    this.unit,
    this.rollWidth,
    this.rollLength,
    this.patternRepeat,
    this.wastePercentage,
    this.packageArea,
    this.packageCoverage,
    this.packageWidth,
    this.packageLength,
    this.branchLength,
    this.tileArea,
    this.tileWidth,
    this.tileLength,
    this.unitPrice,
  });

  factory ProductCalculator.fromJson(Map<String, dynamic> json) {
    // Debug logging
    print(
      '🔍 ProductCalculator.fromJson called with keys: ${json.keys.toList()}',
    );
    print('   Raw json data: $json');

    // Helper function to safely parse numeric values
    double? _parseDouble(dynamic value) {
      if (value == null) return null;
      try {
        return (value as num).toDouble();
      } catch (e) {
        print(
          '   ⚠️ Failed to parse double from: $value (type: ${value.runtimeType})',
        );
        return null;
      }
    }

    // Check if fields are nested in 'params' object (API structure)
    final params = json['params'] as Map<String, dynamic>?;

    // Map API fields - support both snake_case and short names (roll_w, roll_l, pkg_cov)
    // Check in params first, then top level
    print('   Checking params: $params');
    print(
      '   Checking for roll_w: ${params?['roll_w'] ?? json['roll_w']}, roll_width: ${params?['roll_width'] ?? json['roll_width']}',
    );
    print(
      '   Checking for roll_l: ${params?['roll_l'] ?? json['roll_l']}, roll_length: ${params?['roll_length'] ?? json['roll_length']}',
    );
    print(
      '   Checking for pkg_cov: ${params?['pkg_cov'] ?? json['pkg_cov']}, package_coverage: ${params?['package_coverage'] ?? json['package_coverage']}',
    );

    final rollWidth = _parseDouble(
      params?['roll_width'] ??
          params?['roll_w'] ??
          json['roll_width'] ??
          json['roll_w'],
    );
    final rollLength = _parseDouble(
      params?['roll_length'] ??
          params?['roll_l'] ??
          json['roll_length'] ??
          json['roll_l'],
    );
    final packageCoverage = _parseDouble(
      params?['package_coverage'] ??
          params?['pkg_cov'] ??
          json['package_coverage'] ??
          json['pkg_cov'],
    );

    print(
      '   Parsed values: rollWidth=$rollWidth, rollLength=$rollLength, packageCoverage=$packageCoverage',
    );

    // Auto-detect unit if not explicitly set
    // Check 'method' field first (API uses 'method' instead of 'unit' sometimes)
    String? detectedUnit;
    final unitFromJson = json['unit']?.toString() ?? json['method']?.toString();
    if (unitFromJson != null && unitFromJson.isNotEmpty) {
      detectedUnit = unitFromJson;
    } else {
      // Auto-detect from fields
      if (rollWidth != null && rollLength != null) {
        detectedUnit = 'roll'; // رول
      } else if (packageCoverage != null && packageCoverage > 0) {
        detectedUnit = 'package'; // بسته
      }
    }

    // Check 'active' field (API uses 'active' instead of 'is_active')
    final isActive = json['is_active'] ?? json['active'] ?? false;

    return ProductCalculator(
      isActive: isActive is bool
          ? isActive
          : (isActive.toString().toLowerCase() == 'true'),
      calculationMode:
          json['calculation_mode']?.toString() ?? json['method']?.toString(),
      unit: detectedUnit, // Auto-detected or explicit
      rollWidth: rollWidth,
      rollLength: rollLength,
      patternRepeat: _parseDouble(
        params?['pattern_repeat'] ?? json['pattern_repeat'],
      ),
      wastePercentage:
          _parseDouble(
            params?['waste_percentage'] ?? json['waste_percentage'],
          ) ??
          0.1, // Default 10%
      packageArea: _parseDouble(
        params?['package_area'] ?? json['package_area'],
      ),
      packageCoverage: packageCoverage, // From pkg_cov or package_coverage
      packageWidth: json['package_width'] != null
          ? (json['package_width'] as num).toDouble()
          : null,
      packageLength: json['package_length'] != null
          ? (json['package_length'] as num).toDouble()
          : null,
      branchLength: json['branch_length'] != null
          ? (json['branch_length'] as num).toDouble()
          : null,
      tileArea: _parseDouble(params?['tile_area'] ?? json['tile_area']),
      tileWidth: _parseDouble(
        params?['tile_w'] ?? params?['tile_width'] ?? json['tile_width'],
      ),
      tileLength: _parseDouble(
        params?['tile_l'] ?? params?['tile_length'] ?? json['tile_length'],
      ),
      unitPrice: _parseDouble(params?['unit_price'] ?? json['unit_price']),
    );
  }

  // Get unit type - prioritize explicit unit, then infer from parameters
  String? get detectedUnit {
    // If unit is explicitly set, use it (handle both Persian and English)
    if (unit != null && unit!.isNotEmpty) {
      final normalized = unit!.toLowerCase().trim();
      // Normalize Persian to English for internal use
      if (normalized == 'رول') return 'roll';
      if (normalized == 'بسته') return 'package';
      if (normalized == 'تایل') return 'tile';
      return normalized; // Already in English or return as-is
    }
    // Auto-detect based on available parameters
    if (rollWidth != null && rollLength != null) return 'roll';
    if (packageArea != null || packageCoverage != null) return 'package';
    if (tileArea != null || (tileWidth != null && tileLength != null))
      return 'tile';
    if (branchLength != null) return 'branch';
    if (unitPrice != null) return 'length';
    return null; // Unknown unit
  }

  // Get default calculation mode based on available parameters
  String get defaultMode {
    if (calculationMode != null && calculationMode!.isNotEmpty) {
      return calculationMode!;
    }
    // Use detected unit
    final detected = detectedUnit;
    if (detected != null) return detected;
    return 'square_meter'; // Default fallback
  }
}

class ProductAttribute {
  final String name;
  final String value;

  ProductAttribute({required this.name, required this.value});

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    final options = json['options'];
    String value = '';
    if (options is List && options.isNotEmpty) {
      value = options.join(', ');
    } else if (json['option'] != null) {
      value = json['option'].toString();
    } else if (json['value'] != null) {
      value = json['value'].toString();
    }

    return ProductAttribute(
      name: json['name']?.toString() ?? 'ویژگی',
      value: value,
    );
  }
}
