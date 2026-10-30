import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/account_store.dart';
import '../data/cart_store.dart';
import '../data/home_slide.dart';
import '../data/salon_detail.dart';
import '../theme/app_colors.dart';
import '../widgets/favorite_button.dart';
import '../widgets/kids_backdrop.dart';
import '../widgets/salon_media_slider.dart';
import 'cart_screen.dart';
import 'login_screen.dart';

class SalonScreen extends StatefulWidget {
  const SalonScreen({
    super.key,
    required this.salonId,
    required this.locale,
    this.palette = SalonPalette.gold,
    this.onBack,
    this.onOpenCart,
  });

  final int salonId;
  final Locale locale;
  final SalonPalette palette;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenCart;

  static Future<bool> Function(Uri uri) openMaps = (uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  static void useDefaultMaps() =>
      openMaps = (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  State<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends State<SalonScreen> {
  SalonDetail? _detail;
  var _loading = true;
  int? _serviceId;
  int? _specialistId;
  DateTime? _day;
  String? _time;

  bool get _english => widget.locale.languageCode == 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await SalonDetailApi.load(widget.salonId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      logSlideError(error);
      if (!mounted) return;
      setState(() {
        _detail = SalonDetail.fallback;
        _loading = false;
      });
    }
  }

  bool get _kids =>
      widget.palette.accent == SalonPalette.kids.accent ||
      _detail?.categorySlug == 'kids';

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final body = SafeArea(
      child: _loading || detail == null
          ? Center(
              child: CircularProgressIndicator(color: widget.palette.accent),
            )
          : _SalonBody(
              detail: detail,
              english: _english,
              serviceId: _serviceId,
              specialistId: _specialistId,
              day: _day,
              time: _time,
              onService: (id) => setState(() {
                _serviceId = id;
                _specialistId = null;
                _time = null;
              }),
              onSpecialist: (id) => setState(() {
                _specialistId = id;
                _time = null;
              }),
              onDay: (day) => setState(() {
                _day = day;
                _time = null;
              }),
              onTime: (time) => setState(() => _time = time),
              onBook: _book,
              onLogin: _login,
              onBack: widget.onBack,
            ),
    );

    return SalonTheme(
      palette: widget.palette,
      child: Directionality(
        textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _kids
              ? Colors.transparent
              : widget.palette.background,
          body: _kids ? KidsBackdrop(child: body) : body,
        ),
      ),
    );
  }

  void _login() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  void _book() {
    final detail = _detail;
    final day = _day;
    final time = _time;
    if (detail == null || _serviceId == null || day == null || time == null) {
      return;
    }
    final service = detail.services.firstWhere((item) => item.id == _serviceId);
    SalonSpecialistItem? specialist;
    for (final item in detail.specialists) {
      if (item.id == _specialistId) specialist = item;
    }
    final item = CartStore.instance.add(
      salon: detail,
      service: service,
      specialist: specialist,
      date: _dateKey(day),
      time: time,
    );
    setState(() => _time = null);

    final open = widget.onOpenCart;
    if (open != null) {
      open(item.key);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Directionality(
          textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
          child: Scaffold(
            backgroundColor: widget.palette.background,
            body: SafeArea(
              child: CartScreen(
                palette: widget.palette,
                highlightKey: item.key,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SalonBody extends StatelessWidget {
  const _SalonBody({
    required this.detail,
    required this.english,
    required this.serviceId,
    required this.specialistId,
    required this.day,
    required this.time,
    required this.onService,
    required this.onSpecialist,
    required this.onDay,
    required this.onTime,
    required this.onBook,
    required this.onLogin,
    this.onBack,
  });

  final SalonDetail detail;
  final bool english;
  final int? serviceId;
  final int? specialistId;
  final DateTime? day;
  final String? time;
  final ValueChanged<int> onService;
  final ValueChanged<int?> onSpecialist;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<String> onTime;
  final VoidCallback onBook;
  final VoidCallback onLogin;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final service = _selectedService();
    final specialists = _specialistsFor(service);
    final days = _upcomingDays();
    final times = day == null ? const <String>[] : _timesFor(day!, specialists);
    final ready = serviceId != null && day != null && time != null;
    final todayHour = detail.hours.cast<SalonHour?>().firstWhere(
      (hour) => hour != null && !hour.isClosed && hour.opensAt != null,
      orElse: () => null,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BackButton(
            color: SalonTheme.of(context).accent,
            onPressed: onBack,
          ),
        ),
        SalonMediaSlider(
          media: detail.media,
          fallbackName: detail.nameFor(english),
          fallbackUrl: detail.imageUrl,
          height: 210,
        ),
        const SizedBox(height: 16),
        Text(
          detail.eyebrow(english ? 'en' : 'ar'),
          textAlign: TextAlign.start,
          style: TextStyle(
            color: SalonTheme.of(context).deep,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                detail.nameFor(english),
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: SalonTheme.of(context).accent,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            FavoriteButton(
              salonId: detail.id,
              size: 28,
              color: SalonTheme.of(context).accent,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _meta(
              context,
              Icons.star_rounded,
              '${detail.ratingAvg.toStringAsFixed(detail.ratingAvg == detail.ratingAvg.roundToDouble() ? 0 : 1)} (${detail.reviewsCount} ${english ? 'reviews' : 'تقييم'})',
            ),
            _meta(
              context,
              Icons.place_outlined,
              detail.place,
              key: const Key('salon-address'),
              onTap: () => _openMaps(context, detail),
            ),
            _meta(context, Icons.schedule_rounded, _hoursLabel(todayHour)),
            if (detail.verified)
              _meta(
                context,
                Icons.verified_outlined,
                english ? 'Verified' : 'موثّق',
              ),
          ],
        ),
        if (detail.aboutFor(english).isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            detail.aboutFor(english),
            textAlign: TextAlign.start,
            style: TextStyle(
              color: SalonTheme.of(context).soft,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 26),
        _label(context, english ? 'Choose a service' : 'اختر الخدمة'),
        const SizedBox(height: 8),
        if (detail.services.isEmpty)
          Text(
            english ? 'No services yet.' : 'لا توجد خدمات حالياً.',
            style: TextStyle(color: SalonTheme.of(context).soft),
          )
        else
          for (final item in detail.services)
            _ServiceRow(
              service: item,
              english: english,
              selected: item.id == serviceId,
              onTap: () => onService(item.id),
            ),
        const SizedBox(height: 22),
        _label(context, english ? 'Choose a specialist' : 'اختر الأخصائي'),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _SpecialistChip(
                name: english ? 'Any available' : 'أي متاح',
                title: '',
                selected: specialistId == null,
                onTap: () => onSpecialist(null),
              ),
              for (final specialist in specialists)
                _SpecialistChip(
                  name: specialist.name,
                  title: specialist.titleFor(english),
                  selected: specialist.id == specialistId,
                  onTap: () => onSpecialist(specialist.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _label(context, english ? 'Choose a time' : 'اختر الوقت'),
        const SizedBox(height: 12),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = days[index];
              final selected = day != null && _dateKey(day!) == _dateKey(date);
              return _DayChip(
                name: _dayName(_weekday(date), english),
                number: '${date.day}',
                selected: selected,
                onTap: () => onDay(date),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (day == null)
          Text(
            english
                ? 'Pick a day to see the times.'
                : 'اختر اليوم لعرض المواعيد.',
            style: TextStyle(color: SalonTheme.of(context).soft, fontSize: 13),
          )
        else if (times.isEmpty)
          Text(
            english ? 'No times on this day.' : 'لا توجد مواعيد في هذا اليوم.',
            style: TextStyle(color: SalonTheme.of(context).soft, fontSize: 13),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in times)
                _TimeChip(
                  label: _format12(slot),
                  selected: slot == time,
                  onTap: () => onTime(slot),
                ),
            ],
          ),
        const SizedBox(height: 26),
        _label(context, english ? 'Reviews' : 'التقييمات'),
        const SizedBox(height: 10),
        if (detail.reviews.isEmpty)
          Text(
            english ? 'No reviews yet.' : 'لا توجد تقييمات سابقة.',
            style: TextStyle(color: SalonTheme.of(context).soft, fontSize: 14),
          )
        else
          for (final review in detail.reviews) ...[
            _ReviewCard(review: review, english: english),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: AccountStore.instance,
          builder: (context, _) {
            final guest = !AccountStore.instance.loggedIn;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: Key(guest ? 'login-to-book' : 'book-button'),
                    onPressed: guest ? onLogin : (ready ? onBook : null),
                    style: FilledButton.styleFrom(
                      backgroundColor: SalonTheme.of(context).accent,
                      disabledBackgroundColor: SalonTheme.of(
                        context,
                      ).accent.withValues(alpha: 0.28),
                      foregroundColor: SalonTheme.of(context).ink,
                      disabledForegroundColor: SalonTheme.of(
                        context,
                      ).ink.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          guest
                              ? Icons.login_rounded
                              : Icons.shopping_bag_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          guest
                              ? (english ? 'Sign in' : 'تسجيل الدخول')
                              : (english ? 'Book' : 'احجز'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (guest || !ready) ...[
                  const SizedBox(height: 8),
                  Text(
                    guest
                        ? (english
                              ? 'Sign in to book this salon.'
                              : 'سجّل الدخول لتتمكن من الحجز.')
                        : english
                        ? 'Choose a service, a day, and a time.'
                        : 'اختر الخدمة واليوم والوقت.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SalonTheme.of(context).soft,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  SalonServiceItem? _selectedService() {
    for (final service in detail.services) {
      if (service.id == serviceId) return service;
    }
    return null;
  }

  List<SalonSpecialistItem> _specialistsFor(SalonServiceItem? service) {
    if (service == null || service.specialistIds.isEmpty) {
      return detail.specialists;
    }
    return detail.specialists
        .where((specialist) => service.specialistIds.contains(specialist.id))
        .toList();
  }

  List<DateTime> _upcomingDays() {
    final start = DateTime.now();
    // Use calendar-date construction — Duration(days:) shifts by 24h and can
    // duplicate/skip weekdays across DST transitions (e.g. الخميس twice).
    return [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
  }

  List<String> _timesFor(DateTime date, List<SalonSpecialistItem> specialists) {
    final hour = detail.hourFor(_weekday(date));
    if (hour == null || hour.isClosed) return const [];
    final opens = hour.opensAt;
    final closes = hour.closesAt;
    if (opens == null || closes == null) return const [];

    final start = _minutes(opens);
    final end = _minutes(closes);
    final now = DateTime.now();
    final isToday = _dateKey(date) == _dateKey(now);
    final nowMinutes = now.hour * 60 + now.minute;
    final eligible = specialists.map((item) => item.id).toList();
    final slots = <String>[];

    for (var minute = start; minute + 30 <= end; minute += 30) {
      if (isToday && minute <= nowMinutes) continue;
      final label = _clock(minute);
      if (_taken(date, label, eligible)) continue;
      slots.add(label);
    }
    return slots;
  }

  bool _taken(DateTime date, String slot, List<int> eligible) {
    final key = _dateKey(date);
    final rows = detail.booked.where(
      (item) => item.date == key && item.time == slot,
    );
    if (specialistId != null) {
      return rows.any((item) => item.specialistId == specialistId);
    }
    if (eligible.isEmpty) return false;
    final busy = rows.map((item) => item.specialistId).toSet();
    return eligible.every(busy.contains);
  }

  String _hoursLabel(SalonHour? hour) {
    if (hour == null || hour.isClosed || hour.opensAt == null) {
      return english ? 'Closed' : 'مغلق';
    }
    final open = _format12(hour.opensAt!);
    final close = _format12(hour.closesAt ?? hour.opensAt!);
    return english ? 'Open $open–$close' : 'مفتوح $open–$close';
  }

  Future<void> _openMaps(BuildContext context, SalonDetail salon) async {
    final lat = salon.latitude;
    final lng = salon.longitude;
    final uri = lat != null && lng != null
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(salon.mapQuery)}',
          );
    try {
      await SalonScreen.openMaps(uri);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            english ? 'Could not open Google Maps.' : 'تعذر فتح خرائط جوجل.',
          ),
        ),
      );
    }
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: SalonTheme.of(context).accent,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _meta(
    BuildContext context,
    IconData icon,
    String text, {
    Key? key,
    VoidCallback? onTap,
  }) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: SalonTheme.of(context).accent, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: onTap != null
                  ? SalonTheme.of(context).accent
                  : SalonTheme.of(context).soft,
              fontSize: 12,
              decoration: onTap != null ? TextDecoration.underline : null,
              decorationColor: SalonTheme.of(context).accent,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.english,
    required this.selected,
    required this.onTap,
  });

  final SalonServiceItem service;
  final bool english;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = service.price == service.price.roundToDouble()
        ? service.price.toInt().toString()
        : service.price.toStringAsFixed(0);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: SalonTheme.of(context).line),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.nameFor(english),
                    style: TextStyle(
                      color: SalonTheme.of(context).accent,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    english
                        ? '${service.durationMinutes} min'
                        : '${service.durationMinutes} دقيقة',
                    style: TextStyle(
                      color: SalonTheme.of(context).soft,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              english ? '$amount EGP' : '$amount ج.م',
              style: TextStyle(
                color: SalonTheme.of(context).accent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_rounded,
                color: SalonTheme.of(context).accent,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpecialistChip extends StatelessWidget {
  const _SpecialistChip({
    required this.name,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 108,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? SalonTheme.of(context).accent
                    : SalonTheme.of(context).line,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SalonTheme.of(context).accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SalonTheme.of(context).soft,
                      fontSize: 11,
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

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.name,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SalonTheme.of(context).accent : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? SalonTheme.of(context).accent
                  : SalonTheme.of(context).line,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: selected
                      ? SalonTheme.of(context).ink
                      : SalonTheme.of(context).soft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                number,
                style: TextStyle(
                  color: selected
                      ? SalonTheme.of(context).ink
                      : SalonTheme.of(context).accent,
                  fontSize: 16,
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

class _TimeChip extends StatelessWidget {
  const _TimeChip({
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
      color: selected ? SalonTheme.of(context).accent : Colors.transparent,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? SalonTheme.of(context).accent
                  : SalonTheme.of(context).line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? SalonTheme.of(context).ink
                  : SalonTheme.of(context).accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.english});

  final SalonReviewItem review;
  final bool english;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SalonTheme.of(context).panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SalonTheme.of(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.customerName,
                  style: TextStyle(
                    color: SalonTheme.of(context).accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${'★' * review.rating}${'☆' * (5 - review.rating)}',
                style: TextStyle(
                  color: SalonTheme.of(context).accent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: TextStyle(
                color: SalonTheme.of(context).soft,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
          if (review.date.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.date,
              style: TextStyle(
                color: SalonTheme.of(context).deep,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

int _weekday(DateTime date) =>
    date.weekday == DateTime.sunday ? 0 : date.weekday;

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

int _minutes(String clock) {
  final parts = clock.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _clock(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _format12(String clock24) {
  final total = _minutes(clock24);
  var hour = total ~/ 60;
  final minute = (total % 60).toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '$hour:$minute $period';
}

String _dayName(int day, bool english) {
  const arabic = {
    0: 'الأحد',
    1: 'الإثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
  };
  const englishNames = {
    0: 'Sun',
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
  };
  return (english ? englishNames : arabic)[day] ?? '';
}
