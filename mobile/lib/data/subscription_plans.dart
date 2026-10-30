import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:muzayen/data/localized.dart';

import 'home_slide.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.durationLabel,
    required this.durationUnit,
    required this.durationValue,
    this.nameEn,
    this.tagline,
    this.taglineEn,
    this.badge,
    this.badgeEn,
    this.price = 0,
    this.priceLabelEn,
    this.isFree = false,
    this.isFeatured = false,
    this.features = const [],
    this.featuresEn = const [],
    this.terms = const [],
    this.termsEn = const [],
    this.durationLabelEn,
    this.maxServices,
    this.maxSpecialists,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value.map((item) => '$item').where((item) => item.isNotEmpty).toList()
        : const [];
    String? text(Object? value) {
      final out = value?.toString().trim();
      return out == null || out.isEmpty ? null : out;
    }

    return SubscriptionPlan(
      id: (json['id'] as num).toInt(),
      name: '${json['name'] ?? ''}',
      nameEn: text(json['name_en']),
      tagline: text(json['tagline']),
      taglineEn: text(json['tagline_en']),
      badge: text(json['badge']),
      badgeEn: text(json['badge_en']),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      priceLabel: '${json['price_label'] ?? ''}',
      priceLabelEn: text(json['price_label_en']),
      isFree: json['is_free'] == true,
      durationValue: (json['duration_value'] as num?)?.toInt() ?? 1,
      durationUnit: '${json['duration_unit'] ?? 'year'}',
      durationLabel: '${json['duration_label'] ?? ''}',
      durationLabelEn: text(json['duration_label_en']),
      features: strings(json['features']),
      featuresEn: strings(json['features_en']),
      terms: strings(json['terms']),
      termsEn: strings(json['terms_en']),
      maxServices: (json['max_services'] as num?)?.toInt(),
      maxSpecialists: (json['max_specialists'] as num?)?.toInt(),
      isFeatured: json['is_featured'] == true,
    );
  }

  final int id;
  final String name;
  final String? nameEn;
  final String? tagline;
  final String? taglineEn;
  final String? badge;
  final String? badgeEn;
  final double price;
  final String priceLabel;
  final String? priceLabelEn;
  final bool isFree;
  final int durationValue;
  final String durationUnit;
  final String durationLabel;
  final String? durationLabelEn;
  final List<String> features;
  final List<String> featuresEn;
  final List<String> terms;
  final List<String> termsEn;
  final int? maxServices;
  final int? maxSpecialists;
  final bool isFeatured;

  String nameFor(bool english) => localized(name, nameEn, english);

  String? taglineFor(bool english) {
    final value = localized(tagline ?? '', taglineEn, english).trim();
    return value.isEmpty ? null : value;
  }

  String? badgeFor(bool english) {
    final value = localized(badge ?? '', badgeEn, english).trim();
    return value.isEmpty ? null : value;
  }

  String priceLabelFor(bool english) =>
      localized(priceLabel, priceLabelEn, english);

  String durationLabelFor(bool english) =>
      localized(durationLabel, durationLabelEn, english);

  List<String> featuresFor(bool english) =>
      english && featuresEn.isNotEmpty ? featuresEn : features;

  List<String> termsFor(bool english) =>
      english && termsEn.isNotEmpty ? termsEn : terms;

  DateTime endsFrom(DateTime start) {
    final value = durationValue < 1 ? 1 : durationValue;
    return switch (durationUnit) {
      'day' => start.add(Duration(days: value)),
      'month' => DateTime(start.year, start.month + value, start.day),
      _ => DateTime(start.year + value, start.month, start.day),
    };
  }
}

class SubscriptionPlansApi {
  static Future<List<SubscriptionPlan>> Function() load = _load;

  static void useDefault() => load = _load;

  static Future<List<SubscriptionPlan>> _load() async {
    final response = await http
        .get(
          Uri.parse('${SlidesApi.baseUrl}/api/subscription-plans'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('plans ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlan.fromJson)
        .toList();
  }
}
