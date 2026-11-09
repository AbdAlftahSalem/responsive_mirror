import 'package:flutter/widgets.dart';

/// A product in the demo shop.
class Product {
  const Product(this.id, this.name, this.price, this.colorValue, [this.nameAr]);

  final int id;
  final String name;
  final String? nameAr;

  String localizedName(bool arabic) => arabic ? (nameAr ?? name) : name;

  /// One of [ShopStore.categories] (not 'All').
  String get category => ShopStore.categories[1 + id % 3];
  final double price;
  final int colorValue;
}

/// App-level state. It lives OUTSIDE MaterialApp, so every mirrored device
/// shares it: add to cart on the phone and the desktop badge updates too.
class ShopStore extends ChangeNotifier {
  final List<Product> products = [
    for (var i = 0; i < _names.length; i++)
      Product(i, _names[i], 9.0 + (i * 7) % 40, _colors[i % _colors.length],
          _namesAr[i]),
  ];

  static const categories = ['All', 'Kitchen', 'Decor', 'Living'];

  String _filter = 'All';
  String get filter => _filter;
  set filter(String value) {
    _filter = value;
    notifyListeners();
  }

  List<Product> get visibleProducts => _filter == 'All'
      ? products
      : products.where((p) => p.category == _filter).toList();

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

  static const _namesAr = [
    'وعاء خشب الزيتون',
    'كوب وردة الصحراء',
    'حقيبة كتان',
    'مزهرية خزف',
    'مصباح نحاسي',
    'بطانية صوف',
    'شمعة الأرز',
    'دورق زجاجي',
    'أصيص فخار',
    'إبريق نحاس',
    'سلة خيزران',
    'طقم قواعد حجرية',
    'سجادة قطن',
    'رف بلوط',
    'دفتر جلد',
    'صينية رخام',
    'لوح خيزران',
    'حصيرة جوت',
    'وسادة حرير',
    'كرسي صنوبر',
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

/// The app's own language switch. Shared by every device, like [store].
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));
