import 'package:flutter/foundation.dart';

/// A product in the demo shop.
class Product {
  const Product(this.id, this.name, this.price, this.colorValue);

  final int id;
  final String name;
  final double price;
  final int colorValue;
}

/// App-level state. It lives OUTSIDE MaterialApp, so every mirrored device
/// shares it: add to cart on the phone and the desktop badge updates too.
class ShopStore extends ChangeNotifier {
  final List<Product> products = [
    for (var i = 0; i < _names.length; i++)
      Product(i, _names[i], 9.0 + (i * 7) % 40, _colors[i % _colors.length]),
  ];

  int _cart = 0;
  int get cartCount => _cart;

  void addToCart(Product p) {
    _cart++;
    notifyListeners();
  }

  void addProduct(String name, double price) {
    products.insert(
        0,
        Product(products.length, name, price,
            _colors[products.length % _colors.length]));
    notifyListeners();
  }

  static const _names = [
    'Olive Wood Bowl',
    'Desert Rose Mug',
    'Linen Tote',
    'Ceramic Vase',
    'Brass Lamp',
    'Wool Throw',
    'Cedar Candle',
    'Glass Carafe',
    'Clay Planter',
    'Copper Kettle',
    'Rattan Basket',
    'Stone Coaster Set',
    'Cotton Rug',
    'Oak Shelf',
    'Leather Journal',
    'Marble Tray',
    'Bamboo Board',
    'Jute Mat',
    'Silk Cushion',
    'Pine Stool',
  ];

  static const _colors = [
    0xFFE57373,
    0xFF64B5F6,
    0xFF81C784,
    0xFFFFB74D,
    0xFFBA68C8,
    0xFF4DB6AC,
    0xFFF06292,
    0xFF7986CB,
  ];
}

final ShopStore store = ShopStore();
