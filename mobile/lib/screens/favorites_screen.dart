import 'package:flutter/material.dart';

import '../data/favorites_store.dart';
import '../data/home_salon.dart';
import '../theme/app_colors.dart';
import '../widgets/favorite_button.dart';
import '../widgets/salon_photo.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    required this.onBack,
    required this.onOpenSalon,
  });

  final VoidCallback onBack;
  final void Function(int id, String categorySlug) onOpenSalon;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<HomeSalon> _salons = HomeSalon.fallback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final salons = await SalonsApi.load();
      if (!mounted) return;
      setState(() => _salons = salons);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final english = Directionality.of(context) == TextDirection.ltr;

    return ColoredBox(
      key: const Key('favorites-screen'),
      color: AppColors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TitleBar(
              title: english ? 'Favorites' : 'المفضلة',
              onBack: widget.onBack,
              backKey: const Key('favorites-back'),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: FavoritesStore.instance,
                builder: (context, _) {
                  final saved = _salons
                      .where(
                        (salon) => FavoritesStore.instance.contains(salon.id),
                      )
                      .toList();
                  if (saved.isEmpty) {
                    return _Empty(
                      icon: Icons.favorite_border_rounded,
                      title: english
                          ? 'No favorite salons yet'
                          : 'لا توجد صالونات في المفضلة',
                      body: english
                          ? 'Tap the heart on a salon to save it here.'
                          : 'اضغط القلب على أي صالون ليُحفظ هنا.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: saved.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final salon = saved[index];
                      return _SalonTile(
                        salon: salon,
                        onTap: () =>
                            widget.onOpenSalon(salon.id, salon.categorySlug),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonTile extends StatelessWidget {
  const _SalonTile({required this.salon, required this.onTap});

  final HomeSalon salon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: SalonPhoto(
                    url: salon.imageUrl,
                    asset: salonPhotoAsset(salon.name),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salon.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      salon.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.goldSoft, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      salon.ratingAvg.toStringAsFixed(1),
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FavoriteButton(salonId: salon.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.onBack,
    required this.backKey,
  });

  final String title;
  final VoidCallback onBack;
  final Key backKey;

  @override
  Widget build(BuildContext context) {
    final back = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_forward_rounded
        : Icons.arrow_back_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            key: backKey,
            onPressed: onBack,
            icon: Icon(back, color: AppColors.gold),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.gold, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.goldSoft,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
