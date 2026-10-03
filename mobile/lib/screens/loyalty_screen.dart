import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/loyalty.dart';
import '../theme/settings_tone.dart';
import '../theme/system_bars.dart';
import 'login_screen.dart';

enum _Filter { all, earn, redeem, expire }

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  LoyaltySummary? _summary;
  bool _loading = false;
  String? _error;
  var _filter = _Filter.all;

  bool get _english => Directionality.of(context) == TextDirection.ltr;

  String _t(String ar, String en) => _english ? en : ar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final account = AccountStore.instance;
    final token = account.token;
    if (!account.loggedIn || token == null || token.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await LoyaltyApi.load(token);
      if (!mounted) return;
      account.setLoyaltyPoints(summary.points);
      setState(() => _summary = summary);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _t(
          'تعذر تحميل نقاط الولاء.',
          'Could not load your loyalty points.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    final direction = Directionality.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Directionality(
          textDirection: direction,
          child: const LoginScreen(),
        ),
      ),
    );
    if (mounted) _load();
  }

  String _money(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return _english ? 'EGP $text' : '$text ج.م';
  }

  String _date(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final account = AccountStore.instance;
    final tone = SettingsTone.of(account.darkMode);

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
        title: Text(_t('نقاط الولاء', 'Loyalty points')),
      ),
      body: !account.loggedIn
          ? _guest(tone)
          : RefreshIndicator(
              color: tone.ink,
              backgroundColor: tone.accent,
              onRefresh: _load,
              child: ListView(
                key: const Key('loyalty-screen'),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: _content(tone),
              ),
            ),
    );
  }

  List<Widget> _content(SettingsTone tone) {
    final summary = _summary;
    if (summary == null) {
      return [
        const SizedBox(height: 120),
        if (_loading)
          Center(child: CircularProgressIndicator(color: tone.accent))
        else
          Column(
            children: [
              Icon(Icons.wifi_off_rounded, color: tone.muted, size: 42),
              const SizedBox(height: 10),
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: tone.muted),
              ),
              TextButton(
                key: const Key('loyalty-retry'),
                onPressed: _load,
                child: Text(
                  _t('إعادة المحاولة', 'Try again'),
                  style: TextStyle(color: tone.accent),
                ),
              ),
            ],
          ),
      ];
    }

    return [
      if (!summary.active) ...[
        _banner(
          tone,
          key: const Key('loyalty-paused'),
          icon: Icons.pause_circle_outline_rounded,
          color: tone.muted,
          text: _t(
            'برنامج النقاط متوقف مؤقتاً، ورصيدك محفوظ.',
            'The program is paused. Your balance is safe.',
          ),
        ),
        const SizedBox(height: 12),
      ],
      _hero(tone, summary),
      const SizedBox(height: 14),
      _nextReward(tone, summary),
      if (summary.expiringPoints > 0 && summary.expiringDate != null) ...[
        const SizedBox(height: 12),
        _banner(
          tone,
          key: const Key('loyalty-expiring'),
          icon: Icons.timer_outlined,
          color: const Color(0xFFE5A04B),
          text: _t(
            'تنتهي صلاحية ${summary.expiringPoints} نقطة في ${_date(summary.expiringDate!)}، استخدمها قبل ذلك.',
            '${summary.expiringPoints} points expire on ${_date(summary.expiringDate!)}.',
          ),
        ),
      ],
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _stat(
              tone,
              key: const Key('loyalty-earned'),
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF4CAF7A),
              label: _t('مكتسبة', 'Earned'),
              value: summary.earned,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _stat(
              tone,
              key: const Key('loyalty-redeemed'),
              icon: Icons.redeem_rounded,
              color: tone.accent,
              label: _t('مستبدلة', 'Redeemed'),
              value: summary.redeemed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _stat(
              tone,
              key: const Key('loyalty-expired'),
              icon: Icons.hourglass_bottom_rounded,
              color: const Color(0xFFE56B6B),
              label: _t('منتهية', 'Expired'),
              value: summary.expired,
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      _title(tone, _t('كيف تعمل النقاط؟', 'How it works')),
      const SizedBox(height: 10),
      _rules(tone, summary.rules),
      const SizedBox(height: 22),
      _title(tone, _t('سجل النقاط', 'Points history')),
      const SizedBox(height: 10),
      _filters(tone),
      const SizedBox(height: 12),
      ..._history(tone, summary),
    ];
  }

  Widget _hero(SettingsTone tone, LoyaltySummary summary) {
    final gold = tone.accent;
    return Container(
      key: const Key('loyalty-hero'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: tone.dark
              ? const [Color(0xFF3A2C10), Color(0xFF1A150B), Color(0xFF0B0B0B)]
              : const [Color(0xFFE9C978), Color(0xFFD4AE5A), Color(0xFFB88E3A)],
        ),
        border: Border.all(color: gold.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: tone.dark ? 0.22 : 0.3),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: -50,
            bottom: -70,
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 210,
              color: (tone.dark ? gold : Colors.white).withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: tone.dark ? gold : tone.ink,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _t('رصيد نقاطك', 'Your balance'),
                            style: TextStyle(
                              color: tone.dark
                                  ? gold
                                  : tone.ink.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: summary.points.toDouble()),
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Text(
                          '${value.round()}',
                          key: const Key('loyalty-points'),
                          style: TextStyle(
                            color: tone.dark ? Colors.white : tone.ink,
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                      Text(
                        _t('نقطة', 'points'),
                        style: TextStyle(
                          color: tone.dark
                              ? Colors.white70
                              : tone.ink.withValues(alpha: 0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        key: const Key('loyalty-worth'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tone.dark
                              ? gold.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          summary.redeemablePoints > 0
                              ? _t(
                                  'تساوي خصماً بقيمة ${_money(summary.redeemableValue)}',
                                  'Worth ${_money(summary.redeemableValue)} off',
                                )
                              : _t(
                                  'اجمع ${summary.rules.minRedeemPoints} نقطة لأول خصم',
                                  'Collect ${summary.rules.minRedeemPoints} for your first reward',
                                ),
                          style: TextStyle(
                            color: tone.dark ? gold : tone.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Ring(
                  progress: summary.progress,
                  color: tone.dark ? gold : tone.ink,
                  track: (tone.dark ? Colors.white : tone.ink).withValues(
                    alpha: 0.14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.redeem_rounded,
                        color: tone.dark ? gold : tone.ink,
                        size: 26,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(summary.progress * 100).round()}%',
                        style: TextStyle(
                          color: tone.dark ? Colors.white : tone.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
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
    );
  }

  Widget _nextReward(SettingsTone tone, LoyaltySummary summary) {
    return Container(
      key: const Key('loyalty-next'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: tone.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('مكافأتك القادمة', 'Next reward'),
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${summary.points} / ${summary.nextTarget}',
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: summary.progress),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: tone.line,
                valueColor: AlwaysStoppedAnimation(tone.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            summary.nextRemaining == 0
                ? _t(
                    'رصيدك يكفي لخصم ${_money(summary.nextValue)}.',
                    'You can redeem ${_money(summary.nextValue)}.',
                  )
                : _t(
                    'باقي ${summary.nextRemaining} نقطة لتحصل على خصم ${_money(summary.nextValue)}',
                    '${summary.nextRemaining} more points for ${_money(summary.nextValue)} off',
                  ),
            key: const Key('loyalty-next-text'),
            style: TextStyle(color: tone.text, fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _rules(SettingsTone tone, LoyaltyRules rules) {
    String amount(double value) => _money(value);
    final items = [
      (
        const Key('loyalty-rule-earn'),
        Icons.add_card_rounded,
        _t('اكسب', 'Earn'),
        _t(
          'كل ${amount(rules.earnAmount)} تدفعها = ${rules.earnPoints} نقطة، تُضاف عند اكتمال الحجز.',
          'Every ${amount(rules.earnAmount)} spent = ${rules.earnPoints} point(s), added when the visit is completed.',
        ),
      ),
      (
        const Key('loyalty-rule-redeem'),
        Icons.redeem_rounded,
        _t('استبدل', 'Redeem'),
        _t(
          'كل ${rules.redeemPoints} نقطة = خصم ${amount(rules.redeemValue)}، والحد الأدنى ${rules.minRedeemPoints} نقطة.',
          'Every ${rules.redeemPoints} points = ${amount(rules.redeemValue)} off. Minimum ${rules.minRedeemPoints}.',
        ),
      ),
      (
        const Key('loyalty-rule-expire'),
        Icons.event_available_rounded,
        _t('الصلاحية', 'Validity'),
        rules.expireDays == null
            ? _t('نقاطك لا تنتهي صلاحيتها.', 'Your points never expire.')
            : _t(
                'تبقى النقاط صالحة ${rules.expireDays} يوماً من تاريخ اكتسابها.',
                'Points stay valid for ${rules.expireDays} days.',
              ),
      ),
      (
        const Key('loyalty-rule-cancel'),
        Icons.undo_rounded,
        _t('الإلغاء', 'Cancellation'),
        _t(
          'عند إلغاء الحجز تعود النقاط المستبدلة إلى رصيدك.',
          'Cancelling a booking returns any redeemed points.',
        ),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: tone.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.line),
      ),
      child: Column(
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0)
              Divider(height: 1, color: tone.line, indent: 66, endIndent: 16),
            Padding(
              key: item.$1,
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tone.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.$2, color: tone.accent, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: tone.text,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$4,
                          style: TextStyle(
                            color: tone.muted,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filters(SettingsTone tone) {
    final options = [
      (_Filter.all, _t('الكل', 'All')),
      (_Filter.earn, _t('مكتسبة', 'Earned')),
      (_Filter.redeem, _t('مستبدلة', 'Redeemed')),
      (_Filter.expire, _t('منتهية', 'Expired')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (filter, label) in options) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                key: Key('loyalty-filter-${filter.name}'),
                label: Text(label),
                selected: _filter == filter,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = filter),
                selectedColor: tone.accent,
                backgroundColor: tone.panel,
                side: BorderSide(
                  color: _filter == filter ? tone.accent : tone.line,
                ),
                labelStyle: TextStyle(
                  color: _filter == filter ? tone.ink : tone.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _history(SettingsTone tone, LoyaltySummary summary) {
    final entries = summary.entries.where((entry) {
      return switch (_filter) {
        _Filter.all => true,
        _Filter.earn =>
          entry.type == 'earn' || (entry.type == 'adjust' && entry.points > 0),
        _Filter.redeem =>
          entry.type == 'redeem' ||
              (entry.type == 'adjust' && entry.points < 0),
        _Filter.expire => entry.type == 'expire',
      };
    }).toList();

    if (entries.isEmpty) {
      return [
        Padding(
          key: const Key('loyalty-empty'),
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            children: [
              Icon(Icons.stars_outlined, color: tone.muted, size: 40),
              const SizedBox(height: 8),
              Text(
                _t(
                  'لا توجد حركات بعد. احجز وأكمل زيارتك لتبدأ جمع النقاط.',
                  'No activity yet. Complete a visit to start earning.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: tone.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _entry(tone, entry),
        ),
    ];
  }

  Widget _entry(SettingsTone tone, LoyaltyEntry entry) {
    final positive = entry.points >= 0;
    final (icon, color) = switch (entry.type) {
      'earn' => (Icons.add_circle_outline_rounded, const Color(0xFF4CAF7A)),
      'redeem' => (Icons.redeem_rounded, tone.accent),
      'expire' => (Icons.hourglass_bottom_rounded, const Color(0xFFE56B6B)),
      _ => (
        positive ? Icons.card_giftcard_rounded : Icons.remove_circle_outline,
        positive ? const Color(0xFF4CAF7A) : const Color(0xFFE56B6B),
      ),
    };
    final details = [
      ?entry.salon,
      if (entry.createdAt != null) _date(entry.createdAt!),
    ].join(' • ');

    return Container(
      key: Key('loyalty-entry-${entry.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.note?.isNotEmpty == true ? entry.note! : entry.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: TextStyle(color: tone.muted, fontSize: 12),
                  ),
                if (entry.expiresAt != null)
                  Text(
                    _t(
                      'صالحة حتى ${_date(entry.expiresAt!)}',
                      'Valid until ${_date(entry.expiresAt!)}',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFE5A04B),
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${positive ? '+' : '−'}${entry.points.abs()}',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    SettingsTone tone, {
    required Key key,
    required IconData icon,
    required Color color,
    required String label,
    required int value,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: tone.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: tone.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: TextStyle(color: tone.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _banner(
    SettingsTone tone, {
    required Key key,
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: tone.text, fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(SettingsTone tone, String text) => Text(
    text,
    style: TextStyle(
      color: tone.text,
      fontSize: 17,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _guest(SettingsTone tone) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          key: const Key('loyalty-guest'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              color: tone.accent,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              _t('اجمع النقاط مع كل زيارة', 'Earn points on every visit'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tone.text,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'سجّل الدخول لتتابع رصيد نقاطك وتستبدلها بخصومات على حجوزاتك.',
                'Sign in to track your points and turn them into discounts.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: tone.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('loyalty-login'),
              onPressed: _login,
              style: FilledButton.styleFrom(
                backgroundColor: tone.accent,
                foregroundColor: tone.ink,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _t('تسجيل الدخول', 'Sign in'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.progress,
    required this.color,
    required this.track,
    required this.child,
  });

  final double progress;
  final Color color;
  final Color track;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, inner) => CustomPaint(
        size: const Size.square(96),
        painter: _RingPainter(value: value, color: color, track: track),
        child: SizedBox.square(dimension: 96, child: Center(child: inner)),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
