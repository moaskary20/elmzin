import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:muzayen/data/home_slide.dart';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.durationMinutes,
    this.description,
  });

  final int id;
  final String name;
  final int durationMinutes;
  final String? description;

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      description: json['description'] as String?,
    );
  }
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.services,
  });

  final int id;
  final String name;
  final String slug;
  final List<CatalogItem> services;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    final services = json['services'] as List<dynamic>? ?? const [];
    return CatalogCategory(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      services: services
          .whereType<Map<String, dynamic>>()
          .map(CatalogItem.fromJson)
          .toList(),
    );
  }
}

class SalonCatalogApi {
  static Future<List<CatalogCategory>> Function() load = _load;

  static void useDefault() => load = _load;

  static Future<List<CatalogCategory>> _load() async {
    final response = await http
        .get(
          Uri.parse('${SlidesApi.baseUrl}/api/catalog'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('catalog ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(CatalogCategory.fromJson)
        .toList();
  }
}
