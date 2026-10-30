import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account_store.dart';
import '../theme/system_bars.dart';
import 'language_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  var _left = false;
  var _ready = false;
  Timer? _timer;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AccountStore.instance.load();
    try {
      final data = await rootBundle.load('asset/logo.png');
      if (!mounted) return;
      setState(() {
        _bytes = data.buffer.asUint8List();
        _ready = true;
      });
      _timer = Timer(const Duration(milliseconds: 3200), _openNext);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _timer = Timer(const Duration(milliseconds: 1800), _openNext);
    }
  }

  void _openNext() {
    if (_left || !mounted) return;
    _left = true;
    // Always ask for language on each cold start so the user can switch
    // Arabic/English every time the app is opened.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => const LanguageScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoSize = (width * 0.58).clamp(200.0, 280.0);
    final bytes = _bytes;

    return SystemBars(
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: ColoredBox(
          color: const Color(0xFF000000),
          child: Center(
            child: !_ready
                ? const SizedBox.shrink()
                : bytes == null
                ? Text(
                    'المزين',
                    key: const Key('splash-logo-fallback'),
                    style: TextStyle(
                      color: const Color(0xFFD9B25B),
                      fontSize: logoSize * 0.22,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Image.memory(
                    bytes,
                    key: const Key('splash-logo'),
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    semanticLabel: 'المزين',
                  ),
          ),
        ),
      ),
    );
  }
}
