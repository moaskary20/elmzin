import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account_store.dart';
import '../data/salon_booking.dart';
import '../theme/app_colors.dart';

enum _Lens { upcoming, pending, confirmed, past, cancelled, all }

class SalonBookingsScreen extends StatefulWidget {
  const SalonBookingsScreen({super.key, this.reloadToken = 0});

  final int reloadToken;

  @override
  State<SalonBookingsScreen> createState() => _SalonBookingsScreenState();
}

class _SalonBookingsScreenState extends State<SalonBookingsScreen> {
  List<SalonBooking> _items = const [];
  var _lens = _Lens.upcoming;
  var _loading = true;
  String? _error;
  final Set<int> _busy = {};

  bool get _english => Directionality.of(context) == TextDirection.ltr;

  String _t(String ar, String en) => _english ? en : ar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SalonBookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) _load();
  }

  Future<void> _load() async {
    try {
      final items = await SalonBookingsApi.load();
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
        _error = error is SalonBookingsException
            ? error.message
            : 'تعذر تحميل حجوزات الصالون.';
      });
    }
  }

  List<SalonBooking> get _upcoming {
    final rows = _items.where((row) => row.upcoming).toList()
      ..sort((a, b) => a.at!.compareTo(b.at!));
    return rows;
  }

  SalonBooking? get _next {
    final rows = _upcoming;
    return rows.isEmpty ? null : rows.first;
  }

  List<SalonBooking> get _visible {
    final upcoming = _upcoming;
    final past = _items.where((row) => !row.upcoming).toList()
      ..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
    return switch (_lens) {
      _Lens.upcoming => upcoming,
      _Lens.pending => upcoming.where((r) => r.status == 'pending').toList(),
      _Lens.confirmed =>
        upcoming.where((r) => r.status == 'confirmed').toList(),
      _Lens.past => past.where((r) => r.status != 'cancelled').toList(),
      _Lens.cancelled => past.where((r) => r.status == 'cancelled').toList(),
      _Lens.all => [...upcoming, ...past],
    };
  }

  void _replace(SalonBooking updated) {
    setState(() {
      _items = [for (final row in _items) row.id == updated.id ? updated : row];
    });
  }

  Future<void> _confirm(SalonBooking booking) async {
    if (_busy.contains(booking.id)) return;
    setState(() => _busy.add(booking.id));
    try {
      final updated = await SalonBookingsApi.confirm(booking.id);
      if (!mounted) return;
      _replace(updated);
      _toast(_t('تم تأكيد الحجز وسيظهر مؤكداً للعميل.', 'Booking confirmed.'));
    } catch (error) {
      if (!mounted) return;
      _toast(error is SalonBookingsException ? error.message : 'تعذر التأكيد.');
    } finally {
      if (mounted) setState(() => _busy.remove(booking.id));
    }
  }

  Future<void> _cancel(SalonBooking booking) async {
    if (_busy.contains(booking.id)) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(booking: booking, english: _english),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy.add(booking.id));
    try {
      final updated = await SalonBookingsApi.cancel(booking.id, reason);
      if (!mounted) return;
      _replace(updated);
      _toast(_t('تم إلغاء الحجز.', 'Booking cancelled.'));
    } catch (error) {
      if (!mounted) return;
      _toast(error is SalonBookingsException ? error.message : 'تعذر الإلغاء.');
    } finally {
      if (mounted) setState(() => _busy.remove(booking.id));
    }
  }

  void _openDetails(SalonBooking booking) {
    final english = _english;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) => Directionality(
        textDirection: english ? TextDirection.ltr : TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              _BookingDetails(
                booking: booking,
                english: english,
                busy: false,
                onCopy: _copyPhone,
                onConfirm: booking.canConfirm
                    ? () {
                        Navigator.pop(sheet);
                        _confirm(booking);
                      }
                    : null,
                onCancel: booking.canCancel
                    ? () {
                        Navigator.pop(sheet);
                        _cancel(booking);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    _toast(_t('تم نسخ رقم العميل $phone', 'Copied $phone'));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.panel,
          content: Text(message, style: TextStyle(color: AppColors.gold)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final english = _english;
    final next = _next;
    final upcoming = _upcoming;
    final pending = upcoming.where((r) => r.status == 'pending').length;
    final now = DateTime.now();
    final today = upcoming.where((r) {
      final at = r.at!;
      return at.year == now.year && at.month == now.month && at.day == now.day;
    }).length;
    final expected = upcoming.fold<double>(0, (sum, r) => sum + r.total);
    final visible = _visible;

    return ColoredBox(
      key: const Key('salon-bookings-screen'),
      color: AppColors.black,
      child: RefreshIndicator(
        color: AppColors.ink,
        backgroundColor: AppColors.gold,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              _t('حجوزات الصالون', 'Salon bookings'),
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AccountStore.instance.name.isEmpty
                  ? _t('تابع مواعيد عملائك', 'Track your clients')
                  : AccountStore.instance.name,
              style: TextStyle(color: AppColors.goldSoft, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(
                  key: const Key('salon-stat-pending'),
                  value: '$pending',
                  label: _t('بانتظار التأكيد', 'Pending'),
                  icon: Icons.hourglass_top_rounded,
                  highlight: pending > 0,
                ),
                const SizedBox(width: 8),
                _Stat(
                  key: const Key('salon-stat-today'),
                  value: '$today',
                  label: _t('مواعيد اليوم', 'Today'),
                  icon: Icons.today_rounded,
                ),
                const SizedBox(width: 8),
                _Stat(
                  key: const Key('salon-stat-expected'),
                  value: _money(expected, english),
                  label: _t('دخل متوقع', 'Expected'),
                  icon: Icons.payments_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (_error != null)
              _Empty(
                icon: Icons.cloud_off_rounded,
                title: _t('تعذر تحميل الحجوزات', 'Could not load bookings'),
                body: _error!,
                action: TextButton(
                  key: const Key('salon-bookings-retry'),
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                  child: Text(
                    _t('إعادة المحاولة', 'Retry'),
                    style: TextStyle(color: AppColors.gold),
                  ),
                ),
              )
            else ...[
              _SectionTitle(
                icon: Icons.event_available_rounded,
                label: _t('الحجز القادم', 'Next booking'),
              ),
              const SizedBox(height: 10),
              if (next == null)
                _Empty(
                  icon: Icons.event_busy_rounded,
                  title: _t('لا يوجد حجز قادم', 'No upcoming booking'),
                  body: _t(
                    'عندما يحجز عميل موعداً في صالونك سيظهر هنا بكل تفاصيله.',
                    'New client bookings will show up here.',
                  ),
                )
              else
                Container(
                  key: const Key('salon-next'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppColors.warm, AppColors.panel],
                    ),
                    border: Border.all(color: AppColors.gold, width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33D9B25B),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _BookingDetails(
                    booking: next,
                    english: english,
                    busy: _busy.contains(next.id),
                    onCopy: _copyPhone,
                    onConfirm: next.canConfirm ? () => _confirm(next) : null,
                    onCancel: next.canCancel ? () => _cancel(next) : null,
                  ),
                ),
              const SizedBox(height: 22),
              _SectionTitle(
                icon: Icons.list_alt_rounded,
                label: _t('كل الحجوزات', 'All bookings'),
              ),
              const SizedBox(height: 10),
              _Filters(
                english: english,
                lens: _lens,
                counts: {
                  _Lens.upcoming: upcoming.length,
                  _Lens.pending: pending,
                },
                onChanged: (lens) => setState(() => _lens = lens),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                _Empty(
                  icon: Icons.inbox_outlined,
                  title: _t('لا توجد حجوزات هنا', 'Nothing here'),
                  body: _t(
                    'جرّب تصنيفاً آخر من الأعلى.',
                    'Try another filter above.',
                  ),
                )
              else
                for (final booking in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BookingTile(
                      booking: booking,
                      english: english,
                      busy: _busy.contains(booking.id),
                      onTap: () => _openDetails(booking),
                      onConfirm: booking.canConfirm
                          ? () => _confirm(booking)
                          : null,
                      onCancel: booking.canCancel
                          ? () => _cancel(booking)
                          : null,
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingDetails extends StatelessWidget {
  const _BookingDetails({
    required this.booking,
    required this.english,
    required this.busy,
    required this.onCopy,
    this.onConfirm,
    this.onCancel,
  });

  final SalonBooking booking;
  final bool english;
  final bool busy;
  final ValueChanged<String> onCopy;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  String _t(String ar, String en) => english ? en : ar;

  @override
  Widget build(BuildContext context) {
    final id = booking.id;
    final moment = booking.at;
    final specialist = booking.specialistName.isEmpty
        ? _t('أي أخصائي متاح', 'Any stylist')
        : booking.specialistTitle.isEmpty
        ? booking.specialistName
        : '${booking.specialistName} · ${booking.specialistTitle}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StatusBadge(status: booking.status, english: english),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: booking.upcoming && moment != null
                    ? _Pill(
                        icon: Icons.timer_outlined,
                        label: _countdown(moment, english),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '#$id',
              style: TextStyle(color: AppColors.goldSoft, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _DateBlock(booking: booking, english: english),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.serviceName,
                    key: Key('salon-booking-service-$id'),
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _IconLine(
                    icon: Icons.schedule_rounded,
                    text: booking.durationMinutes > 0
                        ? _t(
                            '${booking.time} • ${booking.durationMinutes} دقيقة',
                            '${booking.time} • ${booking.durationMinutes} min',
                          )
                        : booking.time,
                  ),
                  const SizedBox(height: 4),
                  _IconLine(icon: Icons.content_cut_rounded, text: specialist),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Block(
          title: _t('العميل', 'Client'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Avatar(
                    name: booking.customerName,
                    url: booking.customerAvatar,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.customerName,
                          key: Key('salon-booking-customer-$id'),
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Pill(
                              icon: booking.registered
                                  ? Icons.verified_user_outlined
                                  : Icons.person_outline,
                              label: booking.registered
                                  ? _t('عميل مسجل', 'Registered')
                                  : _t('زائر', 'Guest'),
                            ),
                            _Pill(
                              key: Key('salon-booking-visits-$id'),
                              icon: Icons.repeat_rounded,
                              label: booking.visits <= 1
                                  ? _t('أول زيارة', 'First visit')
                                  : _t(
                                      'زيارة رقم ${booking.visits}',
                                      'Visit #${booking.visits}',
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (booking.customerPhone.isNotEmpty) ...[
                const SizedBox(height: 12),
                Material(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: Key('salon-booking-phone-$id'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onCopy(booking.customerPhone),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_in_talk_outlined,
                            color: AppColors.gold,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              booking.customerPhone,
                              textDirection: TextDirection.ltr,
                              textAlign: english
                                  ? TextAlign.left
                                  : TextAlign.right,
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _t('نسخ', 'Copy'),
                            style: TextStyle(
                              color: AppColors.goldSoft,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            color: AppColors.goldSoft,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (booking.customerEmail != null) ...[
                const SizedBox(height: 8),
                _IconLine(
                  icon: Icons.alternate_email_rounded,
                  text: booking.customerEmail!,
                ),
              ],
              if (booking.customerAddress != null ||
                  booking.customerCity != null) ...[
                const SizedBox(height: 6),
                _IconLine(
                  icon: Icons.location_on_outlined,
                  text: [
                    booking.customerAddress,
                    booking.customerCity,
                  ].whereType<String>().join('، '),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Block(
          title: _t('الحساب', 'Payment'),
          child: Column(
            children: [
              _Amount(
                label: _t('سعر الخدمة', 'Service price'),
                value: _money(
                  booking.subtotal > 0 ? booking.subtotal : booking.total,
                  english,
                ),
              ),
              if (booking.discount > 0)
                _Amount(
                  label: booking.couponCode == null
                      ? _t('خصم الكوبون', 'Coupon')
                      : _t(
                          'كوبون ${booking.couponCode}',
                          'Coupon ${booking.couponCode}',
                        ),
                  value: '- ${_money(booking.discount, english)}',
                ),
              if (booking.pointsDiscount > 0)
                _Amount(
                  label: _t(
                    'نقاط الولاء (${booking.pointsRedeemed})',
                    'Points (${booking.pointsRedeemed})',
                  ),
                  value: '- ${_money(booking.pointsDiscount, english)}',
                ),
              Divider(color: AppColors.line, height: 16),
              _Amount(
                key: Key('salon-booking-total-$id'),
                label: _t('المطلوب من العميل', 'Client pays'),
                value: _money(booking.total, english),
                strong: true,
              ),
            ],
          ),
        ),
        if (booking.notes != null) ...[
          const SizedBox(height: 10),
          _Block(
            title: _t('ملاحظات العميل', 'Notes'),
            child: Text(
              booking.notes!,
              key: Key('salon-booking-notes-$id'),
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
        if (booking.createdAt != null) ...[
          const SizedBox(height: 10),
          _IconLine(
            icon: Icons.history_rounded,
            text: _t(
              'تم الحجز ${_stamp(booking.createdAt!, english)}',
              'Booked ${_stamp(booking.createdAt!, english)}',
            ),
          ),
        ],
        if (onConfirm != null || onCancel != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (onConfirm != null)
                Expanded(
                  child: FilledButton.icon(
                    key: Key('salon-confirm-$id'),
                    onPressed: busy ? null : onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.ink,
                      disabledBackgroundColor: AppColors.goldDeep,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.ink,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      _t('تأكيد الحجز', 'Confirm'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (onConfirm != null && onCancel != null)
                const SizedBox(width: 10),
              if (onCancel != null)
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('salon-cancel-$id'),
                    onPressed: busy ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE58B8B),
                      side: const BorderSide(color: Color(0x99E58B8B)),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(
                      _t('إلغاء الحجز', 'Cancel'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (booking.status == 'confirmed' && booking.upcoming) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: AppColors.gold, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _t(
                    'الحجز مؤكد والعميل يراه مؤكداً',
                    'Confirmed — the client can see it',
                  ),
                  key: Key('salon-confirmed-note-$id'),
                  style: TextStyle(color: AppColors.goldSoft, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({
    required this.booking,
    required this.english,
    required this.busy,
    required this.onTap,
    this.onConfirm,
    this.onCancel,
  });

  final SalonBooking booking;
  final bool english;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final faded = booking.status == 'cancelled';
    return Opacity(
      opacity: faded ? 0.6 : 1,
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('salon-booking-${booking.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: booking.status == 'pending' && booking.upcoming
                    ? AppColors.gold
                    : AppColors.line,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _DateBlock(booking: booking, english: english, compact: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                booking.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _StatusBadge(
                              status: booking.status,
                              english: english,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${booking.serviceName} · ${_money(booking.total, english)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.goldSoft,
                            fontSize: 13,
                          ),
                        ),
                        if (onConfirm != null || onCancel != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (onConfirm != null)
                                _SmallAction(
                                  key: Key('salon-tile-confirm-${booking.id}'),
                                  label: english ? 'Confirm' : 'تأكيد',
                                  icon: Icons.check_rounded,
                                  filled: true,
                                  onTap: busy ? null : onConfirm,
                                ),
                              if (onConfirm != null && onCancel != null)
                                const SizedBox(width: 8),
                              if (onCancel != null)
                                _SmallAction(
                                  key: Key('salon-tile-cancel-${booking.id}'),
                                  label: english ? 'Cancel' : 'إلغاء',
                                  icon: Icons.close_rounded,
                                  onTap: busy ? null : onCancel,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.booking, required this.english});

  final SalonBooking booking;
  final bool english;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.english;
    return Directionality(
      textDirection: english ? TextDirection.ltr : TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          english
              ? 'Cancel this booking?'
              : 'إلغاء حجز ${widget.booking.customerName}؟',
          style: TextStyle(color: AppColors.gold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              english
                  ? 'The client will see the booking as cancelled.'
                  : 'سيظهر الحجز ملغياً لدى العميل. يمكنك كتابة السبب ليعرفه.',
              style: TextStyle(color: AppColors.goldSoft, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('salon-cancel-reason'),
              controller: _reason,
              maxLines: 2,
              maxLength: 300,
              style: TextStyle(color: AppColors.gold),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                hintText: english
                    ? 'Reason (optional)'
                    : 'سبب الإلغاء (اختياري)',
                hintStyle: TextStyle(color: AppColors.goldSoft),
                filled: true,
                fillColor: AppColors.black,
                counterStyle: TextStyle(color: AppColors.goldSoft),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('salon-cancel-keep'),
            onPressed: () => Navigator.pop(context),
            child: Text(
              english ? 'Keep it' : 'تراجع',
              style: TextStyle(color: AppColors.goldSoft),
            ),
          ),
          FilledButton(
            key: const Key('salon-cancel-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE58B8B),
              foregroundColor: AppColors.ink,
            ),
            onPressed: () => Navigator.pop(context, _reason.text),
            child: Text(
              english ? 'Cancel booking' : 'تأكيد الإلغاء',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({
    required this.booking,
    required this.english,
    this.compact = false,
  });

  final SalonBooking booking;
  final bool english;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final moment = booking.at;
    final size = compact ? 62.0 : 78.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: compact ? AppColors.black : AppColors.gold,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: compact ? Border.all(color: AppColors.line) : null,
      ),
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              moment == null ? '' : _dayName(moment, english),
              style: TextStyle(
                color: compact ? AppColors.goldSoft : AppColors.ink,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              moment == null ? booking.date : '${moment.day}/${moment.month}',
              style: TextStyle(
                color: compact ? AppColors.gold : AppColors.ink,
                fontSize: compact ? 16 : 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              booking.time,
              style: TextStyle(
                color: compact ? AppColors.goldSoft : AppColors.ink,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '؟' : name.trim().characters.first;
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.gold, AppColors.goldDeep]),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.goldSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? AppColors.gold : AppColors.goldSoft,
                fontSize: strong ? 15 : 13,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.gold,
              fontSize: strong ? 18 : 14,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.goldSoft),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.goldSoft,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x1FD9B25B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
    final (label, color, filled) = switch (status) {
      'pending' => (
        english ? 'Pending' : 'بانتظار التأكيد',
        AppColors.gold,
        false,
      ),
      'confirmed' => (english ? 'Confirmed' : 'مؤكد', AppColors.gold, true),
      'completed' => (
        english ? 'Done' : 'مكتمل',
        const Color(0xFF7BC47F),
        false,
      ),
      'cancelled' => (
        english ? 'Cancelled' : 'ملغي',
        const Color(0xFFE58B8B),
        false,
      ),
      _ => (status, AppColors.goldSoft, false),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? AppColors.ink : color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = filled ? AppColors.gold : const Color(0xFFE58B8B);
    return Material(
      color: filled ? AppColors.gold : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: filled ? AppColors.ink : color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: filled ? AppColors.ink : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: highlight ? AppColors.gold : AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight ? AppColors.gold : AppColors.line,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: highlight ? AppColors.ink : AppColors.gold,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: highlight ? AppColors.ink : AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: highlight ? AppColors.ink : AppColors.goldSoft,
                fontSize: 11,
              ),
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
    required this.counts,
    required this.onChanged,
  });

  final bool english;
  final _Lens lens;
  final Map<_Lens, int> counts;
  final ValueChanged<_Lens> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (_Lens.upcoming, english ? 'Upcoming' : 'القادمة', 'upcoming'),
      (_Lens.pending, english ? 'Pending' : 'بانتظار التأكيد', 'pending'),
      (_Lens.confirmed, english ? 'Confirmed' : 'المؤكدة', 'confirmed'),
      (_Lens.past, english ? 'Past' : 'السابقة', 'past'),
      (_Lens.cancelled, english ? 'Cancelled' : 'الملغاة', 'cancelled'),
      (_Lens.all, english ? 'All' : 'الكل', 'all'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label, key) in items) ...[
            Material(
              color: lens == value ? AppColors.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                key: Key('salon-filter-$key'),
                onTap: () => onChanged(value),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: lens == value ? AppColors.gold : AppColors.line,
                    ),
                  ),
                  child: Text(
                    (counts[value] ?? 0) > 0
                        ? '$label (${counts[value]})'
                        : label,
                    style: TextStyle(
                      color: lens == value ? AppColors.ink : AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.goldSoft,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

String _dayName(DateTime moment, bool english) {
  final now = DateTime.now();
  final diff = DateTime(
    moment.year,
    moment.month,
    moment.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
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
  return (english ? en : ar)[moment.weekday - 1];
}

String _countdown(DateTime moment, bool english) {
  final left = moment.difference(DateTime.now());
  if (left.inMinutes < 60) {
    final minutes = left.inMinutes.clamp(1, 59);
    return english ? 'In $minutes min' : 'بعد $minutes دقيقة';
  }
  if (left.inHours < 24) {
    final hours = left.inHours;
    if (english) return 'In $hours h';
    return switch (hours) {
      1 => 'بعد ساعة',
      2 => 'بعد ساعتين',
      <= 10 => 'بعد $hours ساعات',
      _ => 'بعد $hours ساعة',
    };
  }
  final days = left.inDays;
  if (english) return 'In $days d';
  return switch (days) {
    1 => 'بعد يوم',
    2 => 'بعد يومين',
    <= 10 => 'بعد $days أيام',
    _ => 'بعد $days يوماً',
  };
}

String _stamp(DateTime at, bool english) {
  final hour = at.hour.toString().padLeft(2, '0');
  final minute = at.minute.toString().padLeft(2, '0');
  return english
      ? 'on ${at.day}/${at.month} at $hour:$minute'
      : 'يوم ${at.day}/${at.month} الساعة $hour:$minute';
}

String _money(double value, bool english) {
  final whole = value == value.roundToDouble();
  final digits = whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return english ? 'EGP $digits' : '$digits ج.م';
}
