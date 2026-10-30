import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzayen/data/account_api.dart';
import 'package:muzayen/data/account_store.dart';
import 'package:muzayen/data/auth_api.dart';
import 'package:muzayen/data/salon_catalog.dart';
import 'package:muzayen/data/salon_profile.dart';
import 'package:muzayen/data/subscription_plans.dart';
import 'package:muzayen/screens/map_picker_screen.dart';
import 'package:muzayen/theme/app_colors.dart';
import 'package:muzayen/theme/settings_tone.dart';
import 'package:muzayen/theme/system_bars.dart';
import 'package:muzayen/widgets/account_avatar.dart';
import 'package:muzayen/widgets/brand_hero.dart';
import 'package:muzayen/widgets/plan_picker.dart';

enum _SalonStep {
  plan(
    'اختر باقة الاشتراك',
    'Choose a subscription plan',
    'ابدأ رحلتك مع المزين، ويمكنك الترقية لاحقاً.',
    'Start with Al-Muzayyin — you can upgrade later.',
    Icons.workspace_premium_outlined,
  ),
  services(
    'الخدمات والأسعار',
    'Services & prices',
    'اختر أقسام مركز التجميل وحدد سعر كل خدمة.',
    'Pick your center categories and set each service price.',
    Icons.content_cut_rounded,
  ),
  team(
    'فريق العمل',
    'Team',
    'أضف الأخصائيين الذين يستقبلون الحجوزات.',
    'Add the specialists who take bookings.',
    Icons.groups_2_outlined,
  ),
  hours(
    'مواعيد العمل',
    'Working hours',
    'حدد أيام وساعات استقبال العملاء.',
    'Set the days and hours you welcome clients.',
    Icons.schedule_rounded,
  ),
  details(
    'بيانات مركز التجميل',
    'Beauty center details',
    'الصورة وبيانات التواصل والعنوان.',
    'Photos, contact details, and address.',
    Icons.storefront_outlined,
  );

  const _SalonStep(
    this.titleAr,
    this.titleEn,
    this.hintAr,
    this.hintEn,
    this.icon,
  );

  final String titleAr;
  final String titleEn;
  final String hintAr;
  final String hintEn;
  final IconData icon;

  String title(bool english) => english ? titleEn : titleAr;
  String hint(bool english) => english ? hintEn : hintAr;
}

class _TeamMember {
  final name = TextEditingController();
  final nameEn = TextEditingController();
  final title = TextEditingController();
  final titleEn = TextEditingController();

  void dispose() {
    name.dispose();
    nameEn.dispose();
    title.dispose();
    titleEn.dispose();
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static Future<String?> Function(ImageSource source) pickPhoto = _pick;
  static Future<List<String>> Function() pickSalonImages = _pickMany;
  static Future<String?> Function() pickSalonVideo = _pickVideo;

  static void useDefaultPicker() {
    pickPhoto = _pick;
    pickSalonImages = _pickMany;
    pickSalonVideo = _pickVideo;
  }

  static Future<String?> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    return file?.path;
  }

  static Future<List<String>> _pickMany() async {
    final files = await ImagePicker().pickMultiImage(
      maxWidth: 1200,
      imageQuality: 85,
      limit: 8,
    );
    return [for (final file in files) file.path];
  }

  static Future<String?> _pickVideo() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    return file?.path;
  }

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _nameEn = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _type;
  MapAddress? _address;
  bool _busy = false;
  bool _hidden = true;
  String? _error;
  Future<List<CatalogCategory>>? _catalog;
  List<CatalogCategory>? _categories;

  bool get _english => AccountStore.instance.isEnglish;
  String _t(String ar, String en) => _english ? en : ar;

  static const _dayNames = <(int, String, String)>[
    (6, 'السبت', 'Saturday'),
    (0, 'الأحد', 'Sunday'),
    (1, 'الإثنين', 'Monday'),
    (2, 'الثلاثاء', 'Tuesday'),
    (3, 'الأربعاء', 'Wednesday'),
    (4, 'الخميس', 'Thursday'),
    (5, 'الجمعة', 'Friday'),
  ];

  String _dayLabel(int day) {
    for (final item in _dayNames) {
      if (item.$1 == day) return _english ? item.$3 : item.$2;
    }
    return '';
  }

  void _loadCatalog() {
    _catalog = SalonCatalogApi.load().then((items) {
      if (items.isNotEmpty) _categories = items;
      return items;
    });
  }

  Future<List<SubscriptionPlan>>? _plansFuture;
  List<SubscriptionPlan> _plans = const [];
  int? _planId;
  bool _terms = false;
  bool _plansLoading = false;
  int _page = 0;
  final List<_TeamMember> _team = [_TeamMember()];
  List<OwnHour> _hours = [
    for (final item in _dayNames)
      OwnHour(
        day: item.$1,
        label: item.$2,
        isClosed: false,
        opensAt: '10:00',
        closesAt: '22:00',
      ),
  ];

  void _loadPlans() {
    _plansLoading = true;
    _plansFuture = SubscriptionPlansApi.load()
        .whenComplete(() {
          _plansLoading = false;
        })
        .then((items) {
          _plans = items;
          if (items.isNotEmpty && !items.any((item) => item.id == _planId)) {
            _planId = items
                .firstWhere(
                  (item) => item.isFeatured,
                  orElse: () => items.first,
                )
                .id;
            _terms = false;
          }
          if (mounted) setState(() {});
          return items;
        });
  }

  SubscriptionPlan? get _plan {
    for (final plan in _plans) {
      if (plan.id == _planId) return plan;
    }
    return null;
  }

  final List<int> _categoryIds = [];
  final Set<int> _services = {};
  final Map<int, TextEditingController> _prices = {};
  String? _photo;
  final List<String> _salonPhotos = [];
  String? _salonVideo;
  String? _healthCertificate;
  final _nationalId = TextEditingController();

  List<CatalogCategory> get _selectedCategories {
    final catalog = _categories ?? const <CatalogCategory>[];
    return [
      for (final id in _categoryIds)
        for (final category in catalog)
          if (category.id == id) category,
    ];
  }

  Future<void> _choosePhoto() => _pickInto('customer');

  Future<void> _chooseHealthCertificate() => _pickInto('health');

  Future<void> _pickInto(String target) async {
    final current = switch (target) {
      'health' => _healthCertificate,
      _ => _photo,
    };
    void put(String? path) => setState(() {
      switch (target) {
        case 'health':
          _healthCertificate = path;
        default:
          _photo = path;
      }
      _error = null;
    });
    final tone = SettingsTone.of(AccountStore.instance.darkMode);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: tone.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) => Directionality(
        textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _photoAction(
                  sheet,
                  tone,
                  'gallery',
                  Icons.photo_library_outlined,
                  _t('اختيار من معرض الصور', 'Choose from gallery'),
                ),
                _photoAction(
                  sheet,
                  tone,
                  'camera',
                  Icons.photo_camera_outlined,
                  _t('التقاط صورة بالكاميرا', 'Take a photo'),
                ),
                if (current != null)
                  _photoAction(
                    sheet,
                    tone,
                    'remove',
                    Icons.delete_outline,
                    _t('إزالة الصورة', 'Remove photo'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'remove') {
      put(null);
      return;
    }
    try {
      final path = await RegisterScreen.pickPhoto(
        action == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (path == null || !mounted) return;
      put(path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('تعذر فتح الصور.', 'Could not open photos.'))));
    }
  }

  Future<void> _addSalonPhotos() async {
    try {
      final paths = await RegisterScreen.pickSalonImages();
      if (paths.isEmpty || !mounted) return;
      setState(() {
        for (final path in paths) {
          if (_salonPhotos.length >= 8) break;
          if (!_salonPhotos.contains(path)) _salonPhotos.add(path);
        }
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('تعذر فتح الصور.', 'Could not open photos.'))));
    }
  }

  Future<void> _addSalonVideo() async {
    if (_salonVideo != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('يمكنك رفع فيديو واحد فقط.', 'You can upload only one video.'))),
      );
      return;
    }
    try {
      final path = await RegisterScreen.pickSalonVideo();
      if (path == null || !mounted) return;
      setState(() {
        _salonVideo = path;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('تعذر فتح الفيديو.', 'Could not open the video.'))));
    }
  }

  void _removeSalonPhotoAt(int index) {
    setState(() {
      _salonPhotos.removeAt(index);
      _error = null;
    });
  }

  Widget _photoAction(
    BuildContext sheet,
    SettingsTone tone,
    String value,
    IconData icon,
    String label,
  ) {
    return ListTile(
      key: Key('register-photo-$value'),
      leading: Icon(icon, color: tone.accent),
      title: Text(label, style: TextStyle(color: tone.text)),
      onTap: () => Navigator.of(sheet).pop(value),
    );
  }

  Widget _photoPicker(SettingsTone tone) {
    return Column(
      children: [
        GestureDetector(
          key: const Key('register-photo'),
          onTap: _choosePhoto,
          child: AccountAvatar(
            photoPath: _photo,
            tone: tone,
            size: 104,
            onEdit: _choosePhoto,
            editKey: const Key('register-photo-edit'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _photo == null ? _t('أضف صورتك الشخصية (اختياري)', 'Add your photo (optional)') : _t('تم اختيار الصورة', 'Photo selected'),
          key: const Key('register-photo-label'),
          style: TextStyle(color: tone.muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _salonPhotoPicker(SettingsTone tone) {
    final hasMedia = _salonPhotos.isNotEmpty || _salonVideo != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: tone.panel,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            key: const Key('register-salon-photo'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasMedia ? tone.accent : tone.line,
                width: hasMedia ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _t('صور وفيديو السليدر', 'Slider photos & video'),
                  key: const Key('register-salon-photo-label'),
                  style: TextStyle(
                    color: tone.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('حتى ٨ صور، وفيديو واحد اختياري داخل سليدر صفحة المركز', 'Up to 8 photos and one optional video for the center page slider'),
                  style: TextStyle(color: tone.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_salonPhotos.isNotEmpty)
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _salonPhotos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final path = _salonPhotos[index];
                        final file = File(path);
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: file.existsSync()
                                  ? Image.file(
                                      file,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                    )
                                  : ColoredBox(
                                      color: tone.line,
                                      child: SizedBox(
                                        width: 92,
                                        height: 92,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: tone.muted,
                                        ),
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: InkWell(
                                onTap: () => _removeSalonPhotoAt(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (_salonPhotos.isNotEmpty) const SizedBox(height: 12),
                if (_salonVideo != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: tone.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tone.accent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.videocam_rounded, color: tone.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _t('تم اختيار فيديو للسليدر', 'Slider video selected'),
                            style: TextStyle(
                              color: tone.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _salonVideo = null;
                            _error = null;
                          }),
                          icon: Icon(Icons.delete_outline, color: tone.muted),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('register-salon-add-photos'),
                        onPressed: _salonPhotos.length >= 8
                            ? null
                            : _addSalonPhotos,
                        icon: Icon(Icons.add_photo_alternate_outlined,
                            color: tone.accent),
                        label: Text(
                          _salonPhotos.isEmpty
                              ? _t('إضافة صور', 'Add photos')
                              : _t('إضافة صور (${_salonPhotos.length}/8)', 'Add photos (${_salonPhotos.length}/8)'),
                          style: TextStyle(color: tone.text),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: tone.line),
                          foregroundColor: tone.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('register-salon-add-video'),
                        onPressed: _salonVideo == null ? _addSalonVideo : null,
                        icon: Icon(Icons.video_library_outlined,
                            color: tone.accent),
                        label: Text(
                          _salonVideo == null ? _t('إضافة فيديو', 'Add video') : _t('فيديو جاهز', 'Video ready'),
                          style: TextStyle(color: tone.text),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: tone.line),
                          foregroundColor: tone.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _healthCertificatePicker(SettingsTone tone) {
    final path = _healthCertificate;
    final file = path == null ? null : File(path);
    final hasImage = file != null && file.existsSync();
    return Material(
      color: tone.panel,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('register-health-certificate'),
        onTap: _chooseHealthCertificate,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: path == null ? tone.line : tone.accent,
              width: path == null ? 1 : 1.5,
            ),
            image: hasImage
                ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                : null,
          ),
          child: Stack(
            children: [
              if (!hasImage)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        color: tone.accent,
                        size: 38,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        path == null
                            ? _t('ارفع الشهادة الصحية', 'Upload health certificate')
                            : _t('تم اختيار الشهادة', 'Certificate selected'),
                        key: const Key('register-health-certificate-label'),
                        style: TextStyle(
                          color: tone.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t('صورة واضحة للشهادة الصحية سارية', 'A clear photo of a valid health certificate'),
                        style: TextStyle(color: tone.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              if (path != null)
                PositionedDirectional(
                  end: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: tone.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 14, color: tone.ink),
                        const SizedBox(width: 4),
                        Text(
                          _t('تغيير', 'Change'),
                          style: TextStyle(
                            color: tone.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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

  void _chooseType(String type) {
    setState(() {
      _type = type;
      _error = null;
      if (type == 'salon' && _categories == null) _loadCatalog();
      if (type == 'salon' && _plansFuture == null) _loadPlans();
    });
  }

  void _toggleCategory(CatalogCategory category) {
    setState(() {
      if (_categoryIds.contains(category.id)) {
        _categoryIds.remove(category.id);
        for (final item in category.services) {
          _services.remove(item.id);
        }
      } else {
        _categoryIds.add(category.id);
      }
      _error = null;
    });
  }

  void _toggleService(int id) {
    setState(() {
      if (!_services.remove(id)) _services.add(id);
      _error = null;
    });
  }

  Color _frameFor(String slug) {
    return switch (slug) {
      'women' => SalonPalette.blush.accent,
      'kids' => SalonPalette.kids.accent,
      _ => AppColors.gold,
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _nameEn.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _nationalId.dispose();
    for (final controller in _prices.values) {
      controller.dispose();
    }
    for (final member in _team) {
      member.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<MapAddress>(
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (picked == null || !mounted) return;
    setState(() => _address = picked);
  }

  _SalonStep? get _current =>
      _type == 'salon' && _page > 0 ? _SalonStep.values[_page - 1] : null;

  Map<int, double>? _servicePrices() {
    final prices = <int, double>{};
    for (final id in _services.toList()..sort()) {
      final value = double.tryParse(
        _normalizeDigits(_prices[id]?.text ?? '').trim(),
      );
      if (value == null || value <= 0) return null;
      prices[id] = value;
    }
    return prices;
  }

  String? _check(_SalonStep step) {
    switch (step) {
      case _SalonStep.plan:
        if (_plansLoading) return _t('انتظر تحميل الباقات.', 'Wait for plans to load.');
        final plan = _plan;
        if (_plans.isNotEmpty && plan == null) return _t('اختر باقة الاشتراك.', 'Choose a subscription plan.');
        if (plan != null && plan.terms.isNotEmpty && !_terms) {
          return _t('يجب الموافقة على قوانين الاشتراك أولاً.', 'Please accept the subscription terms first.');
        }
      case _SalonStep.services:
        if (_categoryIds.isEmpty) return _t('اختر قسماً واحداً على الأقل.', 'Select at least one category.');
        if (_services.isEmpty) {
          return _t('اختر خدمة واحدة على الأقل من خدمات الأقسام.', 'Select at least one service from the categories.');
        }
        final limit = _plan?.maxServices;
        if (limit != null && _services.length > limit) {
          return _t(
            '${_plan!.nameFor(false)} تسمح بحد أقصى $limit خدمة.',
            '${_plan!.nameFor(true)} allows up to $limit services.',
          );
        }
        if (_servicePrices() == null) return _t('حدد سعر كل خدمة مختارة.', 'Set a price for each selected service.');
      case _SalonStep.team:
        if (_team.isEmpty) return _t('أضف أخصائياً واحداً على الأقل.', 'Add at least one specialist.');
        if (_team.any((member) => member.name.text.trim().isEmpty)) {
          return _t('اكتب اسم كل أخصائي أو احذف الخانة الفارغة.', 'Enter each specialist name or remove the empty row.');
        }
        final limit = _plan?.maxSpecialists;
        if (limit != null && _team.length > limit) {
          return _t(
            '${_plan!.nameFor(false)} تسمح بحد أقصى $limit أخصائي.',
            '${_plan!.nameFor(true)} allows up to $limit specialists.',
          );
        }
      case _SalonStep.hours:
        if (_hours.every((hour) => hour.isClosed)) {
          return _t('افتح يوماً واحداً على الأقل.', 'Open at least one day.');
        }
        for (final hour in _hours) {
          if (!hour.isClosed &&
              (hour.closesAt ?? '').compareTo(hour.opensAt ?? '') <= 0) {
            final day = _dayLabel(hour.day);
            return _t(
              'وقت الإغلاق يجب أن يكون بعد وقت الفتح يوم $day.',
              'Closing time must be after opening time on $day.',
            );
          }
        }
      case _SalonStep.details:
        return _checkDetails();
    }
    return null;
  }

  String? _checkDetails() {
    if (_type == 'salon' &&
        _salonPhotos.isEmpty &&
        _salonVideo == null) {
      return _t('ارفع صورة واحدة على الأقل أو فيديو للسليدر.', 'Upload at least one photo or a slider video.');
    }
    if (_type == 'salon' && _healthCertificate == null) {
      return _t('ارفع صورة الشهادة الصحية.', 'Upload the health certificate photo.');
    }
    if (_type == 'salon') {
      final nationalId = _normalizeDigits(_nationalId.text).trim();
      if (!RegExp(r'^\d{14}$').hasMatch(nationalId)) {
        return _t('أدخل رقم البطاقة الشخصية ١٤ رقماً.', 'Enter the 14-digit national ID.');
      }
    }
    final address = _address;
    if (_name.text.trim().isEmpty ||
        !_email.text.trim().contains('@') ||
        _phone.text.trim().isEmpty ||
        _password.text.length < 6 ||
        address == null ||
        address.address.trim().isEmpty) {
      return _t('أكمل الاسم والبريد والهاتف والعنوان من الخريطة وكلمة مرور من ٦ أحرف على الأقل.', 'Complete name, email, phone, map address, and a password of at least 6 characters.');
    }
    return null;
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() {
      _page = page;
      _error = null;
    });
  }

  void _next() {
    if (_busy || _type != 'salon') return;
    final step = _current;
    if (step == null) {
      _go(1);
      return;
    }
    final error = _check(step);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (step == _SalonStep.details) {
      _submit();
      return;
    }
    _go(_page + 1);
  }

  void _back() {
    if (_page > 0 && !_busy) _go(_page - 1);
  }

  Future<void> _submit() async {
    if (_busy || _type == null) return;
    final salon = _type == 'salon';
    if (salon) {
      for (final step in _SalonStep.values) {
        final error = _check(step);
        if (error != null) {
          setState(() {
            _page = step.index + 1;
            _error = error;
          });
          return;
        }
      }
    } else {
      final error = _checkDetails();
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    final plan = salon ? _plan : null;
    final address = _address!;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await AuthApi.register(
        accountType: _type!,
        name: _name.text.trim(),
        nameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        address: address.address,
        city: address.city,
        latitude: address.latitude,
        longitude: address.longitude,
        notifications: AccountStore.instance.notifications,
        darkMode: AccountStore.instance.darkMode,
        locale: AccountStore.instance.locale == 'en' ? 'en' : 'ar',
        categoryId: salon ? _categoryIds.first : null,
        categoryIds: salon ? List<int>.from(_categoryIds) : null,
        nationalId: salon ? _normalizeDigits(_nationalId.text).trim() : null,
        servicePrices: salon ? _servicePrices()! : const {},
        planId: plan?.id,
        acceptTerms: _terms,
        specialists: salon
            ? [
                for (final member in _team)
                  {
                    'name': member.name.text.trim(),
                    'name_en': member.nameEn.text.trim().isEmpty
                        ? null
                        : member.nameEn.text.trim(),
                    'title': member.title.text.trim().isEmpty
                        ? null
                        : member.title.text.trim(),
                    'title_en': member.titleEn.text.trim().isEmpty
                        ? null
                        : member.titleEn.text.trim(),
                  },
              ]
            : null,
        hours: salon ? [for (final hour in _hours) hour.toJson()] : null,
      );
      if (!mounted) return;
      AccountStore.instance.applySession(session);
      final photo = _type == 'customer' ? _photo : null;
      if (photo != null) unawaited(AccountStore.instance.setPhoto(photo));
      if (salon && session.token.isNotEmpty) {
        final photos = List<String>.from(_salonPhotos);
        final video = _salonVideo;
        unawaited(() async {
          for (final path in photos) {
            try {
              await AccountApi.uploadSalonMedia(
                token: session.token,
                path: path,
                type: 'image',
              );
            } catch (_) {}
          }
          if (video != null) {
            try {
              await AccountApi.uploadSalonMedia(
                token: session.token,
                path: video,
                type: 'video',
              );
            } catch (_) {}
          }
        }());
      }
      final health = salon ? _healthCertificate : null;
      if (health != null && session.token.isNotEmpty) {
        unawaited(
          AccountApi.uploadHealthCertificate(
            token: session.token,
            path: health,
          ).catchError((_) {}),
        );
      }
      if (plan != null) {
        await showSubscriptionWelcome(
          context,
          plan,
          SettingsTone.of(AccountStore.instance.darkMode),
        );
        if (!mounted) return;
      }
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _t('تعذر الاتصال بالخادم.', 'Could not reach the server.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SettingsTone.of(AccountStore.instance.darkMode);
    final salon = _type == 'salon';
    final step = _current;

    final english = AccountStore.instance.isEnglish;
    return Directionality(
      textDirection: english ? TextDirection.ltr : TextDirection.rtl,
      child: PopScope(
        canPop: step == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: tone.background,
          appBar: AppBar(
            backgroundColor: tone.background,
            foregroundColor: tone.text,
            elevation: 0,
            title: step == null
                ? null
                : Text(
                    _t('تسجيل مركز تجميل', 'Beauty center signup'),
                    style: TextStyle(
                      color: tone.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
            centerTitle: true,
            systemOverlayStyle: SystemBars.overlay(
              lightStatus: !tone.dark,
              lightNavigation: !tone.dark,
              statusColor: tone.background,
              navigationColor: tone.background,
            ),
          ),
          body: Column(
            children: [
              if (step != null) _progress(tone, step),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey('register-page-$_page-$_type'),
                    child: step == null
                        ? _typePage(tone)
                        : _stepPage(tone, step),
                  ),
                ),
              ),
              if (salon) _bottomBar(tone, step),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typePage(SettingsTone tone) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      children: [
        BrandHero(
          tone: tone,
          size: 112,
          logoKey: const Key('register-logo'),
          title: _t('أنشئ حسابك', 'Create your account'),
          subtitle: _t('انضم إلى المزين واحجز في أفضل مراكز التجميل بسهولة.', 'Join Al-Muzayyin and book top beauty centers easily.'),
        ),
        const SizedBox(height: 24),
        Text(
          _t('اختر نوع الحساب', 'Choose account type'),
          style: TextStyle(
            color: tone.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _choice(
                tone,
                key: const Key('register-client'),
                type: 'customer',
                label: _t('عميل', 'Customer'),
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _choice(
                tone,
                key: const Key('register-salon'),
                type: 'salon',
                label: _t('مركز تجميل', 'Beauty center'),
                icon: Icons.storefront_outlined,
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: switch (_type) {
            'customer' => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 22),
                _photoPicker(tone),
                const SizedBox(height: 18),
                ..._accountFields(tone),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _errorText(),
                ],
                const SizedBox(height: 24),
                _primaryButton(
                  tone,
                  key: const Key('register-submit'),
                  label: _busy ? _t('جارٍ إنشاء الحساب…', 'Creating account…') : _t('إنشاء الحساب', 'Create account'),
                  onPressed: _submit,
                ),
              ],
            ),
            'salon' => _salonIntro(tone),
            _ => const SizedBox(width: double.infinity),
          },
        ),
      ],
    );
  }

  Widget _salonIntro(SettingsTone tone) {
    return Container(
      key: const Key('register-salon-intro'),
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tone.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('سجّل مركز التجميل في ${_SalonStep.values.length} خطوات بسيطة', 'Register your beauty center in ${_SalonStep.values.length} simple steps'),
            style: TextStyle(
              color: tone.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t('جهّز بيانات الخدمات وفريق العمل ومواعيدك، ويمكنك تعديلها لاحقاً في أي وقت.', 'Prepare services, team, and hours — you can edit them anytime later.'),
            style: TextStyle(color: tone.muted, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 14),
          for (final step in _SalonStep.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tone.accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(step.icon, color: tone.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${step.index + 1}. ${step.title(_english)}',
                      style: TextStyle(
                        color: tone.text,
                        fontWeight: FontWeight.w700,
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

  Widget _progress(SettingsTone tone, _SalonStep step) {
    final total = _SalonStep.values.length;
    return Padding(
      key: const Key('register-progress'),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final item in _SalonStep.values) ...[
                if (item.index > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 5,
                    decoration: BoxDecoration(
                      color: item.index <= step.index ? tone.accent : tone.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tone.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(step.icon, color: tone.ink, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('الخطوة ${step.index + 1} من $total', 'Step ${step.index + 1} of $total'),
                      key: const Key('register-step-label'),
                      style: TextStyle(
                        color: tone.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      step.title(_english),
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      step.hint(_english),
                      style: TextStyle(color: tone.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepPage(SettingsTone tone, _SalonStep step) {
    return ListView(
      key: Key('register-step-${step.name}'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: switch (step) {
        _SalonStep.plan => [_planSetup(tone)],
        _SalonStep.services => [_salonSetup(tone)],
        _SalonStep.team => _teamStep(tone),
        _SalonStep.hours => _hoursStep(tone),
        _SalonStep.details => [
          _summary(tone),
          const SizedBox(height: 16),
          _salonPhotoPicker(tone),
          const SizedBox(height: 14),
          _healthCertificatePicker(tone),
          const SizedBox(height: 14),
          TextField(
            key: const Key('register-national-id'),
            controller: _nationalId,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            maxLength: 14,
            style: TextStyle(color: tone.text),
            cursorColor: tone.accent,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: _field(tone, _t('رقم البطاقة الشخصية', 'National ID')).copyWith(
              counterText: '',
              hintText: _t('١٤ رقماً', '14 digits'),
              hintStyle: TextStyle(color: tone.muted),
              prefixIcon: Icon(
                Icons.badge_outlined,
                color: tone.accent,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ..._accountFields(tone),
        ],
      },
    );
  }

  Widget _bottomBar(SettingsTone tone, _SalonStep? step) {
    final last = step == _SalonStep.details;
    return Container(
      decoration: BoxDecoration(
        color: tone.background,
        border: Border(top: BorderSide(color: tone.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[_errorText(), const SizedBox(height: 10)],
              Row(
                children: [
                  if (step != null) ...[
                    OutlinedButton(
                      key: const Key('register-back'),
                      onPressed: _busy ? null : _back,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tone.text,
                        side: BorderSide(color: tone.line),
                        minimumSize: const Size(96, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(_t('السابق', 'Back'),
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _primaryButton(
                      tone,
                      key: Key(last ? 'register-submit' : 'register-next'),
                      label: last
                          ? (_busy ? _t('جارٍ إنشاء الحساب…', 'Creating account…') : _t('إنشاء الحساب', 'Create account'))
                          : (step == null ? _t('ابدأ التسجيل', 'Start signup') : _t('التالي', 'Next')),
                      icon: last ? Icons.check_rounded : Icons.arrow_forward,
                      onPressed: _next,
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

  Widget _primaryButton(
    SettingsTone tone, {
    required Key key,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: tone.accent,
        foregroundColor: tone.ink,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: icon == null
          ? text
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: text),
                const SizedBox(width: 8),
                Icon(icon, size: 20),
              ],
            ),
    );
  }

  Widget _errorText() => Text(
    _error!,
    key: const Key('register-error'),
    style: const TextStyle(color: Color(0xFFE56B6B), height: 1.4),
  );

  List<Widget> _accountFields(SettingsTone tone) {
    final salon = _type == 'salon';
    return [
      TextField(
        key: const Key('register-name'),
        controller: _name,
        style: TextStyle(color: tone.text),
        cursorColor: tone.accent,
        decoration: _field(
          tone,
          salon
              ? _t('اسم مركز التجميل (عربي)', 'Beauty center name (Arabic)')
              : _t('الاسم (عربي)', 'Name (Arabic)'),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('register-name-en'),
        controller: _nameEn,
        style: TextStyle(color: tone.text),
        cursorColor: tone.accent,
        decoration: _field(
          tone,
          salon
              ? _t('اسم مركز التجميل (English)', 'Beauty center name (English)')
              : _t('الاسم (English)', 'Name (English)'),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('register-email'),
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textDirection: TextDirection.ltr,
        style: TextStyle(color: tone.text),
        cursorColor: tone.accent,
        decoration: _field(tone, _t('البريد', 'Email')),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('register-phone'),
        controller: _phone,
        keyboardType: TextInputType.phone,
        style: TextStyle(color: tone.text),
        cursorColor: tone.accent,
        decoration: _field(tone, _t('رقم الهاتف', 'Phone number')),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        key: const Key('register-address'),
        onPressed: _pickAddress,
        style: OutlinedButton.styleFrom(
          foregroundColor: tone.text,
          side: BorderSide(color: tone.line),
          minimumSize: const Size.fromHeight(56),
          alignment: AlignmentDirectional.centerStart,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(Icons.map_outlined, color: tone.accent),
        label: Text(
          _address?.address ?? _t('اختر العنوان من الخريطة', 'Pick address on the map'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('register-password'),
        controller: _password,
        obscureText: _hidden,
        style: TextStyle(color: tone.text),
        cursorColor: tone.accent,
        decoration: _field(tone, _t('كلمة المرور', 'Password')).copyWith(
          suffixIcon: IconButton(
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(
              _hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: tone.muted,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _summary(SettingsTone tone) {
    final open = _hours.where((hour) => !hour.isClosed).length;
    final items = [
      (
        Icons.workspace_premium_outlined,
        _plan?.nameFor(_english) ?? _t('بدون باقة', 'No plan'),
      ),
      (Icons.content_cut_rounded, _t('${_services.length} خدمة', '${_services.length} services')),
      (Icons.groups_2_outlined, _t('${_team.length} أخصائي', '${_team.length} specialists')),
      (Icons.schedule_rounded, _t('$open أيام عمل', '$open working days')),
    ];
    return Container(
      key: const Key('register-summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.accent.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children: [
          for (final (icon, label) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: tone.accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<(String ar, String en)> get _titleSuggestions {
    final titles = <(String, String)>{};
    for (final category in _selectedCategories) {
      titles.addAll(switch (category.slug) {
        'women' => const [
          ('خبيرة تجميل', 'Beautician'),
          ('مصففة شعر', 'Hair stylist'),
          ('أخصائية بشرة', 'Skin specialist'),
        ],
        'kids' => const [
          ('حلاق أطفال', 'Kids barber'),
          ('مصفف شعر', 'Hair stylist'),
        ],
        _ => const [
          ('حلاق', 'Barber'),
          ('حلاق أول', 'Senior barber'),
          ('خبير لحية', 'Beard specialist'),
        ],
      });
    }
    if (titles.isEmpty) {
      return const [
        ('حلاق', 'Barber'),
        ('حلاق أول', 'Senior barber'),
        ('خبير لحية', 'Beard specialist'),
      ];
    }
    return titles.toList();
  }

  void _addMember() {
    final limit = _plan?.maxSpecialists;
    if (limit != null && _team.length >= limit) return;
    setState(() {
      _team.add(_TeamMember());
      _error = null;
    });
  }

  void _removeMember(int index) {
    setState(() {
      _team.removeAt(index).dispose();
      _error = null;
    });
  }

  List<Widget> _teamStep(SettingsTone tone) {
    final limit = _plan?.maxSpecialists;
    final full = limit != null && _team.length >= limit;
    return [
      for (final (index, member) in _team.indexed)
        Container(
          key: Key('register-specialist-$index'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: tone.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tone.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: tone.accent.withValues(alpha: 0.16),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: tone.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t('الأخصائي ${index + 1}', 'Specialist ${index + 1}'),
                      style: TextStyle(
                        color: tone.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_team.length > 1)
                    IconButton(
                      key: Key('register-specialist-remove-$index'),
                      onPressed: () => _removeMember(index),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFE56B6B),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: Key('register-specialist-name-$index'),
                controller: member.name,
                style: TextStyle(color: tone.text),
                cursorColor: tone.accent,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: _field(
                  tone,
                  _t('اسم الأخصائي (عربي)', 'Specialist name (Arabic)'),
                ).copyWith(
                  prefixIcon: Icon(Icons.person_outline, color: tone.accent),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: Key('register-specialist-name-en-$index'),
                controller: member.nameEn,
                style: TextStyle(color: tone.text),
                cursorColor: tone.accent,
                decoration: _field(
                  tone,
                  _t('اسم الأخصائي (English)', 'Specialist name (English)'),
                ).copyWith(
                  prefixIcon: Icon(Icons.person_outline, color: tone.accent),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: Key('register-specialist-title-$index'),
                controller: member.title,
                style: TextStyle(color: tone.text),
                cursorColor: tone.accent,
                decoration: _field(
                  tone,
                  _t('التخصص عربي (اختياري)', 'Specialty (Arabic, optional)'),
                ).copyWith(
                  prefixIcon: Icon(Icons.badge_outlined, color: tone.accent),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: Key('register-specialist-title-en-$index'),
                controller: member.titleEn,
                style: TextStyle(color: tone.text),
                cursorColor: tone.accent,
                decoration: _field(
                  tone,
                  _t('التخصص (English, optional)', 'Specialty (English, optional)'),
                ).copyWith(
                  prefixIcon: Icon(Icons.badge_outlined, color: tone.accent),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final (ar, en) in _titleSuggestions)
                    ActionChip(
                      label: Text(_english ? en : ar),
                      onPressed: () => setState(() {
                        member.title.text = ar;
                        member.titleEn.text = en;
                      }),
                      backgroundColor: member.title.text == ar
                          ? tone.accent
                          : tone.background,
                      side: BorderSide(
                        color: member.title.text == ar
                            ? tone.accent
                            : tone.line,
                      ),
                      labelStyle: TextStyle(
                        color: member.title.text == ar
                            ? tone.ink
                            : tone.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      OutlinedButton.icon(
        key: const Key('register-specialist-add'),
        onPressed: full ? null : _addMember,
        style: OutlinedButton.styleFrom(
          foregroundColor: tone.accent,
          side: BorderSide(color: full ? tone.line : tone.accent),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(
          full ? _t('وصلت للحد الأقصى في باقتك ($limit)', 'You reached your plan limit ($limit)') : _t('إضافة أخصائي آخر', 'Add another specialist'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ];
  }

  void _setHour(int index, OwnHour hour) {
    setState(() {
      _hours = [..._hours]..[index] = hour;
      _error = null;
    });
  }

  void _copyFirstOpenDay() {
    final source = _hours.firstWhere(
      (hour) => !hour.isClosed,
      orElse: () => _hours.first,
    );
    setState(() {
      _hours = [
        for (final hour in _hours)
          hour.isClosed
              ? hour
              : hour.copyWith(
                  opensAt: source.opensAt,
                  closesAt: source.closesAt,
                ),
      ];
      _error = null;
    });
  }

  List<Widget> _hoursStep(SettingsTone tone) {
    final open = _hours.where((hour) => !hour.isClosed).length;
    return [
      Text(
        _t('فعّل اليوم ثم اضغط على وقت الفتح أو الإغلاق لتعديله.', 'Enable the day, then tap open or close time to edit it.'),
        style: TextStyle(color: tone.muted, fontSize: 13, height: 1.45),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(
              _t('$open أيام عمل في الأسبوع', '$open working days per week'),
              key: const Key('register-hours-count'),
              style: TextStyle(color: tone.muted, fontSize: 13),
            ),
          ),
          TextButton.icon(
            key: const Key('register-hours-copy'),
            onPressed: _copyFirstOpenDay,
            icon: Icon(Icons.copy_all_rounded, color: tone.accent, size: 18),
            label: Text(
              _t('نفس الموعد لكل الأيام', 'Same hours for all days'),
              style: TextStyle(color: tone.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      for (final (index, hour) in _hours.indexed)
        AnimatedContainer(
          key: Key('register-hour-${hour.day}'),
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: tone.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hour.isClosed
                  ? tone.line
                  : tone.accent.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dayLabel(hour.day),
                      style: TextStyle(
                        color: hour.isClosed ? tone.muted : tone.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    hour.isClosed ? _t('مغلق', 'Closed') : _t('مفتوح', 'Open'),
                    style: TextStyle(
                      color: hour.isClosed ? tone.muted : tone.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    key: Key('register-hour-switch-${hour.day}'),
                    value: !hour.isClosed,
                    activeThumbColor: tone.accent,
                    inactiveThumbColor: tone.muted,
                    inactiveTrackColor: tone.line,
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
              if (!hour.isClosed) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _timeField(
                        tone,
                        key: Key('register-hour-open-${hour.day}'),
                        label: _t('من', 'From'),
                        value: hour.opensAt ?? '10:00',
                        onPicked: (value) => _setHour(
                          index,
                          hour.copyWith(opensAt: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _timeField(
                        tone,
                        key: Key('register-hour-close-${hour.day}'),
                        label: _t('إلى', 'To'),
                        value: hour.closesAt ?? '22:00',
                        onPicked: (value) => _setHour(
                          index,
                          hour.copyWith(closesAt: value),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
    ];
  }

  String _formatHour12(String value) {
    final parts = value.split(':');
    final hour24 = int.tryParse(parts.first) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final period = hour24 >= 12
        ? (_english ? 'PM' : 'م')
        : (_english ? 'AM' : 'ص');
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pickHourTime(
    String current,
    ValueChanged<String> onPicked,
  ) async {
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 10,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
      helpText: _t('اختر الوقت', 'Pick time'),
      cancelText: _t('إلغاء', 'Cancel'),
      confirmText: _t('تم', 'Done'),
      hourLabelText: _t('ساعة', 'Hour'),
      minuteLabelText: _t('دقيقة', 'Minute'),
      builder: (context, child) {
        return Directionality(
          textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.gold,
                  onPrimary: AppColors.ink,
                  surface: AppColors.panel,
                  onSurface: AppColors.gold,
                ),
                timePickerTheme: TimePickerThemeData(
                  backgroundColor: AppColors.panel,
                  hourMinuteTextColor: AppColors.gold,
                  dialHandColor: AppColors.gold,
                  dialBackgroundColor: AppColors.warm,
                  entryModeIconColor: AppColors.gold,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    onPicked(
      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  Widget _timeField(
    SettingsTone tone, {
    required Key key,
    required String label,
    required String value,
    required ValueChanged<String> onPicked,
  }) {
    return Material(
      color: tone.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pickHourTime(value, onPicked),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tone.accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, color: tone.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatHour12(value),
                      textDirection:
                          _english ? TextDirection.ltr : TextDirection.rtl,
                      style: TextStyle(
                        color: tone.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: tone.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(
    SettingsTone tone, {
    required Key key,
    required String type,
    required String label,
    required IconData icon,
  }) {
    final selected = _type == type;
    return Material(
      color: selected ? tone.accent : tone.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(16),
        onTap: () => _chooseType(type),
        child: Container(
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? tone.accent : tone.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? tone.ink : tone.accent),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? tone.ink : tone.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planSetup(SettingsTone tone) {
    return FutureBuilder<List<SubscriptionPlan>>(
      future: _plansFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Center(child: CircularProgressIndicator(color: tone.accent)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              children: [
                Text(
                  _t('تعذر تحميل باقات الاشتراك.', 'Could not load subscription plans.'),
                  style: TextStyle(color: tone.muted),
                ),
                TextButton(
                  key: const Key('register-plans-retry'),
                  onPressed: () => setState(_loadPlans),
                  child: Text(
                    _t('إعادة المحاولة', 'Retry'),
                    style: TextStyle(color: tone.accent),
                  ),
                ),
              ],
            ),
          );
        }
        if (_plans.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              _t('لا توجد باقات متاحة حالياً، اضغط التالي للمتابعة.', 'No plans available now — tap Next to continue.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: tone.muted),
            ),
          );
        }
        return Column(
          key: const Key('register-plans'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlanPicker(
              plans: _plans,
              selectedId: _planId,
              accepted: _terms,
              tone: tone,
              onSelect: (plan) => setState(() {
                if (_planId != plan.id) _terms = false;
                _planId = plan.id;
                _error = null;
              }),
              onAccepted: (value) => setState(() {
                _terms = value;
                _error = null;
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _salonSetup(SettingsTone tone) {
    return FutureBuilder<List<CatalogCategory>>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Center(child: CircularProgressIndicator(color: tone.accent)),
          );
        }
        final categories = snapshot.data ?? const <CatalogCategory>[];
        if (snapshot.hasError || categories.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Column(
              children: [
                Text(
                  _t('تعذر تحميل الأقسام والخدمات.', 'Could not load categories and services.'),
                  style: TextStyle(color: tone.muted),
                ),
                TextButton(
                  key: const Key('register-catalog-retry'),
                  onPressed: () => setState(_loadCatalog),
                  child: Text(
                    _t('إعادة المحاولة', 'Retry'),
                    style: TextStyle(color: tone.accent),
                  ),
                ),
              ],
            ),
          );
        }

        final selected = _selectedCategories;
        final totalServices = selected.fold<int>(
          0,
          (sum, category) => sum + category.services.length,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(tone, '1', _t('اختر أقسام مركز التجميل', 'Choose beauty center categories')),
            const SizedBox(height: 6),
            Text(
              _t('يمكنك اختيار أكثر من قسم في نفس الوقت.', 'You can select more than one category at once.'),
              style: TextStyle(color: tone.muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (index, item) in categories.indexed) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(child: _categoryCard(tone, item)),
                ],
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: selected.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : _servicesPicker(tone, selected, totalServices),
            ),
          ],
        );
      },
    );
  }

  Widget _categoryCard(SettingsTone tone, CatalogCategory category) {
    final selected = _categoryIds.contains(category.id);
    final frame = _frameFor(category.slug);
    final icon = switch (category.slug) {
      'women' => Icons.face_3_outlined,
      'kids' => Icons.child_care_outlined,
      _ => Icons.face_outlined,
    };
    return Material(
      color: selected ? frame : tone.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('register-category-${category.slug}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleCategory(category),
        child: Container(
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: frame, width: selected ? 1.6 : 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? tone.ink : frame),
              const SizedBox(height: 6),
              Text(
                category.nameFor(_english),
                style: TextStyle(
                  color: selected ? tone.ink : tone.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _servicesPicker(
    SettingsTone tone,
    List<CatalogCategory> categories,
    int totalServices,
  ) {
    final all = totalServices > 0 && _services.length == totalServices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: _heading(tone, '2', _t('اختر الخدمات التي تقدمها', 'Choose the services you offer'))),
            TextButton(
              key: const Key('register-services-all'),
              onPressed: () => setState(() {
                if (all) {
                  _services.clear();
                } else {
                  for (final category in categories) {
                    _services.addAll(category.services.map((item) => item.id));
                  }
                }
                _error = null;
              }),
              child: Text(
                all ? _t('إلغاء الكل', 'Clear all') : _t('تحديد الكل', 'Select all'),
                style: TextStyle(
                  color: tone.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Text(
          _t('تم اختيار ${_services.length} من $totalServices • كل إطار بلون قسمه، وحدد سعر كل خدمة.', 'Selected ${_services.length} of $totalServices • each frame matches its category; set every service price.'),
          key: const Key('register-services-count'),
          style: TextStyle(color: tone.muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 10),
        for (final category in categories) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _frameFor(category.slug),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category.nameFor(_english),
                  style: TextStyle(
                    color: _frameFor(category.slug),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (category.services.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _t('لا توجد خدمات في هذا القسم بعد.', 'No services in this category yet.'),
                style: TextStyle(color: tone.muted),
              ),
            ),
          for (final item in category.services)
            _serviceTile(tone, item, category.slug),
        ],
      ],
    );
  }

  static String _normalizeDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final char in value.split('')) {
      final index = arabic.indexOf(char);
      buffer.write(index >= 0 ? '$index' : (char == '٫' ? '.' : char));
    }
    return buffer.toString();
  }

  Widget _priceField(SettingsTone tone, CatalogItem item) {
    final controller = _prices.putIfAbsent(item.id, TextEditingController.new);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: TextField(
        key: Key('register-service-price-${item.id}'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        style: TextStyle(color: tone.text, fontWeight: FontWeight.w700),
        cursorColor: tone.accent,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: _field(tone, _t('سعر الخدمة', 'Service price')).copyWith(
          isDense: true,
          hintText: _t('مثال: 150', 'e.g. 150'),
          hintStyle: TextStyle(color: tone.muted),
          suffixText: _t('ج.م', 'EGP'),
          suffixStyle: TextStyle(color: tone.accent),
          prefixIcon: Icon(Icons.sell_outlined, color: tone.accent, size: 20),
        ),
      ),
    );
  }

  Widget _serviceTile(SettingsTone tone, CatalogItem item, String slug) {
    final selected = _services.contains(item.id);
    final frame = _frameFor(slug);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: tone.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? frame : frame.withValues(alpha: 0.45),
            width: selected ? 1.8 : 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: Key('register-service-${item.id}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggleService(item.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: _serviceRow(tone, item, selected, frame),
                ),
              ),
            ),
            if (selected) _priceField(tone, item),
          ],
        ),
      ),
    );
  }

  Widget _serviceRow(
    SettingsTone tone,
    CatalogItem item,
    bool selected,
    Color frame,
  ) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: selected ? frame : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: frame),
          ),
          child: selected ? Icon(Icons.check, size: 16, color: tone.ink) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nameFor(_english),
                style: TextStyle(color: tone.text, fontWeight: FontWeight.w700),
              ),
              if (item.descriptionFor(_english) != null)
                Text(
                  item.descriptionFor(_english)!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tone.muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heading(SettingsTone tone, String step, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: tone.accent),
          ),
          child: Text(
            step,
            style: TextStyle(
              color: tone.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: tone.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
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
        borderSide: BorderSide(color: tone.accent),
      ),
    );
  }
}
