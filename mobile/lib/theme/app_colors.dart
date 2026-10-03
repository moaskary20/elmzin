import 'package:flutter/material.dart';

import '../data/account_store.dart';

/// Brand colors. They follow the dark mode switch in settings, so read them
/// at build time and never inside `const` expressions.
abstract final class AppColors {
  static bool get dark => AccountStore.instance.darkMode;

  static Color get black =>
      dark ? const Color(0xFF050505) : const Color(0xFFF6F3EC);
  static Color get panel =>
      dark ? const Color(0xFF101010) : const Color(0xFFFFFFFF);
  static Color get gold =>
      dark ? const Color(0xFFD9B25B) : const Color(0xFF9E7A2C);
  static Color get goldDeep =>
      dark ? const Color(0xFFB8923E) : const Color(0xFF7E5F1E);
  static const ink = Color(0xFF14120C);
  static Color get warm =>
      dark ? const Color(0xFF1C1810) : const Color(0xFFF1E7D0);
  static Color get glass =>
      dark ? const Color(0xB3000000) : const Color(0xE6FFFFFF);
  static Color get goldSoft =>
      dark ? const Color(0xB8D9B25B) : const Color(0xFF7A6A4A);
  static Color get line =>
      dark ? const Color(0x38D9B25B) : const Color(0x409E7A2C);
}

class SalonPalette {
  const SalonPalette._brand()
    : background = const Color(0),
      panel = const Color(0),
      accent = const Color(0),
      deep = const Color(0),
      ink = const Color(0),
      soft = const Color(0),
      line = const Color(0),
      banner = const Color(0),
      bannerEnd = const Color(0),
      onBar = const Color(0),
      circle = const Color(0),
      onCircle = const Color(0);

  const SalonPalette({
    required this.background,
    required this.panel,
    required this.accent,
    required this.deep,
    required this.ink,
    required this.soft,
    required this.line,
    required this.banner,
    required this.bannerEnd,
    required this.onBar,
    required this.circle,
    required this.onCircle,
  });

  final Color background;
  final Color panel;
  final Color accent;
  final Color deep;
  final Color ink;
  final Color soft;
  final Color line;
  final Color banner;
  final Color bannerEnd;
  final Color onBar;
  final Color circle;
  final Color onCircle;

  /// Black and gold in dark mode, cream and gold in light mode.
  static const SalonPalette gold = _BrandPalette();

  static const blush = SalonPalette(
    background: Color(0xFFFFF4F8),
    panel: Color(0xFFFFFFFF),
    accent: Color(0xFFE56B94),
    deep: Color(0xFFC44774),
    ink: Color(0xFF3D1424),
    soft: Color(0xFFA85A76),
    line: Color(0x66E56B94),
    banner: Color(0xFFF8C3D6),
    bannerEnd: Color(0xFFE56B94),
    onBar: Color(0xFFFFFFFF),
    circle: Color(0xFFFFFFFF),
    onCircle: Color(0xFFE56B94),
  );
}

class SalonTheme extends InheritedWidget {
  const SalonTheme({required this.palette, required super.child});

  final SalonPalette palette;

  static SalonPalette of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<SalonTheme>();
    return theme?.palette ?? SalonPalette.gold;
  }

  @override
  bool updateShouldNotify(SalonTheme oldWidget) => oldWidget.palette != palette;
}

class _BrandPalette extends SalonPalette {
  const _BrandPalette() : super._brand();

  @override
  Color get background => AppColors.black;
  @override
  Color get panel => AppColors.panel;
  @override
  Color get accent => AppColors.gold;
  @override
  Color get deep => AppColors.goldDeep;
  @override
  Color get ink => AppColors.ink;
  @override
  Color get soft => AppColors.goldSoft;
  @override
  Color get line => AppColors.line;
  @override
  Color get banner =>
      AppColors.dark ? const Color(0xFF14120C) : const Color(0xFFF1E7D0);
  @override
  Color get bannerEnd => AppColors.black;
  @override
  Color get onBar => AppColors.ink;
  @override
  Color get circle => AppColors.gold;
  @override
  Color get onCircle => AppColors.ink;
}
