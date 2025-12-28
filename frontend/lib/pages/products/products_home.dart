// Products Home Page
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/product_service.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/persian_number.dart';
import 'product_detail_screen.dart';
import '../../pages/cart/cart_order_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductsHome extends StatefulWidget {
  const ProductsHome({super.key});

  @override
  State<ProductsHome> createState() => _ProductsHomeState();
}

class _ProductsHomeState extends State<ProductsHome> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  CategoryModel? _selectedCategory;
  static const int _allCategoryId = -1; // Special ID for "All" category
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isGridView = true;
  int _page = 1;
  final int _perPage =
      1000; // Large number to fetch all products when category is selected
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Price reveal state: Map of product ID to whether price is revealed
  final Map<int, bool> _revealedPrices = {};
  final Map<int, Timer> _priceRevealTimers = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Auto-load products when page is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _autoLoadProducts();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-load products when page becomes visible (e.g., returning from another screen)
    // Only load if products list is empty to avoid unnecessary reloads
    if (_products.isEmpty && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _autoLoadProducts();
        }
      });
    }
  }

  /// Auto-load products and categories automatically
  Future<void> _autoLoadProducts() async {
    if (_isLoading) return; // Prevent multiple simultaneous loads
    
    // Load categories first, then products
    await _loadCategories();
    await _loadProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    // Cancel all timers
    for (var timer in _priceRevealTimers.values) {
      timer.cancel();
    }
    _priceRevealTimers.clear();
    super.dispose();
  }

  void _revealPriceTemporarily(int productId) {
    // Cancel existing timer if any
    _priceRevealTimers[productId]?.cancel();

    // Reveal price
    setState(() {
      _revealedPrices[productId] = true;
    });

    // Hide price after 2 seconds
    _priceRevealTimers[productId] = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _revealedPrices[productId] = false;
        });
        _priceRevealTimers.remove(productId);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;

    // If a category is selected, we already loaded all products, so no need to load more
    if (_selectedCategory != null && _selectedCategory!.id != _allCategoryId) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    _page++;
    final products = await _productService.getProducts(
      categoryId: (_selectedCategory?.id == _allCategoryId)
          ? null
          : _selectedCategory?.id,
      page: _page,
      perPage: _perPage,
      search: _searchController.text.isEmpty ? null : _searchController.text,
    );

    // Sort products by ID descending (newest first)
    final sortedProducts = List<ProductModel>.from(products);
    sortedProducts.sort((a, b) => b.id.compareTo(a.id));

    setState(() {
      if (products.isEmpty || products.length < _perPage) {
        _hasMore = false;
      } else {
        _products.addAll(sortedProducts);
      }
      _isLoadingMore = false;
    });
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    final categories = await _productService.getCategories();
    
      // Filter to only show allowed categories (must match backend)
      final allowedCategoryNames = [
        'پارکت',
        'پارکت لمینت',
        'کاغذ دیواری',
      'قرنیز و ابزار',
        'درب',
        'کفپوش',
        'کفپوش pvc',
      ];

    // Categories to explicitly exclude (Parkett Tools / ابزارهای پارکت)
    final excludedCategoryNames = [
      'ابزار پارکت',
      'ابزارهای پارکت',
      'ابزار های پارکت',
      'parkett tools',
      'parquet tools',
    ];
    
    // Always include category ID 80 (Cornice and Tools / قرنیز و ابزار)
    final allowedCategoryIds = [80];
    
    var filteredCategories = categories.where((cat) {
      // Exclude if category name matches excluded names
      if (excludedCategoryNames.any(
        (excluded) =>
            cat.name.toLowerCase().contains(excluded.toLowerCase()) ||
            excluded.toLowerCase().contains(cat.name.toLowerCase()),
      )) {
        return false;
      }
      
      // Include if ID is in allowed list OR name matches allowed names
      if (allowedCategoryIds.contains(cat.id)) {
        return true;
      }
        return allowedCategoryNames.any(
          (allowed) =>
              cat.name.toLowerCase().contains(allowed.toLowerCase()) ||
              allowed.toLowerCase().contains(cat.name.toLowerCase()),
        );
      }).toList();
    
    // Always ensure category ID 80 is included if not already present
    if (!filteredCategories.any((cat) => cat.id == 80)) {
      // Try to fetch category 80 directly
      final category80 = await _productService.getCategoryById(80);
      if (category80 != null) {
        filteredCategories.add(category80);
      }
    }
    
    setState(() {
      _categories = filteredCategories;

      // Set first category as default if available
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
      _isLoading = false;
    });
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _products = [];
      _hasMore = true;
    }

    setState(() {
      _isLoading = true;
    });

    // Add delay to ensure proper loading state
    await Future.delayed(const Duration(milliseconds: 300));

    final selectedCategoryId = _selectedCategory?.id;

    // When a category is selected, fetch all products (backend will return all for category)
    // When no category or searching, use pagination
    final products = await _productService.getProducts(
      categoryId: selectedCategoryId,
      page: _page,
      perPage: selectedCategoryId != null
          ? 1000
          : _perPage, // Fetch all when category selected
      search: _searchController.text.isEmpty ? null : _searchController.text,
    );

    // Sort products by ID descending (newest first) as fallback
    // Backend should already sort, but ensure it here
    final sortedProducts = List<ProductModel>.from(products);
    sortedProducts.sort((a, b) => b.id.compareTo(a.id));

    // Backend already filters by category and sorts newest first, so use products directly
    setState(() {
      if (reset) {
        _products = sortedProducts;
      } else {
        _products.addAll(sortedProducts);
      }
      // If category is selected, we fetched all products, so no more pages
      if (selectedCategoryId != null) {
        _hasMore = false;
      } else {
        _hasMore = products.isNotEmpty && products.length >= _perPage;
      }
      _isLoading = false;
    });
  }

  Future<void> _onRefresh() async {
    // Reload products from WooCommerce on pull-to-refresh
    setState(() {
      _isRefreshing = true;
    });

    // Show loading message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('در حال به‌روزرسانی محصولات...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    // Reload products and categories
    await _loadCategories();
    await _loadProducts(reset: true);

    setState(() {
      _isRefreshing = false;
    });

    if (mounted && _isRefreshing == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('محصولات به‌روزرسانی شد'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onSearch(String query) {
    _loadProducts(reset: true);
  }

  String _removeCategoryFromName(String name, CategoryModel? category) {
    if (category == null) return name;
    if (name.startsWith(category.name)) {
      return name.substring(category.name.length).trim();
    }
    return name;
  }

  Color _getStockStatusColor(int stockQuantity) {
    if (stockQuantity == 0) {
      return Colors.red;
    } else if (stockQuantity < 5) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getStockStatusText(int stockQuantity) {
    if (stockQuantity == 0) {
      return 'ناموجود';
    } else if (stockQuantity < 5) {
      return 'موجودی محدود';
    } else {
      return 'موجود';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محصولات'),
          actions: [
            IconButton(
              icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
            ),
            Consumer<CartProvider>(
              builder: (context, cart, _) {
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CartOrderScreen(),
                          ),
                        );
                      },
                    ),
                    if (cart.itemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cart.itemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'جستجوی محصول...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadProducts(reset: true);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: _onSearch,
              ),
            ),
            // Categories (Tree view)
            if (_categories.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory?.id == category.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(category.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = selected
                                ? category
                                : _categories.first; // Default to "همه"
                          });
                          _loadProducts(reset: true);
                        },
                      ),
                    );
                  },
                ),
              ),
            // Products list/grid with pull-to-refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: _isLoading && _products.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _products.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'محصولی یافت نشد\nبرای به‌روزرسانی، صفحه را به پایین بکشید',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : _isGridView
                    ? GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.7,
                            ),
                        itemCount: _products.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _products.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return _buildProductCard(_products[index]);
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _products.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return _buildProductListItem(_products[index]);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final displayName = _removeCategoryFromName(
      product.name,
      _selectedCategory,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with status badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: product.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 50),
                          ),
                        )
                      : Container(
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 50),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      _revealPriceTemporarily(product.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStockStatusColor(product.stockQuantity),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStockStatusText(product.stockQuantity),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.packageArea != null)
                    Text(
                      '${PersianNumber.formatNumber(product.packageArea!.toInt())} متر مربع',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _revealedPrices[product.id] == true
                        ? (product.displayPrice != null
                              ? Text(
                                  '${PersianNumber.formatPrice(product.displayPrice!)} تومان',
                                  key: const ValueKey('price'),
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const Text(
                                  'قیمت در دسترس نیست',
                                  key: ValueKey('no-price'),
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ))
                        : const Text(
                            '••••••',
                            key: ValueKey('hidden'),
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListItem(ProductModel product) {
    final displayName = _removeCategoryFromName(
      product.name,
      _selectedCategory,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            product.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image),
                  ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  _revealPriceTemporarily(product.id);
                },
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStockStatusColor(product.stockQuantity),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.packageArea != null)
              Text(
                '${PersianNumber.formatNumber(product.packageArea!.toInt())} متر مربع',
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _revealedPrices[product.id] == true
                  ? (product.displayPrice != null
                        ? Text(
                            '${PersianNumber.formatPrice(product.displayPrice!)} تومان',
                            key: const ValueKey('price'),
                          )
                        : const Text(
                            'قیمت در دسترس نیست',
                            key: ValueKey('no-price'),
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ))
                  : const Text(
                      '••••••',
                      key: ValueKey('hidden'),
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
      ),
    );
  }
}
