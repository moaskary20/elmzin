import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'account_store.dart';
import 'home_slide.dart';

class SalonHour {
  const SalonHour({
    required this.day,
    required this.isClosed,
    this.opensAt,
    this.closesAt,
  });

  final int day;
  final bool isClosed;
  final String? opensAt;
  final String? closesAt;
}

class SalonServiceItem {
  const SalonServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.specialistIds,
  });

  final int id;
  final String name;
  final double price;
  final int durationMinutes;
  final List<int> specialistIds;
}

class SalonSpecialistItem {
  const SalonSpecialistItem({
    required this.id,
    required this.name,
    required this.title,
  });

  final int id;
  final String name;
  final String title;
}

class SalonReviewItem {
  const SalonReviewItem({
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  final String customerName;
  final int rating;
  final String comment;
  final String date;
}

class BookedSlot {
  const BookedSlot({
    required this.specialistId,
    required this.date,
    required this.time,
  });

  final int specialistId;
  final String date;
  final String time;
}

class SalonDetail {
  const SalonDetail({
    required this.id,
    required this.name,
    required this.about,
    required this.city,
    required this.district,
    required this.category,
    required this.categorySlug,
    required this.ratingAvg,
    required this.reviewsCount,
    required this.verified,
    this.imageUrl,
    required this.hours,
    required this.services,
    required this.specialists,
    required this.reviews,
    required this.booked,
  });

  final int id;
  final String name;
  final String about;
  final String city;
  final String district;
  final String category;
  final String categorySlug;
  final double ratingAvg;
  final int reviewsCount;
  final bool verified;
  final String? imageUrl;
  final List<SalonHour> hours;
  final List<SalonServiceItem> services;
  final List<SalonSpecialistItem> specialists;
  final List<SalonReviewItem> reviews;
  final List<BookedSlot> booked;

  String get place => district.isEmpty ? city : '$district · $city';

  String eyebrow(String languageCode) {
    if (languageCode == 'en') {
      return switch (categorySlug) {
        'men' => "Men's grooming",
        'women' => "Women's beauty",
        'kids' => "Kids' salon",
        _ => category,
      };
    }
    return switch (categorySlug) {
      'men' => 'حلاقة رجالي',
      'women' => 'تجميل حريمي',
      'kids' => 'صالون أطفال',
      _ => category,
    };
  }

  SalonHour? hourFor(int day) {
    for (final hour in hours) {
      if (hour.day == day) return hour;
    }
    return null;
  }

  static const fallback = SalonDetail(
    id: 1,
    name: 'صالون الليث',
    about: 'حلاقة كلاسيكية وعناية باللحية في أجواء هادئة.',
    city: 'القاهرة',
    district: 'مدينة نصر',
    category: 'رجالي',
    categorySlug: 'men',
    ratingAvg: 5,
    reviewsCount: 1,
    verified: true,
    hours: [
      SalonHour(day: 6, opensAt: '10:00', closesAt: '23:00', isClosed: false),
      SalonHour(day: 0, opensAt: '10:00', closesAt: '23:00', isClosed: false),
      SalonHour(day: 1, opensAt: '10:00', closesAt: '23:00', isClosed: false),
      SalonHour(day: 2, opensAt: '10:00', closesAt: '23:00', isClosed: false),
      SalonHour(day: 3, opensAt: '10:00', closesAt: '23:00', isClosed: false),
      SalonHour(day: 4, opensAt: '10:00', closesAt: '23:00', isClosed: false),
      SalonHour(day: 5, isClosed: true),
    ],
    services: [
      SalonServiceItem(
        id: 1,
        name: 'قص شعر',
        price: 120,
        durationMinutes: 30,
        specialistIds: [1],
      ),
      SalonServiceItem(
        id: 2,
        name: 'تهذيب لحية',
        price: 80,
        durationMinutes: 20,
        specialistIds: [1, 2],
      ),
    ],
    specialists: [
      SalonSpecialistItem(id: 1, name: 'كريم محمود', title: 'حلاق'),
      SalonSpecialistItem(id: 2, name: 'يوسف عادل', title: 'أخصائي لحية'),
    ],
    reviews: [
      SalonReviewItem(
        customerName: 'أحمد سامي',
        rating: 5,
        comment: 'شغل نظيف وموعد دقيق.',
        date: '2026-09-30',
      ),
    ],
    booked: [],
  );
}

class SalonDetailApi {
  static Future<SalonDetail> Function(int id) load = _fetch;
  static Future<String?> Function(BookingRequest request) book = _book;

  @visibleForTesting
  static const useDefaultBook = _book;

  static Future<SalonDetail> _fetch(int id) async {
    final response = await http
        .get(Uri.parse('${SlidesApi.baseUrl}/api/salons/$id'))
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return SalonDetail.fallback;

    final body = jsonDecode(response.body);
    final row = body is Map<String, dynamic> ? body['data'] : null;
    if (row is! Map<String, dynamic>) return SalonDetail.fallback;
    return _detail(row);
  }

  static Future<String?> _book(BookingRequest request) async {
    final response = await http
        .post(
          Uri.parse(
            '${SlidesApi.baseUrl}/api/salons/${request.salonId}/bookings',
          ),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (AccountStore.instance.loggedIn &&
                (AccountStore.instance.token ?? '').isNotEmpty)
              'Authorization': 'Bearer ${AccountStore.instance.token}',
          },
          body: jsonEncode({
            'service_id': request.serviceId,
            'specialist_id': request.specialistId,
            'booked_on': request.date,
            'booked_time': request.time,
            'customer_name': request.customerName,
            'customer_phone': request.customerPhone,
            'payment_method': request.paymentMethod,
            if (request.cardLast4 != null) 'card_last4': request.cardLast4,
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode >= 200 && response.statusCode < 300) return null;

    try {
      final body = jsonDecode(response.body);
      final errors = body is Map ? body['errors'] : null;
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return '${first.first}';
      }
      if (body is Map && body['message'] is String)
        return body['message'] as String;
    } catch (_) {}

    return 'تعذر إتمام الحجز.';
  }

  static SalonDetail _detail(Map<String, dynamic> row) {
    List<Map<String, dynamic>> maps(Object? value) {
      if (value is! List) return const [];
      return value.whereType<Map<String, dynamic>>().toList();
    }

    return SalonDetail(
      id: row['id'] is int ? row['id'] as int : 0,
      name: '${row['name'] ?? ''}',
      about: '${row['about'] ?? ''}',
      city: '${row['city'] ?? ''}',
      district: '${row['district'] ?? ''}',
      category: '${row['category'] ?? ''}',
      categorySlug: '${row['category_slug'] ?? ''}',
      ratingAvg: row['rating_avg'] is num
          ? (row['rating_avg'] as num).toDouble()
          : 0,
      reviewsCount: row['reviews_count'] is int
          ? row['reviews_count'] as int
          : 0,
      verified: row['verified'] == true,
      imageUrl: row['image_url'] as String?,
      hours: maps(row['hours'])
          .map(
            (hour) => SalonHour(
              day: hour['day'] is int ? hour['day'] as int : 0,
              opensAt: hour['opens_at'] as String?,
              closesAt: hour['closes_at'] as String?,
              isClosed: hour['is_closed'] == true,
            ),
          )
          .toList(),
      services: maps(row['services'])
          .map(
            (service) => SalonServiceItem(
              id: service['id'] is int ? service['id'] as int : 0,
              name: '${service['name'] ?? ''}',
              price: service['price'] is num
                  ? (service['price'] as num).toDouble()
                  : 0,
              durationMinutes: service['duration_minutes'] is int
                  ? service['duration_minutes'] as int
                  : 30,
              specialistIds: service['specialist_ids'] is List
                  ? (service['specialist_ids'] as List)
                        .whereType<int>()
                        .toList()
                  : const [],
            ),
          )
          .toList(),
      specialists: maps(row['specialists'])
          .map(
            (specialist) => SalonSpecialistItem(
              id: specialist['id'] is int ? specialist['id'] as int : 0,
              name: '${specialist['name'] ?? ''}',
              title: '${specialist['title'] ?? ''}',
            ),
          )
          .toList(),
      reviews: maps(row['reviews'])
          .map(
            (review) => SalonReviewItem(
              customerName: '${review['customer_name'] ?? ''}',
              rating: review['rating'] is int ? review['rating'] as int : 0,
              comment: '${review['comment'] ?? ''}',
              date: '${review['created_at'] ?? ''}',
            ),
          )
          .toList(),
      booked: maps(row['booked'])
          .map(
            (slot) => BookedSlot(
              specialistId: slot['specialist_id'] is int
                  ? slot['specialist_id'] as int
                  : 0,
              date: '${slot['date'] ?? ''}',
              time: '${slot['time'] ?? ''}',
            ),
          )
          .toList(),
    );
  }
}

class BookingRequest {
  const BookingRequest({
    required this.salonId,
    required this.serviceId,
    required this.date,
    required this.time,
    required this.customerName,
    required this.customerPhone,
    this.specialistId,
    this.paymentMethod = 'cash',
    this.cardLast4,
  });

  final int salonId;
  final int serviceId;
  final int? specialistId;
  final String date;
  final String time;
  final String customerName;
  final String customerPhone;
  final String paymentMethod;
  final String? cardLast4;
}
