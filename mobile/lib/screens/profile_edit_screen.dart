import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/account_store.dart';
import '../theme/settings_tone.dart';
import '../theme/system_bars.dart';
import '../widgets/account_avatar.dart';
import 'salon_manage_screen.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String? _photo;

  bool get _english => Directionality.of(context) == TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    final account = AccountStore.instance;
    _name = TextEditingController(text: account.name);
    _phone = TextEditingController(text: account.phone);
    _photo = account.photoPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      setState(() => _photo = file.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _english ? 'Could not open photos.' : 'تعذر فتح الصور.',
          ),
        ),
      );
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    AccountStore.instance.saveProfile(
      name: name,
      phone: _phone.text,
      photoPath: _photo,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final english = Directionality.of(context) == TextDirection.ltr;
    final tone = SettingsTone.of(AccountStore.instance.darkMode);

    return Scaffold(
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
        title: Text(english ? 'Edit profile' : 'تعديل الملف الشخصي'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        children: [
          Center(
            child: AccountAvatar(
              photoPath: _photo,
              photoUrl: AccountStore.instance.photoUrl,
              tone: tone,
              onEdit: _pickPhoto,
              editKey: const Key('profile-photo'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            english
                ? 'Tap the pencil to change the photo'
                : 'اضغط القلم لتغيير الصورة',
            textAlign: TextAlign.center,
            style: TextStyle(color: tone.muted, fontSize: 13),
          ),
          const SizedBox(height: 28),
          _field(
            tone: tone,
            controller: _name,
            key: const Key('profile-name'),
            label: english ? 'Name' : 'الاسم',
          ),
          const SizedBox(height: 14),
          _field(
            tone: tone,
            controller: _phone,
            key: const Key('profile-phone'),
            label: english ? 'Phone' : 'الهاتف',
            keyboard: TextInputType.phone,
          ),
          if (AccountStore.instance.role == 'salon') ...[
            const SizedBox(height: 22),
            _salonCard(tone, english),
          ],
          const SizedBox(height: 28),
          FilledButton(
            key: const Key('profile-save'),
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: tone.accent,
              disabledBackgroundColor: tone.accent.withValues(alpha: 0.35),
              foregroundColor: tone.ink,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              english ? 'Save' : 'حفظ',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _salonCard(SettingsTone tone, bool english) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('profile-salon-manage'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Directionality(
              textDirection: Directionality.of(context),
              child: const SalonManageScreen(),
            ),
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [tone.accent.withValues(alpha: 0.18), tone.panel],
            ),
            border: Border.all(color: tone.accent.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tone.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.storefront_rounded, color: tone.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      english ? 'Manage your salon' : 'إدارة الصالون',
                      style: TextStyle(
                        color: tone.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      english
                          ? 'Details, services and prices, team, and hours'
                          : 'البيانات، الخدمات والأسعار، الأخصائيون، ومواعيد العمل',
                      style: TextStyle(color: tone.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                english
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                color: tone.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required SettingsTone tone,
    required TextEditingController controller,
    required Key key,
    required String label,
    TextInputType? keyboard,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboard,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: tone.text),
      cursorColor: tone.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: tone.muted),
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
}
