import 'package:flutter/material.dart';

import '../data/shop_cart_store.dart';
import '../data/shop_catalog.dart';
import '../theme/app_colors.dart';
import 'product_detail_screen.dart';
import 'shop_cart_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.locale});

  final Locale locale;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<ShopCategory> _categories = ShopCategory.fallback;
  var _loading = true;
  int? _categoryId;

  bool get _english => widget.locale.languageCode == 'en';

  @override
  void initState() {
    super.initState();
    ShopCartStore.instance.load();
    ShopCartStore.instance.addListener(_onCart);
    _load();
  }

  void _onCart() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ShopCartStore.instance.removeListener(_onCart);
    super.dispose();
  }

  Future<void> _openCart() async {
    final english = widget.locale.languageCode == 'en';
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: ShopCartScreen(locale: widget.locale),
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final categories = await ShopApi.loadCatalog();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = ShopCategory.fallback;
        _loading = false;
      });
    }
  }

  List<ShopProduct> get _products {
    if (_categoryId == null) {
      return [for (final category in _categories) ...category.products];
    }
    for (final category in _categories) {
      if (category.id == _categoryId) return category.products;
    }
    return const [];
  }

  Future<void> _openProduct(ShopProduct product) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailScreen(product: product, locale: widget.locale),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final english = _english;
    final products = _products;

    return ColoredBox(
      key: const Key('shop-screen'),
      color: AppColors.black,
      child: RefreshIndicator(
        color: AppColors.ink,
        backgroundColor: AppColors.gold,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    english ? 'Shop' : 'التسوق',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                Material(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: const Key('shop-open-cart'),
                    onTap: _openCart,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.gold,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            english ? 'Cart' : 'السلة',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (ShopCartStore.instance.count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${ShopCartStore.instance.count}',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              english
                  ? 'Browse categories and products for your salon look.'
                  : 'تصفّح الأقسام والمنتجات لعناية صالونك.',
              style: TextStyle(
                color: AppColors.goldSoft,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              english ? 'Categories' : 'الأقسام',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 118,
              child: ListView(
                key: const Key('shop-categories-slider'),
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip(
                    key: const Key('shop-category-all'),
                    label: english ? 'All' : 'الكل',
                    selected: _categoryId == null,
                    icon: Icons.apps_rounded,
                    onTap: () => setState(() => _categoryId = null),
                  ),
                  for (final category in _categories)
                    _CategoryChip(
                      key: Key('shop-category-${category.slug}'),
                      label: category.name,
                      selected: _categoryId == category.id,
                      imageUrl: category.imageUrl,
                      icon: _iconFor(category.slug),
                      onTap: () => setState(() => _categoryId = category.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    english ? 'Products' : 'المنتجات',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  english
                      ? '${products.length} items'
                      : '${products.length} منتج',
                  style: TextStyle(color: AppColors.goldSoft, fontSize: 12.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFD9B25B)),
                ),
              )
            else if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: AppColors.goldSoft,
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      english ? 'No products here' : 'لا توجد منتجات هنا',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                key: const Key('shop-products-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductCard(
                    product: product,
                    english: english,
                    onTap: () => _openProduct(product),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String slug) {
    return switch (slug) {
      'hair-care' => Icons.content_cut_rounded,
      'skin-care' => Icons.spa_rounded,
      'beard-tools' => Icons.face_retouching_natural,
      'kids-fun' => Icons.child_care_rounded,
      _ => Icons.shopping_bag_outlined,
    };
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.imageUrl,
    this.icon = Icons.shopping_bag_outlined,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: Material(
        color: selected ? AppColors.gold : AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 104,
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.line,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.ink.withValues(alpha: 0.12)
                        : AppColors.black,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            icon,
                            color: selected ? AppColors.ink : AppColors.gold,
                          ),
                        )
                      : Icon(
                          icon,
                          color: selected ? AppColors.ink : AppColors.gold,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? AppColors.ink : AppColors.gold,
                    fontSize: 12.5,
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.english,
    required this.onTap,
  });

  final ShopProduct product;
  final bool english;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('shop-product-${product.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17),
                      ),
                      child: ColoredBox(
                        color: AppColors.black,
                        child: product.imageUrl != null
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.shopping_bag_outlined,
                                  color: AppColors.gold,
                                  size: 36,
                                ),
                              )
                            : Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.gold,
                                size: 36,
                              ),
                      ),
                    ),
                    if (product.onSale)
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            english ? 'Sale' : 'عرض',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          english
                              ? 'EGP ${product.price.round()}'
                              : '${product.price.round()} ج.م',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        if (product.onSale) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${product.compareAtPrice!.round()}',
                            style: TextStyle(
                              color: AppColors.goldSoft,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
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
}
