import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bundled photo for the seeded salons, used when the server image is missing.
String? salonPhotoAsset(String name) {
  return switch (name) {
    'صالون الليث' => 'asset/salons/layth.jpg',
    'لمسة جمال' => 'asset/salons/lamsa.jpg',
    'براعم' => 'asset/salons/baraem.jpg',
    'بيت الحلاقة' => 'asset/salons/bait.jpg',
    'دار الجمال' => 'asset/salons/dar.jpg',
    'أتيليه نور' => 'asset/salons/atelier.jpg',
    'صالون الصغير' => 'asset/salons/saghir.jpg',
    _ => null,
  };
}

class SalonPhoto extends StatelessWidget {
  const SalonPhoto({super.key, required this.url, this.asset});

  final String? url;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final local = _assetImage();
    final image = url;
    if (image == null || image.isEmpty) {
      return local ?? const _PhotoFallback();
    }

    return Image.network(
      image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) =>
          local ?? const _PhotoFallback(),
    );
  }

  Widget? _assetImage() {
    final path = asset;
    if (path == null || path.isEmpty) return null;
    return Image.asset(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.dark ? const Color(0xFF161616) : const Color(0xFFEDE6D6),
      child: Center(
        child: Icon(Icons.storefront_outlined, color: AppColors.gold, size: 32),
      ),
    );
  }
}
