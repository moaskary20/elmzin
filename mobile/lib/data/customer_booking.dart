import 'dart:convert';

import 'package:http/http.dart' as http;

import 'account_store.dart';
import 'home_slide.dart';

class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.status,
    required this.date,
    required this.time,
    required this.total,
    required this.subtotal,
    required this.discount,
    required this.points,
    required this.canCancel,
    required this.canReview,
    required this.reviewed,
    required this.salonId,
    required this.salonName,
    required this.categorySlug,
    required this.city,
    required this.district,
    required this.serviceName,
    required this.durationMinutes,
    required this.specialistName,
    this.specialistTitle = '',
    this.imageUrl,
    this.notes,
  });

  final int id;
  final String status;
  final String date;
  final String time;
  final double total;
  final double subtotal;
  final double discount;
  final int points;
  final bool canCancel;
  final bool canReview;
  final bool reviewed;
  final int salonId;
  final String salonName;
  final String categorySlug;
  final String city;
  final String district;
  final String? imageUrl;
  final String serviceName;
  final int durationMinutes;
  final String specialistName;
  final String specialistTitle;
  final String? notes;

  DateTime? get at {
    final day = DateTime.tryParse(date);
    if (day == null) return null;
    final parts = time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  bool get upcoming {
    final moment = at;
    if (moment == null) return false;
    return (status == 'pending' || status == 'confirmed') &&
        moment.isAfter(DateTime.now());
  }

  String get place {
    if (district.isEmpty) return city;
    if (city.isEmpty) return district;
    return '$district، $city';
  }

  factory CustomerBooking.fromJson(Map<String, dynamic> row) {
    final salon = row['salon'] is Map
        ? Map<String, dynamic>.from(row['salon'] as Map)
        : const <String, dynamic>{};
    final service = row['service'] is Map
        ? Map<String, dynamic>.from(row['service'] as Map)
        : const <String, dynamic>{};
    final specialist = row['specialist'] is Map
        ? Map<String, dynamic>.from(row['specialist'] as Map)
        : const <String, dynamic>{};

    double amount(Object? value) => value is num ? value.toDouble() : 0;

    return CustomerBooking(
      id: row['id'] is int ? row['id'] as int : 0,
      status: '${row['status'] ?? ''}',
      date: '${row['booked_on'] ?? ''}',
      time: '${row['booked_time'] ?? ''}',
      total: amount(row['total']),
      subtotal: amount(row['subtotal']),
      discount: amount(row['discount_amount']),
      points: row['points_awarded'] is int ? row['points_awarded'] as int : 0,
      canCancel: row['can_cancel'] == true,
      canReview: row['can_review'] == true,
      reviewed: row['reviewed'] == true,
      salonId: salon['id'] is int ? salon['id'] as int : 0,
      salonName: '${salon['name'] ?? ''}',
      categorySlug: '${salon['category_slug'] ?? ''}',
      city: '${salon['city'] ?? ''}',
      district: '${salon['district'] ?? ''}',
      imageUrl: salon['image_url'] as String?,
      serviceName: '${service['name'] ?? ''}',
      durationMinutes: service['duration_minutes'] is int
          ? service['duration_minutes'] as int
          : 0,
      specialistName: '${specialist['name'] ?? ''}',
      specialistTitle: '${specialist['title'] ?? ''}',
      notes: row['notes'] as String?,
    );
  }
}

class BookingsException implements Exception {
  BookingsException(this.message);

  final String message;
}

class BookingsApi {
  static Future<List<CustomerBooking>> Function() load = _load;
  static Future<void> Function(int id) cancel = _cancel;
  static Future<void> Function({
    required int id,
    required int rating,
    required String comment,
  })
  review = _review;

  static Future<List<CustomerBooking>> _load() async {
    final body = await _send('GET', '/api/account/bookings');
    final rows = body['data'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => CustomerBooking.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<void> _cancel(int id) {
    return _send('POST', '/api/account/bookings/$id/cancel');
  }

  static Future<void> _review({
    required int id,
    required int rating,
    required String comment,
  }) {
    return _send('POST', '/api/account/bookings/$id/review', {
      'rating': rating,
      'comment': comment,
    });
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final token = AccountStore.instance.token ?? '';
    final request = http.Request(
      method,
      Uri.parse('${SlidesApi.baseUrl}$path'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final sent = await request.send().timeout(const Duration(seconds: 8));
    final raw = await sent.stream.bytesToString();
    final decoded = raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    if (sent.statusCode < 200 || sent.statusCode >= 300) {
      throw BookingsException(_message(decoded));
    }
    return decoded;
  }

  static String _message(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return '${first.first}';
    }
    if (body['message'] is String) return body['message'] as String;
    return 'تعذر تنفيذ الطلب.';
  }
}
