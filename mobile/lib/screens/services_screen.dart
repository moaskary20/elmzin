import 'package:flutter/material.dart';

import '../data/home_category.dart';
import '../data/service_catalog.dart';
import '../theme/app_colors.dart';
import '../widgets/salon_photo.dart';

enum _Sort { popular, cheapest, quickest, name }

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({
    super.key,
    required this.locale,
    required this.onOpenSalon,
  });

  final Locale locale;
  final void Function(int id, String categorySlug) onOpenSalon;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _query = TextEditingController();
  List<ServiceOffer> _offers = ServiceOffer.fallback;
  List<HomeCategory> _categories = HomeCategory.fallback;
  String? _category;
  var _sort = _Sort.popular;
  var _homeOnly = false;

  bool get _english => widget.locale.languageCode == 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ServicesApi.load(),
        CategoriesApi.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _offers = results[0] as List<ServiceOffer>;
        _categories = results[1] as List<HomeCategory>;
      });
    } catch (_) {}
  }

  List<ServiceGroup> get _groups {
    final text = _query.text.trim();
    final offers = _offers.where((offer) {
      if (_category != null && offer.categorySlug != _category) return false;
      if (_homeOnly && !offer.homeService) return false;
      if (text.isNotEmpty &&
          !'${offer.name} ${offer.description} ${offer.salonName}'.contains(
            text,
          )) {
        return false;
      }
      return true;
    }).toList();
    final groups = ServiceGroup.from(offers);
    groups.sort(
      (a, b) => switch (_sort) {
        _Sort.popular =>
          b.bookings != a.bookings
              ? b.bookings.compareTo(a.bookings)
              : b.salons.compareTo(a.salons),
        _Sort.cheapest => a.minPrice.compareTo(b.minPrice),
        _Sort.quickest => a.shortest.compareTo(b.shortest),
        _Sort.name => a.name.compareTo(b.name),
      },
    );
    return groups;
  }

  List<ServiceGroup> get _popular {
    final groups = ServiceGroup.from(_offers)
      ..sort((a, b) {
        final byBookings = b.bookings.compareTo(a.bookings);
        return byBookings != 0 ? byBookings : b.salons.compareTo(a.salons);
      });
    return groups.take(5).toList();
  }

  void _openGroup(ServiceGroup group) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: Directionality.of(context),
        child: _OffersSheet(
          group: group,
          english: _english,
          onOpen: (offer) {
            Navigator.pop(sheetContext);
            widget.onOpenSalon(offer.salonId, offer.categorySlug);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final filtering =
        _query.text.trim().isNotEmpty || _category != null || _homeOnly;

    return ColoredBox(
      key: const Key('services-screen'),
      color: AppColors.black,
      child: RefreshIndicator(
        color: AppColors.ink,
        backgroundColor: AppColors.gold,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              _english ? 'Services' : 'الخدمات',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _english
                  ? 'Pick a service and compare salons and prices.'
                  : 'اختر الخدمة وقارن بين الصالونات والأسعار.',
              style: TextStyle(color: AppColors.goldSoft, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _searchField(),
            const SizedBox(height: 14),
            _categoryRow(),
            if (!filtering && _popular.isNotEmpty) ...[
              const SizedBox(height: 20),
              _heading(_english ? 'Most requested' : 'الأكثر طلباً'),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _popular.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _PopularCard(
                    group: _popular[index],
                    english: _english,
                    onTap: () => _openGroup(_popular[index]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _heading(
                    _english
                        ? 'All services (${groups.length})'
                        : 'كل الخدمات (${groups.length})',
                  ),
                ),
                _SortMenu(
                  english: _english,
                  sort: _sort,
                  onChanged: (sort) => setState(() => _sort = sort),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _HomeToggle(
              english: _english,
              value: _homeOnly,
              onChanged: (value) => setState(() => _homeOnly = value),
            ),
            const SizedBox(height: 12),
            if (groups.isEmpty)
              _Empty(
                english: _english,
                onReset: () => setState(() {
                  _query.clear();
                  _category = null;
                  _homeOnly = false;
                }),
              )
            else
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ServiceTile(
                    group: group,
                    english: _english,
                    onTap: () => _openGroup(group),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.gold,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      key: const Key('services-search'),
      controller: _query,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: AppColors.gold),
      cursorColor: AppColors.gold,
      decoration: InputDecoration(
        hintText: _english ? 'Haircut, color, makeup…' : 'قص، صبغة، مكياج…',
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

  Widget _categoryRow() {
    final items = [
      (null, _english ? 'All' : 'الكل'),
      for (final category in _categories)
        (category.slug, category.nameFor(widget.locale.languageCode)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _Chip(
                key: Key('services-category-${item.$1 ?? 'all'}'),
                label: item.$2,
                selected: _category == item.$1,
                onTap: () => setState(() => _category = item.$1),
              ),
            ),
        ],
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : AppColors.panel,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.ink : AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.english,
    required this.sort,
    required this.onChanged,
  });

  final bool english;
  final _Sort sort;
  final ValueChanged<_Sort> onChanged;

  String _label(_Sort value) => switch (value) {
    _Sort.popular => english ? 'Most requested' : 'الأكثر طلباً',
    _Sort.cheapest => english ? 'Lowest price' : 'الأقل سعراً',
    _Sort.quickest => english ? 'Shortest' : 'الأقصر مدة',
    _Sort.name => english ? 'Name' : 'الاسم',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Sort>(
      key: const Key('services-sort'),
      color: AppColors.panel,
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final value in _Sort.values)
          PopupMenuItem(
            key: Key('services-sort-${value.name}'),
            value: value,
            child: Text(
              _label(value),
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: value == sort ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 4),
          Text(
            _label(sort),
            style: TextStyle(color: AppColors.goldSoft, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HomeToggle extends StatelessWidget {
  const _HomeToggle({
    required this.english,
    required this.value,
    required this.onChanged,
  });

  final bool english;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('services-home'),
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? AppColors.gold : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(Icons.home_rounded, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                english ? 'Home service only' : 'خدمة منزلية فقط',
                style: TextStyle(color: AppColors.gold),
              ),
            ),
            IgnorePointer(
              child: Switch(
                value: value,
                activeThumbColor: AppColors.ink,
                activeTrackColor: AppColors.gold,
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({
    required this.group,
    required this.english,
    required this.onTap,
  });

  final ServiceGroup group;
  final bool english;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.warm, AppColors.panel],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ServiceIcon(name: group.name, size: 40),
              const Spacer(),
              Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                english
                    ? 'From EGP ${group.minPrice.round()}'
                    : 'من ${group.minPrice.round()} ج.م',
                style: TextStyle(color: AppColors.goldSoft, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.group,
    required this.english,
    required this.onTap,
  });

  final ServiceGroup group;
  final bool english;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = group.minPrice == group.maxPrice
        ? '${group.minPrice.round()}'
        : '${group.minPrice.round()} – ${group.maxPrice.round()}';
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('service-${group.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              _ServiceIcon(name: group.name, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _Meta(
                          icon: Icons.storefront_rounded,
                          text: english
                              ? '${group.salons} salons'
                              : '${group.salons} صالون',
                        ),
                        _Meta(
                          icon: Icons.schedule_rounded,
                          text: english
                              ? 'from ${group.shortest} min'
                              : 'من ${group.shortest} د',
                        ),
                        if (group.bookings > 0)
                          _Meta(
                            icon: Icons.local_fire_department_rounded,
                            text: english
                                ? '${group.bookings} bookings'
                                : '${group.bookings} حجز',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    english ? 'EGP' : 'ج.م',
                    style: TextStyle(color: AppColors.goldSoft, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: AppColors.goldSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OffersSheet extends StatelessWidget {
  const _OffersSheet({
    required this.group,
    required this.english,
    required this.onOpen,
  });

  final ServiceGroup group;
  final bool english;
  final ValueChanged<ServiceOffer> onOpen;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;
    final description = group.offers
        .map((offer) => offer.description)
        .firstWhere((text) => text.trim().isNotEmpty, orElse: () => '');

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: SafeArea(
        top: false,
        child: Column(
          key: const Key('services-offers'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  _ServiceIcon(name: group.name, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          english
                              ? 'Available at ${group.salons} salons'
                              : 'متوفرة في ${group.salons} صالون',
                          style: TextStyle(
                            color: AppColors.goldSoft,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  description,
                  style: TextStyle(
                    color: AppColors.goldSoft,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: group.offers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final offer = group.offers[index];
                  return _OfferRow(
                    offer: offer,
                    english: english,
                    cheapest: index == 0 && group.offers.length > 1,
                    onTap: () => onOpen(offer),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.offer,
    required this.english,
    required this.cheapest,
    required this.onTap,
  });

  final ServiceOffer offer;
  final bool english;
  final bool cheapest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('services-offer-${offer.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cheapest ? AppColors.gold : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: SalonPhoto(
                    url: offer.imageUrl,
                    asset: salonPhotoAsset(offer.salonName),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            offer.salonName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (offer.verified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.gold,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.goldSoft, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        _Meta(
                          icon: Icons.star_rounded,
                          text: offer.rating.toStringAsFixed(1),
                        ),
                        _Meta(
                          icon: Icons.schedule_rounded,
                          text: english
                              ? '${offer.durationMinutes} min'
                              : '${offer.durationMinutes} د',
                        ),
                        if (offer.homeService)
                          _Meta(
                            icon: Icons.home_rounded,
                            text: english ? 'Home' : 'منزلي',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (cheapest)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        english ? 'Best price' : 'أفضل سعر',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    english
                        ? 'EGP ${offer.price.round()}'
                        : '${offer.price.round()} ج.م',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    english ? 'Book' : 'احجز',
                    style: TextStyle(
                      color: AppColors.goldSoft,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.goldSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.name, required this.size});

  final String name;
  final double size;

  IconData get _icon {
    if (name.contains('لحية')) return Icons.face_retouching_natural_rounded;
    if (name.contains('أطفال')) return Icons.child_care_rounded;
    if (name.contains('صبغ')) return Icons.palette_rounded;
    if (name.contains('بشرة')) return Icons.spa_rounded;
    if (name.contains('مكياج')) return Icons.brush_rounded;
    if (name.contains('تسريح')) return Icons.auto_awesome_rounded;
    if (name.contains('رسم')) return Icons.draw_rounded;
    if (name.contains('قص') || name.contains('حلاق')) {
      return Icons.content_cut_rounded;
    }
    return Icons.auto_awesome_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0x22D9B25B),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: AppColors.line),
      ),
      child: Icon(_icon, color: AppColors.gold, size: size * 0.5),
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
            english ? 'No matching services' : 'لا توجد خدمات مطابقة',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
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
