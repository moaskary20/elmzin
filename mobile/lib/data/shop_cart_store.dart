import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'account_store.dart';
import 'home_slide.dart';
import 'shop_catalog.dart';

class ShopCartItem {
  const ShopCartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.stock,
    this.imageUrl,
    this.categoryName = '',
  });

  final int productId;
  final String name;
  final double price;
  final int quantity;
  final int stock;
  final String? imageUrl;
  final String categoryName;

  double get lineTotal => price * quantity;

  ShopCartItem copyWith({int? quantity, int? stock}) {
    return ShopCartItem(
      productId: productId,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      stock: stock ?? this.stock,
      imageUrl: imageUrl,
      categoryName: categoryName,
    );
  }

  Map<String, Object?> toJson() => {
    'product_id': productId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'stock': stock,
    'image_url': imageUrl,
    'category_name': categoryName,
  };

  static ShopCartItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final row = Map<String, dynamic>.from(raw);
    final id = row['product_id'];
    if (id is! num) return null;
    return ShopCartItem(
      productId: id.toInt(),
      name: '${row['name'] ?? ''}',
      price: (row['price'] as num?)?.toDouble() ?? 0,
      quantity: (row['quantity'] as num?)?.toInt() ?? 1,
      stock: (row['stock'] as num?)?.toInt() ?? 0,
      imageUrl: row['image_url'] as String?,
      categoryName: '${row['category_name'] ?? ''}',
    );
  }
}

class ShopOrderResult {
  const ShopOrderResult({
    required this.id,
    required this.total,
    required this.paymentMethod,
  });

  final int id;
  final double total;
  final String paymentMethod;
}

class ShopCartStore extends ChangeNotifier {
  ShopCartStore._();

  static final instance = ShopCartStore._();
  static const _prefsKey = 'muzayen_shop_cart';

  final List<ShopCartItem> _items = [];
  var _loaded = false;

  List<ShopCartItem> get items => List.unmodifiable(_items);

  int get count => _items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => _items.isEmpty;

  double get total => _items.fold(0, (sum, item) => sum + item.lineTotal);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final rows = jsonDecode(raw);
      if (rows is! List) return;
      _items
        ..clear()
        ..addAll(rows.map(ShopCartItem.fromJson).whereType<ShopCartItem>());
      notifyListeners();
    } catch (_) {}
  }

  void add(ShopProduct product, {int quantity = 1}) {
    final qty = quantity.clamp(1, product.stock <= 0 ? 1 : product.stock);
    final index = _items.indexWhere((item) => item.productId == product.id);
    if (index >= 0) {
      final current = _items[index];
      final next = (current.quantity + qty).clamp(1, product.stock);
      _items[index] = current.copyWith(quantity: next, stock: product.stock);
    } else {
      _items.add(
        ShopCartItem(
          productId: product.id,
          name: product.name,
          price: product.price,
          quantity: qty,
          stock: product.stock,
          imageUrl: product.imageUrl,
          categoryName: product.categoryName,
        ),
      );
    }
    _changed();
  }

  void setQuantity(int productId, int quantity) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index < 0) return;
    final item = _items[index];
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = item.copyWith(
        quantity: quantity.clamp(1, item.stock <= 0 ? quantity : item.stock),
      );
    }
    _changed();
  }

  void remove(int productId) {
    _items.removeWhere((item) => item.productId == productId);
    _changed();
  }

  void clear() {
    _items.clear();
    _changed();
  }

  Future<ShopOrderResult> checkout({
    required String name,
    required String phone,
    String? address,
    String paymentMethod = 'cash',
    String? cardLast4,
  }) async {
    if (_items.isEmpty) {
      throw Exception('السلة فارغة.');
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final token = AccountStore.instance.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http
        .post(
          Uri.parse('${SlidesApi.baseUrl}/api/shop/orders'),
          headers: headers,
          body: jsonEncode({
            'customer_name': name,
            'customer_phone': phone,
            if (address != null && address.trim().isNotEmpty)
              'customer_address': address.trim(),
            'payment_method': paymentMethod,
            if (paymentMethod == 'card' && cardLast4 != null)
              'card_last4': cardLast4,
            'items': [
              for (final item in _items)
                {
                  'product_id': item.productId,
                  'quantity': item.quantity,
                },
            ],
          }),
        )
        .timeout(const Duration(seconds: 25));

    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'تعذر إتمام الطلب.';
      if (body is Map) {
        final errors = body['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            message = '${first.first}';
          }
        } else if (body['message'] != null) {
          message = '${body['message']}';
        }
      }
      throw Exception(message);
    }

    final data = body is Map ? body['data'] : null;
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    clear();
    return ShopOrderResult(
      id: map['id'] is num ? (map['id'] as num).toInt() : 0,
      total: map['total'] is num ? (map['total'] as num).toDouble() : 0,
      paymentMethod: '${map['payment_method'] ?? paymentMethod}',
    );
  }

  @visibleForTesting
  void reset() {
    _items.clear();
    _loaded = true;
    notifyListeners();
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode([for (final item in _items) item.toJson()]),
      );
    } catch (_) {}
  }
}
