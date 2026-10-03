import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.label,
    required this.labelEn,
  });

  final IconData icon;
  final String label;
  final String labelEn;
}

const navDestinations = [
  NavDestination(icon: Icons.home_outlined, label: 'الرئيسية', labelEn: 'Home'),
  NavDestination(
    icon: Icons.event_note_outlined,
    label: 'حجوزاتي',
    labelEn: 'Bookings',
  ),
  NavDestination(icon: Icons.search, label: 'البحث', labelEn: 'Search'),
  NavDestination(
    icon: Icons.content_cut_rounded,
    label: 'الخدمات',
    labelEn: 'Services',
  ),
  NavDestination(
    icon: Icons.settings_outlined,
    label: 'الإعدادات',
    labelEn: 'Settings',
  ),
];

class MuzayenNavBar extends StatefulWidget {
  const MuzayenNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.english,
    this.palette = SalonPalette.gold,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final bool english;
  final SalonPalette palette;

  @override
  State<MuzayenNavBar> createState() => _MuzayenNavBarState();
}

class _MuzayenNavBarState extends State<MuzayenNavBar>
    with TickerProviderStateMixin {
  static const _buttonRadius = 26.0;
  static const _notchRadius = 34.0;
  static const _barTop = 34.0;
  static const _barBody = 68.0;

  late final AnimationController _motion;
  late final AnimationController _tint;
  late Animation<double> _slide;
  SalonPalette _fromPalette = SalonPalette.gold;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _tint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = AlwaysStoppedAnimation(widget.index.toDouble());
    _fromPalette = widget.palette;
  }

  @override
  void didUpdateWidget(MuzayenNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.palette != widget.palette) {
      _fromPalette = oldWidget.palette;
      _tint.forward(from: 0);
    }
    if (oldWidget.index == widget.index) return;
    _slide = Tween<double>(
      begin: oldWidget.index.toDouble(),
      end: widget.index.toDouble(),
    ).animate(CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic));
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    _tint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final feminine = widget.palette.accent == SalonPalette.blush.accent;
    final systemColor = feminine ? Colors.white : AppColors.black;
    final barHeight = _barTop + _barBody;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isRtl = Directionality.of(context) == TextDirection.rtl;
              final width = constraints.maxWidth;
              final count = navDestinations.length;
              final slot = width / count;

              return AnimatedBuilder(
                animation: Listenable.merge([_motion, _tint]),
                builder: (context, _) {
                  final logical = _slide.value;
                  final visual = isRtl ? (count - 1) - logical : logical;
                  final rawCenter = (visual + 0.5) * slot;
                  final centerX = rawCenter.clamp(
                    _notchRadius + 8,
                    width - _notchRadius - 8,
                  );
                  final lift = math.sin(_motion.value * math.pi) * 7;
                  final circleTop = _barTop - 2 - _buttonRadius - lift;
                  final destination = navDestinations[widget.index];
                  final shift = Curves.easeOutCubic.transform(_tint.value);
                  final bar = Color.lerp(
                    _fromPalette.accent,
                    widget.palette.accent,
                    shift,
                  )!;
                  final onBar = Color.lerp(
                    _fromPalette.onBar,
                    widget.palette.onBar,
                    shift,
                  )!;
                  final circle = Color.lerp(
                    _fromPalette.circle,
                    widget.palette.circle,
                    shift,
                  )!;
                  final onCircle = Color.lerp(
                    _fromPalette.onCircle,
                    widget.palette.onCircle,
                    shift,
                  )!;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _NotchedBarPainter(
                            centerX: centerX,
                            barTop: _barTop,
                            circleCenterY: _barTop - 2 - lift,
                            notchRadius: _notchRadius,
                            color: bar,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _barTop,
                        bottom: 0,
                        child: Row(
                          children: [
                            for (var i = 0; i < count; i++)
                              Expanded(
                                child: _NavItem(
                                  destination: navDestinations[i],
                                  selected: widget.index == i,
                                  english: widget.english,
                                  foreground: onBar,
                                  bottomInset: 0,
                                  onTap: () => widget.onChanged(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: centerX - _buttonRadius,
                        top: circleTop,
                        width: _buttonRadius * 2,
                        height: _buttonRadius * 2,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: circle,
                              shape: BoxShape.circle,
                              border: Border.all(color: onCircle, width: 2.6),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutBack,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Icon(
                                destination.icon,
                                key: ValueKey(widget.index),
                                color: onCircle,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        ColoredBox(
          color: systemColor,
          child: SizedBox(width: double.infinity, height: bottom),
        ),
      ],
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({
    required this.centerX,
    required this.barTop,
    required this.circleCenterY,
    required this.notchRadius,
    required this.color,
  });

  final double centerX;
  final double barTop;
  final double circleCenterY;
  final double notchRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final top = barTop;
    final dy = top - circleCenterY;
    final reach = math.sqrt(math.max(0, notchRadius * notchRadius - dy * dy));
    final leftX = centerX - reach;
    final rightX = centerX + reach;
    final angleLeft = math.atan2(dy, -reach);
    final angleRight = math.atan2(dy, reach);
    const fillet = 14.0;
    const tuck = 0.62;

    Offset onCircle(double angle) {
      return Offset(
        centerX + notchRadius * math.cos(angle),
        circleCenterY + notchRadius * math.sin(angle),
      );
    }

    final leftLip = onCircle(angleLeft - tuck);
    final rightLip = onCircle(angleRight + tuck);
    final path = Path()
      ..moveTo(0, top)
      ..lineTo(leftX - fillet, top)
      ..quadraticBezierTo(leftX, top, leftLip.dx, leftLip.dy)
      ..arcToPoint(
        rightLip,
        radius: Radius.circular(notchRadius),
        clockwise: false,
      )
      ..quadraticBezierTo(rightX, top, rightX + fillet, top)
      ..lineTo(width, top)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    canvas.drawShadow(path, const Color(0xFF000000), 8, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter oldDelegate) {
    return oldDelegate.centerX != centerX ||
        oldDelegate.barTop != barTop ||
        oldDelegate.circleCenterY != circleCenterY ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.color != color;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.english,
    required this.foreground,
    required this.bottomInset,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool english;
  final Color foreground;
  final double bottomInset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = english ? destination.labelEn : destination.label;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 0 : 1,
              child: Icon(destination.icon, color: foreground, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
