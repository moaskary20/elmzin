import 'package:flutter/material.dart';

/// White canvas with cartoon characters behind kids category and salon screens.
class KidsBackdrop extends StatelessWidget {
  const KidsBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFFFFFFF)),
        const _Sticker(
          'asset/kids/kids-cloud.png',
          top: 12,
          start: -28,
          size: 148,
          opacity: 0.88,
        ),
        const _Sticker(
          'asset/kids/kids-balloons.png',
          top: 64,
          end: -30,
          size: 150,
          opacity: 0.9,
        ),
        const _Sticker(
          'asset/kids/kids-stars.png',
          top: 300,
          start: -34,
          size: 132,
          opacity: 0.82,
        ),
        const _Sticker(
          'asset/kids/kids-bear.png',
          bottom: 28,
          end: -18,
          size: 168,
          opacity: 0.92,
        ),
        const _Sticker(
          'asset/kids/kids-stars.png',
          bottom: 120,
          start: 18,
          size: 72,
          opacity: 0.55,
        ),
        const _Sticker(
          'asset/kids/kids-cloud.png',
          bottom: 180,
          end: 24,
          size: 80,
          opacity: 0.5,
        ),
        child,
      ],
    );
  }
}

class _Sticker extends StatelessWidget {
  const _Sticker(
    this.asset, {
    this.top,
    this.bottom,
    this.start,
    this.end,
    required this.size,
    this.opacity = 1,
  });

  final String asset;
  final double? top;
  final double? bottom;
  final double? start;
  final double? end;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: top,
      bottom: bottom,
      start: start,
      end: end,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
