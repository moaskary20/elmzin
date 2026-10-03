import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'home_slide.dart';

class HomeSalon {
  const HomeSalon({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.ratingAvg,
    required this.isFeatured,
    required this.offersHomeService,
    this.latitude,
    this.longitude,
    this.minPrice,
    this.imageUrl,
    this.categorySlug = '',
    this.verified = false,
    this.reviewsCount = 0,
    this.services = const [],
  });

  final int id;
  final String name;
  final String city;
  final String district;
  final double ratingAvg;
  final bool isFeatured;
  final bool offersHomeService;
  final double? latitude;
  final double? longitude;
  final double? minPrice;
  final String? imageUrl;
  final String categorySlug;
  final bool verified;
  final int reviewsCount;
  final List<String> services;

  static const originLatitude = 30.0444;
  static const originLongitude = 31.2357;

  static const knownPlaces = <String, (double, double)>{
    'مدينة نصر': (30.0561, 31.3300),
    'المهندسين': (30.0556, 31.2001),
    'التجمع الخامس': (30.0074, 31.4913),
    'المعادي': (29.9602, 31.2569),
    'الزمالك': (30.0626, 31.2197),
    'الدقي': (30.0384, 31.2089),
    'القاهرة': (30.0444, 31.2357),
    'الجيزة': (30.0131, 31.2089),
  };

  String get place => district.isEmpty ? city : '$district، $city';

  double get distanceKm => distanceFrom(originLatitude, originLongitude);

  double distanceFrom(double originLat, double originLng) {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return 9999;
    const earth = 6371.0;
    double rad(double degree) => degree * math.pi / 180;
    final dLat = rad(lat - originLat);
    final dLng = rad(lng - originLng);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(originLat)) *
            math.cos(rad(lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static const fallback = [
    HomeSalon(
      id: 1,
      name: 'صالون الليث',
      city: 'القاهرة',
      district: 'مدينة نصر',
      ratingAvg: 4.9,
      isFeatured: true,
      offersHomeService: false,
      latitude: 30.0561,
      longitude: 31.3300,
      minPrice: 80,
      categorySlug: 'men',
      verified: true,
    ),
    HomeSalon(
      id: 2,
      name: 'لمسة جمال',
      city: 'الجيزة',
      district: 'المهندسين',
      ratingAvg: 4.6,
      isFeatured: true,
      offersHomeService: true,
      latitude: 30.0556,
      longitude: 31.2001,
      minPrice: 300,
      categorySlug: 'women',
      verified: true,
    ),
    HomeSalon(
      id: 3,
      name: 'براعم',
      city: 'القاهرة',
      district: 'التجمع الخامس',
      ratingAvg: 4.2,
      isFeatured: true,
      offersHomeService: false,
      latitude: 30.0074,
      longitude: 31.4913,
      minPrice: 70,
      categorySlug: 'kids',
      verified: false,
    ),
    HomeSalon(
      id: 4,
      name: 'بيت الحلاقة',
      city: 'القاهرة',
      district: 'المعادي',
      ratingAvg: 4.7,
      isFeatured: false,
      offersHomeService: true,
      latitude: 29.9602,
      longitude: 31.2569,
      minPrice: 100,
      categorySlug: 'men',
      verified: true,
    ),
    HomeSalon(
      id: 5,
      name: 'دار الجمال',
      city: 'القاهرة',
      district: 'الزمالك',
      ratingAvg: 4.9,
      isFeatured: false,
      offersHomeService: false,
      latitude: 30.0626,
      longitude: 31.2197,
      minPrice: 380,
      categorySlug: 'women',
      verified: true,
    ),
    HomeSalon(
      id: 6,
      name: 'صالون الصغير',
      city: 'القاهرة',
      district: 'مدينة نصر',
      ratingAvg: 4.1,
      isFeatured: false,
      offersHomeService: false,
      latitude: 30.0620,
      longitude: 31.3400,
      minPrice: 60,
      categorySlug: 'kids',
      verified: false,
    ),
  ];

  static List<HomeSalon> selectedFrom(List<HomeSalon> salons) {
    final featured = salons.where((salon) => salon.isFeatured).take(3).toList();
    if (featured.length >= 3 || featured.length == salons.length) {
      return featured;
    }
    final chosen = featured.map((salon) => salon.id).toSet();
    final fillers = salons.where((salon) => !chosen.contains(salon.id)).toList()
      ..sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
    return [...featured, ...fillers.take(3 - featured.length)];
  }
}

class SalonsApi {
  static Future<List<HomeSalon>> Function() load = _fetch;

  static Future<List<HomeSalon>> _fetch() async {
    final response = await http
        .get(Uri.parse('${SlidesApi.baseUrl}/api/salons'))
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return HomeSalon.fallback;

    final body = jsonDecode(response.body);
    final rows = body is Map<String, dynamic> ? body['data'] : null;
    if (rows is! List || rows.isEmpty) return HomeSalon.fallback;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => HomeSalon(
            id: row['id'] is int ? row['id'] as int : 0,
            name: '${row['name'] ?? ''}',
            city: '${row['city'] ?? ''}',
            district: '${row['district'] ?? ''}',
            ratingAvg: row['rating_avg'] is num
                ? (row['rating_avg'] as num).toDouble()
                : 0,
            isFeatured: row['is_featured'] == true,
            offersHomeService: row['offers_home_service'] == true,
            latitude: row['latitude'] is num
                ? (row['latitude'] as num).toDouble()
                : null,
            longitude: row['longitude'] is num
                ? (row['longitude'] as num).toDouble()
                : null,
            minPrice: row['min_price'] is num
                ? (row['min_price'] as num).toDouble()
                : null,
            imageUrl: row['image_url'] as String?,
            categorySlug: '${row['category_slug'] ?? ''}',
            verified: row['verified'] == true,
            reviewsCount: row['reviews_count'] is int
                ? row['reviews_count'] as int
                : 0,
            services: row['services'] is List
                ? (row['services'] as List).map((name) => '$name').toList()
                : const [],
          ),
        )
        .toList();
  }
}
