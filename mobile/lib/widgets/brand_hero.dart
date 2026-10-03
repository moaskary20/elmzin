import 'package:flutter/material.dart';

import '../theme/settings_tone.dart';

class BrandHero extends StatefulWidget {
  const BrandHero({
    super.key,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.size = 142,
    this.logoKey,
  });

  final SettingsTone tone;
  final String title;
  final String subtitle;
  final double size;
  final Key? logoKey;

  @override
  State<BrandHero> createState() => _BrandHeroState();
}

class _BrandHeroState extends State<BrandHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final gold = tone.accent;
    final size = widget.size;
    final medallion = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
    );
    final caption = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
    );

    return Column(
      children: [
        SizedBox(
          height: size + 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 1.62,
                height: size + 28,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      gold.withValues(alpha: tone.dark ? 0.22 : 0.16),
                      gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              ScaleTransition(
                scale: Tween<double>(begin: 0.82, end: 1).animate(medallion),
                child: FadeTransition(
                  opacity: _intro.drive(
                    CurveTween(curve: const Interval(0, 0.5)),
                  ),
                  child: Container(
                    key: widget.logoKey,
                    width: size,
                    height: size,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold.withValues(alpha: 0.35)),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: tone.dark
                              ? const [Color(0xFF1A1710), Color(0xFF080808)]
                              : [Colors.white, tone.panel],
                        ),
                        border: Border.all(color: gold, width: 1.6),
                        boxShadow: [
                          BoxShadow(
                            color: gold.withValues(alpha: 0.25),
                            blurRadius: 28,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(size * 0.1),
                      child: Image.asset(
                        'asset/logo.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'المزين',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        FadeTransition(
          opacity: caption,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(caption),
            child: Column(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _rule(gold, reverse: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Transform.rotate(
                        angle: 0.785398,
                        child: Container(width: 7, height: 7, color: gold),
                      ),
                    ),
                    _rule(gold),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _rule(Color gold, {bool reverse = false}) {
    final colors = [gold.withValues(alpha: 0), gold];
    return Container(
      width: 54,
      height: 1.2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: reverse ? colors.reversed.toList() : colors,
        ),
      ),
    );
  }
}
