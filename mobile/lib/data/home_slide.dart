import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HomeSlide {
  const HomeSlide({
    required this.title,
    required this.subtitle,
    this.titleEn,
    this.subtitleEn,
    this.imageUrl,
    this.asset,
  });

  final String title;
  final String subtitle;
  final String? titleEn;
  final String? subtitleEn;
  final String? imageUrl;
  final String? asset;

  String titleFor(String languageCode) {
    if (languageCode == 'en' && (titleEn?.trim().isNotEmpty ?? false)) {
      return titleEn!.trim();
    }
    return title;
  }

  String subtitleFor(String languageCode) {
    if (languageCode == 'en' && (subtitleEn?.trim().isNotEmpty ?? false)) {
      return subtitleEn!.trim();
    }
    return subtitle;
  }

  static const fallback = HomeSlide(
    asset: 'asset/slid1.jpg',
    title: 'الكرسي بانتظارك',
    subtitle:
        'مواعيد فورية في أرقى صالونات ومحلات الحلاقة. اختر المصفف، حدد الموعد، واحضر.',
    titleEn: 'Your chair is waiting',
    subtitleEn:
        'Instant appointments at the finest salons and barbershops. Choose the stylist, pick a time, and show up.',
  );
}

class SlidesApi {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8010',
  );

  static Future<List<HomeSlide>> Function() load = _fetch;

  static Future<List<HomeSlide>> _fetch() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/slides'))
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw Exception('slides ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    final slides = data
        .map((item) {
          final slide = item as Map<String, dynamic>;
          return HomeSlide(
            imageUrl: slide['image_url'] as String?,
            title: (slide['title'] as String?) ?? '',
            subtitle: (slide['subtitle'] as String?) ?? '',
            titleEn: slide['title_en'] as String?,
            subtitleEn: slide['subtitle_en'] as String?,
          );
        })
        .where((slide) => slide.title.isNotEmpty)
        .toList();
    if (slides.isEmpty) {
      return const [HomeSlide.fallback];
    }
    return slides;
  }
}

void logSlideError(Object error) {
  debugPrint('slides: $error');
}
