// Product Service
import 'package:dio/dio.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../config/app_config.dart';
import 'api_service.dart';

class ProductService {
  final ApiService _api = ApiService();

  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _api.get('/products/categories');
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => CategoryModel.fromJson(json))
            .toList();
      }
      if (response.statusCode == 403) {
        print(
          '❌ Access denied: Only sellers and store managers can access products',
        );
      }
      return [];
    } catch (e) {
      print('❌ Categories fetch error: $e');
      return [];
    }
  }

  /// Get a single category by ID from WooCommerce
  Future<CategoryModel?> getCategoryById(int categoryId) async {
    try {
      final response = await _api.get('/products/categories/$categoryId');
      if (response.statusCode == 200) {
        return CategoryModel.fromJson(response.data);
      }
      if (response.statusCode == 404) {
        print('❌ Category $categoryId not found');
      }
      if (response.statusCode == 403) {
        print(
          '❌ Access denied: Only sellers and store managers can access categories',
        );
      }
      return null;
    } catch (e) {
      print('❌ Category fetch error: $e');
      return null;
    }
  }

  Future<List<ProductModel>> getProducts({
    int? categoryId,
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'per_page': perPage};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _api.get(
        '/products',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          final products = data
              .map((json) => ProductModel.fromJson(json))
              .toList();
          print('✅ Products fetched: ${products.length} products');
          return products;
        } else {
          print('⚠️  Products response is not a list: ${data.runtimeType}');
          return [];
        }
      }
      if (response.statusCode == 403) {
        print(
          '❌ Access denied: Only sellers and store managers can access products',
        );
      }
      if (response.statusCode == 422) {
        print(
          '❌ Validation error: Invalid request parameters. Check per_page value.',
        );
        // Retry with a smaller per_page value if it was too large
        if (perPage > 100) {
          print('🔄 Retrying with per_page=100...');
          return getProducts(
            categoryId: categoryId,
            page: page,
            perPage: 100,
            search: search,
          );
        }
      }
      print('❌ Products fetch failed: Status ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Products fetch error: $e');
      if (e is DioException && e.response != null) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        print('❌ Status: $statusCode');
        print('❌ Response: $responseData');
        
        // Handle 422 validation error by retrying with smaller per_page
        if (statusCode == 422 && perPage > 100) {
          print('🔄 Retrying with per_page=100 due to validation error...');
          return getProducts(
            categoryId: categoryId,
            page: page,
            perPage: 100,
            search: search,
          );
        }
      }
      return [];
    }
  }

  Future<ProductModel?> getProduct(int productId) async {
    try {
      final response = await _api.get('/products/$productId');
      if (response.statusCode == 200) {
        return ProductModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch product from secure custom API
  /// Endpoint: GET https://your-site.com/wp-json/hooshmate/v1/product/{productId}
  Future<Map<String, dynamic>?> getProductFromSecureAPI(int productId) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '${AppConfig.wooCommerceUrl}/wp-json/hooshmate/v1/product/$productId',
        options: Options(
          headers: {
            'x-api-key': 'midia@2025_SecureKey_#98765',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Secure API fetch error: $e');
      if (e is DioException && e.response != null) {
        print('❌ Status: ${e.response?.statusCode}');
        print('❌ Response: ${e.response?.data}');
      }
      return null;
    }
  }

  Future<bool> updateProductPrice(int productId, double price) async {
    try {
      final response = await _api.put(
        '/products/$productId/price',
        queryParameters: {'price': price},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateProductStock(int productId, int stock) async {
    try {
      final response = await _api.put(
        '/products/$productId/stock',
        queryParameters: {'stock': stock},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getProductVariations(int productId) async {
    try {
      final response = await _api.get('/products/$productId/variations');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      print('❌ Variations fetch error: $e');
      return [];
    }
  }

  Future<({String? brand, List<ProductAttribute> attributes})>
  getWooProductDetails(int wooProductId) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '${AppConfig.wooCommerceUrl}/wp-json/wc/v3/products/$wooProductId',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        String? brand;
        if (data['brands'] is List && (data['brands'] as List).isNotEmpty) {
          brand = (data['brands'] as List).first['name'];
        } else if (data['product_brand'] is List &&
            (data['product_brand'] as List).isNotEmpty) {
          brand = (data['product_brand'] as List).first['name'];
        }

        final attributes =
            data['attributes'] != null && data['attributes'] is List
            ? (data['attributes'] as List)
                  .map((attr) => ProductAttribute.fromJson(attr))
                  .toList()
            : <ProductAttribute>[];

        return (brand: brand, attributes: attributes);
      }
    } catch (e) {
      print('❌ Woo product details fetch error: $e');
    }

    return (brand: null, attributes: <ProductAttribute>[]);
  }
}
