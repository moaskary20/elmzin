import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/salon_detail.dart';
import '../theme/app_colors.dart';
import 'salon_photo.dart';

class SalonMediaSlider extends StatefulWidget {
  const SalonMediaSlider({
    super.key,
    required this.media,
    required this.fallbackName,
    this.fallbackUrl,
    this.height = 210,
  });

  final List<SalonMediaItem> media;
  final String fallbackName;
  final String? fallbackUrl;
  final double height;

  @override
  State<SalonMediaSlider> createState() => _SalonMediaSliderState();
}

class _SalonMediaSliderState extends State<SalonMediaSlider> {
  final _page = PageController();
  var _index = 0;

  List<SalonMediaItem> get _items {
    if (widget.media.isNotEmpty) return widget.media;
    final cover = widget.fallbackUrl;
    if (cover != null && cover.isNotEmpty) {
      return [SalonMediaItem(id: 0, type: 'image', url: cover)];
    }
    return const [];
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final accent = SalonTheme.of(context).accent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: items.isEmpty
            ? SalonPhoto(
                url: null,
                asset: salonPhotoAsset(widget.fallbackName),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    key: const Key('salon-media-slider'),
                    controller: _page,
                    itemCount: items.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      if (item.isVideo) {
                        return _VideoSlide(url: item.url, accent: accent);
                      }
                      return SalonPhoto(
                        url: item.url,
                        asset: salonPhotoAsset(widget.fallbackName),
                      );
                    },
                  ),
                  if (items.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < items.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: i == _index ? 18 : 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? accent
                                    : Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _VideoSlide extends StatefulWidget {
  const _VideoSlide({required this.url, required this.accent});

  final String url;
  final Color accent;

  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  VideoPlayerController? _controller;
  var _ready = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() => _ready = true);
      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return ColoredBox(
        color: AppColors.panel,
        child: Center(
          child: Icon(Icons.videocam_off_outlined, color: widget.accent, size: 42),
        ),
      );
    }
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return ColoredBox(
        color: AppColors.panel,
        child: Center(
          child: CircularProgressIndicator(color: widget.accent),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
        setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded, color: widget.accent, size: 34),
              ),
            ),
        ],
      ),
    );
  }
}
