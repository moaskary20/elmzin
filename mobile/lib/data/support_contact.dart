import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:muzayen/data/account_store.dart';
import 'package:muzayen/data/home_slide.dart';

class SupportChoice {
  const SupportChoice({
    required this.id,
    required this.label,
    this.labelEn,
    this.isOther = false,
  });

  factory SupportChoice.fromJson(Map<String, dynamic> json) => SupportChoice(
        id: (json['id'] as num).toInt(),
        label: '${json['label'] ?? ''}',
        labelEn: _text(json['label_en']),
        isOther: json['is_other'] == true,
      );

  final int id;
  final String label;
  final String? labelEn;
  final bool isOther;

  String labelFor(bool english) {
    if (english && labelEn != null && labelEn!.trim().isNotEmpty) {
      return labelEn!;
    }
    return label;
  }

  @override
  bool operator ==(Object other) =>
      other is SupportChoice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class SupportForm {
  const SupportForm({
    required this.topicLabel,
    required this.relatedLabel,
    required this.successMessage,
    required this.topics,
    required this.related,
    this.topicLabelEn,
    this.relatedLabelEn,
    this.successMessageEn,
  });

  factory SupportForm.fromJson(Map<String, dynamic> json) {
    List<SupportChoice> list(Object? value) => value is List
        ? value
            .whereType<Map<String, dynamic>>()
            .map(SupportChoice.fromJson)
            .toList()
        : const [];

    return SupportForm(
      topicLabel: '${json['topic_label'] ?? 'موضوع الرسالة'}',
      topicLabelEn: _text(json['topic_label_en']),
      relatedLabel: '${json['related_label'] ?? 'يتعلق بـ'}',
      relatedLabelEn: _text(json['related_label_en']),
      successMessage:
          '${json['success_message'] ?? 'سيتم التواصل معك خلال 48 ساعة.'}',
      successMessageEn: _text(json['success_message_en']),
      topics: list(json['topics']),
      related: list(json['related']),
    );
  }

  final String topicLabel;
  final String? topicLabelEn;
  final String relatedLabel;
  final String? relatedLabelEn;
  final String successMessage;
  final String? successMessageEn;
  final List<SupportChoice> topics;
  final List<SupportChoice> related;

  String topicLabelFor(bool english) =>
      english && (topicLabelEn ?? '').trim().isNotEmpty
          ? topicLabelEn!
          : topicLabel;

  String relatedLabelFor(bool english) =>
      english && (relatedLabelEn ?? '').trim().isNotEmpty
          ? relatedLabelEn!
          : relatedLabel;

  String successFor(bool english) =>
      english && (successMessageEn ?? '').trim().isNotEmpty
          ? successMessageEn!
          : successMessage;
}

class SupportContactApi {
  static Future<SupportForm> Function() loadForm = _loadForm;
  static Future<String> Function({
    required int topicOptionId,
    String? topicCustom,
    required int relatedOptionId,
    String? relatedCustom,
    String? message,
  }) send = _send;

  static void useDefault() {
    loadForm = _loadForm;
    send = _send;
  }

  static Future<SupportForm> _loadForm() async {
    final response = await http
        .get(
          Uri.parse('${SlidesApi.baseUrl}/api/support/form'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('support form ${response.statusCode}');
    }
    return SupportForm.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<String> _send({
    required int topicOptionId,
    String? topicCustom,
    required int relatedOptionId,
    String? relatedCustom,
    String? message,
  }) async {
    final token = AccountStore.instance.token;
    if (token == null || token.isEmpty) {
      throw Exception('login required');
    }
    final response = await http
        .post(
          Uri.parse('${SlidesApi.baseUrl}/api/support/tickets'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'topic_option_id': topicOptionId,
            'topic_custom': topicCustom,
            'related_option_id': relatedOptionId,
            'related_custom': relatedCustom,
            'message': message,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return Future.error('${first.first}');
      }
      throw Exception(body['message'] ?? 'send failed');
    }
    final english = AccountStore.instance.isEnglish;
    final ar = '${body['message'] ?? ''}';
    final en = '${body['message_en'] ?? ''}';
    if (english && en.trim().isNotEmpty) return en;
    return ar.isNotEmpty
        ? ar
        : 'تم استلام رسالتك. سيتواصل معك فريق الدعم خلال 48 ساعة.';
  }
}

String? _text(Object? value) {
  final out = value?.toString().trim();
  return out == null || out.isEmpty ? null : out;
}
