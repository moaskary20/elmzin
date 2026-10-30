import 'package:flutter/material.dart';

import '../data/shop_cart_store.dart';
import '../data/shop_catalog.dart';
import '../theme/app_colors.dart';
import '../theme/system_bars.dart';
import 'shop_cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.locale,
  });

  final ShopProduct product;
  final Locale locale;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  var _qty = 1;

  bool get _english => widget.locale.languageCode == 'en';

  ShopProduct get product => widget.product;

  int get _maxQty => product.stock <= 0 ? 0 : product.stock;

  double get _lineTotal => product.price * _qty;

  double? get _savedPerUnit {
    if (!product.onSale) return null;
    return product.compareAtPrice! - product.price;
  }

  int? get _discountPercent {
    final saved = _savedPerUnit;
    if (saved == null || product.compareAtPrice! <= 0) return null;
    return ((saved / product.compareAtPrice!) * 100).round().clamp(1, 99);
  }

  @override
  void initState() {
    super.initState();
    _qty = product.inStock ? 1 : 0;
  }

  void _changeQty(int delta) {
    if (!product.inStock) return;
    setState(() {
      _qty = (_qty + delta).clamp(1, _maxQty);
    });
  }

  String _money(double value) {
    final n = value == value.roundToDouble()
        ? '${value.round()}'
        : value.toStringAsFixed(2);
    return _english ? 'EGP $n' : '$n ج.م';
  }

  @override
  Widget build(BuildContext context) {
    final english = _english;
    final top = MediaQuery.paddingOf(context).top;
    final discount = _discountPercent;
    final saved = _savedPerUnit;

    return Directionality(
      textDirection: english ? TextDirection.ltr : TextDirection.rtl,
      child: SystemBars(
        lightStatus: !AppColors.dark,
        lightNavigation: !AppColors.dark,
        statusColor: AppColors.black,
        navigationColor: AppColors.black,
        child: Scaffold(
          key: const Key('product-detail-screen'),
          backgroundColor: AppColors.black,
          body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 340,
                    pinned: true,
                    backgroundColor: AppColors.black,
                    leading: IconButton(
                      key: const Key('product-back'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        english
                            ? Icons.arrow_back_ios_new_rounded
                            : Icons.arrow_forward_ios_rounded,
                        color: AppColors.gold,
                        size: english ? 24 : 18,
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppColors.panel,
                            child: product.imageUrl != null
                                ? Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.shopping_bag_outlined,
                                      color: AppColors.gold,
                                      size: 72,
                                    ),
                                  )
                                : Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppColors.gold,
                                    size: 72,
                                  ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 110,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.black.withValues(alpha: 0),
                                    AppColors.black,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (product.onSale)
                            PositionedDirectional(
                              top: top + 12,
                              end: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  discount == null
                                      ? (english ? 'Sale' : 'عرض')
                                      : (english
                                            ? '-$discount%'
                                            : 'خصم $discount%'),
                                  style: TextStyle(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: top + 8,
                            left: 0,
                            right: 0,
                            height: 1,
                            child: const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.categoryNameFor(english).isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.panel,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Text(
                                product.categoryNameFor(english),
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Text(
                            product.nameFor(english),
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PriceBlock(
                            english: english,
                            priceLabel: _money(product.price),
                            compareLabel: product.onSale
                                ? _money(product.compareAtPrice!)
                                : null,
                            savedLabel: saved != null && saved > 0
                                ? (english
                                      ? 'You save ${_money(saved)}'
                                      : 'توفر ${_money(saved)}')
                                : null,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            english ? 'Quantity' : 'الكمية',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _QuantityStepper(
                            qty: _qty,
                            enabled: product.inStock,
                            max: _maxQty,
                            english: english,
                            onMinus: () => _changeQty(-1),
                            onPlus: () => _changeQty(1),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.panel,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        english ? 'Order total' : 'إجمالي الطلب',
                                        style: TextStyle(
                                          color: AppColors.goldSoft,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        english
                                            ? '$_qty × ${_money(product.price)}'
                                            : '$_qty × ${_money(product.price)}',
                                        style: TextStyle(
                                          color: AppColors.goldSoft,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  key: const Key('product-line-total'),
                                  _money(_lineTotal),
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            english ? 'About the product' : 'عن المنتج',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.descriptionFor(english).isEmpty
                                ? (english
                                      ? 'No description yet.'
                                      : 'لا يوجد وصف لهذا المنتج بعد.')
                                : product.descriptionFor(english),
                            style: TextStyle(
                              color: AppColors.goldSoft,
                              height: 1.7,
                              fontSize: 14.5,
                            ),
                          ),
                          if (product.onSale && saved != null) ...[
                            const SizedBox(height: 22),
                            Text(
                              english ? 'Offer details' : 'تفاصيل العرض',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              english
                                  ? 'Was ${_money(product.compareAtPrice!)}, now ${_money(product.price)}'
                                      '${discount != null ? ' ($discount% off).' : '.'}'
                                  : 'كان ${_money(product.compareAtPrice!)} وأصبح ${_money(product.price)}'
                                      '${discount != null ? ' بخصم $discount٪.' : '.'}',
                              style: TextStyle(
                                color: AppColors.goldSoft,
                                height: 1.6,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  border: Border(
                    top: BorderSide(color: AppColors.line),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            english ? 'Total' : 'الإجمالي',
                            style: TextStyle(
                              color: AppColors.goldSoft,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _money(_lineTotal),
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        key: const Key('product-order'),
                        onPressed: product.inStock && _qty > 0
                            ? () async {
                                await ShopCartStore.instance.load();
                                ShopCartStore.instance.add(
                                  product,
                                  quantity: _qty,
                                );
                                if (!context.mounted) return;
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => Directionality(
                                      textDirection: english
                                          ? TextDirection.ltr
                                          : TextDirection.rtl,
                                      child: ShopCartScreen(
                                        locale: widget.locale,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.ink,
                          disabledBackgroundColor: AppColors.panel,
                          disabledForegroundColor: AppColors.goldSoft,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          !product.inStock
                              ? (english ? 'Unavailable' : 'غير متوفر')
                              : (english
                                    ? 'Add $_qty to cart'
                                    : 'أضف $_qty للسلة'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
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

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.english,
    required this.priceLabel,
    this.compareLabel,
    this.savedLabel,
  });

  final bool english;
  final String priceLabel;
  final String? compareLabel;
  final String? savedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            english ? 'Price' : 'السعر',
            style: TextStyle(
              color: AppColors.goldSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                key: const Key('product-price'),
                priceLabel,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              if (compareLabel != null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    key: const Key('product-compare-price'),
                    compareLabel!,
                    style: TextStyle(
                      color: AppColors.goldSoft,
                      fontSize: 15,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (savedLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              savedLabel!,
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.qty,
    required this.enabled,
    required this.max,
    required this.english,
    required this.onMinus,
    required this.onPlus,
  });

  final int qty;
  final bool enabled;
  final int max;
  final bool english;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _StepButton(
            key: const Key('product-qty-minus'),
            icon: Icons.remove_rounded,
            onTap: enabled && qty > 1 ? onMinus : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  key: const Key('product-qty'),
                  '$qty',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  enabled
                      ? (english ? 'Max $max' : 'الحد $max')
                      : (english ? 'Unavailable' : 'غير متوفر'),
                  style: TextStyle(
                    color: AppColors.goldSoft,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          _StepButton(
            key: const Key('product-qty-plus'),
            icon: Icons.add_rounded,
            onTap: enabled && qty < max ? onPlus : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return Material(
      color: active ? AppColors.gold : AppColors.warm,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: active ? AppColors.ink : AppColors.goldSoft,
          ),
        ),
      ),
    );
  }
}
