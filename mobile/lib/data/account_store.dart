import 'package:flutter/foundation.dart';
import 'package:muzayen/data/account_api.dart';
import 'package:muzayen/data/auth_api.dart';
import 'package:muzayen/data/localized.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountStore extends ChangeNotifier {
  AccountStore._();

  static final instance = AccountStore._();

  static const _nameKey = 'muzayen_account_name';
  static const _nameEnKey = 'muzayen_account_name_en';
  static const _emailKey = 'muzayen_account_email';
  static const _phoneKey = 'muzayen_account_phone';
  static const _addressKey = 'muzayen_account_address';
  static const _roleKey = 'muzayen_account_role';
  static const _tokenKey = 'muzayen_account_token';
  static const _photoKey = 'muzayen_account_photo';
  static const _photoUrlKey = 'muzayen_account_photo_url';
  static const _localeKey = 'muzayen_account_locale';
  static const _localeChosenKey = 'muzayen_locale_chosen';
  static const _loggedInKey = 'muzayen_account_logged_in';
  static const _notificationsKey = 'muzayen_notifications';
  static const _darkModeKey = 'muzayen_dark_mode';

  String name = '';
  String? nameEn;
  String email = '';
  String phone = '';
  String address = '';
  String role = '';
  String? token;
  String? photoPath;
  String? photoUrl;
  String locale = 'ar';
  bool localeChosen = false;
  bool loggedIn = false;
  bool notifications = true;
  bool darkMode = true;
  double walletBalance = 0;
  int loyaltyPoints = 0;

  bool get isEnglish => locale == 'en';

  static String normalizeLocale(String? code) => code == 'en' ? 'en' : 'ar';

  String displayName(bool english) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return english ? 'Guest' : 'زائر';
    return localized(trimmed, nameEn, english);
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      name = prefs.getString(_nameKey) ?? '';
      nameEn = prefs.getString(_nameEnKey);
      if (nameEn != null && nameEn!.trim().isEmpty) nameEn = null;
      email = prefs.getString(_emailKey) ?? '';
      phone = prefs.getString(_phoneKey) ?? '';
      address = prefs.getString(_addressKey) ?? '';
      role = prefs.getString(_roleKey) ?? '';
      token = prefs.getString(_tokenKey);
      photoPath = prefs.getString(_photoKey);
      photoUrl = prefs.getString(_photoUrlKey);
      final diskLocale = normalizeLocale(prefs.getString(_localeKey));
      final diskChosen = prefs.getBool(_localeChosenKey) ?? false;
      // Keep a locale the user just picked if SharedPreferences is still stale
      // (common on Android when AppShell reloads right after LanguageScreen).
      if (localeChosen && (!diskChosen || diskLocale != locale)) {
        await prefs.setString(_localeKey, locale);
        await prefs.setBool(_localeChosenKey, true);
      } else {
        locale = diskLocale;
        localeChosen = diskChosen;
      }
      loggedIn = prefs.getBool(_loggedInKey) ?? false;
      notifications = prefs.getBool(_notificationsKey) ?? true;
      darkMode = prefs.getBool(_darkModeKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> saveProfile({
    required String name,
    required String phone,
    String? nameEn,
    String? photoPath,
  }) async {
    this.name = name.trim();
    final englishName = nameEn?.trim();
    this.nameEn =
        englishName == null || englishName.isEmpty ? null : englishName;
    this.phone = phone.trim();
    this.photoPath = photoPath;
    notifyListeners();
    await _save();
    _pushProfile();
  }

  void setLoyaltyPoints(int value) {
    if (loyaltyPoints == value) return;
    loyaltyPoints = value;
    notifyListeners();
  }

  void setWalletBalance(double value) {
    if (walletBalance == value) return;
    walletBalance = value;
    notifyListeners();
  }

  Future<void> setPhoto(String path) async {
    photoPath = path;
    notifyListeners();
    await _save();
    final current = token;
    if (!loggedIn || current == null || current.isEmpty) return;
    try {
      await AccountApi.uploadAvatar(token: current, path: path);
      await refresh();
    } catch (_) {}
  }

  void applySession(AuthSession session) {
    name = session.name;
    nameEn = session.nameEn;
    email = session.email;
    phone = session.phone;
    address = session.address;
    role = session.role;
    if (session.token.isNotEmpty) token = session.token;
    notifications = session.notifications;
    darkMode = session.darkMode;
    if (localeChosen) {
      locale = normalizeLocale(locale);
    } else {
      locale = normalizeLocale(session.locale);
    }
    photoUrl = session.avatarUrl;
    walletBalance = session.walletBalance;
    loyaltyPoints = session.loyaltyPoints;
    loggedIn = true;
    notifyListeners();
    _save();
  }

  Future<void> refresh() async {
    final current = token;
    if (!loggedIn || current == null || current.isEmpty) return;
    try {
      final session = await AccountApi.show(current);
      name = session.name;
      nameEn = session.nameEn;
      email = session.email;
      phone = session.phone;
      address = session.address;
      role = session.role;
      notifications = session.notifications;
      darkMode = session.darkMode;
      if (!localeChosen) {
        locale = normalizeLocale(session.locale);
      }
      photoUrl = session.avatarUrl;
      walletBalance = session.walletBalance;
      loyaltyPoints = session.loyaltyPoints;
      notifyListeners();
      await _save();
    } catch (_) {}
  }

  Future<void> logout() async {
    name = '';
    nameEn = null;
    email = '';
    phone = '';
    address = '';
    role = '';
    token = null;
    photoPath = null;
    photoUrl = null;
    walletBalance = 0;
    loyaltyPoints = 0;
    loggedIn = false;
    notifyListeners();
    await _save();
  }

  Future<void> setNotifications(bool value) async {
    notifications = value;
    notifyListeners();
    await _save();
    _pushSettings();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    notifyListeners();
    await _save();
    _pushSettings();
  }

  Future<void> setLocale(String code) async {
    final next = normalizeLocale(code);
    locale = next;
    localeChosen = true;
    notifyListeners();
    await _save();
    _pushSettings();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nameKey, name);
      if (nameEn == null || nameEn!.isEmpty) {
        await prefs.remove(_nameEnKey);
      } else {
        await prefs.setString(_nameEnKey, nameEn!);
      }
      await prefs.setString(_emailKey, email);
      await prefs.setString(_phoneKey, phone);
      await prefs.setString(_addressKey, address);
      await prefs.setString(_roleKey, role);
      if (token == null || token!.isEmpty) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, token!);
      }
      if (photoPath == null || photoPath!.isEmpty) {
        await prefs.remove(_photoKey);
      } else {
        await prefs.setString(_photoKey, photoPath!);
      }
      if (photoUrl == null || photoUrl!.isEmpty) {
        await prefs.remove(_photoUrlKey);
      } else {
        await prefs.setString(_photoUrlKey, photoUrl!);
      }
      await prefs.setString(_localeKey, locale);
      await prefs.setBool(_localeChosenKey, localeChosen);
      await prefs.setBool(_loggedInKey, loggedIn);
      await prefs.setBool(_notificationsKey, notifications);
      await prefs.setBool(_darkModeKey, darkMode);
    } catch (_) {}
  }

  @visibleForTesting
  void reset() {
    name = '';
    nameEn = null;
    email = '';
    phone = '';
    address = '';
    role = '';
    token = null;
    photoPath = null;
    photoUrl = null;
    walletBalance = 0;
    loyaltyPoints = 0;
    locale = 'ar';
    localeChosen = false;
    loggedIn = false;
    notifications = true;
    darkMode = true;
    notifyListeners();
  }

  void _pushSettings() {
    final current = token;
    if (!loggedIn || current == null || current.isEmpty) return;
    _send(
      () => AccountApi.update(
        token: current,
        notifications: notifications,
        darkMode: darkMode,
        locale: locale,
      ),
    );
  }

  void _pushProfile() {
    final current = token;
    if (!loggedIn || current == null || current.isEmpty) return;
    _send(
      () => AccountApi.update(
        token: current,
        name: name,
        nameEn: nameEn,
        phone: phone,
      ),
    );
    final path = photoPath;
    if (path == null || path.isEmpty) return;
    _send(() => AccountApi.uploadAvatar(token: current, path: path));
  }

  void _send(Future<void> Function() call) {
    () async {
      try {
        await call();
      } catch (_) {}
    }();
  }
}
