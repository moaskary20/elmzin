import 'dart:convert';

import 'package:http/http.dart' as http;

import 'account_store.dart';
import 'home_slide.dart';

class SalonBooking {
  const SalonBooking({
    required this.id,
    required this.status,
    required this.date,
    required this.time,
    required this.customerName,
    required this.customerPhone,
    required this.serviceName,
    required this.total,
    this.subtotal = 0,
    this.discount = 0,
    this.pointsRedeemed = 0,
    this.pointsDiscount = 0,
    this.couponCode,
    this.canConfirm = false,
    this.canCancel = false,
    this.notes,
    this.createdAt,
    this.customerEmail,
    this.customerCity,
    this.customerAddress,
    this.customerAvatar,
    this.registered = false,
    this.visits = 0,
    this.durationMinutes = 0,
    this.specialistName = '',
    this.specialistTitle = '',
  });

  final int id;
  final String status;
  final String date;
  final String time;
  final String customerName;
  final String customerPhone;
  final String serviceName;
  final double total;
  final double subtotal;
  final double discount;
  final int pointsRedeemed;
  final double pointsDiscount;
  final String? couponCode;
  final bool canConfirm;
  final bool canCancel;
  final String? notes;
  final DateTime? createdAt;
  final String? customerEmail;
  final String? customerCity;
  final String? customerAddress;
  final String? customerAvatar;
  final bool registered;
  final int visits;
  final int durationMinutes;
  final String specialistName;
  final String specialistTitle;

  DateTime? get at {
    final day = DateTime.tryParse(date);
    if (day == null) return null;
    final parts = time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  bool get active => status == 'pending' || status == 'confirmed';

  bool get upcoming {
    final moment = at;
    return active && moment != null && moment.isAfter(DateTime.now());
  }

  factory SalonBooking.fromJson(Map<String, dynamic> row) {
    Map<String, dynamic> part(String key) => row[key] is Map
        ? Map<String, dynamic>.from(row[key] as Map)
        : const <String, dynamic>{};
    double amount(Object? value) => value is num ? value.toDouble() : 0;
    int whole(Object? value) => value is num ? value.toInt() : 0;
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value : null;

    final customer = part('customer');
    final service = part('service');
    final specialist = part('specialist');

    return SalonBooking(
      id: whole(row['id']),
      status: '${row['status'] ?? ''}',
      date: '${row['booked_on'] ?? ''}',
      time: '${row['booked_time'] ?? ''}',
      total: amount(row['total']),
      subtotal: amount(row['subtotal']),
      discount: amount(row['discount_amount']),
      pointsRedeemed: whole(row['points_redeemed']),
      pointsDiscount: amount(row['points_discount']),
      couponCode: text(row['coupon_code']),
      canConfirm: row['can_confirm'] == true,
      canCancel: row['can_cancel'] == true,
      notes: text(row['notes']),
      createdAt: DateTime.tryParse('${row['created_at'] ?? ''}')?.toLocal(),
      customerName: '${customer['name'] ?? ''}',
      customerPhone: '${customer['phone'] ?? ''}',
      customerEmail: text(customer['email']),
      customerCity: text(customer['city']),
      customerAddress: text(customer['address']),
      customerAvatar: text(customer['avatar_url']),
      registered: customer['registered'] == true,
      visits: whole(customer['visits']),
      serviceName: '${service['name'] ?? ''}',
      durationMinutes: whole(service['duration_minutes']),
      specialistName: '${specialist['name'] ?? ''}',
      specialistTitle: '${specialist['title'] ?? ''}',
    );
  }
}

class SalonBookingsException implements Exception {
  SalonBookingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SalonBookingsApi {
  static Future<List<SalonBooking>> Function() load = _load;
  static Future<SalonBooking> Function(int id) confirm = _confirm;
  static Future<SalonBooking> Function(int id, String reason) cancel = _cancel;

  static void useDefaults() {
    load = _load;
    confirm = _confirm;
    cancel = _cancel;
  }

  static Future<List<SalonBooking>> _load() async {
    final body = await _send('GET', '/api/salon/bookings');
    final rows = body['data'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => SalonBooking.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<SalonBooking> _confirm(int id) async {
    final body = await _send('POST', '/api/salon/bookings/$id/confirm');
    return SalonBooking.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  static Future<SalonBooking> _cancel(int id, String reason) async {
    final body = await _send('POST', '/api/salon/bookings/$id/cancel', {
      if (reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return SalonBooking.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final request = http.Request(
      method,
      Uri.parse('${SlidesApi.baseUrl}$path'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] =
        'Bearer ${AccountStore.instance.token ?? ''}';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final sent = await request.send().timeout(const Duration(seconds: 10));
    final raw = await sent.stream.bytesToString();
    final decoded = raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    if (sent.statusCode < 200 || sent.statusCode >= 300) {
      throw SalonBookingsException(_message(decoded));
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
