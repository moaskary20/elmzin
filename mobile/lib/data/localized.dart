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
  'قصر النيل': 'Qasr El Nil',
  'ميدان التحرير': 'Tahrir Square',
  'غير محدد': 'Unspecified',
  'مصر': 'Egypt',
  'شارع عباس العقاد': 'Abbas Al-Akkad St.',
  'أعلى كافيه النخبة': 'above Al-Nokhba Cafe',
  'كافيه النخبة': 'Al-Nokhba Cafe',
  'شارع شهاب': 'Shehab St.',
  'برج الأندلس': 'Al-Andalus Tower',
  'الأندلس': 'Al-Andalus',
  'الدور الثالث': '3rd floor',
  'التسعين الشمالي': 'North 90 St.',
  'مول الحديقة': 'Al-Hadiqa Mall',
  'شارع 9': 'Street 9',
  'شارع البرازيل': 'Brazil St.',
  'شارع التحرير': 'Tahrir St.',
  'شارع محمد محمود': 'Mohamed Mahmoud St.',
  '1 شارع محمد محمود': '1 Mohamed Mahmoud St.',
};

String placePartFor(String value, bool english) {
  final trimmed = value.trim();
  if (!english || trimmed.isEmpty) return trimmed;
  return placeNamesEn[trimmed] ?? translatePlaceText(trimmed);
}

String translatePlaceText(String value) {
  var out = value;
  final keys = placeNamesEn.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keys) {
    out = out.replaceAll(key, placeNamesEn[key]!);
  }
  return out;
}

String placeLineFor({
  required bool english,
  String? address,
  String? addressEn,
  String city = '',
  String? cityEn,
  String district = '',
  String? districtEn,
}) {
  if (english) {
    final englishAddress = addressEn?.trim();
    if (englishAddress != null && englishAddress.isNotEmpty) {
      return englishAddress;
    }
    final line = address?.trim();
    if (line != null && line.isNotEmpty) {
      return translatePlaceText(line);
    }
    final area = placePartFor(
      (districtEn ?? '').trim().isNotEmpty ? districtEn! : district,
      true,
    );
    final town = placePartFor(
      (cityEn ?? '').trim().isNotEmpty ? cityEn! : city,
      true,
    );
    if (area.isEmpty) return town;
    if (town.isEmpty) return area;
    return '$area, $town';
  }

  final line = address?.trim();
  if (line != null && line.isNotEmpty) return line;
  if (district.isEmpty) return city;
  if (city.isEmpty) return district;
  return '$district، $city';
}
