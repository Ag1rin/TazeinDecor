// Cart Provider
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

class CartItem {
  final ProductModel product;
  final int localProductId;
  double quantity;
  String unit; // 'package' or 'm2'
  int? variationId; // WooCommerce variation ID
  String? variationPattern; // Selected pattern (طرح)
  String? variationImage; // Variation image URL

  CartItem({
    required this.product,
    required this.localProductId,
    required this.quantity,
    this.unit = 'package',
    this.variationId,
    this.variationPattern,
    this.variationImage,
  });

  double get total {
    // Only use colleague_price (displayPrice)
    final price = product.displayPrice ?? 0.0;
    if (unit == 'm2' && product.packageArea != null) {
      // Convert m² to packages
      final packages = quantity / product.packageArea!;
      return packages * price;
    }
    return quantity * price;
  }
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get itemCount => _items.length;

  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }

  void addToCart(
    ProductModel product, {
    double quantity = 1,
    String unit = 'package',
    int? variationId,
    String? variationPattern,
    String? variationImage,
  }) {
    final existingIndex = _items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.localProductId == product.id &&
          item.unit == unit &&
          item.variationId == variationId,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(
        CartItem(
          product: product,
          localProductId: product.id,
          quantity: quantity,
          unit: unit,
          variationId: variationId,
          variationPattern: variationPattern,
          variationImage: variationImage,
        ),
      );
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void updateQuantity(int index, double quantity) {
    if (index >= 0 && index < _items.length) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  void updateUnit(int index, String unit) {
    if (index >= 0 && index < _items.length) {
      _items[index].unit = unit;
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  double convertAreaToPackages(double area, double? packageArea) {
    if (packageArea == null || packageArea == 0) return 0;
    return area / packageArea;
  }

  double convertPackagesToArea(double packages, double? packageArea) {
    if (packageArea == null) return 0;
    return packages * packageArea;
  }
}
