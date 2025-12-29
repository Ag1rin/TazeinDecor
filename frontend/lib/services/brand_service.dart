// Brand Service - Fetch and cache brands from WooCommerce
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class BrandModel {
  final int id;
  final String name;
  final String? thumbnailUrl;

  BrandModel({
    required this.id,
    required this.name,
    this.thumbnailUrl,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'],
      name: json['name'],
      thumbnailUrl: json['thumbnail_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'thumbnail_url': thumbnailUrl,
    };
  }
}

class BrandService {
  final ApiService _api = ApiService();
  static const String _cacheKey = 'cached_brands';
  static const String _cacheTimestampKey = 'cached_brands_timestamp';

  /// Get brands from API and cache them locally
  Future<List<BrandModel>> fetchBrands({bool forceRefresh = false}) async {
    try {
      // Check cache first (unless force refresh)
      if (!forceRefresh) {
        final cachedBrands = await getCachedBrands();
        if (cachedBrands.isNotEmpty) {
          return cachedBrands;
        }
      }

      // Fetch from API
      final response = await _api.get('/brands');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final brands = data.map((json) => BrandModel.fromJson(json)).toList();

        // Cache the brands
        await _cacheBrands(brands);

        return brands;
      }
      return [];
    } catch (e) {
      print('⚠️ Error fetching brands: $e');
      // Return cached brands if available, even if expired
      return await getCachedBrands();
    }
  }

  /// Get cached brands from local storage
  Future<List<BrandModel>> getCachedBrands() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      
      if (cachedJson != null) {
        final List<dynamic> data = jsonDecode(cachedJson);
        return data.map((json) => BrandModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('⚠️ Error reading cached brands: $e');
      return [];
    }
  }

  /// Cache brands to local storage
  Future<void> _cacheBrands(List<BrandModel> brands) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brandsJson = jsonEncode(
        brands.map((brand) => brand.toJson()).toList(),
      );
      await prefs.setString(_cacheKey, brandsJson);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('⚠️ Error caching brands: $e');
    }
  }

  /// Clear cached brands
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      print('⚠️ Error clearing brand cache: $e');
    }
  }

  /// Get brand by ID from cache
  Future<BrandModel?> getBrandById(int brandId) async {
    final brands = await getCachedBrands();
    try {
      return brands.firstWhere((brand) => brand.id == brandId);
    } catch (e) {
      return null;
    }
  }

  /// Get brand by name from cache
  Future<BrandModel?> getBrandByName(String brandName) async {
    final brands = await getCachedBrands();
    try {
      return brands.firstWhere(
        (brand) => brand.name.toLowerCase() == brandName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}

