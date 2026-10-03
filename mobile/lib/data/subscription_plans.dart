import 'dart:convert';

import 'package:http/http.dart' as http;

import 'home_slide.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.durationLabel,
    required this.durationUnit,
    required this.durationValue,
    this.tagline,
    this.badge,
    this.price = 0,
    this.isFree = false,
    this.isFeatured = false,
    this.features = const [],
    this.terms = const [],
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
      tagline: text(json['tagline']),
      badge: text(json['badge']),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      priceLabel: '${json['price_label'] ?? ''}',
      isFree: json['is_free'] == true,
      durationValue: (json['duration_value'] as num?)?.toInt() ?? 1,
      durationUnit: '${json['duration_unit'] ?? 'year'}',
      durationLabel: '${json['duration_label'] ?? ''}',
      features: strings(json['features']),
      terms: strings(json['terms']),
      maxServices: (json['max_services'] as num?)?.toInt(),
      maxSpecialists: (json['max_specialists'] as num?)?.toInt(),
      isFeatured: json['is_featured'] == true,
    );
  }

  final int id;
  final String name;
  final String? tagline;
  final String? badge;
  final double price;
  final String priceLabel;
  final bool isFree;
  final int durationValue;
  final String durationUnit;
  final String durationLabel;
  final List<String> features;
  final List<String> terms;
  final int? maxServices;
  final int? maxSpecialists;
  final bool isFeatured;

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
