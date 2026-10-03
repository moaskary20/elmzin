import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:muzayen/config/google_maps.dart';
import 'package:muzayen/data/home_slide.dart';

class AuthSession {
  const AuthSession({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    required this.token,
    this.notifications = true,
    this.darkMode = true,
    this.locale = 'ar',
    this.avatarUrl,
    this.walletBalance = 0,
    this.loyaltyPoints = 0,
  });

  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final String token;
  final bool notifications;
  final bool darkMode;
  final String locale;
  final String? avatarUrl;
  final double walletBalance;
  final int loyaltyPoints;

  factory AuthSession.fromJson(Map<String, dynamic> data, {String token = ''}) {
    return AuthSession(
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      role: (data['role'] as String?) ?? '',
      token: token,
      notifications: data['notifications'] as bool? ?? true,
      darkMode: data['dark_mode'] as bool? ?? true,
      locale: (data['locale'] as String?) ?? 'ar',
      avatarUrl: data['avatar_url'] as String?,
      walletBalance: (data['wallet_balance'] as num?)?.toDouble() ?? 0,
      loyaltyPoints: (data['loyalty_points'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;
}

class AuthApi {
  static Future<AuthSession> Function({
    required String email,
    required String password,
  })
  signIn = _signIn;

  static Future<AuthSession> Function({
    required String accountType,
    required String name,
    required String email,
    required String phone,
    required String password,
    required String address,
    required String? city,
    required double latitude,
    required double longitude,
    required bool notifications,
    required bool darkMode,
    required String locale,
    required int? categoryId,
    required Map<int, double> servicePrices,
    int? planId,
    bool acceptTerms,
    List<Map<String, Object?>>? specialists,
    List<Map<String, Object?>>? hours,
  })
  register = _register;

  static Future<void> Function({required String email}) requestReset =
      _requestReset;

  static Future<AuthSession> Function({
    required String email,
    required String code,
    required String password,
  })
  resetPassword = _resetPassword;

  static void useDefaults() {
    signIn = _signIn;
    register = _register;
    requestReset = _requestReset;
    resetPassword = _resetPassword;
  }

  static Future<void> _requestReset({required String email}) async {
    await _post('/api/auth/forgot-password', {'email': email});
  }

  static Future<AuthSession> _resetPassword({
    required String email,
    required String code,
    required String password,
  }) {
    return _post('/api/auth/reset-password', {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': password,
    });
  }

  static Future<AuthSession> _signIn({
    required String email,
    required String password,
  }) {
    return _post('/api/auth/login', {'email': email, 'password': password});
  }

  static Future<AuthSession> _register({
    required String accountType,
    required String name,
    required String email,
    required String phone,
    required String password,
    required String address,
    required String? city,
    required double latitude,
    required double longitude,
    required bool notifications,
    required bool darkMode,
    required String locale,
    required int? categoryId,
    required Map<int, double> servicePrices,
    int? planId,
    bool acceptTerms = false,
    List<Map<String, Object?>>? specialists,
    List<Map<String, Object?>>? hours,
  }) {
    return _post('/api/auth/register', {
      if (specialists != null && specialists.isNotEmpty)
        'specialists': specialists,
      if (hours != null && hours.isNotEmpty) 'hours': hours,
      'category_id': ?categoryId,
      if (servicePrices.isNotEmpty)
        'services': [
          for (final entry in servicePrices.entries)
            {'id': entry.key, 'price': entry.value},
        ],
      'plan_id': ?planId,
      if (planId != null) 'accept_terms': acceptTerms,
      'account_type': accountType,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'address': address,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'notifications': notifications,
      'dark_mode': darkMode,
      'locale': locale,
    });
  }

  static Future<AuthSession> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('${SlidesApi.baseUrl}$path'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_message(decoded));
    }

    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return AuthSession.fromJson(
      data,
      token: (decoded['token'] as String?) ?? '',
    );
  }

  static String messageOf(Map<String, dynamic> body) => _message(body);

  static String _message(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) return '${value.first}';
        if (value is String && value.isNotEmpty) return value;
      }
    }
    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'تعذر إتمام الطلب.';
  }
}

class MapAddress {
  const MapAddress({
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final String? city;
  final double latitude;
  final double longitude;
}

class MapGeocoder {
  static Future<MapAddress> Function(double latitude, double longitude)
  resolve = _resolve;

  static void useDefault() => resolve = _resolve;

  static Future<MapAddress> _resolve(double latitude, double longitude) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '$latitude,$longitude',
      'language': 'ar',
      'key': googleMapsApiKey,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? const [];
    if (results.isEmpty) {
      throw AuthException('تعذر قراءة العنوان من الخريطة.');
    }
    final first = results.first as Map<String, dynamic>;
    return MapAddress(
      address: (first['formatted_address'] as String?) ?? '',
      city: _city(first),
      latitude: latitude,
      longitude: longitude,
    );
  }

  static String? _city(Map<String, dynamic> result) {
    final parts = result['address_components'] as List<dynamic>? ?? const [];
    for (final part in parts) {
      if (part is! Map) continue;
      final types = part['types'];
      if (types is List && types.contains('locality')) {
        return part['long_name'] as String?;
      }
    }
    return null;
  }
}
