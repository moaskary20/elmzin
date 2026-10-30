import 'dart:async';

import 'package:flutter/material.dart';
import 'package:muzayen/data/account_store.dart';
import 'package:muzayen/data/auth_api.dart';
import 'package:muzayen/theme/settings_tone.dart';
import 'package:muzayen/theme/system_bars.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendSeconds = 60;

  bool get _english => AccountStore.instance.isEnglish;

  String _t(String ar, String en) => _english ? en : ar;

  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _sent = false;
  var _busy = false;
  var _hidden = true;
  var _wait = 0;
  Timer? _timer;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _wait = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _wait <= 1) {
        timer.cancel();
        if (mounted) setState(() => _wait = 0);
        return;
      }
      setState(() => _wait--);
    });
  }

  Future<void> _send() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'أدخل بريداً إلكترونياً صحيحاً.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthApi.requestReset(email: email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _notice = _t(
          'أرسلنا رمزاً من ٦ أرقام إلى $email إذا كان مسجلاً لدينا.',
          'We sent a 6-digit code to $email if it is registered with us.',
        );
      });
      _startCountdown();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الاتصال بالخادم.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    final code = _code.text.trim();
    final password = _password.text;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'الرمز مكوّن من ٦ أرقام.');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _error = _t(
          'كلمة المرور يجب أن تكون ٦ أحرف على الأقل.',
          'Password must be at least 6 characters.',
        ),
      );
      return;
    }
    if (password != _confirm.text) {
      setState(
        () => _error = _t(
          'تأكيد كلمة المرور غير مطابق.',
          'Password confirmation does not match.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await AuthApi.resetPassword(
        email: _email.text.trim(),
        code: code,
        password: password,
      );
      if (!mounted) return;
      AccountStore.instance.applySession(session);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'تم تغيير كلمة المرور وتسجيل دخولك.',
              'Password updated. You are signed in.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الاتصال بالخادم.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SettingsTone.of(AccountStore.instance.darkMode);

    return Directionality(
      textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
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
          title: Text(_t('نسيت كلمة المرور', 'Forgot password')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.panel,
                  border: Border.all(color: tone.accent),
                ),
                child: Icon(
                  _sent ? Icons.mark_email_read_outlined : Icons.lock_reset,
                  color: tone.accent,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _Steps(tone: tone, sent: _sent, english: _english),
            const SizedBox(height: 18),
            Text(
              _sent
                  ? _t(
                      'أدخل الرمز الذي وصلك على البريد ثم اختر كلمة مرور جديدة.',
                      'Enter the code from your email, then choose a new password.',
                    )
                  : _t(
                      'أدخل البريد المسجّل في حسابك وسنرسل لك رمزاً لاستعادة كلمة المرور.',
                      'Enter your registered email and we will send a recovery code.',
                    ),
              style: TextStyle(color: tone.muted, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('forgot-email'),
              controller: _email,
              enabled: !_sent,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: tone.text),
              cursorColor: tone.accent,
              decoration: _field(
                tone,
                _t('البريد الإلكتروني', 'Email'),
                Icons.mail_outline,
              ),
            ),
            if (_sent) ...[
              const SizedBox(height: 14),
              TextField(
                key: const Key('forgot-code'),
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 22,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w700,
                ),
                cursorColor: tone.accent,
                decoration: _field(
                  tone,
                  _t('رمز الاستعادة', 'Recovery code'),
                  Icons.pin_outlined,
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('forgot-password'),
                controller: _password,
                obscureText: _hidden,
                style: TextStyle(color: tone.text),
                cursorColor: tone.accent,
                decoration:
                    _field(
                      tone,
                      _t('كلمة المرور الجديدة', 'New password'),
                      Icons.lock_outline,
                    ).copyWith(
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
              const SizedBox(height: 14),
              TextField(
                key: const Key('forgot-confirm'),
                controller: _confirm,
                obscureText: _hidden,
                style: TextStyle(color: tone.text),
                cursorColor: tone.accent,
                decoration: _field(
                  tone,
                  _t('تأكيد كلمة المرور', 'Confirm password'),
                  Icons.lock_outline,
                ),
              ),
            ],
            if (_notice != null && _error == null) ...[
              const SizedBox(height: 14),
              Text(
                _notice!,
                key: const Key('forgot-notice'),
                style: TextStyle(color: tone.accent, height: 1.5),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                key: const Key('forgot-error'),
                style: const TextStyle(color: Color(0xFFE56B6B), height: 1.4),
              ),
            ],
            const SizedBox(height: 26),
            FilledButton(
              key: const Key('forgot-submit'),
              onPressed: _sent ? _reset : _send,
              style: FilledButton.styleFrom(
                backgroundColor: tone.accent,
                foregroundColor: tone.ink,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _busy
                    ? _t('جارٍ الإرسال…', 'Sending…')
                    : _sent
                    ? _t('تغيير كلمة المرور', 'Update password')
                    : _t('إرسال الرمز', 'Send code'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_sent) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    key: const Key('forgot-resend'),
                    onPressed: _wait > 0 || _busy ? null : _send,
                    child: Text(
                      _wait > 0
                          ? _t(
                              'إعادة الإرسال بعد $_wait ث',
                              'Resend in $_wait s',
                            )
                          : _t('إعادة إرسال الرمز', 'Resend code'),
                      style: TextStyle(
                        color: _wait > 0 ? tone.muted : tone.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text('•', style: TextStyle(color: tone.muted)),
                  TextButton(
                    key: const Key('forgot-change-email'),
                    onPressed: () => setState(() {
                      _sent = false;
                      _notice = null;
                      _error = null;
                      _code.clear();
                      _timer?.cancel();
                      _wait = 0;
                    }),
                    child: Text(
                      _t('تغيير البريد', 'Change email'),
                      style: TextStyle(
                        color: tone.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _field(SettingsTone tone, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: tone.muted),
      prefixIcon: Icon(icon, color: tone.muted),
      filled: true,
      fillColor: tone.panel,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tone.line),
      ),
      disabledBorder: OutlineInputBorder(
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

class _Steps extends StatelessWidget {
  const _Steps({
    required this.tone,
    required this.sent,
    required this.english,
  });

  final SettingsTone tone;
  final bool sent;
  final bool english;

  @override
  Widget build(BuildContext context) {
    Widget dot(int number, String label, bool active) {
      return Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? tone.accent : tone.panel,
              border: Border.all(color: tone.accent),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: active ? tone.ink : tone.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: tone.muted, fontSize: 12)),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(1, english ? 'Email' : 'البريد', true),
        Container(
          width: 60,
          height: 2,
          margin: const EdgeInsets.only(bottom: 20, left: 8, right: 8),
          color: sent ? tone.accent : tone.line,
        ),
        dot(2, english ? 'New password' : 'كلمة جديدة', sent),
      ],
    );
  }
}
