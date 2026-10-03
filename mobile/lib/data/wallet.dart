import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:muzayen/data/auth_api.dart';
import 'package:muzayen/data/home_slide.dart';

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.type,
    required this.label,
    required this.amount,
    required this.balanceAfter,
    this.note,
    this.bookingId,
    this.createdAt,
  });

  final int id;
  final String type;
  final String label;
  final double amount;
  final double balanceAfter;
  final String? note;
  final int? bookingId;
  final DateTime? createdAt;

  bool get credit => amount > 0;

  factory WalletEntry.fromJson(Map<String, dynamic> json) {
    return WalletEntry(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      bookingId: (json['booking_id'] as num?)?.toInt(),
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

class WalletSummary {
  const WalletSummary({
    required this.balance,
    required this.points,
    required this.totalIn,
    required this.totalOut,
    required this.entries,
  });

  final double balance;
  final int points;
  final double totalIn;
  final double totalOut;
  final List<WalletEntry> entries;

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    final entries = json['transactions'] as List<dynamic>? ?? const [];
    return WalletSummary(
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      points: (json['loyalty_points'] as num?)?.toInt() ?? 0,
      totalIn: (json['total_in'] as num?)?.toDouble() ?? 0,
      totalOut: (json['total_out'] as num?)?.toDouble() ?? 0,
      entries: entries
          .whereType<Map<String, dynamic>>()
          .map(WalletEntry.fromJson)
          .toList(),
    );
  }
}

class WalletApi {
  static Future<WalletSummary> Function(String token) load = _load;

  static void useDefault() => load = _load;

  static Future<WalletSummary> _load(String token) async {
    final response = await http
        .get(
          Uri.parse('${SlidesApi.baseUrl}/api/account/wallet'),
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
    return WalletSummary.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }
}
