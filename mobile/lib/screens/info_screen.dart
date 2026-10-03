import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/support_pages.dart';
import '../theme/settings_tone.dart';
import '../theme/system_bars.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen.help({super.key}) : slug = 'help';

  const InfoScreen.faq({super.key}) : slug = 'faq';

  const InfoScreen.privacy({super.key}) : slug = 'privacy';

  final String slug;

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  SupportPage? _remote;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pages = await PagesApi.load();
      SupportPage? match;
      for (final page in pages) {
        if (page.slug == widget.slug && page.blocks.isNotEmpty) {
          match = page;
          break;
        }
      }
      if (!mounted || match == null) return;
      setState(() => _remote = match);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final english = Directionality.of(context) == TextDirection.ltr;
    final tone = SettingsTone.of(AccountStore.instance.darkMode);
    final page = _remote ?? fallbackPage(widget.slug);
    final intro = page.introFor(english);

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
        title: Text(page.titleFor(english)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (intro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                intro,
                style: TextStyle(color: tone.muted, fontSize: 14, height: 1.6),
              ),
            ),
          for (final block in page.blocks) ...[
            Text(
              block.titleFor(english),
              style: TextStyle(
                color: tone.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              block.bodyFor(english),
              style: TextStyle(color: tone.muted, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
