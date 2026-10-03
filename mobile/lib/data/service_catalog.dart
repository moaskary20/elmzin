import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'home_slide.dart';

class ServiceOffer {
  const ServiceOffer({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.salonId,
    required this.salonName,
    required this.categorySlug,
    this.description = '',
    this.bookings = 0,
    this.city = '',
    this.district = '',
    this.rating = 0,
    this.homeService = false,
    this.verified = false,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;
  final int bookings;
  final int salonId;
  final String salonName;
  final String categorySlug;
  final String city;
  final String district;
  final double rating;
  final bool homeService;
  final bool verified;
  final String? imageUrl;

  String get place => district.isEmpty ? city : '$district، $city';

  factory ServiceOffer.fromJson(Map<String, dynamic> row) {
    final salon = row['salon'] is Map
        ? Map<String, dynamic>.from(row['salon'] as Map)
        : const <String, dynamic>{};
    return ServiceOffer(
      id: row['id'] is int ? row['id'] as int : 0,
      name: '${row['name'] ?? ''}',
      description: '${row['description'] ?? ''}',
      price: row['price'] is num ? (row['price'] as num).toDouble() : 0,
      durationMinutes: row['duration_minutes'] is int
          ? row['duration_minutes'] as int
          : 30,
      bookings: row['bookings_count'] is int ? row['bookings_count'] as int : 0,
      salonId: salon['id'] is int ? salon['id'] as int : 0,
      salonName: '${salon['name'] ?? ''}',
      categorySlug: '${salon['category_slug'] ?? ''}',
      city: '${salon['city'] ?? ''}',
      district: '${salon['district'] ?? ''}',
      rating: salon['rating_avg'] is num
          ? (salon['rating_avg'] as num).toDouble()
          : 0,
      homeService: salon['offers_home_service'] == true,
      verified: salon['verified'] == true,
      imageUrl: salon['image_url'] as String?,
    );
  }

  static const fallback = [
    ServiceOffer(
      id: 1,
      name: 'قص شعر',
      price: 120,
      durationMinutes: 30,
      salonId: 1,
      salonName: 'صالون الليث',
      categorySlug: 'men',
      city: 'القاهرة',
      district: 'مدينة نصر',
      rating: 4.9,
      verified: true,
    ),
    ServiceOffer(
      id: 2,
      name: 'تهذيب لحية',
      price: 80,
      durationMinutes: 20,
      salonId: 1,
      salonName: 'صالون الليث',
      categorySlug: 'men',
      city: 'القاهرة',
      district: 'مدينة نصر',
      rating: 4.9,
      verified: true,
    ),
    ServiceOffer(
      id: 3,
      name: 'قص شعر',
      price: 100,
      durationMinutes: 30,
      salonId: 4,
      salonName: 'بيت الحلاقة',
      categorySlug: 'men',
      city: 'القاهرة',
      district: 'المعادي',
      rating: 4.7,
      homeService: true,
      verified: true,
    ),
    ServiceOffer(
      id: 4,
      name: 'صبغة شعر',
      price: 450,
      durationMinutes: 90,
      salonId: 2,
      salonName: 'لمسة جمال',
      categorySlug: 'women',
      city: 'الجيزة',
      district: 'المهندسين',
      rating: 4.6,
      homeService: true,
      verified: true,
    ),
    ServiceOffer(
      id: 5,
      name: 'عناية بشرة',
      price: 380,
      durationMinutes: 50,
      salonId: 5,
      salonName: 'دار الجمال',
      categorySlug: 'women',
      city: 'القاهرة',
      district: 'الزمالك',
      rating: 4.9,
      verified: true,
    ),
    ServiceOffer(
      id: 6,
      name: 'قصة أطفال',
      price: 90,
      durationMinutes: 25,
      salonId: 3,
      salonName: 'براعم',
      categorySlug: 'kids',
      city: 'القاهرة',
      district: 'التجمع الخامس',
      rating: 4.2,
    ),
  ];
}

/// One service name with every salon that offers it.
class ServiceGroup {
  const ServiceGroup({required this.name, required this.offers});

  final String name;
  final List<ServiceOffer> offers;

  double get minPrice => offers.map((offer) => offer.price).reduce(math.min);

  double get maxPrice => offers.map((offer) => offer.price).reduce(math.max);

  int get shortest =>
      offers.map((offer) => offer.durationMinutes).reduce(math.min);

  int get bookings => offers.fold(0, (sum, offer) => sum + offer.bookings);

  int get salons => offers.map((offer) => offer.salonId).toSet().length;

  Set<String> get categories =>
      offers.map((offer) => offer.categorySlug).toSet();

  static List<ServiceGroup> from(List<ServiceOffer> offers) {
    final byName = <String, List<ServiceOffer>>{};
    for (final offer in offers) {
      byName.putIfAbsent(offer.name.trim(), () => []).add(offer);
    }
    return [
      for (final entry in byName.entries)
        ServiceGroup(
          name: entry.key,
          offers: [...entry.value]..sort((a, b) => a.price.compareTo(b.price)),
        ),
    ];
  }
}

class ServicesApi {
  static Future<List<ServiceOffer>> Function() load = _fetch;

  static Future<List<ServiceOffer>> _fetch() async {
    final response = await http
        .get(Uri.parse('${SlidesApi.baseUrl}/api/services'))
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return ServiceOffer.fallback;
    final body = jsonDecode(response.body);
    final rows = body is Map<String, dynamic> ? body['data'] : null;
    if (rows is! List || rows.isEmpty) return ServiceOffer.fallback;
    return rows
        .whereType<Map>()
        .map((row) => ServiceOffer.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}
