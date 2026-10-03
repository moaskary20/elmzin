import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:muzayen/data/auth_api.dart';
import 'package:muzayen/data/home_slide.dart';

class AccountApi {
  static Future<AuthSession> Function(String token) show = _show;

  static Future<void> Function({
    required String token,
    String? name,
    String? phone,
    bool? notifications,
    bool? darkMode,
    String? locale,
  })
  update = _update;

  static Future<void> Function({required String token, required String path})
  uploadAvatar = _uploadAvatar;

  static Future<void> Function({required String token, required String path})
  uploadSalonImage = _uploadSalonImage;

  static void useDefaults() {
    show = _show;
    update = _update;
    uploadAvatar = _uploadAvatar;
    uploadSalonImage = _uploadSalonImage;
  }

  static Future<void> _uploadSalonImage({
    required String token,
    required String path,
  }) async {
    if (!File(path).existsSync()) return;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${SlidesApi.baseUrl}/api/account/salon/image'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('image', path));
    final response = await request.send().timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('تعذر رفع صورة الصالون.');
    }
  }

  static Future<AuthSession> _show(String token) async {
    final decoded = await _send('GET', '/api/account', token);
    return AuthSession.fromJson(decoded['data'] as Map<String, dynamic>? ?? {});
  }

  static Future<void> _update({
    required String token,
    String? name,
    String? phone,
    bool? notifications,
    bool? darkMode,
    String? locale,
  }) async {
    final body = <String, Object?>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (notifications != null) body['notifications'] = notifications;
    if (darkMode != null) body['dark_mode'] = darkMode;
    if (locale != null) body['locale'] = locale;
    await _send('PATCH', '/api/account', token, body);
  }

  static Future<void> _uploadAvatar({
    required String token,
    required String path,
  }) async {
    if (!File(path).existsSync()) return;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${SlidesApi.baseUrl}/api/account/avatar'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('avatar', path));
    final response = await request.send().timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('تعذر رفع الصورة.');
    }
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path,
    String token, [
    Map<String, Object?>? body,
  ]) async {
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
    final sent = await request.send().timeout(const Duration(seconds: 12));
    final raw = await sent.stream.bytesToString();
    final decoded = raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    if (sent.statusCode < 200 || sent.statusCode >= 300) {
      throw AuthException(AuthApi.messageOf(decoded));
    }
    return decoded;
  }
}
