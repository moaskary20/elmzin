import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/support_contact.dart';
import '../theme/settings_tone.dart';

class SupportContactScreen extends StatefulWidget {
  const SupportContactScreen({super.key});

  @override
  State<SupportContactScreen> createState() => _SupportContactScreenState();
}

class _SupportContactScreenState extends State<SupportContactScreen> {
  SupportForm? _form;
  String? _error;
  bool _loading = true;
  bool _sending = false;

  SupportChoice? _topic;
  SupportChoice? _related;
  final _topicCustom = TextEditingController();
  final _relatedCustom = TextEditingController();
  final _message = TextEditingController();

  bool get _english => AccountStore.instance.isEnglish;

  String _t(String ar, String en) => _english ? en : ar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _topicCustom.dispose();
    _relatedCustom.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final form = await SupportContactApi.loadForm();
      if (!mounted) return;
      setState(() {
        _form = form;
        _loading = false;
        _topic = form.topics.isNotEmpty ? form.topics.first : null;
        _related = form.related.isNotEmpty ? form.related.first : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _t('تعذر تحميل نموذج الدعم.', 'Could not load the support form.');
      });
    }
  }

  Future<void> _submit() async {
    final form = _form;
    final topic = _topic;
    final related = _related;
    if (form == null || topic == null || related == null || _sending) return;

    if (topic.isOther && _topicCustom.text.trim().isEmpty) {
      _toast(_t('اكتب تفاصيل الموضوع.', 'Please describe the topic.'));
      return;
    }
    if (related.isOther && _relatedCustom.text.trim().isEmpty) {
      _toast(_t('اكتب تفاصيل ما يتعلق به الطلب.', 'Please describe what this relates to.'));
      return;
    }

    setState(() => _sending = true);
    try {
      final message = await SupportContactApi.send(
        topicOptionId: topic.id,
        topicCustom: topic.isOther ? _topicCustom.text.trim() : null,
        relatedOptionId: related.id,
        relatedCustom: related.isOther ? _relatedCustom.text.trim() : null,
        message: _message.text.trim().isEmpty ? null : _message.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          final tone = SettingsTone.of(AccountStore.instance.darkMode);
          return AlertDialog(
            backgroundColor: tone.panel,
            title: Text(
              _t('تم الإرسال', 'Sent'),
              style: TextStyle(color: tone.text, fontWeight: FontWeight.w800),
            ),
            content: Text(
              message.isNotEmpty ? message : form.successFor(_english),
              style: TextStyle(color: tone.muted, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_t('حسناً', 'OK'), style: TextStyle(color: tone.accent)),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _toast('$error'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
          title: Text(
            _t('مراسلة الدعم', 'Contact support'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: tone.accent))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: tone.muted)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _load,
                            child: Text(_t('إعادة المحاولة', 'Retry'), style: TextStyle(color: tone.accent)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Text(
                        _t(
                          'اختر موضوع الرسالة وما يتعلق به، وسنرد عليك خلال 48 ساعة.',
                          'Choose a topic and what it relates to — we will reply within 48 hours.',
                        ),
                        style: TextStyle(color: tone.muted, height: 1.45),
                      ),
                      const SizedBox(height: 18),
                      _dropdown(
                        tone: tone,
                        label: _form!.topicLabelFor(_english),
                        value: _topic,
                        items: _form!.topics,
                        onChanged: (value) => setState(() => _topic = value),
                      ),
                      if (_topic?.isOther == true) ...[
                        const SizedBox(height: 10),
                        _field(
                          tone: tone,
                          controller: _topicCustom,
                          hint: _t('اكتب الموضوع هنا', 'Write the topic here'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _dropdown(
                        tone: tone,
                        label: _form!.relatedLabelFor(_english),
                        value: _related,
                        items: _form!.related,
                        onChanged: (value) => setState(() => _related = value),
                      ),
                      if (_related?.isOther == true) ...[
                        const SizedBox(height: 10),
                        _field(
                          tone: tone,
                          controller: _relatedCustom,
                          hint: _t('اكتب التفاصيل هنا', 'Write the details here'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        _t('تفاصيل إضافية (اختياري)', 'Additional details (optional)'),
                        style: TextStyle(
                          color: tone.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _field(
                        tone: tone,
                        controller: _message,
                        hint: _t('اكتب رسالتك...', 'Write your message...'),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        key: const Key('support-send'),
                        onPressed: _sending ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: tone.accent,
                          foregroundColor: tone.ink,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _sending
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: tone.ink,
                                ),
                              )
                            : Text(
                                _t('إرسال', 'Send'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _dropdown({
    required SettingsTone tone,
    required String label,
    required SupportChoice? value,
    required List<SupportChoice> items,
    required ValueChanged<SupportChoice?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tone.text,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: tone.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tone.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SupportChoice>(
              isExpanded: true,
              value: value,
              dropdownColor: tone.panel,
              iconEnabledColor: tone.accent,
              style: TextStyle(color: tone.text, fontSize: 15),
              items: [
                for (final item in items)
                  DropdownMenuItem(
                    value: item,
                    child: Text(item.labelFor(_english)),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required SettingsTone tone,
    required TextEditingController controller,
    required String hint,
    int maxLines = 2,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: tone.text),
      cursorColor: tone.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tone.muted),
        filled: true,
        fillColor: tone.panel,
        contentPadding: const EdgeInsets.all(14),
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
