import 'package:flutter/material.dart';

import '../data/subscription_plans.dart';
import '../screens/cart_screen.dart' show ConfettiBurst;
import '../theme/settings_tone.dart';

class PlanPicker extends StatelessWidget {
  const PlanPicker({
    super.key,
    required this.plans,
    required this.selectedId,
    required this.accepted,
    required this.tone,
    required this.onSelect,
    required this.onAccepted,
  });

  final List<SubscriptionPlan> plans;
  final int? selectedId;
  final bool accepted;
  final SettingsTone tone;
  final ValueChanged<SubscriptionPlan> onSelect;
  final ValueChanged<bool> onAccepted;

  SubscriptionPlan? get _selected {
    for (final plan in plans) {
      if (plan.id == selectedId) return plan;
    }
    return null;
  }

  Future<void> _openTerms(BuildContext context, SubscriptionPlan plan) async {
    final agreed = await showPlanTerms(context, plan, tone);
    if (agreed == true) onAccepted(true);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (plans.length == 1) {
              return _PlanCard(
                plan: plans.first,
                tone: tone,
                selected: plans.first.id == selectedId,
                onTap: () => onSelect(plans.first),
                onTerms: () => _openTerms(context, plans.first),
              );
            }
            final width = constraints.maxWidth * 0.84;
            return SingleChildScrollView(
              key: const Key('plan-scroller'),
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, plan) in plans.indexed) ...[
                      if (index > 0) const SizedBox(width: 12),
                      SizedBox(
                        width: width,
                        child: _PlanCard(
                          plan: plan,
                          tone: tone,
                          selected: plan.id == selectedId,
                          onTap: () => onSelect(plan),
                          onTerms: () => _openTerms(context, plan),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        if (selected != null && selected.terms.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TermsCheck(
            plan: selected,
            tone: tone,
            accepted: accepted,
            onChanged: onAccepted,
            onOpen: () => _openTerms(context, selected),
          ),
        ],
      ],
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.plan,
    required this.tone,
    required this.selected,
    required this.onTap,
    required this.onTerms,
  });

  final SubscriptionPlan plan;
  final SettingsTone tone;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onTerms;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.plan.badge != null) _shine.repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final tone = widget.tone;
    final selected = widget.selected;
    final gold = tone.accent;
    final colors = tone.dark
        ? const [Color(0xFF2A2110), Color(0xFF16130B), Color(0xFF0D0D0D)]
        : const [Color(0xFFFFF6DF), Color(0xFFFFFCF4), Color(0xFFFFFFFF)];

    return AnimatedScale(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      scale: selected ? 1 : 0.97,
      child: AnimatedContainer(
        key: Key('plan-${plan.id}'),
        duration: const Duration(milliseconds: 260),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: colors,
          ),
          border: Border.all(
            color: selected ? gold : tone.line,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: gold.withValues(alpha: tone.dark ? 0.28 : 0.22),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -40,
                  top: -40,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          gold.withValues(alpha: 0.22),
                          gold.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  gold,
                                  Color.lerp(gold, Colors.white, 0.35)!,
                                ],
                              ),
                            ),
                            child: Icon(
                              plan.isFree
                                  ? Icons.workspace_premium_rounded
                                  : Icons.diamond_outlined,
                              color: tone.ink,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (plan.badge != null) ...[
                                  _ShineBadge(
                                    text: plan.badge!,
                                    tone: tone,
                                    shine: _shine,
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Text(
                                  plan.name,
                                  style: TextStyle(
                                    color: tone.text,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (plan.tagline != null)
                                  Text(
                                    plan.tagline!,
                                    style: TextStyle(
                                      color: tone.muted,
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: selected
                                ? Container(
                                    key: const ValueKey('on'),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: gold,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: tone.ink,
                                    ),
                                  )
                                : Container(
                                    key: const ValueKey('off'),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: tone.line),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(
                            plan.priceLabel,
                            key: Key('plan-price-${plan.id}'),
                            style: TextStyle(
                              color: gold,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              plan.isFree
                                  ? 'لمدة ${plan.durationLabel}'
                                  : '/ ${plan.durationLabel}',
                              style: TextStyle(
                                color: tone.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (plan.isFree) ...[
                        const SizedBox(height: 6),
                        Text(
                          'بدون أي بيانات دفع • يبدأ فور التسجيل',
                          style: TextStyle(color: tone.muted, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(height: 1, color: tone.line),
                      const SizedBox(height: 14),
                      for (final feature in plan.features)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: gold,
                                size: 18,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    color: tone.text,
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(
                            tone: tone,
                            icon: Icons.content_cut_rounded,
                            text: plan.maxServices == null
                                ? 'خدمات بلا حدود'
                                : 'حتى ${plan.maxServices} خدمة',
                          ),
                          _Chip(
                            tone: tone,
                            icon: Icons.groups_2_outlined,
                            text: plan.maxSpecialists == null
                                ? 'أخصائيون بلا حدود'
                                : 'حتى ${plan.maxSpecialists} أخصائي',
                          ),
                        ],
                      ),
                      if (plan.terms.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            key: Key('plan-terms-${plan.id}'),
                            onPressed: widget.onTerms,
                            style: TextButton.styleFrom(
                              foregroundColor: gold,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            icon: const Icon(Icons.gavel_rounded, size: 18),
                            label: Text(
                              'قوانين الاشتراك (${plan.terms.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShineBadge extends StatelessWidget {
  const _ShineBadge({
    required this.text,
    required this.tone,
    required this.shine,
  });

  final String text;
  final SettingsTone tone;
  final Animation<double> shine;

  @override
  Widget build(BuildContext context) {
    final gold = tone.accent;
    final light = Color.lerp(gold, Colors.white, 0.55)!;
    return AnimatedBuilder(
      animation: shine,
      builder: (context, child) {
        final t = shine.value * 3 - 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [gold, light, gold],
              stops: const [0.3, 0.5, 0.7],
            ),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: tone.ink),
          const SizedBox(width: 4),
          Text(
            text,
            key: const Key('plan-badge'),
            style: TextStyle(
              color: tone.ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.tone, required this.icon, required this.text});

  final SettingsTone tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone.accent),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: tone.text,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsCheck extends StatelessWidget {
  const _TermsCheck({
    required this.plan,
    required this.tone,
    required this.accepted,
    required this.onChanged,
    required this.onOpen,
  });

  final SubscriptionPlan plan;
  final SettingsTone tone;
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tone.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('register-terms'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!accepted),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accepted ? tone.accent : tone.line),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accepted ? tone.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: tone.accent),
                ),
                child: accepted
                    ? Icon(Icons.check, size: 16, color: tone.ink)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'أوافق على ',
                      style: TextStyle(color: tone.text, fontSize: 13.5),
                    ),
                    GestureDetector(
                      key: const Key('register-terms-open'),
                      onTap: onOpen,
                      child: Text(
                        'قوانين الاشتراك',
                        style: TextStyle(
                          color: tone.accent,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationColor: tone.accent,
                        ),
                      ),
                    ),
                    Text(
                      ' في ${plan.name}',
                      style: TextStyle(color: tone.text, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showPlanTerms(
  BuildContext context,
  SubscriptionPlan plan,
  SettingsTone tone,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tone.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheet) => Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.82,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            key: const Key('plan-terms-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tone.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: tone.accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.gavel_rounded, color: tone.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'قوانين الاشتراك',
                            style: TextStyle(
                              color: tone.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${plan.name} • ${plan.priceLabel} لمدة ${plan.durationLabel}',
                            style: TextStyle(color: tone.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                  itemCount: plan.terms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: tone.accent),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: tone.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          plan.terms[index],
                          style: TextStyle(
                            color: tone.text,
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
                child: FilledButton.icon(
                  key: const Key('plan-terms-agree'),
                  onPressed: () => Navigator.of(sheet).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: tone.accent,
                    foregroundColor: tone.ink,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text(
                    'قرأت القوانين وأوافق عليها',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showSubscriptionWelcome(
  BuildContext context,
  SubscriptionPlan plan,
  SettingsTone tone,
) {
  final ends = plan.endsFrom(DateTime.now());
  final until =
      '${ends.year}/${ends.month.toString().padLeft(2, '0')}/${ends.day.toString().padLeft(2, '0')}';
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Material(
                key: const Key('subscription-welcome'),
                color: tone.panel,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: tone.accent, width: 1.4),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.3, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                tone.accent,
                                Color.lerp(tone.accent, Colors.white, 0.4)!,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tone.accent.withValues(alpha: 0.4),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            size: 46,
                            color: tone.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'تم تفعيل اشتراكك',
                        style: TextStyle(
                          color: tone.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'مرحباً بك في ${plan.name}',
                        style: TextStyle(
                          color: tone.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tone.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              plan.isFree
                                  ? '${plan.priceLabel} لمدة ${plan.durationLabel}'
                                  : '${plan.priceLabel} / ${plan.durationLabel}',
                              style: TextStyle(
                                color: tone.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ساري حتى $until',
                              key: const Key('subscription-welcome-until'),
                              textDirection: TextDirection.rtl,
                              style: TextStyle(color: tone.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'سيظهر صالونك للعملاء فور مراجعة الإدارة وتوثيقه، وسنرسل لك إشعاراً بذلك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tone.muted,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const Key('subscription-welcome-start'),
                        onPressed: () => Navigator.of(dialog).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: tone.accent,
                          foregroundColor: tone.ink,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'ابدأ الآن',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiBurst(
                colors: [
                  tone.accent,
                  Color.lerp(tone.accent, Colors.white, 0.5)!,
                  const Color(0xFFF2E3B3),
                  const Color(0xFFFFFFFF),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
