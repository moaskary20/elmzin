import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account_store.dart';
import '../data/cart_store.dart';
import '../theme/app_colors.dart';
import '../widgets/salon_photo.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    this.palette = SalonPalette.gold,
    this.onBack,
    this.onBrowse,
    this.onOpenBookings,
    this.highlightKey,
  });

  final SalonPalette palette;
  final VoidCallback? onBack;
  final VoidCallback? onBrowse;
  final VoidCallback? onOpenBookings;
  final String? highlightKey;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _cardNumber = TextEditingController();
  final _cardHolder = TextEditingController();
  final _cardExpiry = TextEditingController();
  final _cardCvv = TextEditingController();
  late final AnimationController _enter;
  var _step = 0;
  var _pay = 'cash';
  var _paidWith = 'cash';
  var _sending = false;
  String? _error;
  Map<String, String> _failed = const {};
  List<CartItem>? _done;

  SalonPalette get _p => widget.palette;

  bool get _english => Directionality.of(context) == TextDirection.ltr;

  String _t(String ar, String en) => _english ? en : ar;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    final account = AccountStore.instance;
    if (account.loggedIn) {
      _name.text = account.name;
      _phone.text = account.phone;
    }
    CartStore.instance.load();
  }

  @override
  void dispose() {
    _enter.dispose();
    _name.dispose();
    _phone.dispose();
    _cardNumber.dispose();
    _cardHolder.dispose();
    _cardExpiry.dispose();
    _cardCvv.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
  }

  void _toDetails() => _goTo(1);

  void _toPayment() {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(
        () => _error = _t(
          'اكتب الاسم ورقم الهاتف لإتمام الحجز.',
          'Enter your name and phone to book.',
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

  void _back() {
    if (_step > 0 && _done == null) {
      _goTo(_step - 1);
      return;
    }
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _checkout() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(
        () => _error = _t(
          'اكتب الاسم ورقم الهاتف لإتمام الحجز.',
          'Enter your name and phone to book.',
        ),
      );
      return;
    }
    final card = _pay == 'card';
    if (card) {
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
    final digits = _cardNumber.text.replaceAll(' ', '');
    final result = await CartStore.instance.checkout(
      name: name,
      phone: phone,
      paymentMethod: _pay,
      cardLast4: card ? digits.substring(digits.length - 4) : null,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _failed = result.failed;
      if (result.failed.isNotEmpty) _step = 0;
      if (result.failed.isEmpty) {
        _paidWith = _pay;
        _done = result.booked;
      } else if (result.booked.isNotEmpty) {
        _error = _t(
          'تم حجز ${result.booked.length} وتعذر حجز ${result.failed.length}. راجع المواعيد المميزة.',
          '${result.booked.length} booked, ${result.failed.length} failed.',
        );
      } else {
        _error = _t(
          'تعذر إتمام الحجز. راجع المواعيد المميزة بالأحمر.',
          'Could not book. Check the highlighted items.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('cart-screen'),
      color: _p.background,
      child: ListenableBuilder(
        listenable: CartStore.instance,
        builder: (context, _) {
          final done = _done;
          if (done != null) {
            return Stack(
              children: [
                Positioned.fill(child: _success(done)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ConfettiBurst(
                      key: const Key('cart-confetti'),
                      colors: [
                        _p.accent,
                        Color.lerp(_p.accent, Colors.white, 0.55)!,
                        Color.lerp(_p.accent, Colors.black, 0.35)!,
                        Colors.white,
                        _p.deep,
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          final cart = CartStore.instance;
          final step = cart.isEmpty ? 0 : _step;
          return Column(
            children: [
              _header(cart.count, step),
              if (!cart.isEmpty) _stepper(step),
              Expanded(
                child: cart.isEmpty
                    ? _empty()
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: switch (step) {
                          1 => _detailsStep(cart),
                          2 => _paymentStep(cart),
                          _ => _cartStep(cart),
                        },
                      ),
              ),
              if (!cart.isEmpty) _checkoutBar(cart, step),
            ],
          );
        },
      ),
    );
  }

  Widget _cartStep(CartStore cart) {
    return ListView(
      key: const ValueKey('step-cart'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      children: [
        for (final (index, entry) in cart.bySalon.entries.indexed)
          _reveal(index, _salonGroup(entry.value)),
        const SizedBox(height: 6),
        _reveal(cart.bySalon.length, _summary(cart)),
      ],
    );
  }

  Widget _detailsStep(CartStore cart) {
    return ListView(
      key: const ValueKey('step-details'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      children: [
        for (final item in cart.items) _detailCard(item),
        _customerCard(),
        const SizedBox(height: 14),
        _summary(cart),
      ],
    );
  }

  Widget _paymentStep(CartStore cart) {
    final card = _pay == 'card';
    return ListView(
      key: const ValueKey('step-payment'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      children: [
        _payOption(
          key: const Key('cart-pay-cash'),
          value: 'cash',
          icon: Icons.payments_outlined,
          title: _t('الدفع عند الوصول', 'Pay on arrival'),
          note: _t(
            'ادفع نقداً أو بالبطاقة في الصالون بعد الخدمة.',
            'Pay cash or card at the salon after your visit.',
          ),
        ),
        const SizedBox(height: 12),
        _payOption(
          key: const Key('cart-pay-card'),
          value: 'card',
          icon: Icons.credit_card_rounded,
          title: _t('فيزا / بطاقة بنكية', 'Visa / bank card'),
          note: _t(
            'ادفع الآن واضمن موعدك مباشرة.',
            'Pay now and secure your visit.',
          ),
          trailing: _visaMark(),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: card ? _cardForm() : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 16),
        _amountCard(cart),
      ],
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i <= step ? _p.accent : _p.line,
                ),
              ),
            GestureDetector(
              key: Key('cart-step-$i'),
              onTap: i < step ? () => _goTo(i) : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= step ? _p.accent : _p.panel,
                      border: Border.all(
                        color: i <= step ? _p.accent : _p.line,
                        width: 1.4,
                      ),
                      boxShadow: i == step
                          ? [
                              BoxShadow(
                                color: _p.accent.withValues(alpha: 0.35),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: i < step
                        ? Icon(Icons.check_rounded, color: _p.onBar, size: 18)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == step ? _p.onBar : _p.soft,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: i <= step ? _p.accent : _p.soft,
                      fontSize: 11,
                      fontWeight: i == step ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailCard(CartItem item) {
    final at = item.at;
    final error = _failed[item.key];
    final end = at?.add(Duration(minutes: item.durationMinutes));
    return Container(
      key: Key('cart-detail-${item.key}'),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _p.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: error != null ? const Color(0xFFE58B8B) : _p.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SalonPhoto(
                  url: item.salonImageUrl,
                  asset: salonPhotoAsset(item.salonName),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.black.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 14,
                  end: 14,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.salonName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _p.accent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _money(item.price),
                          style: TextStyle(
                            color: _p.onBar,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                _infoRow(
                  Icons.event_rounded,
                  _t('التاريخ', 'Date'),
                  at == null ? item.date : _fullDate(at),
                ),
                _infoRow(
                  Icons.schedule_rounded,
                  _t('الوقت', 'Time'),
                  end == null || item.durationMinutes == 0
                      ? item.time
                      : _t(
                          'من ${item.time} إلى ${_clock(end)}',
                          '${item.time} – ${_clock(end)}',
                        ),
                ),
                if (item.durationMinutes > 0)
                  _infoRow(
                    Icons.timelapse_rounded,
                    _t('المدة', 'Duration'),
                    _t(
                      '${item.durationMinutes} دقيقة',
                      '${item.durationMinutes} min',
                    ),
                  ),
                _infoRow(
                  Icons.content_cut_rounded,
                  _t('الأخصائي', 'Stylist'),
                  item.specialistName.isEmpty
                      ? _t('أي أخصائي متاح', 'Any stylist')
                      : item.specialistName,
                ),
                _infoRow(
                  Icons.hourglass_top_rounded,
                  _t('الحالة', 'Status'),
                  _t('بانتظار تأكيد الصالون', 'Awaiting salon confirmation'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      error,
                      style: const TextStyle(
                        color: Color(0xFFE58B8B),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _p.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _p.accent, size: 16),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: _p.soft, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: _p.accent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _payOption({
    required Key key,
    required String value,
    required IconData icon,
    required String title,
    required String note,
    Widget? trailing,
  }) {
    final selected = _pay == value;
    return GestureDetector(
      key: key,
      onTap: () => setState(() {
        _pay = value;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _p.accent.withValues(alpha: 0.12) : _p.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _p.accent : _p.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? _p.accent : _p.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? _p.onBar : _p.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _p.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(color: _p.soft, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _p.accent : Colors.transparent,
                border: Border.all(
                  color: selected ? _p.accent : _p.soft,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, color: _p.onBar, size: 15)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _visaMark() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F71),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'VISA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _cardForm() {
    return Padding(
      key: const Key('cart-card-form'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([
              _cardNumber,
              _cardHolder,
              _cardExpiry,
            ]),
            builder: (context, _) => _cardPreview(),
          ),
          const SizedBox(height: 14),
          _field(
            const Key('cart-card-number'),
            _cardNumber,
            _t('رقم البطاقة', 'Card number'),
            Icons.credit_card_rounded,
            TextInputType.number,
            formatters: [_DigitsFormatter(19), _GroupFormatter()],
            ltr: true,
          ),
          const SizedBox(height: 10),
          _field(
            const Key('cart-card-holder'),
            _cardHolder,
            _t('الاسم على البطاقة', 'Name on card'),
            Icons.person_outline,
            TextInputType.name,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _field(
                  const Key('cart-card-expiry'),
                  _cardExpiry,
                  _t('الانتهاء MM/YY', 'Expiry MM/YY'),
                  Icons.date_range_outlined,
                  TextInputType.number,
                  formatters: [_DigitsFormatter(4), _ExpiryFormatter()],
                  ltr: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  const Key('cart-card-cvv'),
                  _cardCvv,
                  'CVV',
                  Icons.lock_outline_rounded,
                  TextInputType.number,
                  formatters: [_DigitsFormatter(4)],
                  ltr: true,
                  obscure: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: _p.soft, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _t(
                    'لا نحفظ بيانات بطاقتك، ويصل للصالون آخر 4 أرقام فقط.',
                    'We never store your card. The salon only sees the last 4 digits.',
                  ),
                  style: TextStyle(color: _p.soft, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardPreview() {
    final digits = _cardNumber.text.replaceAll(' ', '');
    final shown = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) shown.write('  ');
      shown.write(i < digits.length ? digits[i] : '•');
    }
    final holder = _cardHolder.text.trim();
    final expiry = _cardExpiry.text;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AspectRatio(
        aspectRatio: 1.7,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(_p.accent, Colors.black, 0.15)!,
                Color.lerp(_p.accent, Colors.black, 0.65)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _p.accent.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF3E2A9), Color(0xFFC9A44C)],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'VISA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                child: Text(
                  shown.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      holder.isEmpty ? 'CARD HOLDER' : holder.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    expiry.isEmpty ? 'MM/YY' : expiry,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

  Widget _amountCard(CartStore cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _p.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _p.line),
      ),
      child: Column(
        children: [
          for (final item in cart.items)
            _row('${item.serviceName} • ${item.salonName}', _money(item.price)),
          Divider(color: _p.line, height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _pay == 'card'
                      ? _t('المبلغ المدفوع الآن', 'Charged now')
                      : _t('تدفع في الصالون', 'Pay at the salon'),
                  style: TextStyle(
                    color: _p.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _money(cart.total),
                key: const Key('cart-pay-total'),
                style: TextStyle(
                  color: _p.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reveal(int index, Widget child) {
    final start = (index * 0.12).clamp(0.0, 0.7);
    final animation = CurvedAnimation(
      parent: _enter,
      curve: Interval(
        start,
        (start + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _header(int count, int step) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 18, 10),
      child: Row(
        children: [
          IconButton(
            key: const Key('cart-back'),
            onPressed: _back,
            icon: Icon(
              _english ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
              color: _p.accent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (step) {
                    1 => _t('تفاصيل الحجز', 'Booking details'),
                    2 => _t('الدفع', 'Payment'),
                    _ => _t('سلة الحجوزات', 'Booking cart'),
                  },
                  style: TextStyle(
                    color: _p.accent,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  step == 1
                      ? _t('راجع كل بيانات موعدك', 'Review every detail')
                      : step == 2
                      ? _t('اختر طريقة الدفع', 'Choose how to pay')
                      : count == 0
                      ? _t('لا توجد مواعيد بعد', 'No visits yet')
                      : _t(
                          '$count ${count == 1
                              ? 'موعد'
                              : count == 2
                              ? 'موعدان'
                              : 'مواعيد'} جاهزة للتأكيد',
                          '$count ready to confirm',
                        ),
                  key: const Key('cart-count'),
                  style: TextStyle(color: _p.soft, fontSize: 13),
                ),
              ],
            ),
          ),
          if (count > 0 && step == 0)
            TextButton.icon(
              key: const Key('cart-clear'),
              onPressed: () => _confirmClear(),
              icon: Icon(Icons.delete_sweep_outlined, color: _p.soft, size: 20),
              label: Text(
                _t('إفراغ', 'Clear'),
                style: TextStyle(color: _p.soft),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: _p.panel,
        title: Text(
          _t('إفراغ السلة؟', 'Clear the cart?'),
          style: TextStyle(color: _p.accent),
        ),
        content: Text(
          _t('سيتم حذف كل المواعيد من السلة.', 'All visits will be removed.'),
          style: TextStyle(color: _p.soft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(_t('تراجع', 'Keep'), style: TextStyle(color: _p.soft)),
          ),
          TextButton(
            key: const Key('cart-clear-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(
              _t('إفراغ', 'Clear'),
              style: TextStyle(color: _p.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (yes == true) {
      CartStore.instance.clear();
      setState(() => _failed = const {});
    }
  }

  Widget _empty() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          key: const Key('cart-empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_p.accent.withValues(alpha: 0.28), _p.panel],
                  ),
                  border: Border.all(color: _p.line, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: _p.accent.withValues(alpha: 0.18),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: _p.accent,
                  size: 58,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _t('سلتك فارغة', 'Your cart is empty'),
              style: TextStyle(
                color: _p.accent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'اختر صالوناً وخدمة وموعداً ثم اضغط «احجز» لتظهر هنا.',
                'Pick a salon, a service and a time, then tap Book.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: _p.soft, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const Key('cart-browse'),
              onPressed: widget.onBrowse ?? _back,
              style: FilledButton.styleFrom(
                backgroundColor: _p.accent,
                foregroundColor: _p.onBar,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.storefront_outlined),
              label: Text(
                _t('تصفح الصالونات', 'Browse salons'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _salonGroup(List<CartItem> items) {
    final first = items.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _p.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 84,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SalonPhoto(
                  url: first.salonImageUrl,
                  asset: salonPhotoAsset(first.salonName),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.25),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _p.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          color: _p.onBar,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              first.salonName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _t(
                                '${items.length} ${items.length == 1 ? 'خدمة' : 'خدمات'}',
                                '${items.length} service(s)',
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final item in items) _itemTile(item),
        ],
      ),
    );
  }

  Widget _itemTile(CartItem item) {
    final error = _failed[item.key];
    final fresh = item.key == widget.highlightKey;
    final at = item.at;
    return Dismissible(
      key: ValueKey('dismiss-${item.key}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => CartStore.instance.remove(item.key),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 22),
        color: const Color(0x33E58B8B),
        child: const Icon(Icons.delete_outline, color: Color(0xFFE58B8B)),
      ),
      child: GestureDetector(
        onTap: _toDetails,
        child: AnimatedContainer(
          key: Key('cart-item-${item.key}'),
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fresh ? _p.accent.withValues(alpha: 0.10) : _p.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: error != null
                  ? const Color(0xFFE58B8B)
                  : fresh
                  ? _p.accent
                  : _p.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.serviceName,
                                style: TextStyle(
                                  color: _p.accent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (fresh) ...[
                              const SizedBox(width: 6),
                              _tag(_t('أضيف الآن', 'Just added')),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.specialistName.isEmpty
                              ? _t('أي أخصائي متاح', 'Any stylist')
                              : item.specialistName,
                          style: TextStyle(color: _p.soft, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(item.price),
                    style: TextStyle(
                      color: _p.accent,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkResponse(
                    key: Key('cart-remove-${item.key}'),
                    onTap: () => CartStore.instance.remove(item.key),
                    radius: 20,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: _p.soft,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(
                    Icons.calendar_month_outlined,
                    at == null ? item.date : _day(at),
                  ),
                  _chip(Icons.schedule_rounded, item.time),
                  if (item.durationMinutes > 0)
                    _chip(
                      Icons.timelapse_rounded,
                      _t(
                        '${item.durationMinutes} دقيقة',
                        '${item.durationMinutes} min',
                      ),
                    ),
                  Text(
                    _t('التفاصيل ‹', 'Details ›'),
                    style: TextStyle(color: _p.soft, fontSize: 12, height: 2),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  key: Key('cart-error-${item.key}'),
                  style: const TextStyle(
                    color: Color(0xFFE58B8B),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _customerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _p.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, color: _p.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                _t('بيانات الحجز', 'Your details'),
                style: TextStyle(
                  color: _p.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(
            const Key('cart-name'),
            _name,
            _t('الاسم', 'Name'),
            Icons.person_outline,
            TextInputType.name,
          ),
          const SizedBox(height: 10),
          _field(
            const Key('cart-phone'),
            _phone,
            _t('رقم الهاتف', 'Phone'),
            Icons.phone_outlined,
            TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _summary(CartStore cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_p.accent.withValues(alpha: 0.16), _p.panel],
        ),
        border: Border.all(color: _p.accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          _row(_t('عدد الخدمات', 'Services'), '${cart.count}'),
          _row(_t('عدد الصالونات', 'Salons'), '${cart.bySalon.length}'),
          if (cart.minutes > 0)
            _row(
              _t('إجمالي الوقت', 'Total time'),
              _t('${cart.minutes} دقيقة', '${cart.minutes} min'),
            ),
          Divider(color: _p.line, height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _t('الإجمالي', 'Total'),
                  style: TextStyle(
                    color: _p.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _money(cart.total),
                key: const Key('cart-total'),
                style: TextStyle(
                  color: _p.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.info_outline, color: _p.soft, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _t(
                    'تختار طريقة الدفع في الخطوة الأخيرة: عند الوصول أو فيزا.',
                    'Choose to pay on arrival or by Visa at the last step.',
                  ),
                  style: TextStyle(color: _p.soft, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _checkoutBar(CartStore cart, int step) {
    final (key, label, icon, action) = switch (step) {
      1 => (
        const Key('cart-to-payment'),
        _t('متابعة للدفع', 'Continue to payment'),
        Icons.payments_rounded,
        _toPayment,
      ),
      2 => (
        const Key('cart-pay'),
        _pay == 'card'
            ? _t('ادفع ${_money(cart.total)}', 'Pay ${_money(cart.total)}')
            : _t('تأكيد الحجز', 'Confirm booking'),
        _pay == 'card' ? Icons.lock_rounded : Icons.event_available_rounded,
        _checkout,
      ),
      _ => (
        const Key('cart-checkout'),
        _t('متابعة (${cart.count})', 'Continue (${cart.count})'),
        Icons.arrow_circle_left_outlined,
        _toDetails,
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        color: _p.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _p.line)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                key: const Key('cart-error'),
                style: const TextStyle(
                  color: Color(0xFFE58B8B),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('المطلوب', 'To pay'),
                      style: TextStyle(color: _p.soft, fontSize: 12),
                    ),
                    Text(
                      _money(cart.total),
                      style: TextStyle(
                        color: _p.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FilledButton(
                    key: key,
                    onPressed: _sending ? null : action,
                    style: FilledButton.styleFrom(
                      backgroundColor: _p.accent,
                      foregroundColor: _p.onBar,
                      disabledBackgroundColor: _p.deep,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _sending
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: _p.onBar,
                            ),
                          )
                        : FittedBox(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon),
                                const SizedBox(width: 8),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
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

  Widget _success(List<CartItem> booked) {
    final total = booked.fold<double>(0, (sum, item) => sum + item.price);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          key: const Key('cart-success'),
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _p.accent,
                  boxShadow: [
                    BoxShadow(
                      color: _p.accent.withValues(alpha: 0.4),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Icon(Icons.check_rounded, color: _p.onBar, size: 70),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _t('تم إرسال حجزك!', 'Booking sent!'),
              style: TextStyle(
                color: _p.accent,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'أرسلنا ${booked.length} ${booked.length == 1 ? 'موعد' : 'مواعيد'} بإجمالي ${_money(total)}. سيؤكد الصالون موعدك قريباً.',
                '${booked.length} visit(s), total ${_money(total)}. The salon will confirm soon.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: _p.soft, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 12),
            Container(
              key: const Key('cart-paid-with'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _p.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _paidWith == 'card'
                        ? Icons.credit_card_rounded
                        : Icons.payments_outlined,
                    color: _p.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _paidWith == 'card'
                        ? _t('تم الدفع بالفيزا', 'Paid by Visa')
                        : _t('الدفع عند الوصول', 'Pay on arrival'),
                    style: TextStyle(
                      color: _p.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final item in booked)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _p.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _p.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: _p.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.serviceName} • ${item.salonName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _p.accent, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${item.at == null ? item.date : _day(item.at!)} ${item.time}',
                      style: TextStyle(color: _p.soft, fontSize: 12),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (widget.onOpenBookings != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('cart-open-bookings'),
                  onPressed: widget.onOpenBookings,
                  style: FilledButton.styleFrom(
                    backgroundColor: _p.accent,
                    foregroundColor: _p.onBar,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _t('عرض حجوزاتي', 'My bookings'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('cart-continue'),
              onPressed: widget.onBrowse ?? _back,
              child: Text(
                _t('متابعة التصفح', 'Keep browsing'),
                style: TextStyle(color: _p.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    Key key,
    TextEditingController controller,
    String label,
    IconData icon,
    TextInputType type, {
    List<TextInputFormatter>? formatters,
    bool ltr = false,
    bool obscure = false,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: type,
      inputFormatters: formatters,
      obscureText: obscure,
      textDirection: ltr ? TextDirection.ltr : null,
      style: TextStyle(color: _p.accent),
      cursorColor: _p.accent,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _p.soft),
        prefixIcon: Icon(icon, color: _p.soft, size: 20),
        filled: true,
        fillColor: _p.background,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _p.accent),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: _p.soft, fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              color: _p.accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _p.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _p.accent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: _p.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _p.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _p.onBar,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _day(DateTime at) {
    final now = DateTime.now();
    final diff = DateTime(
      at.year,
      at.month,
      at.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return _t('اليوم', 'Today');
    if (diff == 1) return _t('غداً', 'Tomorrow');
    const ar = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${(_english ? en : ar)[at.weekday - 1]} ${at.day}/${at.month}';
  }

  String _fullDate(DateTime at) {
    const arDays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    const arMonths = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const enMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return _english
        ? '${enDays[at.weekday - 1]}, ${at.day} ${enMonths[at.month - 1]} ${at.year}'
        : '${arDays[at.weekday - 1]} ${at.day} ${arMonths[at.month - 1]} ${at.year}';
  }

  String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  String _money(double value) {
    final whole = value == value.roundToDouble();
    final digits = whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    return _english ? 'EGP $digits' : '$digits ج.م';
  }
}

bool _luhn(String digits) {
  var sum = 0;
  var even = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var value = digits.codeUnitAt(i) - 48;
    if (even) {
      value *= 2;
      if (value > 9) value -= 9;
    }
    sum += value;
    even = !even;
  }
  return sum % 10 == 0;
}

class _DigitsFormatter extends TextInputFormatter {
  _DigitsFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    for (final rune in newValue.text.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.writeCharCode(rune);
      } else if (rune >= 0x660 && rune <= 0x669) {
        buffer.writeCharCode(rune - 0x660 + 0x30);
      } else if (rune >= 0x6F0 && rune <= 0x6F9) {
        buffer.writeCharCode(rune - 0x6F0 + 0x30);
      }
    }
    var text = buffer.toString();
    if (text.length > max) text = text.substring(0, max);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _GroupFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
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
    final digits = newValue.text;
    final text = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Plays a one-shot paper confetti explosion from the middle of the screen
/// and two side cannons.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    required this.colors,
    this.duration = const Duration(milliseconds: 3200),
  });

  final List<Color> colors;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final List<_Paper> _papers = _make();

  List<_Paper> _make() {
    final random = math.Random();
    final papers = <_Paper>[];
    void burst(Offset origin, double angle, double spread, int count) {
      for (var i = 0; i < count; i++) {
        final direction = angle + (random.nextDouble() - 0.5) * spread;
        final speed = 0.55 + random.nextDouble() * 0.85;
        papers.add(
          _Paper(
            origin: origin,
            velocity: Offset(math.cos(direction), math.sin(direction)) * speed,
            color: widget.colors[random.nextInt(widget.colors.length)],
            size: 5 + random.nextDouble() * 7,
            spin: (random.nextDouble() - 0.5) * 18,
            flip: 4 + random.nextDouble() * 8,
            sway: random.nextDouble() * math.pi * 2,
            round: random.nextDouble() < 0.22,
            delay: random.nextDouble() * 0.08,
          ),
        );
      }
    }

    burst(const Offset(0.5, 0.3), -math.pi / 2, math.pi * 2, 110);
    burst(const Offset(0, 0.95), -math.pi / 3, math.pi / 4, 45);
    burst(const Offset(1, 0.95), -math.pi * 2 / 3, math.pi / 4, 45);
    return papers;
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ConfettiPainter(_clock, _papers),
        size: Size.infinite,
      ),
    );
  }
}

class _Paper {
  const _Paper({
    required this.origin,
    required this.velocity,
    required this.color,
    required this.size,
    required this.spin,
    required this.flip,
    required this.sway,
    required this.round,
    required this.delay,
  });

  final Offset origin;
  final Offset velocity;
  final Color color;
  final double size;
  final double spin;
  final double flip;
  final double sway;
  final bool round;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.clock, this.papers) : super(repaint: clock);

  final Animation<double> clock;
  final List<_Paper> papers;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = clock.value;
    if (progress == 0 || progress == 1) return;
    final scale = math.max(size.width, size.height);
    final paint = Paint();
    for (final paper in papers) {
      final t = ((progress - paper.delay) / (1 - paper.delay)).clamp(0.0, 1.0);
      if (t == 0) continue;
      final time = t * 3;
      final drag = 1 - math.exp(-time * 1.6);
      final fall = math.max(0.0, time - 0.35);
      final x =
          paper.origin.dx * size.width +
          paper.velocity.dx * drag * scale * 0.42 +
          math.sin(time * 3 + paper.sway) * 12 * fall;
      final y =
          paper.origin.dy * size.height +
          paper.velocity.dy * drag * scale * 0.42 +
          fall * fall * size.height * 0.11;
      final opacity = t < 0.75 ? 1.0 : (1 - t) / 0.25;
      paint.color = paper.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(time * paper.spin);
      if (paper.round) {
        canvas.drawCircle(Offset.zero, paper.size * 0.4, paint);
      } else {
        final squash = math.cos(time * paper.flip).abs() * 0.85 + 0.15;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: paper.size,
            height: paper.size * 0.55 * squash,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.papers != papers;
}
