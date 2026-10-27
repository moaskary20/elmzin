import 'dart:convert';

import 'package:http/http.dart' as http;

import 'home_slide.dart';

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.categoryId,
    required this.categoryName,
    required this.categorySlug,
    this.description = '',
    this.compareAtPrice,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String description;
  final double price;
  final double? compareAtPrice;
  final int stock;
  final int categoryId;
  final String categoryName;
  final String categorySlug;
  final String? imageUrl;

  bool get inStock => stock > 0;

  bool get onSale =>
      compareAtPrice != null && compareAtPrice! > price && price > 0;

  factory ShopProduct.fromJson(Map<String, dynamic> row) {
    final category = row['category'] is Map
        ? Map<String, dynamic>.from(row['category'] as Map)
        : const <String, dynamic>{};
    return ShopProduct(
      id: row['id'] is num ? (row['id'] as num).toInt() : 0,
      name: '${row['name'] ?? ''}',
      description: '${row['description'] ?? ''}',
      price: row['price'] is num ? (row['price'] as num).toDouble() : 0,
      compareAtPrice: row['compare_at_price'] is num
          ? (row['compare_at_price'] as num).toDouble()
          : null,
      stock: row['stock'] is num ? (row['stock'] as num).toInt() : 0,
      categoryId: category['id'] is num ? (category['id'] as num).toInt() : 0,
      categoryName: '${category['name'] ?? ''}',
      categorySlug: '${category['slug'] ?? ''}',
      imageUrl: row['image_url'] as String?,
    );
  }

  static const fallback = [
    ShopProduct(
      id: 1,
      name: 'زيت أرغان للشعر',
      description: 'زيت مغذي للشعر الجاف والتالف.',
      price: 180,
      compareAtPrice: 220,
      stock: 40,
      categoryId: 1,
      categoryName: 'عناية الشعر',
      categorySlug: 'hair-care',
    ),
    ShopProduct(
      id: 2,
      name: 'شامبو بروتين',
      description: 'شامبو يقوّي الشعر ويقلل التساقط.',
      price: 95,
      stock: 60,
      categoryId: 1,
      categoryName: 'عناية الشعر',
      categorySlug: 'hair-care',
    ),
    ShopProduct(
      id: 3,
      name: 'غسول وجه لطيف',
      description: 'ينظف البشرة دون جفاف.',
      price: 120,
      stock: 45,
      categoryId: 2,
      categoryName: 'العناية بالبشرة',
      categorySlug: 'skin-care',
    ),
    ShopProduct(
      id: 4,
      name: 'زيت لحية خشبي',
      description: 'يليّن اللحية ويعطيها رائحة خفيفة.',
      price: 110,
      compareAtPrice: 140,
      stock: 50,
      categoryId: 3,
      categoryName: 'مستلزمات اللحية',
      categorySlug: 'beard-tools',
    ),
  ];
}

class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.imageUrl,
    this.products = const [],
  });

  final int id;
  final String name;
  final String slug;
  final String description;
  final String? imageUrl;
  final List<ShopProduct> products;

  factory ShopCategory.fromJson(Map<String, dynamic> row) {
    final products = row['products'] is List
        ? (row['products'] as List)
              .whereType<Map>()
              .map(
                (item) => ShopProduct.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <ShopProduct>[];
    return ShopCategory(
      id: row['id'] is num ? (row['id'] as num).toInt() : 0,
      name: '${row['name'] ?? ''}',
      slug: '${row['slug'] ?? ''}',
      description: '${row['description'] ?? ''}',
      imageUrl: row['image_url'] as String?,
      products: products,
    );
  }

  static const fallback = [
    ShopCategory(
      id: 1,
      name: 'عناية الشعر',
      slug: 'hair-care',
      description: 'زيوت، شامبو، وحلول للعناية بالشعر.',
      products: [
        ShopProduct(
          id: 1,
          name: 'زيت أرغان للشعر',
          description: 'زيت مغذي للشعر الجاف والتالف.',
          price: 180,
          compareAtPrice: 220,
          stock: 40,
          categoryId: 1,
          categoryName: 'عناية الشعر',
          categorySlug: 'hair-care',
        ),
        ShopProduct(
          id: 2,
          name: 'شامبو بروتين',
          description: 'شامبو يقوّي الشعر ويقلل التساقط.',
          price: 95,
          stock: 60,
          categoryId: 1,
          categoryName: 'عناية الشعر',
          categorySlug: 'hair-care',
        ),
      ],
    ),
    ShopCategory(
      id: 2,
      name: 'العناية بالبشرة',
      slug: 'skin-care',
      description: 'منتجات تنظيف وترطيب للبشرة.',
      products: [
        ShopProduct(
          id: 3,
          name: 'غسول وجه لطيف',
          description: 'ينظف البشرة دون جفاف.',
          price: 120,
          stock: 45,
          categoryId: 2,
          categoryName: 'العناية بالبشرة',
          categorySlug: 'skin-care',
        ),
      ],
    ),
    ShopCategory(
      id: 3,
      name: 'مستلزمات اللحية',
      slug: 'beard-tools',
      description: 'زيوت وأدوات للعناية باللحية.',
      products: [
        ShopProduct(
          id: 4,
          name: 'زيت لحية خشبي',
          description: 'يليّن اللحية ويعطيها رائحة خفيفة.',
          price: 110,
          compareAtPrice: 140,
          stock: 50,
          categoryId: 3,
          categoryName: 'مستلزمات اللحية',
          categorySlug: 'beard-tools',
        ),
      ],
    ),
  ];
}

class ShopApi {
  static Future<List<ShopCategory>> Function() loadCatalog = _loadCatalog;

  static void useDefaults() {
    loadCatalog = _loadCatalog;
  }

  static Future<List<ShopCategory>> _loadCatalog() async {
    final response = await http
        .get(
          Uri.parse('${SlidesApi.baseUrl}/api/shop/catalog'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('shop ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    final categories = data
        .whereType<Map>()
        .map((row) => ShopCategory.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return categories.isEmpty ? ShopCategory.fallback : categories;
  }
}
