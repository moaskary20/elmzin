import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/account_store.dart';
import '../data/auth_api.dart';
import '../data/shop_cart_store.dart';
import '../theme/app_colors.dart';
import '../theme/system_bars.dart';
import 'map_picker_screen.dart';

class ShopCartScreen extends StatefulWidget {
  const ShopCartScreen({super.key, required this.locale});

  final Locale locale;

  @override
  State<ShopCartScreen> createState() => _ShopCartScreenState();
}

class _ShopCartScreenState extends State<ShopCartScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _cardNumber = TextEditingController();
  final _cardHolder = TextEditingController();
  final _cardExpiry = TextEditingController();
  final _cardCvv = TextEditingController();

  MapAddress? _address;
  var _step = 0;
  var _pay = 'cash';
  var _sending = false;
  String? _error;
  ShopOrderResult? _done;

  bool get _english => widget.locale.languageCode == 'en';

  String _t(String ar, String en) => _english ? en : ar;

  String _money(double value) {
    final n = value == value.roundToDouble()
        ? '${value.round()}'
        : value.toStringAsFixed(2);
    return _english ? 'EGP $n' : '$n ج.م';
  }

  @override
  void initState() {
    super.initState();
    final account = AccountStore.instance;
    if (account.loggedIn) {
      _name.text = account.name;
      _phone.text = account.phone;
    }
    ShopCartStore.instance.load();
    ShopCartStore.instance.addListener(_onCart);
  }

  void _onCart() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ShopCartStore.instance.removeListener(_onCart);
    _name.dispose();
    _phone.dispose();
    _cardNumber.dispose();
    _cardHolder.dispose();
    _cardExpiry.dispose();
    _cardCvv.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final start = _address;
    final picked = await Navigator.of(context).push<MapAddress>(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
          child: MapPickerScreen(
            initial: start == null
                ? null
                : LatLng(start.latitude, start.longitude),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _address = picked;
      _error = null;
    });
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
  }

  void _toDetails() {
    if (ShopCartStore.instance.isEmpty) return;
    _goTo(1);
  }

  void _toPayment() {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(
        () => _error = _t(
          'اكتب الاسم ورقم الهاتف لإتمام الطلب.',
          'Enter your name and phone to continue.',
        ),
      );
      return;
    }
    if (_address == null || _address!.address.trim().isEmpty) {
      setState(
        () => _error = _t(
          'اختر عنوان التوصيل من الخريطة.',
          'Pick the delivery address from the map.',
        ),
      );
      return;
    }
    _goTo(2);
  }

  String? _cardProblem() {
    final digits = _cardNumber.text.replaceAll(' ', '');
    if (digits.length < 13 || digits.length > 19 || !_luhn(digits)) {
      return _t('رقم البطاقة غير صحيح.', 'Card number is not valid.');
    }
    if (_cardHolder.text.trim().length < 3) {
      return _t(
        'اكتب الاسم كما هو على البطاقة.',
        'Enter the name on the card.',
      );
    }
    final parts = _cardExpiry.text.split('/');
    final month = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final year = parts.length == 2 ? int.tryParse(parts[1]) : null;
    final now = DateTime.now();
    if (month == null ||
        year == null ||
        parts[1].length != 2 ||
        month < 1 ||
        month > 12 ||
        DateTime(2000 + year, month + 1).isBefore(
          DateTime(now.year, now.month, 1).add(const Duration(days: 1)),
        )) {
      return _t('تاريخ انتهاء البطاقة غير صحيح.', 'Expiry date is not valid.');
    }
    if (!RegExp(r'^\d{3,4}$').hasMatch(_cardCvv.text)) {
      return _t('رمز CVV غير صحيح.', 'CVV is not valid.');
    }
    return null;
  }

  bool _luhn(String digits) {
    var sum = 0;
    var alt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = int.parse(digits[i]);
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  Future<void> _checkout() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(
        () => _error = _t(
          'اكتب الاسم ورقم الهاتف لإتمام الطلب.',
          'Enter your name and phone to continue.',
        ),
      );
      return;
    }
    if (_pay == 'card') {
      final problem = _cardProblem();
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final digits = _cardNumber.text.replaceAll(' ', '');
      final result = await ShopCartStore.instance.checkout(
        name: name,
        phone: phone,
        address: _address?.address.trim(),
        paymentMethod: _pay,
        cardLast4: _pay == 'card' ? digits.substring(digits.length - 4) : null,
      );
      if (!mounted) return;
      setState(() {
        _done = result;
        _sending = false;
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ShopCartStore.instance;
    final done = _done;

    final direction = _english ? TextDirection.ltr : TextDirection.rtl;

    return Directionality(
      textDirection: direction,
      child: SystemBars(
        lightStatus: !AppColors.dark,
        lightNavigation: !AppColors.dark,
        statusColor: AppColors.black,
        navigationColor: AppColors.black,
        child: Scaffold(
          key: const Key('shop-cart-screen'),
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.gold,
            elevation: 0,
            centerTitle: false,
            leading: IconButton(
              key: const Key('shop-cart-back'),
              onPressed: () {
                if (_done != null) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  return;
                }
                if (_step > 0) {
                  _goTo(_step - 1);
                  return;
                }
                Navigator.of(context).maybePop();
              },
              icon: Icon(
                _english
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: _english ? 24 : 18,
              ),
            ),
            title: Text(
              done != null
                  ? _t('تم الطلب', 'Order placed')
                  : _t('سلة التسوق', 'Shop cart'),
              textAlign: TextAlign.start,
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: done != null
              ? _success(done)
              : Column(
                  children: [
                    if (!cart.isEmpty) _stepper(_step),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: switch (_step) {
                          1 => _detailsStep(),
                          2 => _paymentStep(cart),
                          _ => _cartStep(cart),
                        },
                      ),
                    ),
                    if (!cart.isEmpty) _bottomBar(cart),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _stepper(int step) {
    final labels = [
      _t('السلة', 'Cart'),
      _t('التفاصيل', 'Details'),
      _t('الدفع', 'Payment'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i <= step ? AppColors.gold : AppColors.line,
                ),
              ),
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= step ? AppColors.gold : AppColors.panel,
                    border: Border.all(
                      color: i <= step ? AppColors.gold : AppColors.line,
                    ),
                  ),
                  child: i < step
                      ? Icon(Icons.check_rounded, color: AppColors.ink, size: 18)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: i == step ? AppColors.ink : AppColors.goldSoft,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    color: i <= step ? AppColors.gold : AppColors.goldSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cartStep(ShopCartStore cart) {
    if (cart.isEmpty) {
      return Center(
        key: const ValueKey('shop-cart-empty'),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, color: AppColors.gold, size: 56),
              const SizedBox(height: 14),
              Text(
                _t('السلة فارغة', 'Cart is empty'),
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'أضف منتجات من شاشة التسوق ثم ارجع هنا للدفع.',
                  'Add products from the shop, then return here to pay.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.goldSoft),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('shop-cart-list'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      itemCount: cart.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return Container(
          key: Key('shop-cart-item-${item.productId}'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: AppColors.black,
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.gold,
                            ),
                          ),
                        )
                      : ColoredBox(
                          color: AppColors.black,
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.gold,
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
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _money(item.price),
                      style: TextStyle(color: AppColors.goldSoft, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _qtyBtn(
                          Icons.remove_rounded,
                          () => ShopCartStore.instance.setQuantity(
                            item.productId,
                            item.quantity - 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${item.quantity}',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _qtyBtn(
                          Icons.add_rounded,
                          item.quantity < item.stock
                              ? () => ShopCartStore.instance.setQuantity(
                                  item.productId,
                                  item.quantity + 1,
                                )
                              : null,
                        ),
                        const Spacer(),
                        Text(
                          _money(item.lineTotal),
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    ShopCartStore.instance.remove(item.productId),
                icon: Icon(Icons.delete_outline, color: AppColors.goldSoft),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? AppColors.warm : AppColors.gold,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? AppColors.goldSoft : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _detailsStep() {
    return ListView(
      key: const ValueKey('shop-cart-details'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      children: [
        Text(
          _t('بيانات التوصيل', 'Delivery details'),
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 14),
        _field(
          controller: _name,
          keyName: 'shop-cart-name',
          label: _t('الاسم', 'Name'),
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _phone,
          keyName: 'shop-cart-phone',
          label: _t('رقم الهاتف', 'Phone'),
          icon: Icons.phone_outlined,
          keyboard: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const Key('shop-cart-address'),
            onTap: _pickAddress,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _address == null ? AppColors.line : AppColors.gold,
                  width: _address == null ? 1 : 1.4,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, color: AppColors.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('عنوان التوصيل', 'Delivery address'),
                          style: TextStyle(
                            color: AppColors.goldSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _address?.address.trim().isNotEmpty == true
                              ? _address!.address
                              : _t(
                                  'اختر العنوان من الخريطة',
                                  'Pick address from the map',
                                ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded, color: AppColors.goldSoft),
                ],
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Color(0xFFE58B8B))),
        ],
      ],
    );
  }

  Widget _paymentStep(ShopCartStore cart) {
    final card = _pay == 'card';
    return ListView(
      key: const ValueKey('shop-cart-payment'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      children: [
        _payOption(
          value: 'cash',
          icon: Icons.payments_outlined,
          title: _t('الدفع عند الاستلام', 'Cash on delivery'),
          note: _t(
            'ادفع نقداً عند استلام المنتجات.',
            'Pay in cash when you receive the products.',
          ),
        ),
        const SizedBox(height: 12),
        _payOption(
          value: 'card',
          icon: Icons.credit_card_rounded,
          title: _t('فيزا / بطاقة بنكية', 'Visa / bank card'),
          note: _t(
            'ادفع الآن لإتمام الطلب مباشرة.',
            'Pay now to complete the order.',
          ),
        ),
        if (card) ...[
          const SizedBox(height: 14),
          _field(
            controller: _cardHolder,
            keyName: 'shop-cart-card-holder',
            label: _t('الاسم على البطاقة', 'Name on card'),
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _cardNumber,
            keyName: 'shop-cart-card-number',
            label: _t('رقم البطاقة', 'Card number'),
            icon: Icons.credit_card,
            keyboard: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _cardExpiry,
                  keyName: 'shop-cart-card-expiry',
                  label: _t('الانتهاء', 'Expiry'),
                  icon: Icons.date_range_outlined,
                  keyboard: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ExpiryFormatter(),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  controller: _cardCvv,
                  keyName: 'shop-cart-card-cvv',
                  label: 'CVV',
                  icon: Icons.lock_outline,
                  keyboard: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Text(
                _t('الإجمالي', 'Total'),
                style: TextStyle(color: AppColors.goldSoft),
              ),
              const Spacer(),
              Text(
                _money(cart.total),
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Color(0xFFE58B8B))),
        ],
      ],
    );
  }

  Widget _payOption({
    required String value,
    required IconData icon,
    required String title,
    required String note,
  }) {
    final selected = _pay == value;
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('shop-cart-pay-$value'),
        onTap: () => setState(() {
          _pay = value;
          _error = null;
        }),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: TextStyle(
                        color: AppColors.goldSoft,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: AppColors.gold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String keyName,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
  }) {
    final rtl = !_english;
    final numeric = keyboard == TextInputType.phone ||
        keyboard == TextInputType.number;
    return TextField(
      key: Key(keyName),
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      inputFormatters: formatters,
      textAlign: rtl && !numeric ? TextAlign.right : TextAlign.start,
      textDirection: numeric ? TextDirection.ltr : (rtl ? TextDirection.rtl : TextDirection.ltr),
      style: TextStyle(color: AppColors.gold),
      cursorColor: AppColors.gold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.goldSoft),
        prefixIcon: rtl ? null : Icon(icon, color: AppColors.gold),
        suffixIcon: rtl ? Icon(icon, color: AppColors.gold) : null,
        alignLabelWithHint: true,
        filled: true,
        fillColor: AppColors.panel,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.gold, width: 1.4),
        ),
      ),
    );
  }

  Widget _bottomBar(ShopCartStore cart) {
    final label = switch (_step) {
      0 => _t('متابعة للتفاصيل', 'Continue to details'),
      1 => _t('متابعة للدفع', 'Continue to payment'),
      _ => _sending
          ? _t('جاري الطلب...', 'Placing order...')
          : _t('ادفع ${_money(cart.total)}', 'Pay ${_money(cart.total)}'),
    };
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        decoration: BoxDecoration(
          color: AppColors.black,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t('الإجمالي', 'Total'),
                    style: TextStyle(color: AppColors.goldSoft, fontSize: 12),
                  ),
                  Text(
                    _money(cart.total),
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              key: Key(
                _step == 2 ? 'shop-cart-checkout' : 'shop-cart-next',
              ),
              onPressed: _sending
                  ? null
                  : switch (_step) {
                      0 => _toDetails,
                      1 => _toPayment,
                      _ => _checkout,
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _success(ShopOrderResult done) {
    return Center(
      key: const Key('shop-cart-success'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 72),
            const SizedBox(height: 16),
            Text(
              _t('تم استلام طلبك', 'Your order was placed'),
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'رقم الطلب #${done.id} · ${_money(done.total)}',
                'Order #${done.id} · ${_money(done.total)}',
              ),
              style: TextStyle(color: AppColors.goldSoft),
            ),
            const SizedBox(height: 8),
            Text(
              done.paymentMethod == 'card'
                  ? _t('تم الدفع بالبطاقة', 'Paid by card')
                  : _t('الدفع عند الاستلام', 'Cash on delivery'),
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('shop-cart-done'),
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _t('العودة للتسوق', 'Back to shop'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 19; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
