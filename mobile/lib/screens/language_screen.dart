import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../theme/app_colors.dart';
import '../theme/system_bars.dart';
import 'app_shell.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _select(Locale locale) {
    AccountStore.instance.setLocale(locale.languageCode);
    setState(() => _locale = locale);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => AppShell(locale: locale),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    );
    return SystemBars(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.7),
              radius: 1.1,
              colors: [Color(0xFF1A160E), Colors.black],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.clamp(0, 420).toDouble();
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    height: constraints.maxHeight,
                    child: Directionality(
                      textDirection: _locale?.languageCode == 'en'
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                      child: FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(curved),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              children: [
                                const Spacer(flex: 3),
                                const _FloatingLogo(),
                                const SizedBox(height: 28),
                                Container(
                                  width: 56,
                                  height: 1,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  'اختر اللغة',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Choose your language',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.goldSoft,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 36),
                                _LanguageChoice(
                                  label: 'العربية',
                                  caption: 'Arabic',
                                  selected: _locale?.languageCode == 'ar',
                                  onTap: () => _select(const Locale('ar')),
                                ),
                                const SizedBox(height: 14),
                                _LanguageChoice(
                                  label: 'English',
                                  caption: 'الإنجليزية',
                                  selected: _locale?.languageCode == 'en',
                                  onTap: () => _select(const Locale('en')),
                                ),
                                const Spacer(flex: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo();

  @override
  State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        final dy = Tween<double>(
          begin: 0,
          end: -8,
        ).transform(Curves.easeInOut.transform(_float.value));
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Image.asset(
        'asset/logo.png',
        width: 210,
        fit: BoxFit.contain,
        semanticLabel: 'المزين',
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey(label),
      color: selected ? AppColors.gold : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? AppColors.gold : AppColors.line,
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.gold.withValues(alpha: 0.16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? AppColors.ink : AppColors.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: TextStyle(
                        color: selected
                            ? AppColors.ink.withValues(alpha: 0.7)
                            : AppColors.goldSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.check_rounded, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
