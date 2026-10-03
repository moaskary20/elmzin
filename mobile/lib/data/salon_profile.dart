import 'dart:convert';

import 'package:http/http.dart' as http;

import 'account_api.dart';
import 'account_store.dart';
import 'home_slide.dart';

class OwnService {
  const OwnService({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.isActive,
    this.description,
    this.specialistIds = const [],
  });

  final int id;
  final String name;
  final double price;
  final int durationMinutes;
  final bool isActive;
  final String? description;
  final List<int> specialistIds;

  factory OwnService.fromJson(Map<String, dynamic> row) => OwnService(
    id: (row['id'] as num).toInt(),
    name: row['name'] as String? ?? '',
    price: (row['price'] as num?)?.toDouble() ?? 0,
    durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 0,
    isActive: row['is_active'] as bool? ?? true,
    description: row['description'] as String?,
    specialistIds: [
      for (final id in row['specialist_ids'] as List? ?? const [])
        (id as num).toInt(),
    ],
  );
}

class OwnSpecialist {
  const OwnSpecialist({
    required this.id,
    required this.name,
    required this.isActive,
    this.title,
    this.phone,
  });

  final int id;
  final String name;
  final bool isActive;
  final String? title;
  final String? phone;

  factory OwnSpecialist.fromJson(Map<String, dynamic> row) => OwnSpecialist(
    id: (row['id'] as num).toInt(),
    name: row['name'] as String? ?? '',
    isActive: row['is_active'] as bool? ?? true,
    title: row['title'] as String?,
    phone: row['phone'] as String?,
  );
}

class OwnHour {
  const OwnHour({
    required this.day,
    required this.label,
    required this.isClosed,
    this.opensAt,
    this.closesAt,
  });

  final int day;
  final String label;
  final bool isClosed;
  final String? opensAt;
  final String? closesAt;

  OwnHour copyWith({bool? isClosed, String? opensAt, String? closesAt}) =>
      OwnHour(
        day: day,
        label: label,
        isClosed: isClosed ?? this.isClosed,
        opensAt: opensAt ?? this.opensAt,
        closesAt: closesAt ?? this.closesAt,
      );

  Map<String, Object?> toJson() => {
    'day': day,
    'is_closed': isClosed,
    'opens_at': isClosed ? null : opensAt,
    'closes_at': isClosed ? null : closesAt,
  };

  factory OwnHour.fromJson(Map<String, dynamic> row) => OwnHour(
    day: (row['day'] as num).toInt(),
    label: row['label'] as String? ?? '',
    isClosed: row['is_closed'] as bool? ?? true,
    opensAt: row['opens_at'] as String?,
    closesAt: row['closes_at'] as String?,
  );
}

class CatalogOption {
  const CatalogOption({
    required this.id,
    required this.name,
    this.durationMinutes,
  });

  final int id;
  final String name;
  final int? durationMinutes;

  factory CatalogOption.fromJson(Map<String, dynamic> row) => CatalogOption(
    id: (row['id'] as num).toInt(),
    name: row['name'] as String? ?? '',
    durationMinutes: (row['duration_minutes'] as num?)?.toInt(),
  );
}

class SalonProfile {
  const SalonProfile({
    required this.id,
    required this.name,
    this.phone,
    this.about,
    this.city,
    this.district,
    this.address,
    this.latitude,
    this.longitude,
    this.homeService = false,
    this.verificationStatus,
    this.verificationLabel,
    this.category,
    this.imageUrl,
    this.services = const [],
    this.specialists = const [],
    this.hours = const [],
    this.catalog = const [],
    this.subscription,
  });

  final int id;
  final String name;
  final String? phone;
  final String? about;
  final String? city;
  final String? district;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool homeService;
  final String? verificationStatus;
  final String? verificationLabel;
  final String? category;
  final String? imageUrl;
  final List<OwnService> services;
  final List<OwnSpecialist> specialists;
  final List<OwnHour> hours;
  final List<CatalogOption> catalog;
  final OwnSubscription? subscription;

  factory SalonProfile.fromJson(Map<String, dynamic> body) {
    final row = body['data'] as Map<String, dynamic>? ?? const {};
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) parse) => [
      for (final item in raw as List? ?? const [])
        if (item is Map<String, dynamic>) parse(item),
    ];
    return SalonProfile(
      id: (row['id'] as num?)?.toInt() ?? 0,
      name: row['name'] as String? ?? '',
      phone: row['phone'] as String?,
      about: row['about'] as String?,
      city: row['city'] as String?,
      district: row['district'] as String?,
      address: row['address'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      homeService: row['offers_home_service'] as bool? ?? false,
      verificationStatus: row['verification_status'] as String?,
      verificationLabel: row['verification_label'] as String?,
      category: row['category'] as String?,
      imageUrl: row['image_url'] as String?,
      services: list(row['services'], OwnService.fromJson),
      specialists: list(row['specialists'], OwnSpecialist.fromJson),
      hours: list(row['hours'], OwnHour.fromJson),
      catalog: list(body['catalog'], CatalogOption.fromJson),
      subscription: body['subscription'] is Map<String, dynamic>
          ? OwnSubscription.fromJson(
              body['subscription'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class OwnSubscription {
  const OwnSubscription({
    required this.planName,
    required this.isFree,
    required this.status,
    required this.statusLabel,
    required this.daysLeft,
    this.startsAt,
    this.endsAt,
  });

  factory OwnSubscription.fromJson(Map<String, dynamic> json) =>
      OwnSubscription(
        planName: '${json['plan_name'] ?? ''}',
        isFree: json['is_free'] == true,
        status: '${json['status'] ?? ''}',
        statusLabel: '${json['status_label'] ?? ''}',
        daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
        startsAt: json['starts_at'] as String?,
        endsAt: json['ends_at'] as String?,
      );

  final String planName;
  final bool isFree;
  final String status;
  final String statusLabel;
  final int daysLeft;
  final String? startsAt;
  final String? endsAt;
}

class SalonProfileException implements Exception {
  const SalonProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Every call returns the salon as saved on the server.
class SalonProfileApi {
  static Future<SalonProfile> Function(
    String method,
    String path, [
    Map<String, Object?>? body,
  ])
  send = _send;

  static Future<void> Function(String path) uploadImage = _uploadImage;

  static void useDefaults() {
    send = _send;
    uploadImage = _uploadImage;
  }

  static Future<SalonProfile> load() => send('GET', '/api/salon/profile');

  static Future<SalonProfile> update(Map<String, Object?> fields) =>
      send('PATCH', '/api/salon/profile', fields);

  static Future<SalonProfile> saveHours(List<OwnHour> hours) => send(
    'PUT',
    '/api/salon/hours',
    {'hours': hours.map((hour) => hour.toJson()).toList()},
  );

  static Future<SalonProfile> addService({
    required int catalogId,
    required double price,
    int? durationMinutes,
  }) => send('POST', '/api/salon/services', {
    'catalog_service_id': catalogId,
    'price': price,
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
  });

  static Future<SalonProfile> updateService(
    int id,
    Map<String, Object?> fields,
  ) => send('PATCH', '/api/salon/services/$id', fields);

  static Future<SalonProfile> deleteService(int id) =>
      send('DELETE', '/api/salon/services/$id');

  static Future<SalonProfile> addSpecialist(Map<String, Object?> fields) =>
      send('POST', '/api/salon/specialists', fields);

  static Future<SalonProfile> updateSpecialist(
    int id,
    Map<String, Object?> fields,
  ) => send('PATCH', '/api/salon/specialists/$id', fields);

  static Future<SalonProfile> deleteSpecialist(int id) =>
      send('DELETE', '/api/salon/specialists/$id');

  static Future<void> _uploadImage(String path) => AccountApi.uploadSalonImage(
    token: AccountStore.instance.token ?? '',
    path: path,
  );

  static Future<SalonProfile> _send(
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
    final http.StreamedResponse sent;
    try {
      sent = await request.send().timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const SalonProfileException('تعذر الاتصال بالخادم.');
    }
    final raw = await sent.stream.bytesToString();
    Map<String, dynamic> decoded;
    try {
      decoded = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      decoded = {};
    }
    if (sent.statusCode < 200 || sent.statusCode >= 300) {
      throw SalonProfileException(_message(decoded));
    }
    return SalonProfile.fromJson(decoded);
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
