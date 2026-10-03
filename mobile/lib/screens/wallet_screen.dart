import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/wallet.dart';
import '../theme/settings_tone.dart';
import '../theme/system_bars.dart';
import 'login_screen.dart';

enum _Filter { all, credit, debit }

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  WalletSummary? _summary;
  bool _loading = false;
  String? _error;
  var _filter = _Filter.all;

  bool get _english => Directionality.of(context) == TextDirection.ltr;

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
      final summary = await WalletApi.load(token);
      if (!mounted) return;
      account.setWalletBalance(summary.balance);
      setState(() => _summary = summary);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _english
            ? 'Could not load your wallet.'
            : 'تعذر تحميل المحفظة.',
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
    final text = value.abs().toStringAsFixed(2);
    return _english ? 'EGP $text' : '$text ج.م';
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountStore.instance;
    final tone = SettingsTone.of(account.darkMode);
    final english = _english;

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
        title: Text(english ? 'Wallet' : 'المحفظة'),
      ),
      body: !account.loggedIn
          ? _guest(tone)
          : RefreshIndicator(
              color: tone.ink,
              backgroundColor: tone.accent,
              onRefresh: _load,
              child: ListView(
                key: const Key('wallet-screen'),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: _content(tone),
              ),
            ),
    );
  }

  List<Widget> _content(SettingsTone tone) {
    final english = _english;
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
                key: const Key('wallet-retry'),
                onPressed: _load,
                child: Text(
                  english ? 'Try again' : 'إعادة المحاولة',
                  style: TextStyle(color: tone.accent),
                ),
              ),
            ],
          ),
      ];
    }

    final entries = summary.entries.where((entry) {
      return switch (_filter) {
        _Filter.all => true,
        _Filter.credit => entry.credit,
        _Filter.debit => !entry.credit,
      };
    }).toList();

    return [
      _balanceCard(tone, summary),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _stat(
              tone,
              icon: Icons.south_west_rounded,
              color: const Color(0xFF4CAF7A),
              label: english ? 'Added' : 'الإضافات',
              value: _money(summary.totalIn),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _stat(
              tone,
              icon: Icons.north_east_rounded,
              color: const Color(0xFFE56B6B),
              label: english ? 'Spent' : 'المدفوعات',
              value: _money(summary.totalOut),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tone.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.line),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: tone.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                english
                    ? 'Top-ups and refunds are added by Al-Muzayyin support.'
                    : 'يُضاف الشحن والاسترداد إلى محفظتك عن طريق إدارة المزين.',
                style: TextStyle(color: tone.muted, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        english ? 'Transactions' : 'سجل الحركات',
        style: TextStyle(
          color: tone.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          _chip(tone, _Filter.all, english ? 'All' : 'الكل'),
          _chip(tone, _Filter.credit, english ? 'Added' : 'الإضافات'),
          _chip(tone, _Filter.debit, english ? 'Spent' : 'الخصومات'),
        ],
      ),
      const SizedBox(height: 12),
      if (entries.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, color: tone.muted, size: 40),
              const SizedBox(height: 10),
              Text(
                english ? 'No transactions yet' : 'لا توجد حركات بعد',
                key: const Key('wallet-empty'),
                style: TextStyle(color: tone.muted),
              ),
            ],
          ),
        )
      else
        for (final entry in entries) _entry(tone, entry),
    ];
  }

  Widget _balanceCard(SettingsTone tone, WalletSummary summary) {
    final english = _english;
    const ink = Color(0xFF14120C);
    return Container(
      key: const Key('wallet-balance-card'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFFE8C877), Color(0xFFD9B25B), Color(0xFFB08A3A)],
        ),
        boxShadow: [
          BoxShadow(
            color: tone.accent.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: ink,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  english ? 'Current balance' : 'رصيدك الحالي',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Image.asset('asset/logo.png', width: 38, height: 38),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _money(summary.balance),
            key: const Key('wallet-balance'),
            style: const TextStyle(
              color: ink,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: ink, size: 16),
                const SizedBox(width: 6),
                Text(
                  english
                      ? '${summary.points} loyalty points'
                      : '${summary.points} نقطة ولاء',
                  key: const Key('wallet-points'),
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    SettingsTone tone, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: tone.muted, fontSize: 12)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
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

  Widget _chip(SettingsTone tone, _Filter value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      key: Key('wallet-filter-${value.name}'),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = value),
      backgroundColor: tone.panel,
      selectedColor: tone.accent,
      side: BorderSide(color: selected ? tone.accent : tone.line),
      labelStyle: TextStyle(
        color: selected ? tone.ink : tone.text,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _entry(SettingsTone tone, WalletEntry entry) {
    final english = _english;
    final color = entry.credit
        ? const Color(0xFF4CAF7A)
        : const Color(0xFFE56B6B);
    final icon = switch (entry.type) {
      'deposit' => Icons.add_card_rounded,
      'refund' => Icons.replay_rounded,
      'reward' => Icons.card_giftcard_rounded,
      'payment' => Icons.content_cut_rounded,
      _ => Icons.remove_circle_outline_rounded,
    };
    final date = entry.createdAt?.toLocal();
    final when = date == null
        ? ''
        : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Container(
      key: Key('wallet-entry-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: TextStyle(
                    color: tone.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.note != null && entry.note!.isNotEmpty)
                  Text(
                    entry.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tone.muted, fontSize: 12),
                  ),
                Text(when, style: TextStyle(color: tone.muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.credit ? '+' : '−'} ${_money(entry.amount)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              Text(
                english
                    ? 'Balance ${_money(entry.balanceAfter)}'
                    : 'الرصيد ${_money(entry.balanceAfter)}',
                style: TextStyle(color: tone.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guest(SettingsTone tone) {
    final english = _english;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: tone.accent,
              size: 64,
            ),
            const SizedBox(height: 14),
            Text(
              english
                  ? 'Sign in to see your wallet.'
                  : 'سجّل الدخول لترى رصيد محفظتك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tone.text, fontSize: 16),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('wallet-login'),
              onPressed: _login,
              style: FilledButton.styleFrom(
                backgroundColor: tone.accent,
                foregroundColor: tone.ink,
                minimumSize: const Size(200, 48),
              ),
              child: Text(english ? 'Sign in' : 'تسجيل الدخول'),
            ),
          ],
        ),
      ),
    );
  }
}
