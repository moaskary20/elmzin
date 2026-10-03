import 'package:flutter/material.dart';

import 'app_colors.dart';

class SettingsTone {
  const SettingsTone({
    required this.dark,
    required this.background,
    required this.panel,
    required this.text,
    required this.muted,
    required this.accent,
    required this.ink,
    required this.line,
  });

  final bool dark;
  final Color background;
  final Color panel;
  final Color text;
  final Color muted;
  final Color accent;
  final Color ink;
  final Color line;

  static const night = SettingsTone(
    dark: true,
    background: Color(0xFF050505),
    panel: Color(0xFF101010),
    text: Color(0xFFD9B25B),
    muted: Color(0xB8D9B25B),
    accent: Color(0xFFD9B25B),
    ink: AppColors.ink,
    line: Color(0x38D9B25B),
  );

  static const day = SettingsTone(
    dark: false,
    background: Color(0xFFF6F3EC),
    panel: Color(0xFFFFFFFF),
    text: Color(0xFF14120C),
    muted: Color(0xFF7A6A4A),
    accent: Color(0xFFD9B25B),
    ink: AppColors.ink,
    line: Color(0x33B8923E),
  );

  static SettingsTone of(bool darkMode) => darkMode ? night : day;
}
