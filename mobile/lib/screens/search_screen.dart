import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/auth_api.dart';
import '../data/home_category.dart';
import '../data/home_salon.dart';
import '../theme/app_colors.dart';
import '../widgets/favorite_button.dart';
import '../widgets/salon_photo.dart';
import 'map_picker_screen.dart';

enum _PlaceType { any, home, salon }

enum _Sort { nearest, rating, cheapest, priciest }

enum _Origin { fallback, device, picked }

class _Filters {
  const _Filters({
    this.place = _PlaceType.any,
    this.minRating,
    this.priceLow,
    this.priceHigh,
    this.radiusKm,
    this.verifiedOnly = false,
  });

  final _PlaceType place;
  final double? minRating;
  final double? priceLow;
  final double? priceHigh;
  final double? radiusKm;
  final bool verifiedOnly;

  _Filters withPlace(_PlaceType value) => _Filters(
    place: value,
    minRating: minRating,
    priceLow: priceLow,
    priceHigh: priceHigh,
    radiusKm: radiusKm,
    verifiedOnly: verifiedOnly,
  );

  int get count {
    var total = 0;
    if (place != _PlaceType.any) total++;
    if (minRating != null) total++;
    if (priceLow != null || priceHigh != null) total++;
    if (radiusKm != null) total++;
    if (verifiedOnly) total++;
    return total;
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.locale,
    required this.onOpenSalon,
  });

  final Locale locale;
  final void Function(int id, String categorySlug) onOpenSalon;

  /// Widget tests cannot build a platform map view.
  static bool useMap = true;

  static Future<(double, double)?> Function() locate = _locateDevice;

  static Future<(double, double)?> _locateDevice() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition();
    return (position.latitude, position.longitude);
  }

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _maxRadius = 50.0;

  final _query = TextEditingController();
  final _map = Completer<GoogleMapController>();
  List<HomeSalon> _salons = HomeSalon.fallback;
  List<HomeCategory> _categories = HomeCategory.fallback;
  String? _category;
  var _sort = _Sort.nearest;
  var _filters = const _Filters();
  var _showMap = true;

  double _lat = HomeSalon.originLatitude;
  double _lng = HomeSalon.originLongitude;
  var _origin = _Origin.fallback;
  String? _address;
  var _locating = false;
  String? _locationNote;

  bool get _english => widget.locale.languageCode == 'en';

  @override
  void initState() {
    super.initState();
    _load();
    _useDevice();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SalonsApi.load(),
        CategoriesApi.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _salons = results[0] as List<HomeSalon>;
        _categories = results[1] as List<HomeCategory>;
      });
    } catch (_) {}
  }

  Future<void> _useDevice() async {
    setState(() {
      _locating = true;
      _locationNote = null;
    });
    (double, double)? found;
    try {
      found = await SearchScreen.locate();
    } catch (_) {}
    if (!mounted) return;
    if (found == null) {
      setState(() {
        _locating = false;
        _locationNote = _english
            ? 'Could not read your location. Showing Cairo.'
            : 'تعذر تحديد موقعك. نعرض القاهرة.';
      });
      return;
    }
    setState(() {
      _lat = found!.$1;
      _lng = found.$2;
      _origin = _Origin.device;
      _address = null;
      _locating = false;
    });
    _moveCamera();
    _describe(found.$1, found.$2);
  }

  Future<void> _describe(double lat, double lng) async {
    try {
      final place = await MapGeocoder.resolve(lat, lng);
      if (!mounted || lat != _lat || lng != _lng) return;
      setState(() => _address = place.address);
    } catch (_) {}
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<MapAddress>(
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lat = picked.latitude;
      _lng = picked.longitude;
      _origin = _Origin.picked;
      _address = picked.address;
      _locationNote = null;
    });
    _moveCamera();
  }

  Future<void> _moveCamera() async {
    if (!SearchScreen.useMap || !_map.isCompleted) return;
    final controller = await _map.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(_lat, _lng), 12),
    );
  }

  (double, double) get _priceBounds {
    final prices = _salons.map((salon) => salon.minPrice).whereType<double>();
    if (prices.isEmpty) return (0, 1);
    final low = prices.reduce(math.min);
    final high = prices.reduce(math.max);
    return (low, high <= low ? low + 1 : high);
  }

  List<HomeSalon> get _results {
    final text = _query.text.trim().toLowerCase();
    final filters = _filters;
    final rows = _salons.where((salon) {
      if (_category != null && salon.categorySlug != _category) return false;
      if (text.isNotEmpty) {
        final haystack = [
          salon.name,
          salon.city,
          salon.district,
          ...salon.services,
        ].join(' ').toLowerCase();
        if (!haystack.contains(text)) return false;
      }
      switch (filters.place) {
        case _PlaceType.home:
          if (!salon.offersHomeService) return false;
        case _PlaceType.salon:
          if (salon.offersHomeService) return false;
        case _PlaceType.any:
          break;
      }
      if (filters.minRating != null && salon.ratingAvg < filters.minRating!) {
        return false;
      }
      final price = salon.minPrice;
      if (price != null) {
        if (filters.priceLow != null && price < filters.priceLow! - 0.5) {
          return false;
        }
        if (filters.priceHigh != null && price > filters.priceHigh! + 0.5) {
          return false;
        }
      }
      if (filters.radiusKm != null &&
          salon.distanceFrom(_lat, _lng) > filters.radiusKm!) {
        return false;
      }
      if (filters.verifiedOnly && !salon.verified) return false;
      return true;
    }).toList();

    int byPrice(HomeSalon a, HomeSalon b) => (a.minPrice ?? double.infinity)
        .compareTo(b.minPrice ?? double.infinity);

    rows.sort(
      (a, b) => switch (_sort) {
        _Sort.nearest =>
          a.distanceFrom(_lat, _lng).compareTo(b.distanceFrom(_lat, _lng)),
        _Sort.rating => b.ratingAvg.compareTo(a.ratingAvg),
        _Sort.cheapest => byPrice(a, b),
        _Sort.priciest => byPrice(b, a),
      },
    );
    return rows;
  }

  void _reset() {
    setState(() {
      _query.clear();
      _category = null;
      _sort = _Sort.nearest;
      _filters = const _Filters();
    });
  }

  Future<void> _openFilters() async {
    final next = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: Directionality.of(context),
        child: _FilterSheet(
          english: _english,
          initial: _filters,
          bounds: _priceBounds,
          maxRadius: _maxRadius,
        ),
      ),
    );
    if (next != null && mounted) setState(() => _filters = next);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final active =
        _filters.count +
        (_category == null ? 0 : 1) +
        (_query.text.trim().isEmpty ? 0 : 1);

    return ColoredBox(
      key: const Key('search-screen'),
      color: AppColors.black,
      child: RefreshIndicator(
        color: AppColors.ink,
        backgroundColor: AppColors.gold,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              _english ? 'Search' : 'البحث',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _english
                  ? 'Find the right salon near you.'
                  : 'اعثر على الصالون المناسب بالقرب منك.',
              style: TextStyle(color: AppColors.goldSoft, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _searchField()),
                const SizedBox(width: 10),
                _FilterButton(count: _filters.count, onTap: _openFilters),
              ],
            ),
            const SizedBox(height: 14),
            _LocationCard(
              english: _english,
              origin: _origin,
              address: _address,
              note: _locationNote,
              locating: _locating,
              onLocate: _useDevice,
              onPick: _pickOnMap,
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: _showMap
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _mapCard(results),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            _placeBar(),
            const SizedBox(height: 12),
            _categoryRow(),
            const SizedBox(height: 10),
            _sortRow(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _english
                        ? '${results.length} places'
                        : '${results.length} مكان',
                    key: const Key('search-count'),
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (active > 0)
                  TextButton(
                    key: const Key('search-reset'),
                    onPressed: _reset,
                    child: Text(
                      _english ? 'Clear all' : 'مسح الكل',
                      style: TextStyle(color: AppColors.gold),
                    ),
                  ),
                IconButton(
                  key: const Key('search-map-toggle'),
                  tooltip: _english ? 'Map' : 'الخريطة',
                  onPressed: () => setState(() => _showMap = !_showMap),
                  icon: Icon(
                    _showMap ? Icons.map_rounded : Icons.map_outlined,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (results.isEmpty)
              _Empty(english: _english, onReset: _reset)
            else
              for (final salon in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ResultCard(
                    salon: salon,
                    english: _english,
                    distanceKm: salon.distanceFrom(_lat, _lng),
                    onTap: () =>
                        widget.onOpenSalon(salon.id, salon.categorySlug),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      key: const Key('search-field'),
      controller: _query,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      style: TextStyle(color: AppColors.gold),
      cursorColor: AppColors.gold,
      decoration: InputDecoration(
        hintText: _english
            ? 'Salon, service, or area'
            : 'اسم الصالون، الخدمة، أو المنطقة',
        hintStyle: TextStyle(color: AppColors.goldSoft, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.gold),
        suffixIcon: _query.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: AppColors.gold),
                onPressed: () => setState(_query.clear),
              ),
        filled: true,
        fillColor: AppColors.panel,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }

  Widget _mapCard(List<HomeSalon> results) {
    final user = LatLng(_lat, _lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        key: const Key('search-map'),
        height: 230,
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SearchScreen.useMap
            ? GoogleMap(
                initialCameraPosition: CameraPosition(target: user, zoom: 12),
                onMapCreated: (controller) {
                  if (!_map.isCompleted) _map.complete(controller);
                },
                myLocationEnabled: _origin == _Origin.device,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                markers: {
                  Marker(
                    markerId: const MarkerId('me'),
                    position: user,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                    infoWindow: InfoWindow(
                      title: _english ? 'You are here' : 'موقعك',
                      snippet: _address,
                    ),
                    zIndexInt: 2,
                  ),
                  for (final salon in results)
                    if (salon.latitude != null && salon.longitude != null)
                      Marker(
                        markerId: MarkerId('salon-${salon.id}'),
                        position: LatLng(salon.latitude!, salon.longitude!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange,
                        ),
                        infoWindow: InfoWindow(
                          title: salon.name,
                          snippet: _distanceLabel(
                            salon.distanceFrom(_lat, _lng),
                            _english,
                          ),
                          onTap: () =>
                              widget.onOpenSalon(salon.id, salon.categorySlug),
                        ),
                      ),
                },
                circles: {
                  if (_filters.radiusKm != null)
                    Circle(
                      circleId: const CircleId('radius'),
                      center: user,
                      radius: _filters.radiusKm! * 1000,
                      strokeColor: AppColors.gold,
                      strokeWidth: 2,
                      fillColor: const Color(0x22D9B25B),
                    ),
                },
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      color: AppColors.gold,
                      size: 34,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _english ? 'You are here' : 'موقعك',
                      style: TextStyle(color: AppColors.gold),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _placeBar() {
    final options = [
      (_PlaceType.any, _english ? 'All' : 'الكل', Icons.apps_rounded),
      (
        _PlaceType.salon,
        _english ? 'At the salon' : 'في الصالون',
        Icons.storefront_rounded,
      ),
      (_PlaceType.home, _english ? 'At home' : 'في المنزل', Icons.home_rounded),
    ];
    return Container(
      key: const Key('search-place-bar'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (final (place, label, icon) in options)
            Expanded(
              child: _PlaceSegment(
                key: Key('search-place-bar-${place.name}'),
                label: label,
                icon: icon,
                selected: _filters.place == place,
                onTap: () =>
                    setState(() => _filters = _filters.withPlace(place)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            key: const Key('search-category-all'),
            label: _english ? 'All' : 'الكل',
            selected: _category == null,
            onTap: () => setState(() => _category = null),
          ),
          for (final category in _categories)
            _Chip(
              key: Key('search-category-${category.slug}'),
              label: category.nameFor(widget.locale.languageCode),
              selected: _category == category.slug,
              onTap: () => setState(() => _category = category.slug),
            ),
        ],
      ),
    );
  }

  Widget _sortRow() {
    final options = [
      (_Sort.nearest, _english ? 'Nearest' : 'الأقرب', Icons.near_me_rounded),
      (
        _Sort.rating,
        _english ? 'Top rated' : 'الأعلى تقييماً',
        Icons.star_rounded,
      ),
      (
        _Sort.cheapest,
        _english ? 'Lowest price' : 'الأقل سعراً',
        Icons.south_rounded,
      ),
      (
        _Sort.priciest,
        _english ? 'Highest price' : 'الأعلى سعراً',
        Icons.north_rounded,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            _Chip(
              key: Key('search-sort-${option.$1.name}'),
              label: option.$2,
              icon: option.$3,
              outlined: true,
              selected: _sort == option.$1,
              onTap: () => setState(() => _sort = option.$1),
            ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const Key('search-filters'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.tune_rounded, color: AppColors.ink),
            ),
          ),
        ),
        if (count > 0)
          PositionedDirectional(
            top: -6,
            end: -6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.black,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.english,
    required this.origin,
    required this.address,
    required this.note,
    required this.locating,
    required this.onLocate,
    required this.onPick,
  });

  final bool english;
  final _Origin origin;
  final String? address;
  final String? note;
  final bool locating;
  final VoidCallback onLocate;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final title = switch (origin) {
      _Origin.device => english ? 'Your current location' : 'موقعك الحالي',
      _Origin.picked => english ? 'Chosen location' : 'الموقع المختار',
      _Origin.fallback => english ? 'Default location' : 'الموقع الافتراضي',
    };
    final line = locating
        ? (english ? 'Finding you…' : 'جارٍ تحديد موقعك…')
        : address ??
              note ??
              (origin == _Origin.fallback
                  ? (english ? 'Cairo' : 'القاهرة')
                  : (english ? 'Location set' : 'تم تحديد الموقع'));

    return Container(
      key: const Key('search-location'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0x22D9B25B),
              shape: BoxShape.circle,
            ),
            child: locating
                ? Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                : Icon(Icons.location_on_rounded, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  key: const Key('search-location-text'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.goldSoft,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('search-locate'),
            tooltip: english ? 'Use my location' : 'استخدم موقعي',
            onPressed: locating ? null : onLocate,
            icon: Icon(Icons.my_location_rounded, color: AppColors.gold),
          ),
          IconButton(
            key: const Key('search-pick'),
            tooltip: english ? 'Pick on map' : 'اختر على الخريطة',
            onPressed: onPick,
            icon: Icon(Icons.edit_location_alt_rounded, color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

class _PlaceSegment extends StatelessWidget {
  const _PlaceSegment({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.ink : AppColors.gold;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.ink : AppColors.gold;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: selected
            ? AppColors.gold
            : (outlined ? Colors.transparent : AppColors.panel),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: foreground),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.salon,
    required this.english,
    required this.distanceKm,
    required this.onTap,
  });

  final HomeSalon salon;
  final bool english;
  final double distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = salon.minPrice;
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('search-result-${salon.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    child: SalonPhoto(
                      url: salon.imageUrl,
                      asset: salonPhotoAsset(salon.name),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              salon.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (salon.verified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              color: AppColors.gold,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        salon.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.goldSoft,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          _Meta(
                            icon: Icons.star_rounded,
                            text: salon.reviewsCount > 0
                                ? '${salon.ratingAvg.toStringAsFixed(1)} (${salon.reviewsCount})'
                                : salon.ratingAvg.toStringAsFixed(1),
                          ),
                          _Meta(
                            icon: Icons.near_me_rounded,
                            text: _distanceLabel(distanceKm, english),
                          ),
                          if (salon.offersHomeService)
                            _Meta(
                              icon: Icons.home_rounded,
                              text: english ? 'Home' : 'منزلي',
                            ),
                        ],
                      ),
                      if (price != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          english
                              ? 'From EGP ${price.round()}'
                              : 'يبدأ من ${price.round()} ج.م',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                FavoriteButton(salonId: salon.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: AppColors.goldSoft, fontSize: 12)),
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.english,
    required this.initial,
    required this.bounds,
    required this.maxRadius,
  });

  final bool english;
  final _Filters initial;
  final (double, double) bounds;
  final double maxRadius;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _PlaceType _place = widget.initial.place;
  late double? _rating = widget.initial.minRating;
  late RangeValues _price = RangeValues(
    (widget.initial.priceLow ?? widget.bounds.$1).clamp(
      widget.bounds.$1,
      widget.bounds.$2,
    ),
    (widget.initial.priceHigh ?? widget.bounds.$2).clamp(
      widget.bounds.$1,
      widget.bounds.$2,
    ),
  );
  late double _radius = widget.initial.radiusKm ?? widget.maxRadius;
  late bool _verified = widget.initial.verifiedOnly;

  bool get _english => widget.english;

  void _apply() {
    final low = widget.bounds.$1;
    final high = widget.bounds.$2;
    Navigator.pop(
      context,
      _Filters(
        place: _place,
        minRating: _rating,
        priceLow: (_price.start - low).abs() < 0.5 ? null : _price.start,
        priceHigh: (_price.end - high).abs() < 0.5 ? null : _price.end,
        radiusKm: _radius >= widget.maxRadius ? null : _radius,
        verifiedOnly: _verified,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _english ? 'Filters' : 'الفلاتر',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _label(_english ? 'Where' : 'مكان الخدمة'),
            Wrap(
              children: [
                _Chip(
                  key: const Key('search-place-any'),
                  label: _english ? 'All' : 'الكل',
                  selected: _place == _PlaceType.any,
                  onTap: () => setState(() => _place = _PlaceType.any),
                ),
                _Chip(
                  key: const Key('search-place-home'),
                  label: _english ? 'At home' : 'في المنزل',
                  icon: Icons.home_rounded,
                  selected: _place == _PlaceType.home,
                  onTap: () => setState(() => _place = _PlaceType.home),
                ),
                _Chip(
                  key: const Key('search-place-salon'),
                  label: _english ? 'At the salon' : 'في الصالون',
                  icon: Icons.storefront_rounded,
                  selected: _place == _PlaceType.salon,
                  onTap: () => setState(() => _place = _PlaceType.salon),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _label(_english ? 'Rating' : 'التقييم'),
            Wrap(
              children: [
                _Chip(
                  key: const Key('search-rating-any'),
                  label: _english ? 'Any' : 'الكل',
                  selected: _rating == null,
                  onTap: () => setState(() => _rating = null),
                ),
                for (final stars in const [3.0, 4.0, 4.5])
                  _Chip(
                    key: Key('search-rating-$stars'),
                    label: '${stars % 1 == 0 ? stars.toInt() : stars}+',
                    icon: Icons.star_rounded,
                    selected: _rating == stars,
                    onTap: () => setState(() => _rating = stars),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _label(
              _english
                  ? 'Price: EGP ${_price.start.round()} – ${_price.end.round()}'
                  : 'السعر: ${_price.start.round()} – ${_price.end.round()} ج.م',
            ),
            SliderTheme(
              data: _slider(context),
              child: RangeSlider(
                key: const Key('search-price'),
                min: widget.bounds.$1,
                max: widget.bounds.$2,
                values: _price,
                onChanged: (values) => setState(() => _price = values),
              ),
            ),
            const SizedBox(height: 6),
            _label(
              _radius >= widget.maxRadius
                  ? (_english ? 'Distance: any' : 'المسافة: أي مسافة')
                  : (_english
                        ? 'Distance: within ${_radius.round()} km'
                        : 'المسافة: حتى ${_radius.round()} كم'),
            ),
            SliderTheme(
              data: _slider(context),
              child: Slider(
                key: const Key('search-radius'),
                min: 1,
                max: widget.maxRadius,
                divisions: (widget.maxRadius - 1).round(),
                value: _radius,
                onChanged: (value) => setState(() => _radius = value),
              ),
            ),
            const SizedBox(height: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('search-verified'),
                onTap: () => setState(() => _verified = !_verified),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.verified_rounded, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _english
                              ? 'Verified salons only'
                              : 'الصالونات الموثقة فقط',
                          style: TextStyle(color: AppColors.gold),
                        ),
                      ),
                      IgnorePointer(
                        child: Switch(
                          value: _verified,
                          activeThumbColor: AppColors.ink,
                          activeTrackColor: AppColors.gold,
                          onChanged: (_) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('search-filters-reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: BorderSide(color: AppColors.gold),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.pop(context, const _Filters()),
                    child: Text(_english ? 'Reset' : 'إعادة ضبط'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('search-filters-apply'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _apply,
                    child: Text(
                      _english ? 'Show results' : 'عرض النتائج',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.goldSoft,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  SliderThemeData _slider(BuildContext context) {
    return SliderTheme.of(context).copyWith(
      activeTrackColor: AppColors.gold,
      inactiveTrackColor: AppColors.line,
      thumbColor: AppColors.gold,
      overlayColor: const Color(0x33D9B25B),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.english, required this.onReset});

  final bool english;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: AppColors.gold, size: 42),
          const SizedBox(height: 12),
          Text(
            english ? 'No places match' : 'لا توجد أماكن مطابقة',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            english
                ? 'Try a wider distance or fewer filters.'
                : 'جرّب مسافة أوسع أو فلاتر أقل.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.goldSoft),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onReset,
            child: Text(
              english ? 'Clear all' : 'مسح الكل',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

String _distanceLabel(double km, bool english) {
  if (km >= 9999) return english ? 'Unknown' : 'غير محدد';
  if (km < 1) {
    final meters = (km * 1000).round();
    return english ? '$meters m' : '$meters م';
  }
  final value = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  return english ? '$value km' : '$value كم';
}
