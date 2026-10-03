import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../data/account_store.dart';
import '../data/auth_api.dart';
import '../data/salon_profile.dart';
import '../theme/settings_tone.dart';
import '../theme/system_bars.dart';
import '../widgets/salon_photo.dart';
import 'map_picker_screen.dart';

/// Lets a salon account edit its details, services and prices, specialists,
/// and working hours.
class SalonManageScreen extends StatefulWidget {
  const SalonManageScreen({super.key});

  static Future<String?> Function() pickImage = _pickImage;

  static Future<MapAddress?> Function(BuildContext context, LatLng? start)
  pickPlace = _pickPlace;

  @visibleForTesting
  static void useDefaults() {
    pickImage = _pickImage;
    pickPlace = _pickPlace;
  }

  static Future<String?> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return file?.path;
  }

  static Future<MapAddress?> _pickPlace(BuildContext context, LatLng? start) {
    return Navigator.of(context).push<MapAddress>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: 'موقع الصالون',
          confirmLabel: 'استخدام هذا الموقع',
          initial: start,
        ),
      ),
    );
  }

  @override
  State<SalonManageScreen> createState() => _SalonManageScreenState();
}

class _SalonManageScreenState extends State<SalonManageScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _about = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _address = TextEditingController();
  SalonProfile? _salon;
  List<OwnHour> _hours = const [];
  double? _lat;
  double? _lng;
  var _homeService = false;
  var _loading = true;
  var _busy = false;
  String? _loadError;

  SettingsTone get _tone => SettingsTone.of(AccountStore.instance.darkMode);

  bool get _english => Directionality.of(context) == TextDirection.ltr;

  String _t(String ar, String en) => _english ? en : ar;

  Widget _directed(Widget child) => Directionality(
    textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
    child: child,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _about,
      _city,
      _district,
      _address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      _apply(await SalonProfileApi.load(), details: true);
    } on SalonProfileException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'تعذر تحميل بيانات الصالون.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(SalonProfile salon, {bool details = false, bool hours = true}) {
    if (!mounted) return;
    setState(() {
      _salon = salon;
      if (hours) _hours = salon.hours;
      if (details) {
        _name.text = salon.name;
        _phone.text = salon.phone ?? '';
        _about.text = salon.about ?? '';
        _city.text = salon.city ?? '';
        _district.text = salon.district ?? '';
        _address.text = salon.address ?? '';
        _lat = salon.latitude;
        _lng = salon.longitude;
        _homeService = salon.homeService;
      }
    });
  }

  /// Runs a server call, applies the returned salon, and reports the result.
  Future<bool> _run(
    Future<SalonProfile> Function() call, {
    required String done,
    bool details = false,
    bool hours = false,
  }) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final salon = await call();
      _apply(salon, details: details, hours: hours);
      _toast(done);
      return true;
    } on SalonProfileException catch (error) {
      _toast(error.message, error: true);
    } catch (_) {
      _toast(_t('تعذر حفظ التعديل.', 'Could not save.'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFB04A4A) : _tone.panel,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _saveDetails() async {
    if (_name.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _address.text.trim().isEmpty) {
      _toast(
        _t(
          'اكتب اسم الصالون والمدينة والعنوان.',
          'Enter the salon name, city, and address.',
        ),
        error: true,
      );
      return;
    }
    await _run(
      () => SalonProfileApi.update({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'about': _about.text.trim(),
        'city': _city.text.trim(),
        'district': _district.text.trim(),
        'address': _address.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'offers_home_service': _homeService,
      }),
      done: _t('تم حفظ بيانات الصالون.', 'Salon details saved.'),
      details: true,
    );
  }

  Future<void> _changeImage() async {
    String? path;
    try {
      path = await SalonManageScreen.pickImage();
    } catch (_) {
      _toast(_t('تعذر فتح الصور.', 'Could not open photos.'), error: true);
      return;
    }
    if (path == null) return;
    await _run(() async {
      await SalonProfileApi.uploadImage(path!);
      return SalonProfileApi.load();
    }, done: _t('تم تغيير صورة الصالون.', 'Photo updated.'));
  }

  Future<void> _pickLocation() async {
    final start = _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null;
    final place = await SalonManageScreen.pickPlace(context, start);
    if (place == null || !mounted) return;
    setState(() {
      _lat = place.latitude;
      _lng = place.longitude;
      if (_address.text.trim().isEmpty) _address.text = place.address;
      if (_city.text.trim().isEmpty && (place.city ?? '').isNotEmpty) {
        _city.text = place.city!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: tone.background,
        appBar: AppBar(
          backgroundColor: tone.background,
          foregroundColor: tone.text,
          elevation: 0,
          systemOverlayStyle: SystemBars.overlay(
            lightStatus: !tone.dark,
            lightNavigation: !tone.dark,
            statusColor: tone.background,
            navigationColor: tone.background,
          ),
          title: Text(_t('إدارة الصالون', 'Manage salon')),
          bottom: _salon == null
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: tone.accent,
                  unselectedLabelColor: tone.muted,
                  indicatorColor: tone.accent,
                  dividerColor: tone.line,
                  labelStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    Tab(
                      key: const Key('manage-tab-details'),
                      icon: const Icon(Icons.storefront_outlined, size: 20),
                      text: _t('البيانات', 'Details'),
                    ),
                    Tab(
                      key: const Key('manage-tab-services'),
                      icon: const Icon(Icons.content_cut_rounded, size: 20),
                      text: _t('الخدمات والأسعار', 'Services'),
                    ),
                    Tab(
                      key: const Key('manage-tab-team'),
                      icon: const Icon(Icons.people_alt_outlined, size: 20),
                      text: _t('الأخصائيون', 'Team'),
                    ),
                    Tab(
                      key: const Key('manage-tab-hours'),
                      icon: const Icon(Icons.schedule_rounded, size: 20),
                      text: _t('مواعيد العمل', 'Hours'),
                    ),
                  ],
                ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: tone.accent))
            : _salon == null
            ? _failed()
            : Stack(
                children: [
                  TabBarView(
                    children: [
                      _detailsTab(),
                      _servicesTab(),
                      _teamTab(),
                      _hoursTab(),
                    ],
                  ),
                  if (_busy)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: tone.accent,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _failed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: _tone.muted, size: 48),
            const SizedBox(height: 12),
            Text(
              _loadError ?? _t('تعذر التحميل.', 'Could not load.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: _tone.text),
            ),
            const SizedBox(height: 16),
            _button(
              key: const Key('manage-retry'),
              label: _t('إعادة المحاولة', 'Retry'),
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _subscriptionCard(SettingsTone tone, OwnSubscription sub) {
    final ending = sub.daysLeft <= 30;
    return Container(
      key: const Key('manage-subscription'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: tone.dark
              ? const [Color(0xFF2A2110), Color(0xFF121212)]
              : const [Color(0xFFFFF6DF), Color(0xFFFFFFFF)],
        ),
        border: Border.all(color: tone.accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.accent,
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: tone.ink,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.planName,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sub.isFree ? 'اشتراك مجاني • ' : ''}ساري حتى ${sub.endsAt ?? ''}',
                  style: TextStyle(color: tone.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${sub.daysLeft}',
                style: TextStyle(
                  color: ending ? const Color(0xFFE5A04B) : tone.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                'يوم متبقٍ',
                style: TextStyle(color: tone.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailsTab() {
    final salon = _salon!;
    final tone = _tone;
    final verified = salon.verificationStatus == 'verified';
    return ListView(
      key: const PageStorageKey('manage-details'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        if (salon.subscription != null) ...[
          _subscriptionCard(tone, salon.subscription!),
          const SizedBox(height: 16),
        ],
        GestureDetector(
          key: const Key('manage-image'),
          onTap: _busy ? null : _changeImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 170,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SalonPhoto(
                    url: salon.imageUrl,
                    asset: salonPhotoAsset(salon.name),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 14,
                    bottom: 12,
                    end: 14,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                salon.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if ((salon.category ?? '').isNotEmpty)
                                Text(
                                  salon.category!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_camera_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _t('تغيير الصورة', 'Change photo'),
                                style: const TextStyle(
                                  color: Colors.white,
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
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
              color: verified ? tone.accent : tone.muted,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              salon.verificationLabel ?? '',
              style: TextStyle(color: tone.muted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _section(_t('بيانات الصالون', 'Salon details')),
        _field(const Key('manage-name'), _name, _t('اسم الصالون', 'Name')),
        _field(
          const Key('manage-phone'),
          _phone,
          _t('هاتف الصالون', 'Phone'),
          keyboard: TextInputType.phone,
        ),
        _field(
          const Key('manage-about'),
          _about,
          _t('نبذة عن الصالون', 'About'),
          lines: 3,
        ),
        const SizedBox(height: 6),
        _section(_t('العنوان والموقع', 'Address and location')),
        _field(const Key('manage-city'), _city, _t('المدينة', 'City')),
        _field(const Key('manage-district'), _district, _t('الحي', 'District')),
        _field(
          const Key('manage-address'),
          _address,
          _t('العنوان بالتفصيل', 'Address'),
        ),
        OutlinedButton.icon(
          key: const Key('manage-location'),
          onPressed: _pickLocation,
          style: OutlinedButton.styleFrom(
            foregroundColor: tone.accent,
            side: BorderSide(color: tone.line),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.location_on_outlined),
          label: Text(
            _lat == null
                ? _t('تحديد الموقع على الخريطة', 'Pick on the map')
                : _t('تغيير الموقع على الخريطة', 'Change on the map'),
          ),
        ),
        const SizedBox(height: 12),
        _switchTile(
          key: const Key('manage-home-service'),
          icon: Icons.home_work_outlined,
          title: _t('خدمة منزلية', 'Home service'),
          subtitle: _t(
            'يمكن للعملاء طلب الخدمة في المنزل.',
            'Clients can book you at home.',
          ),
          value: _homeService,
          onChanged: (value) => setState(() => _homeService = value),
        ),
        const SizedBox(height: 20),
        _button(
          key: const Key('manage-save-details'),
          label: _t('حفظ البيانات', 'Save details'),
          icon: Icons.check_rounded,
          onPressed: _busy ? null : _saveDetails,
        ),
      ],
    );
  }

  Widget _servicesTab() {
    final salon = _salon!;
    final tone = _tone;
    return ListView(
      key: const PageStorageKey('manage-services'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        _button(
          key: const Key('manage-add-service'),
          label: _t('إضافة خدمة', 'Add service'),
          icon: Icons.add_rounded,
          onPressed: _busy ? null : _addService,
        ),
        const SizedBox(height: 16),
        if (salon.services.isEmpty)
          _emptyNote(
            Icons.content_cut_rounded,
            _t(
              'لا توجد خدمات بعد. أضف خدماتك وحدد أسعارها.',
              'No services yet. Add your services and prices.',
            ),
          ),
        for (final service in salon.services)
          Container(
            key: Key('manage-service-${service.id}'),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: tone.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tone.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _busy ? null : () => _editService(service),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tone.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.content_cut_rounded,
                        color: service.isActive ? tone.accent : tone.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: TextStyle(
                              color: service.isActive ? tone.text : tone.muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              decoration: service.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            [
                              _t(
                                '${service.durationMinutes} دقيقة',
                                '${service.durationMinutes} min',
                              ),
                              if (!service.isActive) _t('مخفية', 'Hidden'),
                            ].join(' • '),
                            style: TextStyle(color: tone.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(service.price),
                      key: Key('manage-service-price-${service.id}'),
                      style: TextStyle(
                        color: tone.accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Switch(
                      key: Key('manage-service-active-${service.id}'),
                      value: service.isActive,
                      activeThumbColor: tone.accent,
                      onChanged: _busy
                          ? null
                          : (value) => _run(
                              () => SalonProfileApi.updateService(service.id, {
                                'is_active': value,
                              }),
                              done: value
                                  ? _t('الخدمة ظاهرة الآن.', 'Service shown.')
                                  : _t('تم إخفاء الخدمة.', 'Service hidden.'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _teamTab() {
    final salon = _salon!;
    final tone = _tone;
    return ListView(
      key: const PageStorageKey('manage-team'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        _button(
          key: const Key('manage-add-specialist'),
          label: _t('إضافة أخصائي', 'Add specialist'),
          icon: Icons.person_add_alt_1_rounded,
          onPressed: _busy ? null : () => _editSpecialist(null),
        ),
        const SizedBox(height: 16),
        if (salon.specialists.isEmpty)
          _emptyNote(
            Icons.people_alt_outlined,
            _t('لا يوجد أخصائيون بعد.', 'No specialists yet.'),
          ),
        for (final person in salon.specialists)
          Container(
            key: Key('manage-specialist-${person.id}'),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: tone.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tone.line),
            ),
            child: ListTile(
              onTap: _busy ? null : () => _editSpecialist(person),
              contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 4, 6, 4),
              leading: CircleAvatar(
                backgroundColor: tone.accent.withValues(alpha: 0.16),
                child: Text(
                  person.name.isEmpty ? '?' : person.name.characters.first,
                  style: TextStyle(
                    color: tone.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                person.name,
                style: TextStyle(
                  color: person.isActive ? tone.text : tone.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                [
                  if ((person.title ?? '').isNotEmpty) person.title!,
                  if (!person.isActive) _t('متوقف', 'Paused'),
                ].join(' • '),
                style: TextStyle(color: tone.muted, fontSize: 12),
              ),
              trailing: Switch(
                key: Key('manage-specialist-active-${person.id}'),
                value: person.isActive,
                activeThumbColor: tone.accent,
                onChanged: _busy
                    ? null
                    : (value) => _run(
                        () => SalonProfileApi.updateSpecialist(person.id, {
                          'is_active': value,
                        }),
                        done: value
                            ? _t('الأخصائي متاح.', 'Specialist active.')
                            : _t('تم إيقاف الأخصائي.', 'Specialist paused.'),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _hoursTab() {
    final tone = _tone;
    return ListView(
      key: const PageStorageKey('manage-hours'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text(
          _t(
            'حدد أيام وساعات العمل. يظهر للعملاء الأوقات المتاحة فقط.',
            'Set your days and hours. Clients only see open times.',
          ),
          style: TextStyle(color: tone.muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 14),
        for (final (index, hour) in _hours.indexed)
          Container(
            key: Key('manage-hour-${hour.day}'),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              color: tone.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tone.line),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    hour.label,
                    style: TextStyle(
                      color: hour.isClosed ? tone.muted : tone.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: hour.isClosed
                      ? Text(
                          _t('مغلق', 'Closed'),
                          style: TextStyle(color: tone.muted),
                        )
                      : Row(
                          children: [
                            _timeChip(
                              Key('manage-hour-open-${hour.day}'),
                              hour.opensAt ?? '10:00',
                              (value) => _setHour(
                                index,
                                hour.copyWith(opensAt: value),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '–',
                                style: TextStyle(color: tone.muted),
                              ),
                            ),
                            _timeChip(
                              Key('manage-hour-close-${hour.day}'),
                              hour.closesAt ?? '22:00',
                              (value) => _setHour(
                                index,
                                hour.copyWith(closesAt: value),
                              ),
                            ),
                          ],
                        ),
                ),
                Switch(
                  key: Key('manage-hour-switch-${hour.day}'),
                  value: !hour.isClosed,
                  activeThumbColor: tone.accent,
                  onChanged: (open) => _setHour(
                    index,
                    hour.copyWith(
                      isClosed: !open,
                      opensAt: hour.opensAt ?? '10:00',
                      closesAt: hour.closesAt ?? '22:00',
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _button(
          key: const Key('manage-save-hours'),
          label: _t('حفظ المواعيد', 'Save hours'),
          icon: Icons.check_rounded,
          onPressed: _busy
              ? null
              : () => _run(
                  () => SalonProfileApi.saveHours(_hours),
                  done: _t('تم حفظ مواعيد العمل.', 'Hours saved.'),
                  hours: true,
                ),
        ),
      ],
    );
  }

  void _setHour(int index, OwnHour hour) {
    setState(() {
      _hours = [..._hours]..[index] = hour;
    });
  }

  Widget _timeChip(Key key, String value, ValueChanged<String> onPicked) {
    final tone = _tone;
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final parts = value.split(':');
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.tryParse(parts.first) ?? 10,
            minute: int.tryParse(parts.last) ?? 0,
          ),
        );
        if (picked == null) return;
        onPicked(
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tone.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          value,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: tone.accent, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _addService() async {
    final catalog = _salon!.catalog;
    if (catalog.isEmpty) {
      _toast(
        _t(
          'أضفت كل الخدمات المتاحة لقسم صالونك.',
          'You already added every available service.',
        ),
      );
      return;
    }
    final result = await showModalBottomSheet<_ServiceDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _tone.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _directed(
        _ServiceSheet(
          tone: _tone,
          english: _english,
          catalog: catalog,
          specialists: _salon!.specialists,
        ),
      ),
    );
    if (result == null) return;
    await _run(
      () => SalonProfileApi.addService(
        catalogId: result.catalogId!,
        price: result.price,
        durationMinutes: result.durationMinutes,
      ),
      done: _t('تمت إضافة الخدمة.', 'Service added.'),
    );
  }

  Future<void> _editService(OwnService service) async {
    final result = await showModalBottomSheet<_ServiceDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _tone.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _directed(
        _ServiceSheet(
          tone: _tone,
          english: _english,
          service: service,
          specialists: _salon!.specialists,
        ),
      ),
    );
    if (result == null) return;
    if (result.delete) {
      await _run(
        () => SalonProfileApi.deleteService(service.id),
        done: _t('تم حذف الخدمة.', 'Service deleted.'),
      );
      return;
    }
    await _run(
      () => SalonProfileApi.updateService(service.id, {
        'price': result.price,
        'duration_minutes': result.durationMinutes,
        'description': result.description,
        'is_active': result.isActive,
        'specialist_ids': result.specialistIds,
      }),
      done: _t('تم حفظ الخدمة.', 'Service saved.'),
    );
  }

  Future<void> _editSpecialist(OwnSpecialist? person) async {
    final result = await showModalBottomSheet<_SpecialistDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _tone.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _directed(
        _SpecialistSheet(tone: _tone, english: _english, person: person),
      ),
    );
    if (result == null) return;
    if (person == null) {
      await _run(
        () => SalonProfileApi.addSpecialist(result.toJson()),
        done: _t('تمت إضافة الأخصائي.', 'Specialist added.'),
      );
    } else if (result.delete) {
      await _run(
        () => SalonProfileApi.deleteSpecialist(person.id),
        done: _t('تم حذف الأخصائي.', 'Specialist deleted.'),
      );
    } else {
      await _run(
        () => SalonProfileApi.updateSpecialist(person.id, result.toJson()),
        done: _t('تم حفظ الأخصائي.', 'Specialist saved.'),
      );
    }
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: _tone.accent,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _field(
    Key key,
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _input(
        _tone,
        key: key,
        controller: controller,
        label: label,
        keyboard: keyboard,
        lines: lines,
      ),
    );
  }

  Widget _switchTile({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final tone = _tone;
    return Container(
      decoration: BoxDecoration(
        color: tone.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.line),
      ),
      child: SwitchListTile(
        key: key,
        value: value,
        onChanged: onChanged,
        activeThumbColor: tone.accent,
        secondary: Icon(icon, color: tone.accent),
        title: Text(
          title,
          style: TextStyle(color: tone.text, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: tone.muted, fontSize: 12),
        ),
      ),
    );
  }

  Widget _emptyNote(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, color: _tone.muted, size: 40),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: _tone.muted),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required Key key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
  }) {
    final tone = _tone;
    return FilledButton.icon(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: tone.accent,
        foregroundColor: tone.ink,
        disabledBackgroundColor: tone.accent.withValues(alpha: 0.35),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon ?? Icons.check_rounded),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  String _money(double value) {
    final digits = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return _english ? 'EGP $digits' : '$digits ج.م';
  }
}

Widget _input(
  SettingsTone tone, {
  required Key key,
  required TextEditingController controller,
  required String label,
  TextInputType? keyboard,
  int lines = 1,
  String? suffix,
}) {
  return TextField(
    key: key,
    controller: controller,
    keyboardType: keyboard,
    minLines: lines,
    maxLines: lines,
    style: TextStyle(color: tone.text),
    cursorColor: tone.accent,
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      labelStyle: TextStyle(color: tone.muted),
      suffixStyle: TextStyle(color: tone.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tone.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tone.accent),
      ),
    ),
  );
}

double? _number(String text) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final char in text.trim().characters) {
    final index = arabic.indexOf(char);
    buffer.write(index >= 0 ? '$index' : (char == '٫' ? '.' : char));
  }
  return double.tryParse(buffer.toString());
}

class _ServiceDraft {
  const _ServiceDraft({
    this.catalogId,
    this.price = 0,
    this.durationMinutes,
    this.description,
    this.isActive = true,
    this.specialistIds = const [],
    this.delete = false,
  });

  final int? catalogId;
  final double price;
  final int? durationMinutes;
  final String? description;
  final bool isActive;
  final List<int> specialistIds;
  final bool delete;
}

class _ServiceSheet extends StatefulWidget {
  const _ServiceSheet({
    required this.tone,
    required this.english,
    required this.specialists,
    this.catalog = const [],
    this.service,
  });

  final SettingsTone tone;
  final bool english;
  final List<CatalogOption> catalog;
  final List<OwnSpecialist> specialists;
  final OwnService? service;

  @override
  State<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<_ServiceSheet> {
  late final _price = TextEditingController(
    text: widget.service == null ? '' : _plain(widget.service!.price),
  );
  late final _duration = TextEditingController(
    text: widget.service == null ? '' : '${widget.service!.durationMinutes}',
  );
  late final _description = TextEditingController(
    text: widget.service?.description ?? '',
  );
  late var _active = widget.service?.isActive ?? true;
  late final _team = {...?widget.service?.specialistIds};
  int? _catalogId;
  String? _error;

  String _t(String ar, String en) => widget.english ? en : ar;

  static String _plain(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  @override
  void dispose() {
    _price.dispose();
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final price = _number(_price.text);
    final duration = _number(_duration.text)?.round();
    if (widget.service == null && _catalogId == null) {
      setState(() => _error = _t('اختر الخدمة.', 'Pick a service.'));
      return;
    }
    if (price == null || price < 1) {
      setState(() => _error = _t('اكتب سعراً صحيحاً.', 'Enter a valid price.'));
      return;
    }
    if (_duration.text.trim().isNotEmpty &&
        (duration == null || duration < 5 || duration > 600)) {
      setState(
        () => _error = _t(
          'المدة بين 5 و600 دقيقة.',
          'Duration must be 5–600 minutes.',
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _ServiceDraft(
        catalogId: _catalogId,
        price: price,
        durationMinutes: duration ?? widget.service?.durationMinutes,
        description: _description.text.trim(),
        isActive: _active,
        specialistIds: _team.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final editing = widget.service != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tone.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              editing
                  ? widget.service!.name
                  : _t('إضافة خدمة', 'Add a service'),
              style: TextStyle(
                color: tone.accent,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            if (!editing) ...[
              Text(
                _t('اختر من خدمات القسم', 'Pick from your category'),
                style: TextStyle(color: tone.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in widget.catalog)
                    ChoiceChip(
                      key: Key('manage-catalog-${item.id}'),
                      label: Text(item.name),
                      selected: _catalogId == item.id,
                      selectedColor: tone.accent,
                      backgroundColor: tone.background,
                      side: BorderSide(color: tone.line),
                      labelStyle: TextStyle(
                        color: _catalogId == item.id ? tone.ink : tone.text,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setState(() {
                        _catalogId = item.id;
                        _error = null;
                        if (_duration.text.isEmpty &&
                            item.durationMinutes != null) {
                          _duration.text = '${item.durationMinutes}';
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: _input(
                    tone,
                    key: const Key('manage-service-price'),
                    controller: _price,
                    label: _t('السعر', 'Price'),
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    suffix: _t('ج.م', 'EGP'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _input(
                    tone,
                    key: const Key('manage-service-duration'),
                    controller: _duration,
                    label: _t('المدة', 'Duration'),
                    keyboard: TextInputType.number,
                    suffix: _t('دقيقة', 'min'),
                  ),
                ),
              ],
            ),
            if (editing) ...[
              const SizedBox(height: 12),
              _input(
                tone,
                key: const Key('manage-service-description'),
                controller: _description,
                label: _t('وصف الخدمة', 'Description'),
                lines: 2,
              ),
              if (widget.specialists.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _t('من يقدم هذه الخدمة؟', 'Who offers it?'),
                  style: TextStyle(color: tone.muted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final person in widget.specialists)
                      FilterChip(
                        key: Key('manage-service-team-${person.id}'),
                        label: Text(person.name),
                        selected: _team.contains(person.id),
                        selectedColor: tone.accent.withValues(alpha: 0.25),
                        checkmarkColor: tone.accent,
                        backgroundColor: tone.background,
                        side: BorderSide(color: tone.line),
                        labelStyle: TextStyle(color: tone.text),
                        onSelected: (on) => setState(
                          () => on
                              ? _team.add(person.id)
                              : _team.remove(person.id),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('manage-service-visible'),
                contentPadding: EdgeInsets.zero,
                value: _active,
                activeThumbColor: tone.accent,
                onChanged: (value) => setState(() => _active = value),
                title: Text(
                  _t('ظاهرة للعملاء', 'Visible to clients'),
                  style: TextStyle(color: tone.text),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('manage-service-error'),
                style: const TextStyle(color: Color(0xFFE56B6B)),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('manage-service-save'),
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: tone.accent,
                foregroundColor: tone.ink,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                editing ? _t('حفظ', 'Save') : _t('إضافة', 'Add'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (editing)
              TextButton.icon(
                key: const Key('manage-service-delete'),
                onPressed: () => _confirmDelete(context),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFE56B6B),
                ),
                label: Text(
                  _t('حذف الخدمة', 'Delete service'),
                  style: const TextStyle(color: Color(0xFFE56B6B)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext sheet) async {
    final yes = await _confirm(
      sheet,
      widget.tone,
      _t('حذف الخدمة؟', 'Delete service?'),
      _t(
        'لن تظهر للعملاء بعد الآن. الخدمات التي لها حجوزات لا تحذف ويمكن إخفاؤها.',
        'Services with bookings can only be hidden.',
      ),
      _t('حذف', 'Delete'),
      _t('تراجع', 'Keep'),
    );
    if (yes && sheet.mounted) {
      Navigator.pop(sheet, const _ServiceDraft(delete: true));
    }
  }
}

class _SpecialistDraft {
  const _SpecialistDraft({
    this.name = '',
    this.title = '',
    this.phone = '',
    this.delete = false,
  });

  final String name;
  final String title;
  final String phone;
  final bool delete;

  Map<String, Object?> toJson() => {
    'name': name,
    'title': title,
    'phone': phone,
  };
}

class _SpecialistSheet extends StatefulWidget {
  const _SpecialistSheet({
    required this.tone,
    required this.english,
    this.person,
  });

  final SettingsTone tone;
  final bool english;
  final OwnSpecialist? person;

  @override
  State<_SpecialistSheet> createState() => _SpecialistSheetState();
}

class _SpecialistSheetState extends State<_SpecialistSheet> {
  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late final _title = TextEditingController(text: widget.person?.title ?? '');
  late final _phone = TextEditingController(text: widget.person?.phone ?? '');
  String? _error;

  String _t(String ar, String en) => widget.english ? en : ar;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final editing = widget.person != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tone.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              editing
                  ? _t('تعديل الأخصائي', 'Edit specialist')
                  : _t('إضافة أخصائي', 'Add specialist'),
              style: TextStyle(
                color: tone.accent,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _input(
              tone,
              key: const Key('manage-specialist-name'),
              controller: _name,
              label: _t('الاسم', 'Name'),
            ),
            const SizedBox(height: 12),
            _input(
              tone,
              key: const Key('manage-specialist-title'),
              controller: _title,
              label: _t('التخصص (حلاق، خبيرة مكياج...)', 'Title'),
            ),
            const SizedBox(height: 12),
            _input(
              tone,
              key: const Key('manage-specialist-phone'),
              controller: _phone,
              label: _t('الهاتف (اختياري)', 'Phone (optional)'),
              keyboard: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFE56B6B))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('manage-specialist-save'),
              onPressed: () {
                if (_name.text.trim().isEmpty) {
                  setState(
                    () => _error = _t('اكتب اسم الأخصائي.', 'Enter a name.'),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  _SpecialistDraft(
                    name: _name.text.trim(),
                    title: _title.text.trim(),
                    phone: _phone.text.trim(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: tone.accent,
                foregroundColor: tone.ink,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                editing ? _t('حفظ', 'Save') : _t('إضافة', 'Add'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (editing)
              TextButton.icon(
                key: const Key('manage-specialist-delete'),
                onPressed: () async {
                  final yes = await _confirm(
                    context,
                    tone,
                    _t('حذف الأخصائي؟', 'Delete specialist?'),
                    _t(
                      'الأخصائي الذي له حجوزات لا يحذف ويمكن إيقافه.',
                      'Specialists with bookings can only be paused.',
                    ),
                    _t('حذف', 'Delete'),
                    _t('تراجع', 'Keep'),
                  );
                  if (yes && context.mounted) {
                    Navigator.pop(
                      context,
                      const _SpecialistDraft(delete: true),
                    );
                  }
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFE56B6B),
                ),
                label: Text(
                  _t('حذف الأخصائي', 'Delete specialist'),
                  style: const TextStyle(color: Color(0xFFE56B6B)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context,
  SettingsTone tone,
  String title,
  String body,
  String yes,
  String no,
) async {
  final direction = Directionality.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialog) => Directionality(
      textDirection: direction,
      child: AlertDialog(
        backgroundColor: tone.panel,
        title: Text(title, style: TextStyle(color: tone.accent)),
        content: Text(body, style: TextStyle(color: tone.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(no, style: TextStyle(color: tone.muted)),
          ),
          TextButton(
            key: const Key('manage-confirm-delete'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(
              yes,
              style: const TextStyle(
                color: Color(0xFFE56B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return answer == true;
}
