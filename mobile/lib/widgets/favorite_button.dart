import 'package:flutter/material.dart';

import '../data/favorites_store.dart';
import '../theme/app_colors.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.salonId,
    this.size = 22,
    this.color,
  });

  final int salonId;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavoritesStore.instance,
      builder: (context, _) {
        final saved = FavoritesStore.instance.contains(salonId);
        return GestureDetector(
          key: Key('favorite-$salonId'),
          behavior: HitTestBehavior.opaque,
          onTap: () => FavoritesStore.instance.toggle(salonId),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            scale: saved ? 1.12 : 1,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: color ?? AppColors.gold,
                size: size,
              ),
            ),
          ),
        );
      },
    );
  }
}
