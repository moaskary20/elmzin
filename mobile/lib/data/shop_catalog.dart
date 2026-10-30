import 'dart:convert';

import 'package:http/http.dart' as http;

import 'home_slide.dart';
import 'localized.dart';

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.categoryId,
    required this.categoryName,
    required this.categorySlug,
    this.nameEn,
    this.description = '',
    this.descriptionEn,
    this.categoryNameEn,
    this.compareAtPrice,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? nameEn;
  final String description;
  final String? descriptionEn;
  final double price;
  final double? compareAtPrice;
  final int stock;
  final int categoryId;
  final String categoryName;
  final String? categoryNameEn;
  final String categorySlug;
  final String? imageUrl;

  String nameFor(bool english) => localized(name, nameEn, english);

  String descriptionFor(bool english) =>
      localized(description, descriptionEn, english);

  String categoryNameFor(bool english) =>
      localized(categoryName, categoryNameEn, english);

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
      nameEn: row['name_en'] as String?,
      description: '${row['description'] ?? ''}',
      descriptionEn: row['description_en'] as String?,
      price: row['price'] is num ? (row['price'] as num).toDouble() : 0,
      compareAtPrice: row['compare_at_price'] is num
          ? (row['compare_at_price'] as num).toDouble()
          : null,
      stock: row['stock'] is num ? (row['stock'] as num).toInt() : 0,
      categoryId: category['id'] is num ? (category['id'] as num).toInt() : 0,
      categoryName: '${category['name'] ?? ''}',
      categoryNameEn: category['name_en'] as String?,
      categorySlug: '${category['slug'] ?? ''}',
      imageUrl: row['image_url'] as String?,
    );
  }

  static const fallback = [
    ShopProduct(
      id: 1,
      name: 'زيت أرغان للشعر',
      nameEn: 'Argan hair oil',
      description: 'زيت مغذي للشعر الجاف والتالف.',
      descriptionEn: 'Nourishing oil for dry and damaged hair.',
      price: 180,
      compareAtPrice: 220,
      stock: 40,
      categoryId: 1,
      categoryName: 'عناية الشعر',
      categoryNameEn: 'Hair care',
      categorySlug: 'hair-care',
    ),
    ShopProduct(
      id: 2,
      name: 'شامبو بروتين',
      nameEn: 'Protein shampoo',
      description: 'شامبو يقوّي الشعر ويقلل التساقط.',
      descriptionEn: 'Strengthens hair and reduces shedding.',
      price: 95,
      stock: 60,
      categoryId: 1,
      categoryName: 'عناية الشعر',
      categoryNameEn: 'Hair care',
      categorySlug: 'hair-care',
    ),
    ShopProduct(
      id: 3,
      name: 'غسول وجه لطيف',
      nameEn: 'Gentle face wash',
      description: 'ينظف البشرة دون جفاف.',
      descriptionEn: 'Cleanses skin without dryness.',
      price: 120,
      stock: 45,
      categoryId: 2,
      categoryName: 'العناية بالبشرة',
      categoryNameEn: 'Skin care',
      categorySlug: 'skin-care',
    ),
    ShopProduct(
      id: 4,
      name: 'زيت لحية خشبي',
      nameEn: 'Woody beard oil',
      description: 'يليّن اللحية ويعطيها رائحة خفيفة.',
      descriptionEn: 'Softens the beard with a light scent.',
      price: 110,
      compareAtPrice: 140,
      stock: 50,
      categoryId: 3,
      categoryName: 'مستلزمات اللحية',
      categoryNameEn: 'Beard tools',
      categorySlug: 'beard-tools',
    ),
  ];
}

class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.nameEn,
    this.description = '',
    this.descriptionEn,
    this.imageUrl,
    this.products = const [],
  });

  final int id;
  final String name;
  final String? nameEn;
  final String slug;
  final String description;
  final String? descriptionEn;
  final String? imageUrl;
  final List<ShopProduct> products;

  String nameFor(bool english) => localized(name, nameEn, english);

  String descriptionFor(bool english) =>
      localized(description, descriptionEn, english);

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
      nameEn: row['name_en'] as String?,
      slug: '${row['slug'] ?? ''}',
      description: '${row['description'] ?? ''}',
      descriptionEn: row['description_en'] as String?,
      imageUrl: row['image_url'] as String?,
      products: products,
    );
  }

  static const fallback = [
    ShopCategory(
      id: 1,
      name: 'عناية الشعر',
      nameEn: 'Hair care',
      slug: 'hair-care',
      description: 'زيوت، شامبو، وحلول للعناية بالشعر.',
      descriptionEn: 'Oils, shampoo, and hair-care solutions.',
      products: [
        ShopProduct(
          id: 1,
          name: 'زيت أرغان للشعر',
          nameEn: 'Argan hair oil',
          description: 'زيت مغذي للشعر الجاف والتالف.',
          descriptionEn: 'Nourishing oil for dry and damaged hair.',
          price: 180,
          compareAtPrice: 220,
          stock: 40,
          categoryId: 1,
          categoryName: 'عناية الشعر',
          categoryNameEn: 'Hair care',
          categorySlug: 'hair-care',
        ),
        ShopProduct(
          id: 2,
          name: 'شامبو بروتين',
          nameEn: 'Protein shampoo',
          description: 'شامبو يقوّي الشعر ويقلل التساقط.',
          descriptionEn: 'Strengthens hair and reduces shedding.',
          price: 95,
          stock: 60,
          categoryId: 1,
          categoryName: 'عناية الشعر',
          categoryNameEn: 'Hair care',
          categorySlug: 'hair-care',
        ),
      ],
    ),
    ShopCategory(
      id: 2,
      name: 'العناية بالبشرة',
      nameEn: 'Skin care',
      slug: 'skin-care',
      description: 'منتجات تنظيف وترطيب للبشرة.',
      descriptionEn: 'Cleansing and moisturizing products.',
      products: [
        ShopProduct(
          id: 3,
          name: 'غسول وجه لطيف',
          nameEn: 'Gentle face wash',
          description: 'ينظف البشرة دون جفاف.',
          descriptionEn: 'Cleanses skin without dryness.',
          price: 120,
          stock: 45,
          categoryId: 2,
          categoryName: 'العناية بالبشرة',
          categoryNameEn: 'Skin care',
          categorySlug: 'skin-care',
        ),
      ],
    ),
    ShopCategory(
      id: 3,
      name: 'مستلزمات اللحية',
      nameEn: 'Beard tools',
      slug: 'beard-tools',
      description: 'زيوت وأدوات للعناية باللحية.',
      descriptionEn: 'Oils and tools for beard care.',
      products: [
        ShopProduct(
          id: 4,
          name: 'زيت لحية خشبي',
          nameEn: 'Woody beard oil',
          description: 'يليّن اللحية ويعطيها رائحة خفيفة.',
          descriptionEn: 'Softens the beard with a light scent.',
          price: 110,
          compareAtPrice: 140,
          stock: 50,
          categoryId: 3,
          categoryName: 'مستلزمات اللحية',
          categoryNameEn: 'Beard tools',
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
