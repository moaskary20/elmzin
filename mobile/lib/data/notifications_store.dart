import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'account_store.dart';
import 'home_slide.dart';

class AppNotice {
  const AppNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
    this.bookingId,
  });

  factory AppNotice.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final booking = data is Map ? data['booking_id'] : null;
    return AppNotice(
      id: (json['id'] as num).toInt(),
      type: '${json['type'] ?? ''}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      read: json['read'] == true,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
      bookingId: booking is num ? booking.toInt() : null,
    );
  }

  final int id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;
  final int? bookingId;

  AppNotice copyWith({bool? read}) => AppNotice(
    id: id,
    type: type,
    title: title,
    body: body,
    read: read ?? this.read,
    createdAt: createdAt,
    bookingId: bookingId,
  );
}

class NoticePage {
  const NoticePage({required this.items, required this.unread});

  final List<AppNotice> items;
  final int unread;
}

class NotificationsApi {
  static Future<NoticePage> Function(String token) fetch = _fetch;
  static Future<void> Function(String token, int id) markRead = _markRead;
  static Future<void> Function(String token) markAllRead = _markAllRead;

  static void useDefaults() {
    fetch = _fetch;
    markRead = _markRead;
    markAllRead = _markAllRead;
  }

  static Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  static Future<NoticePage> _fetch(String token) async {
    final response = await http
        .get(
          Uri.parse('${SlidesApi.baseUrl}/api/notifications'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('notifications ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotice.fromJson)
        .toList();
    return NoticePage(
      items: rows,
      unread: (body['unread'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<void> _markRead(String token, int id) async {
    await http
        .post(
          Uri.parse('${SlidesApi.baseUrl}/api/notifications/$id/read'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 12));
  }

  static Future<void> _markAllRead(String token) async {
    await http
        .post(
          Uri.parse('${SlidesApi.baseUrl}/api/notifications/read-all'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 12));
  }
}

class NotificationsStore extends ChangeNotifier {
  NotificationsStore._();

  static final instance = NotificationsStore._();

  static Duration? pollEvery = const Duration(seconds: 30);

  List<AppNotice> items = const [];
  int unread = 0;
  bool loading = false;
  bool loaded = false;
  bool failed = false;

  Timer? _timer;
  String? _token;
  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    AccountStore.instance.addListener(_onAccount);
    _onAccount();
  }

  void _onAccount() {
    final account = AccountStore.instance;
    final token = account.loggedIn ? account.token : null;
    if (token == _token) return;
    _token = token;
    _timer?.cancel();
    _timer = null;
    if (token == null || token.isEmpty) {
      _clear();
      return;
    }
    refresh();
    final every = pollEvery;
    if (every != null) {
      _timer = Timer.periodic(every, (_) => refresh(quiet: true));
    }
  }

  Future<void> refresh({bool quiet = false}) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    if (!quiet) {
      loading = true;
      notifyListeners();
    }
    try {
      final page = await NotificationsApi.fetch(token);
      if (token != _token) return;
      items = page.items;
      unread = page.unread;
      failed = false;
      loaded = true;
    } catch (_) {
      if (!quiet) failed = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(AppNotice notice) async {
    final token = _token;
    if (notice.read || token == null) return;
    items = [
      for (final item in items)
        item.id == notice.id ? item.copyWith(read: true) : item,
    ];
    unread = unread > 0 ? unread - 1 : 0;
    notifyListeners();
    try {
      await NotificationsApi.markRead(token, notice.id);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final token = _token;
    if (unread == 0 || token == null) return;
    items = [for (final item in items) item.copyWith(read: true)];
    unread = 0;
    notifyListeners();
    try {
      await NotificationsApi.markAllRead(token);
    } catch (_) {}
  }

  void _clear() {
    items = const [];
    unread = 0;
    loaded = false;
    failed = false;
    loading = false;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    if (_attached) AccountStore.instance.removeListener(_onAccount);
    _attached = false;
    _timer?.cancel();
    _timer = null;
    _token = null;
    items = const [];
    unread = 0;
    loaded = false;
    failed = false;
    loading = false;
  }
}
