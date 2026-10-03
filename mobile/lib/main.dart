import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/account_store.dart';
import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';
import 'theme/system_bars.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemBars.overlay());
  runApp(const MuzayenApp());
}

class MuzayenApp extends StatefulWidget {
  const MuzayenApp({super.key});

  @override
  State<MuzayenApp> createState() => _MuzayenAppState();
}

class _MuzayenAppState extends State<MuzayenApp> {
  var _dark = AccountStore.instance.darkMode;

  @override
  void initState() {
    super.initState();
    AccountStore.instance.addListener(_onAccount);
  }

  @override
  void dispose() {
    AccountStore.instance.removeListener(_onAccount);
    super.dispose();
  }

  /// Brand colors are read during build, so a mode change rebuilds every
  /// screen in place without losing navigation or form state.
  void _onAccount() {
    final dark = AccountStore.instance.darkMode;
    if (dark == _dark) return;
    _dark = dark;
    setState(() {});
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المزين',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: _dark ? Brightness.dark : Brightness.light,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: AppColors.black,
        colorScheme: _dark
            ? ColorScheme.dark(
                primary: AppColors.gold,
                onPrimary: AppColors.ink,
                surface: AppColors.panel,
                onSurface: AppColors.gold,
              )
            : ColorScheme.light(
                primary: AppColors.gold,
                onPrimary: AppColors.ink,
                surface: AppColors.panel,
                onSurface: AppColors.ink,
              ),
      ),
      home: const SplashScreen(),
    );
  }
}
