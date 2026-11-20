import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/account_store.dart';
import '../data/seller_products_api.dart';
import '../data/shop_catalog.dart';
import '../theme/settings_tone.dart';
import '../theme/system_bars.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  static Future<String?> Function() pickImage = _pickImage;

  @visibleForTesting
  static void useDefaults() {
    pickImage = _pickImage;
  }

  static Future<String?> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return file?.path;
  }

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  List<SellerProduct> _products = const [];
  List<ShopCategory> _categories = const [];
  var _loading = true;
  String? _error;

  SettingsTone get _tone => SettingsTone.of(AccountStore.instance.darkMode);
  bool get _english => AccountStore.instance.isEnglish;
  String _t(String ar, String en) => _english ? en : ar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SellerProductsApi.list(),
        ShopApi.loadCatalog(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<SellerProduct>;
        _categories = results[1] as List<ShopCategory>;
        _loading = false;
      });
    } on SellerProductException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t('تعذر تحميل المنتجات.', 'Could not load products.');
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([SellerProduct? product]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
          child: _SellerProductEditor(
            product: product,
            categories: _categories,
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(SellerProduct product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tone = _tone;
        return AlertDialog(
          backgroundColor: tone.panel,
          title: Text(
            _t('حذف المنتج؟', 'Delete product?'),
            style: TextStyle(color: tone.text),
          ),
          content: Text(
            product.name,
            style: TextStyle(color: tone.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE56B6B),
                foregroundColor: Colors.white,
              ),
              child: Text(_t('حذف', 'Delete')),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await SellerProductsApi.destroy(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('تم حذف المنتج.', 'Product deleted.'))),
      );
      _load();
    } on SellerProductException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final english = _english;

    return Directionality(
      textDirection: english ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: tone.background,
        appBar: AppBar(
          backgroundColor: tone.background,
          foregroundColor: tone.text,
          elevation: 0,
          title: Text(_t('منتجاتي', 'My products')),
          systemOverlayStyle: SystemBars.overlay(
            lightStatus: !tone.dark,
            lightNavigation: !tone.dark,
            statusColor: tone.background,
            navigationColor: tone.background,
          ),
          actions: [
            IconButton(
              key: const Key('seller-products-add'),
              onPressed: _categories.isEmpty ? null : () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              tooltip: _t('إضافة منتج', 'Add product'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('seller-products-fab'),
          onPressed: _categories.isEmpty ? null : () => _openEditor(),
          backgroundColor: tone.accent,
          foregroundColor: tone.ink,
          icon: const Icon(Icons.add_rounded),
          label: Text(_t('منتج جديد', 'New product')),
        ),
        body: RefreshIndicator(
          color: tone.accent,
          onRefresh: _load,
          child: _loading
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.4,
                      child: Center(
                        child: CircularProgressIndicator(color: tone.accent),
                      ),
                    ),
                  ],
                )
              : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(_error!, style: TextStyle(color: tone.muted)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _load,
                      child: Text(
                        _t('إعادة المحاولة', 'Retry'),
                        style: TextStyle(color: tone.accent),
                      ),
                    ),
                  ],
                )
              : _products.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 48),
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 48,
                      color: tone.accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t(
                        'لا توجد منتجات بعد. أضف أول منتج للمتجر.',
                        'No products yet. Add your first shop product.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tone.muted, height: 1.5),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Material(
                      color: tone.panel,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        key: Key('seller-product-${product.id}'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openEditor(product),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: product.imageUrl != null
                                      ? Image.network(
                                          product.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => ColoredBox(
                                            color: tone.background,
                                            child: Icon(
                                              Icons.shopping_bag_outlined,
                                              color: tone.accent,
                                            ),
                                          ),
                                        )
                                      : ColoredBox(
                                          color: tone.background,
                                          child: Icon(
                                            Icons.shopping_bag_outlined,
                                            color: tone.accent,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tone.text,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      english
                                          ? 'EGP ${product.price.round()} · stock ${product.stock}'
                                          : '${product.price.round()} ج.م · مخزون ${product.stock}',
                                      style: TextStyle(
                                        color: tone.muted,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product.isActive
                                          ? _t('معروض', 'Listed')
                                          : _t('مخفي', 'Hidden'),
                                      style: TextStyle(
                                        color: product.isActive
                                            ? tone.accent
                                            : tone.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: Key('seller-product-delete-${product.id}'),
                                onPressed: () => _delete(product),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: tone.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _SellerProductEditor extends StatefulWidget {
  const _SellerProductEditor({
    required this.categories,
    this.product,
  });

  final SellerProduct? product;
  final List<ShopCategory> categories;

  @override
  State<_SellerProductEditor> createState() => _SellerProductEditorState();
}

class _SellerProductEditorState extends State<_SellerProductEditor> {
  late final TextEditingController _name;
  late final TextEditingController _nameEn;
  late final TextEditingController _description;
  late final TextEditingController _descriptionEn;
  late final TextEditingController _price;
  late final TextEditingController _compare;
  late final TextEditingController _stock;
  late int? _categoryId;
  late bool _isActive;
  String? _imagePath;
  String? _existingImageUrl;
  var _busy = false;
  String? _error;

  SettingsTone get _tone => SettingsTone.of(AccountStore.instance.darkMode);
  bool get _english => AccountStore.instance.isEnglish;
  String _t(String ar, String en) => _english ? en : ar;
  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _nameEn = TextEditingController(text: product?.nameEn ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _descriptionEn = TextEditingController(text: product?.descriptionEn ?? '');
    _price = TextEditingController(
      text: product == null ? '' : product.price.toStringAsFixed(0),
    );
    _compare = TextEditingController(
      text: product?.compareAtPrice == null
          ? ''
          : product!.compareAtPrice!.toStringAsFixed(0),
    );
    _stock = TextEditingController(
      text: product == null ? '1' : '${product.stock}',
    );
    _categoryId = product?.categoryId ??
        (widget.categories.isEmpty ? null : widget.categories.first.id);
    _isActive = product?.isActive ?? true;
    _existingImageUrl = product?.imageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _nameEn.dispose();
    _description.dispose();
    _descriptionEn.dispose();
    _price.dispose();
    _compare.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final path = await SellerProductsScreen.pickImage();
      if (path == null || !mounted) return;
      setState(() {
        _imagePath = path;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('تعذر فتح الصور.', 'Could not open photos.'))),
      );
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    final stock = int.tryParse(_stock.text.trim());
    final compareText = _compare.text.trim();
    final compare = compareText.isEmpty
        ? null
        : double.tryParse(compareText.replaceAll(',', '.'));
    final categoryId = _categoryId;

    if (name.isEmpty ||
        price == null ||
        price < 0 ||
        stock == null ||
        stock < 0 ||
        categoryId == null) {
      setState(
        () => _error = _t(
          'أكمل الاسم والسعر والمخزون والقسم.',
          'Complete name, price, stock, and category.',
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_editing) {
        await SellerProductsApi.update(
          id: widget.product!.id,
          name: name,
          nameEn: _nameEn.text.trim(),
          description: _description.text.trim(),
          descriptionEn: _descriptionEn.text.trim(),
          price: price,
          compareAtPrice: compare,
          stock: stock,
          shopCategoryId: categoryId,
          isActive: _isActive,
          imagePath: _imagePath,
        );
      } else {
        await SellerProductsApi.create(
          name: name,
          nameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          descriptionEn: _descriptionEn.text.trim().isEmpty
              ? null
              : _descriptionEn.text.trim(),
          price: price,
          compareAtPrice: compare,
          stock: stock,
          shopCategoryId: categoryId,
          isActive: _isActive,
          imagePath: _imagePath,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on SellerProductException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _t('تعذر حفظ المنتج.', 'Could not save the product.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _field(SettingsTone tone, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: tone.muted),
      filled: true,
      fillColor: tone.panel,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tone.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tone.accent, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final english = _english;
    final localImage = _imagePath == null ? null : File(_imagePath!);

    return Scaffold(
      backgroundColor: tone.background,
      appBar: AppBar(
        backgroundColor: tone.background,
        foregroundColor: tone.text,
        elevation: 0,
        title: Text(
          _editing
              ? _t('تعديل المنتج', 'Edit product')
              : _t('إضافة منتج', 'Add product'),
        ),
        systemOverlayStyle: SystemBars.overlay(
          lightStatus: !tone.dark,
          lightNavigation: !tone.dark,
          statusColor: tone.background,
          navigationColor: tone.background,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Material(
            color: tone.panel,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('seller-product-image'),
              onTap: _pickImage,
              child: SizedBox(
                height: 180,
                child: localImage != null && localImage.existsSync()
                    ? Image.file(localImage, fit: BoxFit.cover)
                    : _existingImageUrl != null
                    ? Image.network(
                        _existingImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _imagePlaceholder(tone),
                      )
                    : _imagePlaceholder(tone),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('seller-product-name'),
            controller: _name,
            style: TextStyle(color: tone.text),
            decoration: _field(tone, _t('اسم المنتج', 'Product name')),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('seller-product-name-en'),
            controller: _nameEn,
            style: TextStyle(color: tone.text),
            decoration: _field(
              tone,
              _t('الاسم بالإنجليزية (اختياري)', 'English name (optional)'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('seller-product-description'),
            controller: _description,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(color: tone.text),
            decoration: _field(tone, _t('الوصف', 'Description')),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('seller-product-description-en'),
            controller: _descriptionEn,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(color: tone.text),
            decoration: _field(
              tone,
              _t('الوصف بالإنجليزية (اختياري)', 'English description (optional)'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('seller-product-price'),
                  controller: _price,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: tone.text),
                  decoration: _field(tone, _t('السعر', 'Price')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('seller-product-compare'),
                  controller: _compare,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: tone.text),
                  decoration: _field(
                    tone,
                    _t('قبل الخصم', 'Compare at'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('seller-product-stock'),
            controller: _stock,
            keyboardType: TextInputType.number,
            style: TextStyle(color: tone.text),
            decoration: _field(tone, _t('المخزون', 'Stock')),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const Key('seller-product-category'),
            value: _categoryId,
            dropdownColor: tone.panel,
            style: TextStyle(color: tone.text),
            decoration: _field(tone, _t('القسم', 'Category')),
            items: [
              for (final category in widget.categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.nameFor(english)),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('seller-product-active'),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            activeThumbColor: tone.ink,
            activeTrackColor: tone.accent,
            title: Text(
              _t('عرض المنتج في المتجر', 'Show product in shop'),
              style: TextStyle(color: tone.text, fontWeight: FontWeight.w700),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const Key('seller-product-error'),
              style: const TextStyle(color: Color(0xFFE56B6B), height: 1.4),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('seller-product-save'),
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: tone.accent,
              foregroundColor: tone.ink,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _busy
                  ? _t('جارٍ الحفظ…', 'Saving…')
                  : _t('حفظ المنتج', 'Save product'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(SettingsTone tone) {
    return ColoredBox(
      color: tone.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined, color: tone.accent, size: 34),
            const SizedBox(height: 8),
            Text(
              _t('إضافة صورة المنتج', 'Add product photo'),
              style: TextStyle(
                color: tone.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
