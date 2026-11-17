import 'dart:convert';

import 'package:http/http.dart' as http;

import 'home_slide.dart';
import 'localized.dart';

class AppPopup {
  const AppPopup({
    required this.id,
    required this.title,
    required this.body,
    required this.buttonLabel,
    this.titleEn,
    this.bodyEn,
    this.buttonLabelEn,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String? titleEn;
  final String body;
  final String? bodyEn;
  final String buttonLabel;
  final String? buttonLabelEn;
  final String? updatedAt;

  String titleFor(bool english) => localized(title, titleEn, english);

  String bodyFor(bool english) => localized(body, bodyEn, english);

  String buttonFor(bool english) =>
      localized(buttonLabel, buttonLabelEn, english);

  factory AppPopup.fromJson(Map<String, dynamic> row) {
    int whole(Object? value) => value is num ? value.toInt() : 0;
    return AppPopup(
      id: whole(row['id']),
      title: '${row['title'] ?? ''}',
      titleEn: localizedText(row['title_en']),
      body: '${row['body'] ?? ''}',
      bodyEn: localizedText(row['body_en']),
      buttonLabel: '${row['button_label'] ?? 'حسناً'}',
      buttonLabelEn: localizedText(row['button_label_en']),
      updatedAt: localizedText(row['updated_at']),
    );
  }
}

class AppPopupApi {
  static Future<AppPopup?> Function() load = _fetch;

  static Future<AppPopup?> _fetch() async {
    try {
      final response = await http
          .get(Uri.parse('${SlidesApi.baseUrl}/api/popup'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map) return null;
      final data = body['data'];
      if (data is! Map) return null;
      final popup = AppPopup.fromJson(Map<String, dynamic>.from(data));
      if (popup.title.trim().isEmpty || popup.body.trim().isEmpty) {
        return null;
      }
      return popup;
    } catch (_) {
      return null;
    }
  }
}
