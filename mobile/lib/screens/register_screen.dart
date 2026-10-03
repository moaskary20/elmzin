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
import 'package:muzayen/theme/settings_tone.dart';
import 'package:muzayen/theme/system_bars.dart';
import 'package:muzayen/widgets/account_avatar.dart';
import 'package:muzayen/widgets/brand_hero.dart';
import 'package:muzayen/widgets/plan_picker.dart';

enum _SalonStep {
  plan(
    'اختر باقة الاشتراك',
    'ابدأ رحلتك مع المزين، ويمكنك الترقية لاحقاً.',
    Icons.workspace_premium_outlined,
  ),
  services(
    'الخدمات والأسعار',
    'اختر قسم صالونك وحدد سعر كل خدمة.',
    Icons.content_cut_rounded,
  ),
  team(
    'فريق العمل',
    'أضف الأخصائيين الذين يستقبلون الحجوزات.',
    Icons.groups_2_outlined,
  ),
  hours(
    'مواعيد العمل',
    'حدد أيام وساعات استقبال العملاء.',
    Icons.schedule_rounded,
  ),
  details(
    'بيانات الصالون',
    'الصورة وبيانات التواصل والعنوان.',
    Icons.storefront_outlined,
  );

  const _SalonStep(this.title, this.hint, this.icon);

  final String title;
  final String hint;
  final IconData icon;
}

class _TeamMember {
  final name = TextEditingController();
  final title = TextEditingController();

  void dispose() {
    name.dispose();
    title.dispose();
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static Future<String?> Function(ImageSource source) pickPhoto = _pick;

  static void useDefaultPicker() => pickPhoto = _pick;

  static Future<String?> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    return file?.path;
  }

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
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
    for (final (day, label) in const [
      (6, 'السبت'),
      (0, 'الأحد'),
      (1, 'الإثنين'),
      (2, 'الثلاثاء'),
      (3, 'الأربعاء'),
      (4, 'الخميس'),
      (5, 'الجمعة'),
    ])
      OwnHour(
        day: day,
        label: label,
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

  CatalogCategory? _category;
  final Set<int> _services = {};
  final Map<int, TextEditingController> _prices = {};
  String? _photo;
  String? _salonPhoto;

  Future<void> _choosePhoto() => _pickInto(salon: false);

  Future<void> _chooseSalonPhoto() => _pickInto(salon: true);

  Future<void> _pickInto({required bool salon}) async {
    final current = salon ? _salonPhoto : _photo;
    void put(String? path) => setState(() {
      if (salon) {
        _salonPhoto = path;
      } else {
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
        textDirection: TextDirection.rtl,
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
                  'اختيار من معرض الصور',
                ),
                _photoAction(
                  sheet,
                  tone,
                  'camera',
                  Icons.photo_camera_outlined,
                  'التقاط صورة بالكاميرا',
                ),
                if (current != null)
                  _photoAction(
                    sheet,
                    tone,
                    'remove',
                    Icons.delete_outline,
                    'إزالة الصورة',
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
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الصور.')));
    }
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
          _photo == null ? 'أضف صورتك الشخصية (اختياري)' : 'تم اختيار الصورة',
          key: const Key('register-photo-label'),
          style: TextStyle(color: tone.muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _salonPhotoPicker(SettingsTone tone) {
    final path = _salonPhoto;
    final file = path == null ? null : File(path);
    final hasImage = file != null && file.existsSync();
    return Material(
      color: tone.panel,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('register-salon-photo'),
        onTap: _chooseSalonPhoto,
        child: Container(
          height: 170,
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
                        path == null
                            ? Icons.add_photo_alternate_outlined
                            : Icons.check_circle_outline,
                        color: tone.accent,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        path == null ? 'ارفع صورة الصالون' : 'تم اختيار الصورة',
                        key: const Key('register-salon-photo-label'),
                        style: TextStyle(
                          color: tone.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'صورة واضحة للواجهة أو من داخل الصالون',
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
                          'تغيير',
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

  void _chooseCategory(CatalogCategory category) {
    if (_category?.id == category.id) return;
    setState(() {
      _category = category;
      _services.clear();
      _error = null;
    });
  }

  void _toggleService(int id) {
    setState(() {
      if (!_services.remove(id)) _services.add(id);
      _error = null;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
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
        if (_plansLoading) return 'انتظر تحميل الباقات.';
        final plan = _plan;
        if (_plans.isNotEmpty && plan == null) return 'اختر باقة الاشتراك.';
        if (plan != null && plan.terms.isNotEmpty && !_terms) {
          return 'يجب الموافقة على قوانين الاشتراك أولاً.';
        }
      case _SalonStep.services:
        if (_category == null) return 'اختر قسم الصالون أولاً.';
        if (_services.isEmpty) {
          return 'اختر خدمة واحدة على الأقل من خدمات القسم.';
        }
        final limit = _plan?.maxServices;
        if (limit != null && _services.length > limit) {
          return '${_plan!.name} تسمح بحد أقصى $limit خدمة.';
        }
        if (_servicePrices() == null) return 'حدد سعر كل خدمة مختارة.';
      case _SalonStep.team:
        if (_team.isEmpty) return 'أضف أخصائياً واحداً على الأقل.';
        if (_team.any((member) => member.name.text.trim().isEmpty)) {
          return 'اكتب اسم كل أخصائي أو احذف الخانة الفارغة.';
        }
        final limit = _plan?.maxSpecialists;
        if (limit != null && _team.length > limit) {
          return '${_plan!.name} تسمح بحد أقصى $limit أخصائي.';
        }
      case _SalonStep.hours:
        if (_hours.every((hour) => hour.isClosed)) {
          return 'افتح يوماً واحداً على الأقل.';
        }
        for (final hour in _hours) {
          if (!hour.isClosed &&
              (hour.closesAt ?? '').compareTo(hour.opensAt ?? '') <= 0) {
            return 'وقت الإغلاق يجب أن يكون بعد وقت الفتح يوم ${hour.label}.';
          }
        }
      case _SalonStep.details:
        return _checkDetails();
    }
    return null;
  }

  String? _checkDetails() {
    if (_type == 'salon' && _salonPhoto == null) return 'ارفع صورة الصالون.';
    final address = _address;
    if (_name.text.trim().isEmpty ||
        !_email.text.trim().contains('@') ||
        _phone.text.trim().isEmpty ||
        _password.text.length < 6 ||
        address == null ||
        address.address.trim().isEmpty) {
      return 'أكمل الاسم والبريد والهاتف والعنوان من الخريطة وكلمة مرور من ٦ أحرف على الأقل.';
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
        categoryId: salon ? _category!.id : null,
        servicePrices: salon ? _servicePrices()! : const {},
        planId: plan?.id,
        acceptTerms: _terms,
        specialists: salon
            ? [
                for (final member in _team)
                  {
                    'name': member.name.text.trim(),
                    'title': member.title.text.trim().isEmpty
                        ? null
                        : member.title.text.trim(),
                  },
              ]
            : null,
        hours: salon ? [for (final hour in _hours) hour.toJson()] : null,
      );
      if (!mounted) return;
      AccountStore.instance.applySession(session);
      final photo = _type == 'customer' ? _photo : null;
      if (photo != null) unawaited(AccountStore.instance.setPhoto(photo));
      final salonPhoto = salon ? _salonPhoto : null;
      if (salonPhoto != null && session.token.isNotEmpty) {
        unawaited(
          AccountApi.uploadSalonImage(
            token: session.token,
            path: salonPhoto,
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
      setState(() => _error = 'تعذر الاتصال بالخادم.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SettingsTone.of(AccountStore.instance.darkMode);
    final salon = _type == 'salon';
    final step = _current;

    return Directionality(
      textDirection: TextDirection.rtl,
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
                    'تسجيل صالون',
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
          title: 'أنشئ حسابك',
          subtitle: 'انضم إلى المزين واحجز في أفضل الصالونات بسهولة.',
        ),
        const SizedBox(height: 24),
        Text(
          'اختر نوع الحساب',
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
                label: 'عميل',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _choice(
                tone,
                key: const Key('register-salon'),
                type: 'salon',
                label: 'صالون',
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
                  label: _busy ? 'جارٍ إنشاء الحساب…' : 'إنشاء الحساب',
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
            'سجّل صالونك في ${_SalonStep.values.length} خطوات بسيطة',
            style: TextStyle(
              color: tone.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'جهّز بيانات الخدمات وفريق العمل ومواعيدك، ويمكنك تعديلها لاحقاً في أي وقت.',
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
                      '${step.index + 1}. ${step.title}',
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
                      'الخطوة ${step.index + 1} من $total',
                      key: const Key('register-step-label'),
                      style: TextStyle(
                        color: tone.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      step.title,
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      step.hint,
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
                      child: const Text(
                        'السابق',
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
                          ? (_busy ? 'جارٍ إنشاء الحساب…' : 'إنشاء الحساب')
                          : (step == null ? 'ابدأ التسجيل' : 'التالي'),
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
    return [
      TextField(
        key: const Key('register-name'),
        controller: _name,
        style: TextStyle(color: tone.text),
        cursorColor: tone.accent,
        decoration: _field(tone, _type == 'salon' ? 'اسم الصالون' : 'الاسم'),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('register-email'),
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textDirection: TextDirection.ltr,
        style: TextStyle(color: tone.text),
        cursorColor: tone.accent,
        decoration: _field(tone, 'البريد'),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('register-phone'),
        controller: _phone,
        keyboardType: TextInputType.phone,
        style: TextStyle(color: tone.text),
        cursorColor: tone.accent,
        decoration: _field(tone, 'رقم الهاتف'),
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
          _address?.address ?? 'اختر العنوان من الخريطة',
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
        decoration: _field(tone, 'كلمة المرور').copyWith(
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
      (Icons.workspace_premium_outlined, _plan?.name ?? 'بدون باقة'),
      (Icons.content_cut_rounded, '${_services.length} خدمة'),
      (Icons.groups_2_outlined, '${_team.length} أخصائي'),
      (Icons.schedule_rounded, '$open أيام عمل'),
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

  List<String> get _titleSuggestions => switch (_category?.slug) {
    'women' => const ['خبيرة تجميل', 'مصففة شعر', 'أخصائية بشرة'],
    'kids' => const ['حلاق أطفال', 'مصفف شعر'],
    _ => const ['حلاق', 'حلاق أول', 'خبير لحية'],
  };

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
                      'الأخصائي ${index + 1}',
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
                decoration: _field(tone, 'اسم الأخصائي').copyWith(
                  prefixIcon: Icon(Icons.person_outline, color: tone.accent),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: Key('register-specialist-title-$index'),
                controller: member.title,
                style: TextStyle(color: tone.text),
                cursorColor: tone.accent,
                decoration: _field(tone, 'التخصص (اختياري)').copyWith(
                  prefixIcon: Icon(Icons.badge_outlined, color: tone.accent),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final title in _titleSuggestions)
                    ActionChip(
                      label: Text(title),
                      onPressed: () =>
                          setState(() => member.title.text = title),
                      backgroundColor: member.title.text == title
                          ? tone.accent
                          : tone.background,
                      side: BorderSide(
                        color: member.title.text == title
                            ? tone.accent
                            : tone.line,
                      ),
                      labelStyle: TextStyle(
                        color: member.title.text == title
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
          full ? 'وصلت للحد الأقصى في باقتك ($limit)' : 'إضافة أخصائي آخر',
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
      Row(
        children: [
          Expanded(
            child: Text(
              '$open أيام عمل في الأسبوع',
              key: const Key('register-hours-count'),
              style: TextStyle(color: tone.muted, fontSize: 13),
            ),
          ),
          TextButton.icon(
            key: const Key('register-hours-copy'),
            onPressed: _copyFirstOpenDay,
            icon: Icon(Icons.copy_all_rounded, color: tone.accent, size: 18),
            label: Text(
              'نفس الموعد لكل الأيام',
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
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            color: tone.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hour.isClosed
                  ? tone.line
                  : tone.accent.withValues(alpha: 0.45),
            ),
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
                    ? Text('مغلق', style: TextStyle(color: tone.muted))
                    : Row(
                        children: [
                          _timeChip(
                            tone,
                            Key('register-hour-open-${hour.day}'),
                            hour.opensAt ?? '10:00',
                            (value) =>
                                _setHour(index, hour.copyWith(opensAt: value)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '–',
                              style: TextStyle(color: tone.muted),
                            ),
                          ),
                          _timeChip(
                            tone,
                            Key('register-hour-close-${hour.day}'),
                            hour.closesAt ?? '22:00',
                            (value) =>
                                _setHour(index, hour.copyWith(closesAt: value)),
                          ),
                        ],
                      ),
              ),
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
        ),
    ];
  }

  Widget _timeChip(
    SettingsTone tone,
    Key key,
    String value,
    ValueChanged<String> onPicked,
  ) {
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
                  'تعذر تحميل باقات الاشتراك.',
                  style: TextStyle(color: tone.muted),
                ),
                TextButton(
                  key: const Key('register-plans-retry'),
                  onPressed: () => setState(_loadPlans),
                  child: Text(
                    'إعادة المحاولة',
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
              'لا توجد باقات متاحة حالياً، اضغط التالي للمتابعة.',
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
                  'تعذر تحميل الأقسام والخدمات.',
                  style: TextStyle(color: tone.muted),
                ),
                TextButton(
                  key: const Key('register-catalog-retry'),
                  onPressed: () => setState(_loadCatalog),
                  child: Text(
                    'إعادة المحاولة',
                    style: TextStyle(color: tone.accent),
                  ),
                ),
              ],
            ),
          );
        }

        final category = _category;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(tone, '1', 'اختر قسم الصالون'),
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
              child: category == null
                  ? const SizedBox(width: double.infinity)
                  : _servicesPicker(tone, category),
            ),
          ],
        );
      },
    );
  }

  Widget _categoryCard(SettingsTone tone, CatalogCategory category) {
    final selected = _category?.id == category.id;
    final icon = switch (category.slug) {
      'women' => Icons.face_3_outlined,
      'kids' => Icons.child_care_outlined,
      _ => Icons.face_outlined,
    };
    return Material(
      color: selected ? tone.accent : tone.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('register-category-${category.slug}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _chooseCategory(category),
        child: Container(
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? tone.accent : tone.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? tone.ink : tone.accent),
              const SizedBox(height: 6),
              Text(
                category.name,
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

  Widget _servicesPicker(SettingsTone tone, CatalogCategory category) {
    final all =
        category.services.isNotEmpty &&
        _services.length == category.services.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: _heading(tone, '2', 'اختر الخدمات التي تقدمها')),
            TextButton(
              key: const Key('register-services-all'),
              onPressed: () => setState(() {
                if (all) {
                  _services.clear();
                } else {
                  _services.addAll(category.services.map((item) => item.id));
                }
                _error = null;
              }),
              child: Text(
                all ? 'إلغاء الكل' : 'تحديد الكل',
                style: TextStyle(
                  color: tone.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Text(
          'تم اختيار ${_services.length} من ${category.services.length} • اختر الخدمات التي يقدمها صالونك وحدد سعر كل خدمة.',
          key: const Key('register-services-count'),
          style: TextStyle(color: tone.muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 10),
        if (category.services.isEmpty)
          Text(
            'لا توجد خدمات في هذا القسم بعد.',
            style: TextStyle(color: tone.muted),
          ),
        for (final item in category.services) _serviceTile(tone, item),
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
        decoration: _field(tone, 'سعر الخدمة').copyWith(
          isDense: true,
          hintText: 'مثال: 150',
          hintStyle: TextStyle(color: tone.muted),
          suffixText: 'ج.م',
          suffixStyle: TextStyle(color: tone.accent),
          prefixIcon: Icon(Icons.sell_outlined, color: tone.accent, size: 20),
        ),
      ),
    );
  }

  Widget _serviceTile(SettingsTone tone, CatalogItem item) {
    final selected = _services.contains(item.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: tone.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? tone.accent : tone.line,
            width: selected ? 1.4 : 1,
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
                  child: _serviceRow(tone, item, selected),
                ),
              ),
            ),
            if (selected) _priceField(tone, item),
          ],
        ),
      ),
    );
  }

  Widget _serviceRow(SettingsTone tone, CatalogItem item, bool selected) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: selected ? tone.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: tone.accent),
          ),
          child: selected ? Icon(Icons.check, size: 16, color: tone.ink) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: TextStyle(color: tone.text, fontWeight: FontWeight.w700),
              ),
              if (item.description != null && item.description!.isNotEmpty)
                Text(
                  item.description!,
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
