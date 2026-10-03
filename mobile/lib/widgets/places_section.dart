import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/auth_api.dart';

import '../data/home_salon.dart';
import '../screens/map_picker_screen.dart';
import '../theme/app_colors.dart';
import 'favorite_button.dart';
import 'salon_photo.dart';

enum _FilterMenu { service, nearest, rating, price }

enum _PlaceType { any, home, salon }

enum _LocationMode { current, custom }

class PlacesSection extends StatefulWidget {
  const PlacesSection({
    super.key,
    required this.salons,
    required this.languageCode,
    this.onOpen,
    this.palette = SalonPalette.gold,
    this.showFeatured = true,
    this.keyPrefix = '',
  });

  final List<HomeSalon> salons;
  final String languageCode;
  final ValueChanged<HomeSalon>? onOpen;
  final SalonPalette palette;
  final bool showFeatured;
  final String keyPrefix;

  static Future<MapAddress?> Function(
    BuildContext context,
    double latitude,
    double longitude,
  )
  pickPlace = _openMap;

  @visibleForTesting
  static void useDefaultPicker() => pickPlace = _openMap;

  static Future<MapAddress?> _openMap(
    BuildContext context,
    double latitude,
    double longitude,
  ) {
    return Navigator.of(context).push<MapAddress>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: 'اختر موقعاً آخر',
          confirmLabel: 'عرض الأماكن القريبة من هنا',
          initial: LatLng(latitude, longitude),
        ),
      ),
    );
  }

  @override
  State<PlacesSection> createState() => _PlacesSectionState();
}

class _PlacesSectionState extends State<PlacesSection> {
  var _menu = _FilterMenu.service;
  var _menuOpen = false;
  var _place = _PlaceType.any;
  var _locationMode = _LocationMode.current;
  int? _minStars;
  double? _priceLow;
  double? _priceHigh;
  double? _deviceLat;
  double? _deviceLng;
  String? _locationNote;
  double? _customLat;
  double? _customLng;
  String? _customLabel;

  bool get _english => widget.languageCode == 'en';

  SalonPalette get _colors => widget.palette;

  Key _key(String name) => Key('${widget.keyPrefix}$name');

  @override
  Widget build(BuildContext context) {
    final selected = widget.showFeatured
        ? HomeSalon.selectedFrom(widget.salons)
        : const <HomeSalon>[];
    final selectedIds = selected.map((salon) => salon.id).toSet();
    final pool = widget.showFeatured
        ? widget.salons
              .where((salon) => !selectedIds.contains(salon.id))
              .toList()
        : widget.salons;
    final origin = _origin;
    final rest = _apply(pool, origin.$1, origin.$2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showFeatured) ...[
            _heading(_english ? 'Selected places' : 'أماكن مختارة'),
            const SizedBox(height: 14),
            SizedBox(
              height: 280,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: selected.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _SalonCard(
                  salon: selected[index],
                  english: _english,
                  originLat: origin.$1,
                  originLng: origin.$2,
                  palette: _colors,
                  width: 220,
                  onTap: widget.onOpen == null
                      ? null
                      : () => widget.onOpen!(selected[index]),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _heading(_english ? 'More places' : 'باقي الأماكن'),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: _menuButton(
                  key: _key('filter-service'),
                  label: _serviceLabel,
                  open: _menuOpen && _menu == _FilterMenu.service,
                  onTap: () => _toggle(_FilterMenu.service),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _menuButton(
                  key: _key('filter-nearest'),
                  label: _nearestLabel,
                  open: _menuOpen && _menu == _FilterMenu.nearest,
                  onTap: () => _toggle(_FilterMenu.nearest),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _menuButton(
                  key: _key('filter-rating'),
                  label: _ratingLabel,
                  open: _menuOpen && _menu == _FilterMenu.rating,
                  onTap: () => _toggle(_FilterMenu.rating),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _menuButton(
                  key: _key('filter-price'),
                  label: _priceLabel(pool),
                  open: _menuOpen && _menu == _FilterMenu.price,
                  onTap: () => _toggle(_FilterMenu.price),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _menuOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _panel(pool),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 14),
          if (rest.isEmpty)
            Text(
              _english
                  ? 'No places match this filter.'
                  : 'لا توجد أماكن مطابقة لهذا الفلتر.',
              style: TextStyle(color: _colors.soft, fontSize: 14),
            )
          else
            for (final salon in rest) ...[
              _SalonCard(
                salon: salon,
                english: _english,
                originLat: origin.$1,
                originLng: origin.$2,
                palette: _colors,
                onTap: widget.onOpen == null
                    ? null
                    : () => widget.onOpen!(salon),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  void _toggle(_FilterMenu menu) {
    setState(() {
      if (_menuOpen && _menu == menu) {
        _menuOpen = false;
      } else {
        _menu = menu;
        _menuOpen = true;
      }
    });
  }

  (double, double) get _origin {
    if (_locationMode == _LocationMode.custom &&
        _customLat != null &&
        _customLng != null) {
      return (_customLat!, _customLng!);
    }
    return (
      _deviceLat ?? HomeSalon.originLatitude,
      _deviceLng ?? HomeSalon.originLongitude,
    );
  }

  List<HomeSalon> _apply(List<HomeSalon> salons, double lat, double lng) {
    final bounds = _priceBounds(salons);
    final low = _priceLow ?? bounds.$1;
    final high = _priceHigh ?? bounds.$2;

    final filtered = salons.where((salon) {
      final placeOk = switch (_place) {
        _PlaceType.home => salon.offersHomeService,
        _PlaceType.salon => !salon.offersHomeService,
        _PlaceType.any => true,
      };
      if (!placeOk) return false;
      if (_minStars != null && salon.ratingAvg < _minStars!) return false;
      final price = salon.minPrice;
      if (price != null && (price < low - 0.5 || price > high + 0.5)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort(
      (a, b) => a.distanceFrom(lat, lng).compareTo(b.distanceFrom(lat, lng)),
    );
    return filtered;
  }

  (double, double) _priceBounds(List<HomeSalon> salons) {
    final prices = salons.map((salon) => salon.minPrice).whereType<double>();
    if (prices.isEmpty) return (0.0, 1.0);
    return (prices.reduce(math.min), prices.reduce(math.max));
  }

  String get _serviceLabel {
    return switch (_place) {
      _PlaceType.home => _english ? 'Home' : 'منزلي',
      _PlaceType.salon => _english ? 'In salon' : 'داخل الصالون',
      _PlaceType.any => _english ? 'Service type' : 'نوع الخدمة',
    };
  }

  String get _nearestLabel {
    if (_locationMode == _LocationMode.custom) {
      return _customLabel ?? (_english ? 'Another place' : 'موقع آخر');
    }
    if (_deviceLat != null) return _english ? 'My location' : 'حسب الموقع';
    return _english ? 'Nearest' : 'الأقرب';
  }

  String get _ratingLabel {
    final stars = _minStars;
    if (stars == null) return _english ? 'Rating' : 'التقييم';
    return _english ? '$stars stars' : '$stars نجوم';
  }

  String _priceLabel(List<HomeSalon> salons) {
    final bounds = _priceBounds(salons);
    final low = _priceLow ?? bounds.$1;
    final high = _priceHigh ?? bounds.$2;
    final untouched =
        (low - bounds.$1).abs() < 0.5 && (high - bounds.$2).abs() < 0.5;
    if (untouched) return _english ? 'Price' : 'السعر';
    return '${low.round()}–${high.round()}';
  }

  Widget _panel(List<HomeSalon> salons) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.line),
      ),
      child: switch (_menu) {
        _FilterMenu.service => _serviceMenu(),
        _FilterMenu.nearest => _nearestMenu(),
        _FilterMenu.rating => _ratingMenu(),
        _FilterMenu.price => _priceMenu(salons),
      },
    );
  }

  Widget _serviceMenu() {
    return Column(
      children: [
        _option(
          key: _key('filter-home'),
          label: _english ? 'Home' : 'منزلي',
          selected: _place == _PlaceType.home,
          onTap: () => setState(() {
            _place = _place == _PlaceType.home
                ? _PlaceType.any
                : _PlaceType.home;
            _menuOpen = false;
          }),
        ),
        _option(
          key: _key('filter-salon'),
          label: _english ? 'In salon' : 'داخل الصالون',
          selected: _place == _PlaceType.salon,
          onTap: () => setState(() {
            _place = _place == _PlaceType.salon
                ? _PlaceType.any
                : _PlaceType.salon;
            _menuOpen = false;
          }),
        ),
      ],
    );
  }

  Future<void> _pickOnMap() async {
    final origin = _origin;
    final picked = await PlacesSection.pickPlace(context, origin.$1, origin.$2);
    if (!mounted || picked == null) return;
    setState(() {
      _locationMode = _LocationMode.custom;
      _customLat = picked.latitude;
      _customLng = picked.longitude;
      _customLabel = _shortPlace(picked);
      _locationNote = null;
      _menuOpen = false;
    });
  }

  String _shortPlace(MapAddress place) {
    final first = place.address.split(RegExp('[،,]')).first.trim();
    if (first.isNotEmpty && first.length <= 24) return first;
    final city = place.city?.trim() ?? '';
    if (city.isNotEmpty) return city;
    return _english ? 'Picked place' : 'الموقع المحدد';
  }

  Widget _nearestMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _option(
          key: _key('filter-by-location'),
          label: _english ? 'By my location' : 'حسب الموقع',
          selected:
              _locationMode == _LocationMode.current && _deviceLat != null,
          onTap: () {
            setState(() {
              _locationMode = _LocationMode.current;
              _menuOpen = false;
            });
            _useDeviceLocation();
          },
        ),
        _option(
          key: _key('filter-other-place'),
          label: _locationMode == _LocationMode.custom && _customLabel != null
              ? (_english
                    ? 'Another place: $_customLabel'
                    : 'موقع آخر: $_customLabel')
              : (_english ? 'Pick another place on the map' : 'إدخال موقع آخر'),
          selected: _locationMode == _LocationMode.custom,
          onTap: _pickOnMap,
        ),
        if (_locationNote != null) ...[
          const SizedBox(height: 8),
          Text(
            _locationNote!,
            style: TextStyle(color: _colors.soft, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _ratingMenu() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              GestureDetector(
                key: _key('filter-star-$star'),
                onTap: () => setState(() {
                  _minStars = _minStars == star ? null : star;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Icon(
                    star <= (_minStars ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: _colors.accent,
                    size: 30,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _minStars == null
              ? (_english ? 'Any rating' : 'كل التقييمات')
              : (_english
                    ? '$_minStars stars or more'
                    : '$_minStars نجوم فأكثر'),
          style: TextStyle(color: _colors.soft, fontSize: 12),
        ),
      ],
    );
  }

  Widget _priceMenu(List<HomeSalon> salons) {
    final bounds = _priceBounds(salons);
    final minPrice = bounds.$1;
    final maxPrice = bounds.$2;
    final same = (maxPrice - minPrice).abs() < 1;
    final low = (_priceLow ?? minPrice).clamp(minPrice, maxPrice);
    final high = (_priceHigh ?? maxPrice).clamp(low, maxPrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _english ? 'From ${low.round()} EGP' : 'من ${low.round()} ج.م',
              style: TextStyle(
                color: _colors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _english ? 'To ${high.round()} EGP' : 'إلى ${high.round()} ج.م',
              style: TextStyle(
                color: _colors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _colors.accent,
            inactiveTrackColor: _colors.line,
            thumbColor: _colors.accent,
            overlayColor: _colors.accent.withValues(alpha: 0.18),
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 8,
            ),
            trackHeight: 3,
          ),
          child: RangeSlider(
            values: RangeValues(low.toDouble(), high.toDouble()),
            min: minPrice,
            max: same ? minPrice + 1 : maxPrice,
            onChanged: same
                ? null
                : (values) => setState(() {
                    _priceLow = values.start;
                    _priceHigh = values.end;
                  }),
          ),
        ),
      ],
    );
  }

  Widget _option({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? _colors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _colors.accent : _colors.line,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? _colors.ink : _colors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuButton({
    required Key key,
    required String label,
    required bool open,
    required VoidCallback onTap,
  }) {
    return Material(
      color: open ? _colors.accent : _colors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: open ? _colors.accent : _colors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: open ? _colors.ink : _colors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: open ? _colors.ink : _colors.accent,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _colors.accent,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(width: 42, height: 1, color: _colors.accent),
      ],
    );
  }

  Future<void> _useDeviceLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        setState(() {
          _locationNote = _english
              ? 'Location is turned off.'
              : 'خدمة الموقع متوقفة.';
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationNote = _english
              ? 'Location permission was denied.'
              : 'لم يُسمح بالوصول إلى الموقع.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _deviceLat = position.latitude;
        _deviceLng = position.longitude;
        _locationNote = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationNote = _english
            ? 'Could not read your location.'
            : 'تعذر تحديد الموقع الحالي.';
      });
    }
  }
}

class _SalonCard extends StatelessWidget {
  const _SalonCard({
    required this.salon,
    required this.english,
    required this.originLat,
    required this.originLng,
    required this.palette,
    this.width,
    this.onTap,
  });

  final HomeSalon salon;
  final bool english;
  final double originLat;
  final double originLng;
  final SalonPalette palette;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final price = salon.minPrice;
    final amount = price == null
        ? null
        : (price == price.roundToDouble()
              ? price.toInt().toString()
              : price.toStringAsFixed(0));
    final km = salon.distanceFrom(originLat, originLng);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: width == null ? 148 : 112,
                width: double.infinity,
                child: SalonPhoto(
                  url: salon.imageUrl,
                  asset: salonPhotoAsset(salon.name),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            salon.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        FavoriteButton(
                          salonId: salon.id,
                          color: palette.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      salon.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.soft, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${salon.ratingAvg.toStringAsFixed(1)} ★  ·  ${km.toStringAsFixed(1)} ${english ? 'km' : 'كم'}',
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _badge(
                          salon.offersHomeService
                              ? (english ? 'Home' : 'منزلي')
                              : (english ? 'In salon' : 'داخل الصالون'),
                        ),
                        if (amount != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              english ? 'From $amount EGP' : 'من $amount ج.م',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.deep,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
