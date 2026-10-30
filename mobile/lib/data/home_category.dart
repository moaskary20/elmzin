import 'dart:convert';

import 'package:http/http.dart' as http;

import 'home_slide.dart';
import 'localized.dart';

class HomeCategory {
  const HomeCategory({
    required this.name,
    required this.slug,
    required this.description,
    this.nameEn,
    this.descriptionEn,
    this.salonsCount = 0,
  });

  final String name;
  final String? nameEn;
  final String slug;
  final String description;
  final String? descriptionEn;
  final int salonsCount;

  String nameFor(String languageCode) {
    final english = languageCode == 'en';
    final fromApi = localized(name, nameEn, english);
    if (english && fromApi == name) {
      return switch (slug) {
        'men' => 'Men',
        'women' => 'Women',
        'kids' => 'Kids',
        _ => name,
      };
    }
    return fromApi;
  }

  String descriptionFor(String languageCode) {
    final english = languageCode == 'en';
    final fromApi = localized(description, descriptionEn, english);
    if (english && fromApi == description) {
      return switch (slug) {
        'men' => "Barbershops and men's grooming.",
        'women' => "Beauty salons and women's care.",
        'kids' => "Kids' salons and gentle haircuts.",
        _ => description,
      };
    }
    return fromApi;
  }

  static const fallback = [
    HomeCategory(
      name: 'رجالي',
      slug: 'men',
      description: 'صالونات الحلاقة والعناية الرجالية.',
    ),
    HomeCategory(
      name: 'حريمي',
      slug: 'women',
      description: 'صالونات التجميل والعناية النسائية.',
    ),
    HomeCategory(
      name: 'أطفال',
      slug: 'kids',
      description: 'صالونات الأطفال وقصات الشعر اللطيفة.',
    ),
  ];
}

class CategoriesApi {
  static Future<List<HomeCategory>> Function() load = _fetch;

  static Future<List<HomeCategory>> _fetch() async {
    final response = await http
        .get(Uri.parse('${SlidesApi.baseUrl}/api/categories'))
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw Exception('categories ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    final categories = data
        .map((item) {
          final category = item as Map<String, dynamic>;
          return HomeCategory(
            name: (category['name'] as String?) ?? '',
            nameEn: category['name_en'] as String?,
            slug: (category['slug'] as String?) ?? '',
            description: (category['description'] as String?) ?? '',
            descriptionEn: category['description_en'] as String?,
            salonsCount: (category['salons_count'] as num?)?.toInt() ?? 0,
          );
        })
        .where((category) => category.name.isNotEmpty)
        .toList();
    if (categories.isEmpty) return HomeCategory.fallback;
    return categories;
  }
}
