import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/system_bars.dart';
import 'language_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;
  var _left = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('asset/splash.mp4');
    _controller.addListener(_onTick);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          _controller.play();
        })
        .catchError((_) {
          _openLanguage();
        });
  }

  void _onTick() {
    final value = _controller.value;
    if (value.hasError) {
      _openLanguage();
      return;
    }
    if (!value.isInitialized || value.duration == Duration.zero) return;
    if (!value.isPlaying && value.position >= value.duration) {
      _openLanguage();
    }
  }

  void _openLanguage() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => const LanguageScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _controller.value.size;
    final ready = _controller.value.isInitialized;

    return SystemBars(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: ColoredBox(
            color: Colors.black,
            child: ready
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
