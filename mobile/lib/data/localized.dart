/// Prefer English text when requested and available; otherwise Arabic/primary.
String localized(String primary, String? english, bool isEnglish) {
  if (!isEnglish) return primary;
  final value = english?.trim();
  if (value == null || value.isEmpty) return primary;
  return value;
}
