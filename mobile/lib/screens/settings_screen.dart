import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../theme/settings_tone.dart';
import '../widgets/account_avatar.dart';
import 'info_screen.dart';
import 'login_screen.dart';
import 'loyalty_screen.dart';
import 'profile_edit_screen.dart';
import 'wallet_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onLocale});

  final ValueChanged<Locale> onLocale;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    AccountStore.instance.load().whenComplete(AccountStore.instance.refresh);
  }

  bool get _english => Directionality.of(context) == TextDirection.ltr;

  void _edit() => _push(const ProfileEditScreen());

  void _login() => _push(const LoginScreen());

  void _push(Widget page) {
    final direction = Directionality.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Directionality(textDirection: direction, child: page),
      ),
    );
  }

  Future<void> _logout() async {
    await AccountStore.instance.logout();
  }

  Future<void> _language() async {
    final english = _english;
    final selected = await showDialog<Locale>(
      context: context,
      builder: (context) {
        final tone = SettingsTone.of(AccountStore.instance.darkMode);
        return Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: tone.panel,
            title: Text(
              english ? 'Language' : 'اللغة',
              style: TextStyle(color: tone.text, fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _languageTile(
                  tone: tone,
                  key: const Key('language-ar'),
                  label: 'العربية',
                  selected: !english,
                  onTap: () => Navigator.pop(context, const Locale('ar')),
                ),
                _languageTile(
                  tone: tone,
                  key: const Key('language-en'),
                  label: 'English',
                  selected: english,
                  onTap: () => Navigator.pop(context, const Locale('en')),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    AccountStore.instance.setLocale(selected.languageCode);
    widget.onLocale(selected);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccountStore.instance,
      builder: (context, _) {
        final account = AccountStore.instance;
        final english = _english;
        final tone = SettingsTone.of(account.darkMode);
        final language = english ? 'English' : 'العربية';

        return ColoredBox(
          key: const Key('settings-root'),
          color: tone.background,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Center(
                child: AccountAvatar(
                  photoPath: account.photoPath,
                  photoUrl: account.photoUrl,
                  tone: tone,
                  onEdit: _edit,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                account.displayName(english),
                key: const Key('settings-name'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              _section(tone, english ? 'Account' : 'الحساب'),
              _group(tone, [
                _row(
                  tone: tone,
                  key: const Key('settings-edit-profile'),
                  icon: Icons.badge_outlined,
                  label: english ? 'Edit profile' : 'تعديل الملف الشخصي',
                  onTap: _edit,
                ),
                _row(
                  tone: tone,
                  key: const Key('settings-wallet'),
                  icon: Icons.account_balance_wallet_outlined,
                  label: english ? 'Wallet' : 'المحفظة',
                  value: account.loggedIn
                      ? (english
                            ? 'EGP ${account.walletBalance.toStringAsFixed(2)}'
                            : '${account.walletBalance.toStringAsFixed(2)} ج.م')
                      : null,
                  onTap: () => _push(const WalletScreen()),
                ),
                _row(
                  tone: tone,
                  key: const Key('settings-loyalty'),
                  icon: Icons.workspace_premium_outlined,
                  label: english ? 'Loyalty points' : 'نقاط الولاء',
                  value: account.loggedIn
                      ? (english
                            ? '${account.loyaltyPoints} pts'
                            : '${account.loyaltyPoints} نقطة')
                      : null,
                  onTap: () => _push(const LoyaltyScreen()),
                ),
              ]),
              const SizedBox(height: 18),
              _section(tone, english ? 'Preferences' : 'التفضيلات'),
              _group(tone, [
                _switchRow(
                  tone: tone,
                  key: const Key('settings-notifications'),
                  icon: Icons.notifications_none_rounded,
                  label: english ? 'Notifications' : 'الإشعارات',
                  value: account.notifications,
                  onChanged: account.setNotifications,
                ),
                _switchRow(
                  tone: tone,
                  key: const Key('settings-dark-mode'),
                  icon: Icons.dark_mode_outlined,
                  label: english ? 'Dark mode' : 'الوضع الداكن',
                  value: account.darkMode,
                  onChanged: account.setDarkMode,
                ),
                _row(
                  tone: tone,
                  key: const Key('settings-language'),
                  icon: Icons.language_rounded,
                  label: english ? 'Language' : 'اللغة',
                  value: language,
                  onTap: _language,
                ),
              ]),
              const SizedBox(height: 18),
              _section(tone, english ? 'Support' : 'الدعم'),
              _group(tone, [
                _row(
                  tone: tone,
                  key: const Key('settings-help'),
                  icon: Icons.support_agent_rounded,
                  label: english ? 'Help center' : 'مركز المساعدة',
                  onTap: () => _open(const InfoScreen.help()),
                ),
                _row(
                  tone: tone,
                  key: const Key('settings-faq'),
                  icon: Icons.quiz_outlined,
                  label: english ? 'FAQ' : 'الأسئلة الشائعة',
                  onTap: () => _open(const InfoScreen.faq()),
                ),
                _row(
                  tone: tone,
                  key: const Key('settings-privacy'),
                  icon: Icons.privacy_tip_outlined,
                  label: english ? 'Privacy policy' : 'سياسة الخصوصية',
                  onTap: () => _open(const InfoScreen.privacy()),
                ),
              ]),
              const SizedBox(height: 22),
              if (account.loggedIn)
                OutlinedButton(
                  key: const Key('settings-auth'),
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tone.accent,
                    side: BorderSide(color: tone.accent),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    english ? 'Log out' : 'تسجيل الخروج',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                FilledButton(
                  key: const Key('settings-auth'),
                  onPressed: _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: tone.accent,
                    foregroundColor: tone.ink,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    english ? 'Sign in' : 'تسجيل الدخول',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _open(Widget page) => _push(page);

  Widget _section(SettingsTone tone, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: tone.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _group(SettingsTone tone, List<Widget> children) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.line),
      ),
      child: Column(children: children),
    );
  }

  Widget _row({
    required SettingsTone tone,
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? value,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: tone.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (value != null)
              Text(value, style: TextStyle(color: tone.muted, fontSize: 13)),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: tone.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required SettingsTone tone,
    required Key key,
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      key: key,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
        child: Row(
          children: [
            Icon(icon, color: tone.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IgnorePointer(
              child: Switch(
                value: value,
                activeThumbColor: tone.ink,
                activeTrackColor: tone.accent,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageTile({
    required SettingsTone tone,
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(
          color: tone.text,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected ? Icon(Icons.check_rounded, color: tone.accent) : null,
    );
  }
}
