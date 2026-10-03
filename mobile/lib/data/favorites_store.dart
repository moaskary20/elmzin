import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();

  static final instance = FavoritesStore._();
  static const _key = 'muzayen_favorite_salons';

  final Set<int> _ids = {};

  Set<int> get ids => Set.unmodifiable(_ids);

  bool contains(int id) => _ids.contains(id);

  int get count => _ids.length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_key) ?? const [];
      _ids
        ..clear()
        ..addAll(stored.map(int.tryParse).whereType<int>());
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle(int id) async {
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _ids.map((id) => '$id').toList());
    } catch (_) {}
  }

  @visibleForTesting
  void reset() {
    _ids.clear();
    notifyListeners();
  }
}
