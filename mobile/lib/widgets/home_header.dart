import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/cart_store.dart';
import '../data/favorites_store.dart';
import '../data/notifications_store.dart';
import '../theme/app_colors.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({
    super.key,
    required this.english,
    this.palette = SalonPalette.gold,
    this.onOpenFavorites,
    this.onOpenNotifications,
    this.onOpenCart,
  });

  /// Height of the bar under the status inset, so other screens can clear it.
  static const barHeight = 86.0;

  final bool english;
  final SalonPalette palette;
  final VoidCallback? onOpenFavorites;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenCart;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    FavoritesStore.instance.load();
    CartStore.instance.load();
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting(widget.english);
    final feminine = widget.palette.accent == SalonPalette.blush.accent;
    final title = feminine ? widget.palette.accent : AppColors.gold;
    final subtitle = feminine ? widget.palette.soft : AppColors.goldSoft;
    final icon = feminine ? widget.palette.accent : AppColors.gold;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: feminine ? widget.palette.panel : AppColors.glass,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: feminine ? widget.palette.line : AppColors.line,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.dark
                            ? const Color(0x33000000)
                            : const Color(0x14000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _BreathingLogo(color: icon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: title,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.english
                                    ? 'Your chair is ready'
                                    : 'كرسيك بانتظارك',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: subtitle, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        ListenableBuilder(
                          listenable: CartStore.instance,
                          builder: (context, _) {
                            final count = CartStore.instance.count;
                            return _HeaderButton(
                              key: const Key('header-cart'),
                              icon: count > 0
                                  ? Icons.shopping_bag_rounded
                                  : Icons.shopping_bag_outlined,
                              color: icon,
                              selected: count > 0,
                              count: count,
                              countText: feminine
                                  ? widget.palette.panel
                                  : AppColors.ink,
                              badgeRing: feminine
                                  ? widget.palette.panel
                                  : AppColors.black,
                              onTap: widget.onOpenCart ?? () {},
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        ListenableBuilder(
                          listenable: FavoritesStore.instance,
                          builder: (context, _) {
                            final saved = FavoritesStore.instance.count > 0;
                            return _HeaderButton(
                              key: const Key('header-heart'),
                              icon: saved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: icon,
                              selected: saved,
                              onTap: widget.onOpenFavorites ?? () {},
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            AccountStore.instance,
                            NotificationsStore.instance,
                          ]),
                          builder: (context, _) {
                            final account = AccountStore.instance;
                            final on = account.notifications;
                            final unread = on && account.loggedIn
                                ? NotificationsStore.instance.unread
                                : 0;
                            return _HeaderButton(
                              key: const Key('header-notifications'),
                              icon: unread > 0
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: icon,
                              selected: false,
                              count: unread,
                              countKey: const Key('header-notifications-count'),
                              countText: feminine
                                  ? widget.palette.panel
                                  : AppColors.ink,
                              badgeRing: feminine
                                  ? widget.palette.panel
                                  : AppColors.black,
                              pulse: _pulse,
                              onTap: widget.onOpenNotifications ?? () {},
                            );
                          },
                        ),
                      ],
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

  String _greeting(bool english) {
    final hour = DateTime.now().hour;
    if (english) {
      if (hour < 12) return 'Good morning';
      if (hour < 17) return 'Good afternoon';
      return 'Good evening';
    }
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'مساء الخير';
    return 'مساء النور';
  }
}

class _BreathingLogo extends StatefulWidget {
  const _BreathingLogo({required this.color});

  final Color color;

  @override
  State<_BreathingLogo> createState() => _BreathingLogoState();
}

class _BreathingLogoState extends State<_BreathingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final scale = 1 + (_breath.value * 0.06);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 46,
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.color, width: 1.4),
        ),
        child: ClipOval(
          child: Image.asset('asset/logo.png', fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.selected,
    this.badgeRing = const Color(0xFF000000),
    this.pulse,
    this.count = 0,
    this.countText = const Color(0xFF14120C),
    this.countKey = const Key('header-cart-count'),
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool selected;
  final Color badgeRing;
  final Animation<double>? pulse;
  final int count;
  final Color countText;
  final Key countKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                scale: selected ? 1.12 : 1,
                child: Icon(icon, color: color, size: 22),
              ),
              if (count > 0)
                PositionedDirectional(
                  top: 2,
                  end: 0,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(count),
                    tween: Tween(begin: 0.4, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: _Pulse(
                      pulse: pulse,
                      child: Container(
                        key: countKey,
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: badgeRing, width: 1.4),
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: TextStyle(
                            color: countText,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pulse extends StatelessWidget {
  const _Pulse({required this.child, this.pulse});

  final Widget child;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    final animation = pulse;
    if (animation == null) return child;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) =>
          Transform.scale(scale: 1 + animation.value * 0.18, child: child),
      child: child,
    );
  }
}
