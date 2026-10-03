import 'package:flutter/material.dart';
import 'package:muzayen/data/account_store.dart';
import 'package:muzayen/data/auth_api.dart';
import 'package:muzayen/screens/forgot_password_screen.dart';
import 'package:muzayen/screens/register_screen.dart';
import 'package:muzayen/theme/settings_tone.dart';
import 'package:muzayen/theme/system_bars.dart';
import 'package:muzayen/widgets/brand_hero.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: AccountStore.instance.email);
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < 6) {
      setState(() {
        _error = 'أدخل بريداً صحيحاً وكلمة مرور من ٦ أحرف على الأقل.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await AuthApi.signIn(email: email, password: password);
      if (!mounted) return;
      AccountStore.instance.applySession(session);
      Navigator.of(context).pop();
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

  Future<void> _openRegister() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const RegisterScreen()));
    if (created == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _openForgot() async {
    final reset = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(email: _email.text.trim()),
      ),
    );
    if (reset == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tone = SettingsTone.of(AccountStore.instance.darkMode);

    return Directionality(
      textDirection: TextDirection.rtl,
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
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          children: [
            BrandHero(
              tone: tone,
              logoKey: const Key('login-logo'),
              title: 'مرحباً بعودتك',
              subtitle: 'سجّل دخولك لتتابع حجوزاتك وصالوناتك المفضلة.',
            ),
            const SizedBox(height: 26),
            TextField(
              key: const Key('login-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: tone.text),
              cursorColor: tone.accent,
              decoration: _field(tone, 'البريد'),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('login-password'),
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
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const Key('login-forgot'),
                onPressed: _openForgot,
                child: Text(
                  'نسيت كلمة المرور؟',
                  style: TextStyle(color: tone.accent, fontSize: 13),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                key: const Key('login-error'),
                style: const TextStyle(color: Color(0xFFE56B6B), height: 1.4),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              key: const Key('login-submit'),
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
                _busy ? 'جارٍ الدخول…' : 'تسجيل الدخول',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              key: const Key('login-register'),
              onPressed: _openRegister,
              child: Text(
                'تسجيل الاشتراك',
                style: TextStyle(
                  color: tone.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
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
