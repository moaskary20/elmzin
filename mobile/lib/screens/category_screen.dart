import 'package:flutter/material.dart';

import '../data/home_category.dart';
import '../data/home_salon.dart';
import '../data/home_slide.dart';
import '../theme/app_colors.dart';
import '../widgets/places_section.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.category,
    required this.locale,
    this.onBack,
    this.onOpenSalon,
  });

  final HomeCategory category;
  final Locale locale;
  final VoidCallback? onBack;
  final ValueChanged<int>? onOpenSalon;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<HomeSalon> _salons = const [];
  var _loading = true;

  bool get _english => widget.locale.languageCode == 'en';

  bool get _blush => widget.category.slug == 'women';

  SalonPalette get _palette => _blush ? SalonPalette.blush : SalonPalette.gold;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final salons = await SalonsApi.load();
      if (!mounted) return;
      setState(() {
        _salons = _forCategory(salons);
        _loading = false;
      });
    } catch (error) {
      logSlideError(error);
      if (!mounted) return;
      setState(() {
        _salons = _forCategory(HomeSalon.fallback);
        _loading = false;
      });
    }
  }

  List<HomeSalon> _forCategory(List<HomeSalon> salons) {
    return salons
        .where((salon) => salon.categorySlug == widget.category.slug)
        .toList();
  }

  IconData get _icon {
    return switch (widget.category.slug) {
      'men' => Icons.content_cut_rounded,
      'women' => Icons.spa_rounded,
      'kids' => Icons.child_care_rounded,
      _ => Icons.storefront_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final category = widget.category;
    final language = widget.locale.languageCode;
    final titleColor = _blush ? palette.ink : palette.accent;

    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : ListView(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BackButton(
                      key: const Key('category-back'),
                      color: titleColor,
                      onPressed: widget.onBack,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.centerStart,
                          end: AlignmentDirectional.centerEnd,
                          colors: [palette.banner, palette.bannerEnd],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: titleColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(_icon, color: titleColor, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.nameFor(language),
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category.descriptionFor(language),
                                  style: TextStyle(
                                    color: _blush
                                        ? palette.ink.withValues(alpha: 0.78)
                                        : palette.soft,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _english
                                      ? '${_salons.length} salons'
                                      : '${_salons.length} صالونات',
                                  style: TextStyle(
                                    color: _blush ? palette.ink : palette.deep,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PlacesSection(
                    salons: _salons,
                    languageCode: language,
                    palette: palette,
                    showFeatured: false,
                    keyPrefix: 'category-',
                    onOpen: widget.onOpenSalon == null
                        ? null
                        : (salon) => widget.onOpenSalon!(salon.id),
                  ),
                ],
              ),
      ),
    );
  }
}
