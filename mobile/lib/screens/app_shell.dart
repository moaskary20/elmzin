import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account_store.dart';
import '../data/home_category.dart';
import '../data/notifications_store.dart';
import '../theme/app_colors.dart';
import '../theme/system_bars.dart';
import '../widgets/home_header.dart';
import '../widgets/muzayen_nav_bar.dart';
import 'bookings_screen.dart';
import 'cart_screen.dart';
import 'category_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'salon_screen.dart';
import 'search_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.locale});

  final Locale locale;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;
  late Locale _locale;
  int? _salonId;
  String? _salonSlug;
  HomeCategory? _category;
  var _favorites = false;
  var _notices = false;
  var _cart = false;
  String? _cartHighlight;
  var _bookingsTick = 0;
  late final Widget _settingsPage;

  bool get _women => _category?.slug == 'women' || _salonSlug == 'women';

  bool get _kids => _category?.slug == 'kids' || _salonSlug == 'kids';

  SalonPalette get _palette => _women
      ? SalonPalette.blush
      : _kids
      ? SalonPalette.kids
      : SalonPalette.gold;

  @override
  void initState() {
    super.initState();
    _locale = Locale(AccountStore.normalizeLocale(widget.locale.languageCode));
    _settingsPage = SettingsScreen(
      onLocale: (locale) {
        if (!mounted) return;
        setState(() => _locale = locale);
      },
    );
    AccountStore.instance.addListener(_onAccount);
    // Prefer the locale passed from LanguageScreen / splash; only hydrate
    // account fields without letting a stale prefs read wipe English.
    AccountStore.instance.load().then((_) {
      if (!mounted) return;
      final code = AccountStore.normalizeLocale(AccountStore.instance.locale);
      if (code != _locale.languageCode) {
        setState(() => _locale = Locale(code));
      }
    });
    NotificationsStore.instance.attach();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale.languageCode != widget.locale.languageCode) {
      _locale = Locale(AccountStore.normalizeLocale(widget.locale.languageCode));
    }
  }

  @override
  void dispose() {
    AccountStore.instance.removeListener(_onAccount);
    super.dispose();
  }

  void _onAccount() {
    final code = AccountStore.instance.locale;
    if ((code == 'ar' || code == 'en') && code != _locale.languageCode) {
      _locale = Locale(code);
    }
    if (mounted) setState(() {});
  }

  void _openSalon(int id, String slug) {
    setState(() {
      _favorites = false;
      _notices = false;
      _salonId = id;
      _salonSlug = slug;
    });
  }

  void _closeSalon() {
    setState(() {
      _salonId = null;
      _salonSlug = null;
      if (_index == 1) _bookingsTick++;
    });
  }

  void _openCart([String? highlight]) {
    setState(() {
      _cart = true;
      _cartHighlight = highlight;
      _favorites = false;
      _notices = false;
    });
  }

  void _closeCart() => setState(() => _cart = false);

  void _browseFromCart() {
    setState(() {
      _cart = false;
      _salonId = null;
      _salonSlug = null;
      _category = null;
      _index = 0;
    });
  }

  void _bookingsFromCart() {
    setState(() {
      _cart = false;
      _salonId = null;
      _salonSlug = null;
      _category = null;
      _index = 1;
      _bookingsTick++;
    });
  }

  void _bookingsFromNotices() {
    setState(() {
      _notices = false;
      _salonId = null;
      _salonSlug = null;
      _category = null;
      _index = 1;
      _bookingsTick++;
    });
  }

  void _openFavorites() {
    setState(() {
      _cart = false;
      _favorites = true;
      _notices = false;
      _salonId = null;
      _salonSlug = null;
      _category = null;
    });
  }

  void _openNotifications() {
    setState(() {
      _cart = false;
      _notices = true;
      _favorites = false;
      _salonId = null;
      _salonSlug = null;
      _category = null;
    });
  }

  Widget _belowHeader(Widget child) {
    final top = MediaQuery.paddingOf(context).top + HomeHeader.barHeight;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: child,
      ),
    );
  }

  /// Overlays cover the tab underneath, including the strip behind the header.
  Widget _overlay(Widget child) {
    return Positioned.fill(
      child: ColoredBox(color: _palette.background, child: _belowHeader(child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final english = _locale.languageCode == 'en';
    final direction = english ? TextDirection.ltr : TextDirection.rtl;
    final light = !AccountStore.instance.darkMode;
    final lightStatus = _women || _kids || light;
    final statusColor = _women || _kids ? Colors.white : AppColors.black;
    final navigationColor = _women || _kids
        ? Colors.white
        : AppColors.black;
    final statusInset = MediaQuery.paddingOf(context).top;

    final pages = [
      HomeScreen(
        locale: _locale,
        onOpenSalon: _openSalon,
        onOpenCategory: (category) => setState(() {
          _category = category;
          _salonId = null;
          _salonSlug = null;
        }),
      ),
      _belowHeader(
        BookingsScreen(reloadToken: _bookingsTick, onOpenSalon: _openSalon),
      ),
      _belowHeader(SearchScreen(locale: _locale, onOpenSalon: _openSalon)),
      _belowHeader(ServicesScreen(locale: _locale, onOpenSalon: _openSalon)),
      _belowHeader(ShopScreen(locale: _locale)),
      _belowHeader(_settingsPage),
    ];

    return SystemBars(
      lightStatus: lightStatus,
      lightNavigation: lightStatus,
      statusColor: statusColor,
      navigationColor: navigationColor,
      child: Directionality(
        textDirection: direction,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (_cart) {
              _closeCart();
              return;
            }
            if (_notices) {
              setState(() => _notices = false);
              return;
            }
            if (_favorites) {
              setState(() => _favorites = false);
              return;
            }
            if (_salonId != null) {
              _closeSalon();
              return;
            }
            if (_category != null) {
              setState(() => _category = null);
              return;
            }
            final leave = await showDialog<bool>(
              context: context,
              builder: (dialog) => Directionality(
                textDirection: direction,
                child: AlertDialog(
                  key: const Key('exit-app-dialog'),
                  backgroundColor: AppColors.panel,
                  title: Text(
                    english ? 'Exit app?' : 'هل تريد الخروج؟',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  content: Text(
                    english
                        ? 'Do you want to close المزين?'
                        : 'هل تريد إغلاق تطبيق المزين؟',
                    style: TextStyle(color: AppColors.goldSoft),
                  ),
                  actions: [
                    TextButton(
                      key: const Key('exit-app-cancel'),
                      onPressed: () => Navigator.of(dialog).pop(false),
                      child: Text(
                        english ? 'Cancel' : 'إلغاء',
                        style: TextStyle(color: AppColors.goldSoft),
                      ),
                    ),
                    FilledButton(
                      key: const Key('exit-app-confirm'),
                      onPressed: () => Navigator.of(dialog).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.ink,
                      ),
                      child: Text(
                        english ? 'Exit' : 'خروج',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (leave == true) {
              await SystemNavigator.pop();
            }
          },
          child: Scaffold(
            backgroundColor: _palette.background,
            body: Stack(
              children: [
                IndexedStack(index: _index, children: pages),
                if (_category != null)
                  _overlay(
                    CategoryScreen(
                      category: _category!,
                      locale: _locale,
                      onBack: () => setState(() => _category = null),
                      onOpenSalon: (id) => _openSalon(id, _category!.slug),
                    ),
                  ),
                if (_salonId != null)
                  _overlay(
                    SalonScreen(
                      salonId: _salonId!,
                      locale: _locale,
                      palette: _palette,
                      onBack: _closeSalon,
                      onOpenCart: _openCart,
                    ),
                  ),
                if (_favorites)
                  _overlay(
                    FavoritesScreen(
                      onBack: () => setState(() => _favorites = false),
                      onOpenSalon: _openSalon,
                    ),
                  ),
                if (_notices)
                  _overlay(
                    NotificationsScreen(
                      onBack: () => setState(() => _notices = false),
                      onOpenBookings: _bookingsFromNotices,
                    ),
                  ),
                if (_cart)
                  _overlay(
                    CartScreen(
                      key: ValueKey(_cartHighlight),
                      palette: _palette,
                      highlightKey: _cartHighlight,
                      onBack: _closeCart,
                      onBrowse: _browseFromCart,
                      onOpenBookings: _bookingsFromCart,
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: HomeHeader(
                    english: english,
                    palette: _palette,
                    onOpenFavorites: _openFavorites,
                    onOpenNotifications: _openNotifications,
                    onOpenCart: _openCart,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: statusInset,
                  child: ColoredBox(color: statusColor),
                ),
              ],
            ),
            bottomNavigationBar: MuzayenNavBar(
              index: _index,
              english: english,
              palette: _palette,
              onChanged: (index) => setState(() {
                if (index == 1) _bookingsTick++;
                _index = index;
                _salonId = null;
                _salonSlug = null;
                _category = null;
                _favorites = false;
                _notices = false;
                _cart = false;
              }),
            ),
          ),
        ),
      ),
    );
  }
}
