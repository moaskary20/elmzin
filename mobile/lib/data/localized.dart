/// Prefer English text when requested and available; otherwise Arabic/primary.
String localized(String primary, String? english, bool isEnglish) {
  if (!isEnglish) return primary;
  final value = english?.trim();
  if (value == null || value.isEmpty) return primary;
  return value;
}

const placeNamesEn = <String, String>{
  'مدينة نصر': 'Nasr City',
  'المهندسين': 'Mohandessin',
  'التجمع الخامس': 'New Cairo',
  'المعادي': 'Maadi',
  'الزمالك': 'Zamalek',
  'الدقي': 'Dokki',
  'القاهرة': 'Cairo',
  'الجيزة': 'Giza',
  'غير محدد': 'Unspecified',
};

String placePartFor(String value, bool english) {
  final trimmed = value.trim();
  if (!english || trimmed.isEmpty) return trimmed;
  return placeNamesEn[trimmed] ?? trimmed;
}

String placeLineFor({
  required bool english,
  String? address,
  String city = '',
  String district = '',
}) {
  final line = address?.trim();
  if (line != null && line.isNotEmpty) {
    if (!english) return line;
    var out = line;
    for (final entry in placeNamesEn.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }
  final area = placePartFor(district, english);
  final town = placePartFor(city, english);
  if (area.isEmpty) return town;
  if (town.isEmpty) return area;
  return english ? '$area, $town' : '$area، $town';
}
