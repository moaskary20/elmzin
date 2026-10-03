import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifications_store.dart';
import 'salon_detail.dart';

class CartItem {
  const CartItem({
    required this.key,
    required this.salonId,
    required this.salonName,
    required this.categorySlug,
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.durationMinutes,
    required this.date,
    required this.time,
    this.salonImageUrl,
    this.specialistId,
    this.specialistName = '',
  });

  final String key;
  final int salonId;
  final String salonName;
  final String categorySlug;
  final String? salonImageUrl;
  final int serviceId;
  final String serviceName;
  final double price;
  final int durationMinutes;
  final int? specialistId;
  final String specialistName;
  final String date;
  final String time;

  DateTime? get at {
    final day = DateTime.tryParse(date);
    if (day == null) return null;
    final parts = time.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.tryParse(parts.first) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'salon_id': salonId,
    'salon_name': salonName,
    'category_slug': categorySlug,
    'salon_image_url': salonImageUrl,
    'service_id': serviceId,
    'service_name': serviceName,
    'price': price,
    'duration_minutes': durationMinutes,
    'specialist_id': specialistId,
    'specialist_name': specialistName,
    'date': date,
    'time': time,
  };

  static CartItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final row = Map<String, dynamic>.from(raw);
    final salonId = row['salon_id'];
    final serviceId = row['service_id'];
    if (salonId is! int || serviceId is! int) return null;
    return CartItem(
      key: '${row['key'] ?? ''}',
      salonId: salonId,
      salonName: '${row['salon_name'] ?? ''}',
      categorySlug: '${row['category_slug'] ?? ''}',
      salonImageUrl: row['salon_image_url'] as String?,
      serviceId: serviceId,
      serviceName: '${row['service_name'] ?? ''}',
      price: (row['price'] as num?)?.toDouble() ?? 0,
      durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 0,
      specialistId: row['specialist_id'] as int?,
      specialistName: '${row['specialist_name'] ?? ''}',
      date: '${row['date'] ?? ''}',
      time: '${row['time'] ?? ''}',
    );
  }
}

class CheckoutResult {
  const CheckoutResult({required this.booked, required this.failed});

  final List<CartItem> booked;
  final Map<String, String> failed;
}

class CartStore extends ChangeNotifier {
  CartStore._();

  static final instance = CartStore._();
  static const _prefsKey = 'muzayen_cart';

  final List<CartItem> _items = [];
  var _loaded = false;

  List<CartItem> get items => List.unmodifiable(_items);

  int get count => _items.length;

  bool get isEmpty => _items.isEmpty;

  double get total => _items.fold(0, (sum, item) => sum + item.price);

  int get minutes => _items.fold(0, (sum, item) => sum + item.durationMinutes);

  /// Items grouped by salon, in the order the salons were first added.
  Map<int, List<CartItem>> get bySalon {
    final groups = <int, List<CartItem>>{};
    for (final item in _items) {
      groups.putIfAbsent(item.salonId, () => []).add(item);
    }
    return groups;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final rows = jsonDecode(raw);
      if (rows is! List) return;
      final now = DateTime.now();
      _items
        ..clear()
        ..addAll(
          rows
              .map(CartItem.fromJson)
              .whereType<CartItem>()
              .where((item) => item.at?.isAfter(now) ?? false),
        );
      notifyListeners();
    } catch (_) {}
  }

  /// Adds a booking to the cart. The same salon slot replaces the older entry.
  CartItem add({
    required SalonDetail salon,
    required SalonServiceItem service,
    SalonSpecialistItem? specialist,
    required String date,
    required String time,
  }) {
    final item = CartItem(
      key: '${salon.id}-${service.id}-$date-$time-${specialist?.id ?? 0}',
      salonId: salon.id,
      salonName: salon.name,
      categorySlug: salon.categorySlug,
      salonImageUrl: salon.imageUrl,
      serviceId: service.id,
      serviceName: service.name,
      price: service.price,
      durationMinutes: service.durationMinutes,
      specialistId: specialist?.id,
      specialistName: specialist?.name ?? '',
      date: date,
      time: time,
    );
    _items.removeWhere(
      (row) =>
          row.key == item.key ||
          (row.salonId == item.salonId &&
              row.date == item.date &&
              row.time == item.time &&
              row.specialistId == item.specialistId),
    );
    _items.add(item);
    _changed();
    return item;
  }

  void remove(String key) {
    _items.removeWhere((item) => item.key == key);
    _changed();
  }

  void clear() {
    _items.clear();
    _changed();
  }

  /// Books every item; successful ones leave the cart, failed ones stay.
  Future<CheckoutResult> checkout({
    required String name,
    required String phone,
    String paymentMethod = 'cash',
    String? cardLast4,
  }) async {
    final booked = <CartItem>[];
    final failed = <String, String>{};
    for (final item in [..._items]) {
      String? error;
      try {
        error = await SalonDetailApi.book(
          BookingRequest(
            salonId: item.salonId,
            serviceId: item.serviceId,
            specialistId: item.specialistId,
            date: item.date,
            time: item.time,
            customerName: name,
            customerPhone: phone,
            paymentMethod: paymentMethod,
            cardLast4: cardLast4,
          ),
        );
      } catch (_) {
        error = 'تعذر الاتصال بالخادم.';
      }
      if (error == null) {
        booked.add(item);
      } else {
        failed[item.key] = error;
      }
    }
    _items.removeWhere((item) => booked.any((row) => row.key == item.key));
    _changed();
    if (booked.isNotEmpty) NotificationsStore.instance.refresh(quiet: true);
    return CheckoutResult(booked: booked, failed: failed);
  }

  @visibleForTesting
  void reset() {
    _items.clear();
    _loaded = true;
    notifyListeners();
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode([for (final item in _items) item.toJson()]),
      );
    } catch (_) {}
  }
}
