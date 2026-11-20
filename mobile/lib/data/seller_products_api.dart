import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'account_store.dart';
import 'home_slide.dart';
import 'shop_catalog.dart';

class SellerProductException implements Exception {
  SellerProductException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SellerProduct {
  const SellerProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.categoryId,
    required this.categoryName,
    required this.isActive,
    this.nameEn,
    this.description = '',
    this.descriptionEn,
    this.categoryNameEn,
    this.compareAtPrice,
    this.imageUrl,
    this.sellerName,
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
  final bool isActive;
  final String? imageUrl;
  final String? sellerName;

  factory SellerProduct.fromJson(Map<String, dynamic> row) {
    final category = row['category'] is Map
        ? Map<String, dynamic>.from(row['category'] as Map)
        : const <String, dynamic>{};
    return SellerProduct(
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
      categoryId: category['id'] is num
          ? (category['id'] as num).toInt()
          : (row['shop_category_id'] is num
                ? (row['shop_category_id'] as num).toInt()
                : 0),
      categoryName: '${category['name'] ?? ''}',
      categoryNameEn: category['name_en'] as String?,
      isActive: row['is_active'] == true || row['is_active'] == 1,
      imageUrl: row['image_url'] as String?,
      sellerName: row['seller_name'] as String?,
    );
  }

  ShopProduct toShopProduct() => ShopProduct(
    id: id,
    name: name,
    nameEn: nameEn,
    description: description,
    descriptionEn: descriptionEn,
    price: price,
    compareAtPrice: compareAtPrice,
    stock: stock,
    categoryId: categoryId,
    categoryName: categoryName,
    categoryNameEn: categoryNameEn,
    categorySlug: '',
    imageUrl: imageUrl,
    sellerName: sellerName,
  );
}

class SellerProductsApi {
  static Future<List<SellerProduct>> Function() list = _list;
  static Future<SellerProduct> Function({
    required String name,
    String? nameEn,
    String? description,
    String? descriptionEn,
    required double price,
    double? compareAtPrice,
    required int stock,
    required int shopCategoryId,
    bool isActive,
    String? imagePath,
  })
  create = _create;

  static Future<SellerProduct> Function({
    required int id,
    String? name,
    String? nameEn,
    String? description,
    String? descriptionEn,
    double? price,
    double? compareAtPrice,
    int? stock,
    int? shopCategoryId,
    bool? isActive,
    String? imagePath,
  })
  update = _update;

  static Future<void> Function(int id) destroy = _destroy;

  static void useDefaults() {
    list = _list;
    create = _create;
    update = _update;
    destroy = _destroy;
  }

  static String get _token {
    final token = AccountStore.instance.token;
    if (token == null || token.isEmpty) {
      throw SellerProductException('يجب تسجيل الدخول أولاً.');
    }
    return token;
  }

  static Future<List<SellerProduct>> _list() async {
    final response = await http
        .get(
          Uri.parse('${SlidesApi.baseUrl}/api/seller/products'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      throw SellerProductException('انتهت الجلسة، سجّل الدخول مجدداً.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SellerProductException('تعذر تحميل المنتجات.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map>()
        .map((row) => SellerProduct.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<SellerProduct> _create({
    required String name,
    String? nameEn,
    String? description,
    String? descriptionEn,
    required double price,
    double? compareAtPrice,
    required int stock,
    required int shopCategoryId,
    bool isActive = true,
    String? imagePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${SlidesApi.baseUrl}/api/seller/products'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $_token';
    request.fields.addAll({
      'name': name,
      if (nameEn != null && nameEn.isNotEmpty) 'name_en': nameEn,
      if (description != null) 'description': description,
      if (descriptionEn != null && descriptionEn.isNotEmpty)
        'description_en': descriptionEn,
      'price': price.toString(),
      if (compareAtPrice != null) 'compare_at_price': compareAtPrice.toString(),
      'stock': stock.toString(),
      'shop_category_id': shopCategoryId.toString(),
      'is_active': isActive ? '1' : '0',
    });
    if (imagePath != null && File(imagePath).existsSync()) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }
    final streamed = await request.send().timeout(const Duration(seconds: 40));
    final response = await http.Response.fromStream(streamed);
    return _parseProduct(response, create: true);
  }

  static Future<SellerProduct> _update({
    required int id,
    String? name,
    String? nameEn,
    String? description,
    String? descriptionEn,
    double? price,
    double? compareAtPrice,
    int? stock,
    int? shopCategoryId,
    bool? isActive,
    String? imagePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${SlidesApi.baseUrl}/api/seller/products/$id'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $_token';
    if (name != null) request.fields['name'] = name;
    if (nameEn != null) request.fields['name_en'] = nameEn;
    if (description != null) request.fields['description'] = description;
    if (descriptionEn != null) {
      request.fields['description_en'] = descriptionEn;
    }
    if (price != null) request.fields['price'] = price.toString();
    if (compareAtPrice != null) {
      request.fields['compare_at_price'] = compareAtPrice.toString();
    }
    if (stock != null) request.fields['stock'] = stock.toString();
    if (shopCategoryId != null) {
      request.fields['shop_category_id'] = shopCategoryId.toString();
    }
    if (isActive != null) request.fields['is_active'] = isActive ? '1' : '0';
    if (imagePath != null && File(imagePath).existsSync()) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }
    final streamed = await request.send().timeout(const Duration(seconds: 40));
    final response = await http.Response.fromStream(streamed);
    return _parseProduct(response);
  }

  static Future<void> _destroy(int id) async {
    final response = await http
        .delete(
          Uri.parse('${SlidesApi.baseUrl}/api/seller/products/$id'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      throw SellerProductException('انتهت الجلسة، سجّل الدخول مجدداً.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SellerProductException('تعذر حذف المنتج.');
    }
  }

  static SellerProduct _parseProduct(
    http.Response response, {
    bool create = false,
  }) {
    if (response.statusCode == 401) {
      throw SellerProductException('انتهت الجلسة، سجّل الدخول مجدداً.');
    }
    if (response.statusCode == 403) {
      throw SellerProductException(
        _message(response) ?? 'اشتراكك غير فعّال.',
      );
    }
    if (response.statusCode == 422) {
      throw SellerProductException(
        _message(response) ?? 'تحقق من بيانات المنتج.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SellerProductException(
        create ? 'تعذر إضافة المنتج.' : 'تعذر تحديث المنتج.',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : <String, dynamic>{};
    return SellerProduct.fromJson(data);
  }

  static String? _message(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        final message = body['message'];
        if (message is String && message.isNotEmpty) return message;
        final errors = body['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return '${first.first}';
          return '$first';
        }
      }
    } catch (_) {}
    return null;
  }
}
