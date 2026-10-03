import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/customer_booking.dart';
import '../theme/app_colors.dart';
import '../widgets/salon_photo.dart';
import 'login_screen.dart';
import 'salon_bookings_screen.dart';

enum _BookingLens { all, upcoming, done, cancelled }

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    required this.onOpenSalon,
    this.reloadToken = 0,
  });

  final void Function(int id, String categorySlug) onOpenSalon;
  final int reloadToken;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<CustomerBooking> _items = const [];
  var _lens = _BookingLens.all;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AccountStore.instance.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(BookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) _load();
  }

  @override
  void dispose() {
    AccountStore.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final account = AccountStore.instance;
    if (!account.loggedIn ||
        (account.token ?? '').isEmpty ||
        account.role == 'salon') {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
        _error = null;
      });
      return;
    }

    try {
      final items = await BookingsApi.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is BookingsException
            ? error.message
            : 'تعذر تحميل الحجوزات.';
      });
    }
  }

  List<CustomerBooking> get _visible {
    final rows = [..._items];
    rows.sort((a, b) {
      final left = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (a.upcoming && b.upcoming) return left.compareTo(right);
      if (a.upcoming) return -1;
      if (b.upcoming) return 1;
      return right.compareTo(left);
    });
    return switch (_lens) {
      _BookingLens.all => rows,
      _BookingLens.upcoming => rows.where((row) => row.upcoming).toList(),
      _BookingLens.done =>
        rows.where((row) => row.status == 'completed').toList(),
      _BookingLens.cancelled =>
        rows.where((row) => row.status == 'cancelled').toList(),
    };
  }

  CustomerBooking? get _next {
    final upcoming = _items.where((row) => row.upcoming).toList()
      ..sort(
        (a, b) => (a.at ?? DateTime.now()).compareTo(b.at ?? DateTime.now()),
      );
    return upcoming.isEmpty ? null : upcoming.first;
  }

  double get _value {
    return _items
        .where((row) => row.status != 'cancelled')
        .fold(0, (sum, row) => sum + row.total);
  }

  Future<void> _signIn() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  Future<void> _cancel(CustomerBooking booking) async {
    final english = Directionality.of(context) == TextDirection.ltr;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(
            english ? 'Cancel this visit?' : 'إلغاء هذا الموعد؟',
            style: TextStyle(color: AppColors.gold),
          ),
          content: Text(
            english
                ? 'The salon will see the appointment as cancelled.'
                : 'سيظهر الموعد ملغياً لدى الصالون.',
            style: TextStyle(color: AppColors.goldSoft, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(english ? 'Keep it' : 'الإبقاء'),
            ),
            TextButton(
              key: const Key('bookings-cancel-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                english ? 'Cancel visit' : 'إلغاء الموعد',
                style: TextStyle(color: AppColors.gold),
              ),
            ),
          ],
        );
      },
    );
    if (yes != true || !mounted) return;
    try {
      await BookingsApi.cancel(booking.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast(error is BookingsException ? error.message : 'تعذر إلغاء الموعد.');
    }
  }

  Future<void> _review(CustomerBooking booking) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _ReviewSheet(booking: booking),
    );
    if (saved == true) await _load();
  }

  void _openDetails(CustomerBooking booking) {
    final english = Directionality.of(context) == TextDirection.ltr;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: _DetailSheet(
            booking: booking,
            english: english,
            onOpenSalon: () {
              Navigator.pop(context);
              widget.onOpenSalon(booking.salonId, booking.categorySlug);
            },
            onCancel: booking.canCancel
                ? () {
                    Navigator.pop(context);
                    _cancel(booking);
                  }
                : null,
            onReview: booking.canReview
                ? () {
                    Navigator.pop(context);
                    _review(booking);
                  }
                : null,
          ),
        );
      },
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.panel,
        content: Text(message, style: TextStyle(color: AppColors.gold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final english = Directionality.of(context) == TextDirection.ltr;

    return ColoredBox(
      key: const Key('bookings-screen'),
      color: AppColors.black,
      child: ListenableBuilder(
        listenable: AccountStore.instance,
        builder: (context, _) {
          if (!AccountStore.instance.loggedIn) {
            return _Guest(english: english, onSignIn: _signIn);
          }
          if (AccountStore.instance.role == 'salon') {
            return SalonBookingsScreen(reloadToken: widget.reloadToken);
          }
          return RefreshIndicator(
            color: AppColors.ink,
            backgroundColor: AppColors.gold,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Text(
                  english ? 'My bookings' : 'حجوزاتي',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _next == null
                      ? (english ? 'No upcoming visit' : 'لا يوجد موعد قادم')
                      : (english
                            ? 'Next: ${_when(_next!, english)}'
                            : 'القادم: ${_when(_next!, english)}'),
                  style: TextStyle(color: AppColors.goldSoft, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _Stats(
                  english: english,
                  upcoming: _items.where((row) => row.upcoming).length,
                  done: _items.where((row) => row.status == 'completed').length,
                  value: _money(_value, english),
                ),
                const SizedBox(height: 14),
                _Filters(
                  english: english,
                  lens: _lens,
                  onChanged: (lens) => setState(() => _lens = lens),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  )
                else if (_error != null)
                  _Empty(
                    icon: Icons.cloud_off_rounded,
                    title: english
                        ? 'Could not load bookings'
                        : 'تعذر تحميل الحجوزات',
                    body: _error!,
                  )
                else if (_visible.isEmpty)
                  _Empty(
                    icon: Icons.event_busy_rounded,
                    title: english
                        ? 'Nothing in this list'
                        : 'لا توجد مواعيد هنا',
                    body: english
                        ? 'Book a salon and the visit will show up here.'
                        : 'احجز من أي صالون وسيظهر موعدك هنا.',
                  )
                else ...[
                  if (_lens == _BookingLens.all ||
                      _lens == _BookingLens.upcoming)
                    if (_next != null && _visible.contains(_next)) ...[
                      _Hero(
                        booking: _next!,
                        english: english,
                        onTap: () => _openDetails(_next!),
                      ),
                      const SizedBox(height: 14),
                    ],
                  for (final booking in _visible.where(
                    (row) =>
                        row.id != _next?.id ||
                        _lens == _BookingLens.done ||
                        _lens == _BookingLens.cancelled,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BookingCard(
                        booking: booking,
                        english: english,
                        onTap: () => _openDetails(booking),
                        onCancel: booking.canCancel
                            ? () => _cancel(booking)
                            : null,
                        onReview: booking.canReview
                            ? () => _review(booking)
                            : null,
                        onOpenSalon: () => widget.onOpenSalon(
                          booking.salonId,
                          booking.categorySlug,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Guest extends StatelessWidget {
  const _Guest({required this.english, required this.onSignIn});

  final bool english;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_rounded, color: AppColors.gold, size: 46),
            const SizedBox(height: 16),
            Text(
              english ? 'My bookings' : 'حجوزاتي',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              english
                  ? 'Sign in to see your visits, cancel one, or leave a review.'
                  : 'سجّل الدخول لترى مواعيدك.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.goldSoft,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              key: const Key('bookings-login'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              onPressed: onSignIn,
              child: Text(
                english ? 'Sign in' : 'تسجيل الدخول',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.english,
    required this.upcoming,
    required this.done,
    required this.value,
  });

  final bool english;
  final int upcoming;
  final int done;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(value: '$upcoming', label: english ? 'Upcoming' : 'القادمة'),
        const SizedBox(width: 8),
        _Stat(value: '$done', label: english ? 'Done' : 'المكتملة'),
        const SizedBox(width: 8),
        _Stat(value: value, label: english ? 'Total' : 'القيمة'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: AppColors.goldSoft, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.english,
    required this.lens,
    required this.onChanged,
  });

  final bool english;
  final _BookingLens lens;
  final ValueChanged<_BookingLens> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (_BookingLens.all, english ? 'All' : 'الكل', 'bookings-filter-all'),
      (
        _BookingLens.upcoming,
        english ? 'Upcoming' : 'القادمة',
        'bookings-filter-upcoming',
      ),
      (
        _BookingLens.done,
        english ? 'Done' : 'المكتملة',
        'bookings-filter-done',
      ),
      (
        _BookingLens.cancelled,
        english ? 'Cancelled' : 'الملغاة',
        'bookings-filter-cancelled',
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _Chip(
              key: Key(item.$3),
              label: item.$2,
              selected: lens == item.$1,
              onTap: () => onChanged(item.$1),
            ),
            const SizedBox(width: 8),
          ],
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
      color: selected ? AppColors.gold : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.booking,
    required this.english,
    required this.onTap,
  });

  final CustomerBooking booking;
  final bool english;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('bookings-next'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.warm, AppColors.panel],
            ),
            border: Border.all(color: AppColors.gold),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 78,
                    height: 78,
                    child: SalonPhoto(
                      url: booking.imageUrl,
                      asset: salonPhotoAsset(booking.salonName),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        english ? 'Next visit' : 'الموعد القادم',
                        style: TextStyle(
                          color: AppColors.goldSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.salonName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${booking.serviceName} · ${_when(booking, english)} · ${booking.time}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.goldSoft,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.english,
    required this.onTap,
    required this.onOpenSalon,
    this.onCancel,
    this.onReview,
  });

  final CustomerBooking booking;
  final bool english;
  final VoidCallback onTap;
  final VoidCallback onOpenSalon;
  final VoidCallback? onCancel;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('bookings-card-${booking.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: SalonPhoto(
                          url: booking.imageUrl,
                          asset: salonPhotoAsset(booking.salonName),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.salonName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.goldSoft,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_when(booking, english)} · ${booking.time}',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: booking.status, english: english),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        booking.specialistName.isEmpty
                            ? (english ? 'Any stylist' : 'أي متاح')
                            : booking.specialistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.goldSoft,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      _money(booking.total, english),
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (onCancel != null || onReview != null || booking.reviewed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        if (onCancel != null)
                          _Action(
                            label: english ? 'Cancel' : 'إلغاء',
                            onTap: onCancel!,
                          ),
                        if (onReview != null)
                          _Action(
                            label: english ? 'Review' : 'قيّم',
                            onTap: onReview!,
                          ),
                        if (booking.reviewed)
                          Text(
                            english ? 'Reviewed' : 'تم التقييم',
                            style: TextStyle(
                              color: AppColors.goldSoft,
                              fontSize: 12,
                            ),
                          ),
                        const Spacer(),
                        _Action(
                          label: english ? 'Salon' : 'الصالون',
                          onTap: onOpenSalon,
                        ),
                      ],
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

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.gold,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.english});

  final String status;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final filled = status == 'confirmed' || status == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? AppColors.gold : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'cancelled' ? AppColors.goldSoft : AppColors.gold,
        ),
      ),
      child: Text(
        _statusLabel(status, english),
        style: TextStyle(
          color: filled
              ? AppColors.ink
              : status == 'cancelled'
              ? AppColors.goldSoft
              : AppColors.gold,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.booking,
    required this.english,
    required this.onOpenSalon,
    this.onCancel,
    this.onReview,
  });

  final CustomerBooking booking;
  final bool english;
  final VoidCallback onOpenSalon;
  final VoidCallback? onCancel;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.salonName,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusBadge(status: booking.status, english: english),
            ],
          ),
          if (booking.place.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              booking.place,
              style: TextStyle(color: AppColors.goldSoft, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          _Line(english ? 'Service' : 'الخدمة', booking.serviceName),
          if (booking.durationMinutes > 0)
            _Line(
              english ? 'Duration' : 'المدة',
              english
                  ? '${booking.durationMinutes} min'
                  : '${booking.durationMinutes} د',
            ),
          _Line(
            english ? 'Stylist' : 'الأخصائي',
            booking.specialistName.isEmpty
                ? (english ? 'Any available' : 'أي متاح')
                : booking.specialistTitle.isEmpty
                ? booking.specialistName
                : '${booking.specialistName} · ${booking.specialistTitle}',
          ),
          _Line(english ? 'Day' : 'اليوم', _when(booking, english)),
          _Line(english ? 'Time' : 'الوقت', booking.time),
          if (booking.discount > 0)
            _Line(
              english ? 'Discount' : 'الخصم',
              _money(booking.discount, english),
            ),
          _Line(english ? 'Total' : 'الإجمالي', _money(booking.total, english)),
          if (booking.points > 0)
            _Line(
              english ? 'Loyalty points' : 'نقاط الولاء',
              '${booking.points}',
            ),
          if ((booking.notes ?? '').isNotEmpty)
            _Line(english ? 'Notes' : 'ملاحظات', booking.notes!),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                  ),
                  onPressed: onOpenSalon,
                  child: Text(english ? 'Open salon' : 'صفحة الصالون'),
                ),
              ),
            ],
          ),
          if (onCancel != null || onReview != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onCancel != null)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: BorderSide(color: AppColors.gold),
                      ),
                      onPressed: onCancel,
                      child: Text(english ? 'Cancel visit' : 'إلغاء الموعد'),
                    ),
                  ),
                if (onCancel != null && onReview != null)
                  const SizedBox(width: 8),
                if (onReview != null)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: BorderSide(color: AppColors.gold),
                      ),
                      onPressed: onReview,
                      child: Text(english ? 'Review visit' : 'قيّم الزيارة'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(color: AppColors.goldSoft, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.booking});

  final CustomerBooking booking;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _comment = TextEditingController();
  var _stars = 5;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BookingsApi.review(
        id: widget.booking.id,
        rating: _stars,
        comment: _comment.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is BookingsException
            ? error.message
            : 'تعذر إرسال التقييم.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = Directionality.of(context) == TextDirection.ltr;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            english ? 'Review your visit' : 'قيّم الزيارة',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  key: Key('bookings-star-$star'),
                  onPressed: () => setState(() => _stars = star),
                  icon: Icon(
                    star <= _stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
          TextField(
            key: const Key('bookings-review'),
            controller: _comment,
            maxLines: 3,
            style: TextStyle(color: AppColors.gold),
            decoration: InputDecoration(
              labelText: english ? 'Comment' : 'تعليقك',
              labelStyle: TextStyle(color: AppColors.goldSoft),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.gold),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: AppColors.goldSoft)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('bookings-review-submit'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
              ),
              onPressed: _saving ? null : _save,
              child: Text(english ? 'Send review' : 'إرسال التقييم'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.goldSoft, height: 1.5),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status, bool english) {
  return switch (status) {
    'pending' => english ? 'Pending' : 'بانتظار التأكيد',
    'confirmed' => english ? 'Confirmed' : 'مؤكد',
    'completed' => english ? 'Done' : 'مكتمل',
    'cancelled' => english ? 'Cancelled' : 'ملغي',
    _ => status,
  };
}

String _when(CustomerBooking booking, bool english) {
  final moment = booking.at;
  if (moment == null) return booking.date;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(moment.year, moment.month, moment.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return english ? 'Today' : 'اليوم';
  if (diff == 1) return english ? 'Tomorrow' : 'غداً';
  if (diff == -1) return english ? 'Yesterday' : 'أمس';
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
  final name = (english ? en : ar)[moment.weekday - 1];
  return '$name ${moment.day}/${moment.month}';
}

String _money(double value, bool english) {
  final whole = value == value.roundToDouble();
  final digits = whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return english ? 'EGP $digits' : '$digits ج.م';
}
