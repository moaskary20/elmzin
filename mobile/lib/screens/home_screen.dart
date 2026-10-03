import 'dart:async';

import 'package:flutter/material.dart';

import '../data/home_category.dart';
import '../data/home_salon.dart';
import '../data/home_slide.dart';
import '../theme/app_colors.dart';
import '../widgets/places_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.locale,
    this.onOpenSalon,
    this.onOpenCategory,
  });

  final Locale locale;
  final void Function(int id, String categorySlug)? onOpenSalon;
  final ValueChanged<HomeCategory>? onOpenCategory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _page = PageController();
  List<HomeSlide> _slides = const [HomeSlide.fallback];
  List<HomeCategory> _categories = HomeCategory.fallback;
  List<HomeSalon> _salons = HomeSalon.fallback;
  var _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
    _loadSalons();
  }

  Future<void> _loadSalons() async {
    try {
      final salons = await SalonsApi.load();
      if (!mounted) return;
      setState(() => _salons = salons);
    } catch (error) {
      logSlideError(error);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoriesApi.load();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (error) {
      logSlideError(error);
    }
  }

  Future<void> _load() async {
    try {
      final slides = await SlidesApi.load();
      if (!mounted) return;
      setState(() {
        _slides = slides;
        _index = 0;
      });
      _schedule();
    } catch (error) {
      logSlideError(error);
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_page.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.locale.languageCode;
    final direction = language == 'en' ? TextDirection.ltr : TextDirection.rtl;

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.62,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _page,
                      itemCount: _slides.length,
                      onPageChanged: (index) => setState(() => _index = index),
                      itemBuilder: (context, index) {
                        return _SlideView(
                          slide: _slides[index],
                          languageCode: language,
                        );
                      },
                    ),
                    if (_slides.length > 1)
                      PositionedDirectional(
                        bottom: 18,
                        start: 0,
                        end: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _slides.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: i == _index ? 22 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: i == _index
                                      ? AppColors.gold
                                      : AppColors.gold.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CategoriesSection(
                categories: _categories,
                languageCode: language,
                onOpen: widget.onOpenCategory,
              ),
            ),
            SliverToBoxAdapter(
              child: PlacesSection(
                salons: _salons,
                languageCode: language,
                onOpen: widget.onOpenSalon == null
                    ? null
                    : (salon) =>
                          widget.onOpenSalon!(salon.id, salon.categorySlug),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.languageCode});

  final HomeSlide slide;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final image = slide.imageUrl != null
        ? Image.network(
            slide.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Image.asset(
              slide.asset ?? HomeSlide.fallback.asset!,
              fit: BoxFit.cover,
            ),
          )
        : Image.asset(
            slide.asset ?? HomeSlide.fallback.asset!,
            fit: BoxFit.cover,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.dark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC000000),
                      Color(0x00000000),
                      Color(0xE6000000),
                    ],
                    stops: [0, 0.42, 1],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0x55000000),
                      const Color(0x00000000),
                      AppColors.black.withValues(alpha: 0),
                      AppColors.black.withValues(alpha: 0.94),
                      AppColors.black,
                    ],
                    stops: const [0, 0.3, 0.45, 0.8, 1],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                slide.titleFor(languageCode),
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                slide.subtitleFor(languageCode),
                style: TextStyle(
                  color: AppColors.goldSoft,
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({
    required this.categories,
    required this.languageCode,
    this.onOpen,
  });

  final List<HomeCategory> categories;
  final String languageCode;
  final ValueChanged<HomeCategory>? onOpen;

  @override
  Widget build(BuildContext context) {
    final title = languageCode == 'en' ? 'Main categories' : 'الأقسام الرئيسية';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(width: 42, height: 1, color: AppColors.gold),
          const SizedBox(height: 16),
          for (final category in categories) ...[
            _CategoryCard(
              category: category,
              languageCode: languageCode,
              onTap: onOpen == null ? null : () => onOpen!(category),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.languageCode,
    this.onTap,
  });

  final HomeCategory category;
  final String languageCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final count = category.salonsCount;
    final countLabel = languageCode == 'en'
        ? '$count salons'
        : '$count صالونات';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('category-${category.slug}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconFor(category.slug), color: AppColors.gold),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.nameFor(languageCode),
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.descriptionFor(languageCode),
                      style: TextStyle(
                        color: AppColors.goldSoft,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        countLabel,
                        style: TextStyle(
                          color: AppColors.goldDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String slug) {
    return switch (slug) {
      'men' => Icons.content_cut_rounded,
      'women' => Icons.spa_rounded,
      'kids' => Icons.child_care_rounded,
      _ => Icons.storefront_rounded,
    };
  }
}
