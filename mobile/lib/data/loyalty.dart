import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:muzayen/data/auth_api.dart';
import 'package:muzayen/data/home_slide.dart';

class LoyaltyEntry {
  const LoyaltyEntry({
    required this.id,
    required this.type,
    required this.label,
    required this.points,
    this.note,
    this.salon,
    this.expiresAt,
    this.createdAt,
  });

  factory LoyaltyEntry.fromJson(Map<String, dynamic> json) => LoyaltyEntry(
    id: (json['id'] as num).toInt(),
    type: '${json['type'] ?? ''}',
    label: '${json['label'] ?? ''}',
    points: (json['points'] as num?)?.toInt() ?? 0,
    note: json['note'] as String?,
    salon: json['salon'] as String?,
    expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}'),
    createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
  );

  final int id;
  final String type;
  final String label;
  final int points;
  final String? note;
  final String? salon;
  final DateTime? expiresAt;
  final DateTime? createdAt;
}

class LoyaltyRules {
  const LoyaltyRules({
    required this.earnAmount,
    required this.earnPoints,
    required this.redeemPoints,
    required this.redeemValue,
    required this.minRedeemPoints,
    this.expireDays,
  });

  factory LoyaltyRules.fromJson(Map<String, dynamic> json) => LoyaltyRules(
    earnAmount: (json['earn_amount'] as num?)?.toDouble() ?? 0,
    earnPoints: (json['earn_points'] as num?)?.toInt() ?? 0,
    redeemPoints: (json['redeem_points'] as num?)?.toInt() ?? 0,
    redeemValue: (json['redeem_value'] as num?)?.toDouble() ?? 0,
    minRedeemPoints: (json['min_redeem_points'] as num?)?.toInt() ?? 0,
    expireDays: (json['expire_days'] as num?)?.toInt(),
  );

  final double earnAmount;
  final int earnPoints;
  final int redeemPoints;
  final double redeemValue;
  final int minRedeemPoints;
  final int? expireDays;
}

class LoyaltySummary {
  const LoyaltySummary({
    required this.points,
    required this.active,
    required this.redeemablePoints,
    required this.redeemableValue,
    required this.nextTarget,
    required this.nextRemaining,
    required this.nextValue,
    required this.rules,
    required this.earned,
    required this.redeemed,
    required this.expired,
    required this.expiringPoints,
    required this.entries,
    this.expiringDate,
  });

  factory LoyaltySummary.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(Object? value) =>
        value is Map<String, dynamic> ? value : const {};
    int whole(Object? value) => (value as num?)?.toInt() ?? 0;
    final next = map(json['next_reward']);
    final totals = map(json['totals']);
    final expiring = map(json['expiring']);
    return LoyaltySummary(
      points: whole(json['points']),
      active: json['is_active'] != false,
      redeemablePoints: whole(json['redeemable_points']),
      redeemableValue: (json['redeemable_value'] as num?)?.toDouble() ?? 0,
      nextTarget: whole(next['target']),
      nextRemaining: whole(next['remaining']),
      nextValue: (next['value'] as num?)?.toDouble() ?? 0,
      rules: LoyaltyRules.fromJson(map(json['rules'])),
      earned: whole(totals['earned']),
      redeemed: whole(totals['redeemed']),
      expired: whole(totals['expired']),
      expiringPoints: whole(expiring['points']),
      expiringDate: DateTime.tryParse('${expiring['date'] ?? ''}'),
      entries: (json['transactions'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LoyaltyEntry.fromJson)
          .toList(),
    );
  }

  final int points;
  final bool active;
  final int redeemablePoints;
  final double redeemableValue;
  final int nextTarget;
  final int nextRemaining;
  final double nextValue;
  final LoyaltyRules rules;
  final int earned;
  final int redeemed;
  final int expired;
  final int expiringPoints;
  final DateTime? expiringDate;
  final List<LoyaltyEntry> entries;

  double get progress {
    if (nextTarget <= 0) return 0;
    return (points / nextTarget).clamp(0, 1).toDouble();
  }
}

class LoyaltyApi {
  static Future<LoyaltySummary> Function(String token) load = _load;

  static void useDefault() => load = _load;

  static Future<LoyaltySummary> _load(String token) async {
    final response = await http
        .get(
          Uri.parse('${SlidesApi.baseUrl}/api/account/loyalty'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 12));
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException(AuthApi.messageOf(body));
    }
    return LoyaltySummary.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }
}
