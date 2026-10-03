import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzayen/data/account_store.dart';
import 'package:muzayen/data/auth_api.dart';
import 'package:muzayen/data/cart_store.dart';
import 'package:muzayen/data/customer_booking.dart';
import 'package:muzayen/data/favorites_store.dart';
import 'package:muzayen/data/home_category.dart';
import 'package:muzayen/data/home_salon.dart';
import 'package:muzayen/data/home_slide.dart';
import 'package:muzayen/data/salon_booking.dart';
import 'package:muzayen/data/salon_catalog.dart';
import 'package:muzayen/data/salon_profile.dart';
import 'package:muzayen/data/wallet.dart';
import 'package:muzayen/screens/wallet_screen.dart';
import 'package:muzayen/data/loyalty.dart';
import 'package:muzayen/screens/loyalty_screen.dart';
import 'package:muzayen/screens/bookings_screen.dart';
import 'package:muzayen/screens/cart_screen.dart';
import 'package:muzayen/screens/category_screen.dart';
import 'package:muzayen/screens/home_screen.dart';
import 'package:muzayen/screens/favorites_screen.dart';
import 'package:muzayen/screens/language_screen.dart';
import 'package:muzayen/screens/login_screen.dart';
import 'package:muzayen/screens/notifications_screen.dart';
import 'package:muzayen/data/notifications_store.dart';
import 'package:muzayen/data/subscription_plans.dart';
import 'package:muzayen/widgets/plan_picker.dart';
import 'package:muzayen/screens/profile_edit_screen.dart';
import 'package:muzayen/screens/register_screen.dart';
import 'package:muzayen/screens/salon_screen.dart';
import 'package:muzayen/screens/search_screen.dart';
import 'package:muzayen/theme/app_colors.dart';
import 'package:muzayen/theme/settings_tone.dart';
import 'package:muzayen/widgets/places_section.dart';
import 'package:muzayen/widgets/salon_photo.dart';
import 'package:muzayen/data/salon_detail.dart';
import 'package:muzayen/data/service_catalog.dart';
import 'package:muzayen/screens/services_screen.dart';
import 'package:muzayen/data/support_pages.dart';

void main() {
  setUp(() {
    SubscriptionPlansApi.load = () async => const [_freePlan];
    NotificationsStore.instance.reset();
    NotificationsStore.pollEvery = null;
    NotificationsApi.fetch = (_) async =>
        const NoticePage(items: [], unread: 0);
    NotificationsApi.markRead = (_, _) async {};
    NotificationsApi.markAllRead = (_) async {};
    ServicesApi.load = () async => ServiceOffer.fallback;
    SearchScreen.useMap = false;
    SearchScreen.locate = () async => null;
    BookingsApi.load = () async => [];
    BookingsApi.cancel = (id) async {};
    BookingsApi.review =
        ({
          required int id,
          required int rating,
          required String comment,
        }) async {};
  });

  testWidgets('choosing Arabic opens the home slider', (tester) async {
    SlidesApi.load = () async => const [HomeSlide.fallback];
    CategoriesApi.load = () async => HomeCategory.fallback;
    SalonsApi.load = () async => HomeSalon.fallback;

    await tester.pumpWidget(const MaterialApp(home: LanguageScreen()));
    await tester.pump();

    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('العربية'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('الكرسي بانتظارك'), findsOneWidget);
    expect(
      find.text(
        'مواعيد فورية في أرقى صالونات ومحلات الحلاقة. اختر المصفف، حدد الموعد، واحضر.',
      ),
      findsOneWidget,
    );
    expect(find.text('الأقسام الرئيسية'), findsOneWidget);
    expect(find.text('رجالي'), findsOneWidget);
    expect(find.text('حريمي'), findsOneWidget);
    expect(find.text('أطفال'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('حجوزاتي'), findsOneWidget);
    expect(find.text('البحث'), findsOneWidget);
    expect(find.text('الخدمات'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.byKey(const Key('header-heart')), findsOneWidget);
    expect(find.byKey(const Key('header-notifications')), findsOneWidget);

    final homeScroll = find.descendant(
      of: find.byType(HomeScreen),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      find.text('أماكن مختارة'),
      400,
      scrollable: homeScroll,
    );
    await tester.pump();
    expect(find.text('صالون الليث'), findsOneWidget);
    expect(find.text('لمسة جمال'), findsOneWidget);
    expect(find.text('براعم'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('بيت الحلاقة'),
      300,
      scrollable: homeScroll,
    );
    expect(find.text('دار الجمال'), findsOneWidget);
    expect(find.text('نوع الخدمة'), findsOneWidget);
    expect(find.text('الأقرب'), findsOneWidget);
    expect(find.text('التقييم'), findsOneWidget);
    expect(find.text('السعر'), findsOneWidget);

    await tester.tap(find.text('حجوزاتي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('سجّل الدخول لترى مواعيدك.'), findsOneWidget);
  });

  testWidgets('place filters open as menus', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlacesSection(
              salons: HomeSalon.fallback,
              languageCode: 'ar',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('filter-service')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const Key('filter-home')));
    await tester.pump();
    expect(find.text('بيت الحلاقة'), findsOneWidget);
    expect(find.text('دار الجمال'), findsNothing);

    await tester.tap(find.byKey(const Key('filter-service')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const Key('filter-salon')));
    await tester.pump();
    expect(find.text('دار الجمال'), findsOneWidget);
    expect(find.text('بيت الحلاقة'), findsNothing);

    await tester.tap(find.byKey(const Key('filter-rating')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('filter-star-5')), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-star-5')));
    await tester.pump();
    expect(find.text('لا توجد أماكن مطابقة لهذا الفلتر.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-nearest')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('حسب الموقع'), findsOneWidget);
    expect(find.text('إدخال موقع آخر'), findsOneWidget);
    final asked = <(double, double)>[];
    PlacesSection.pickPlace = (context, lat, lng) async {
      asked.add((lat, lng));
      return const MapAddress(
        address: 'المعادي، القاهرة',
        city: 'القاهرة',
        latitude: 29.9602,
        longitude: 31.2569,
      );
    };
    addTearDown(PlacesSection.useDefaultPicker);
    await tester.tap(find.byKey(const Key('filter-other-place')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(asked, hasLength(1));
    expect(find.text('المعادي'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-price')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(RangeSlider), findsOneWidget);
  });

  testWidgets('salon screen lists services, time, reviews, and booking', (
    tester,
  ) async {
    SalonDetailApi.load = (_) async => SalonDetail.fallback;

    await tester.pumpWidget(
      const MaterialApp(home: SalonScreen(salonId: 1, locale: Locale('ar'))),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('صالون الليث'), findsOneWidget);
    expect(find.text('اختر الخدمة'), findsOneWidget);
    expect(find.text('قص شعر'), findsOneWidget);

    final scroll = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('اختر الأخصائي'),
      200,
      scrollable: scroll,
    );
    expect(find.text('اختر الأخصائي'), findsOneWidget);
    expect(find.text('أي متاح'), findsOneWidget);
    expect(find.text('اختر الوقت'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('التقييمات'),
      300,
      scrollable: scroll,
    );
    expect(find.text('شغل نظيف وموعد دقيق.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('login-to-book')),
      200,
      scrollable: scroll,
    );
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('سجّل الدخول لتتمكن من الحجز.'), findsOneWidget);
    expect(find.text('احجز'), findsNothing);

    AccountStore.instance.loggedIn = true;
    addTearDown(AccountStore.instance.reset);
    AccountStore.instance.notifyListeners();
    await tester.pump();
    expect(find.text('احجز'), findsOneWidget);
    expect(find.byKey(const Key('login-to-book')), findsNothing);
  });

  testWidgets('a salon heart is saved in favorites', (tester) async {
    FavoritesStore.instance.reset();
    addTearDown(FavoritesStore.instance.reset);
    tester.view.physicalSize = const Size(400, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlacesSection(salons: HomeSalon.fallback, languageCode: 'ar'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('favorite-1')));
    await tester.pump();
    expect(FavoritesStore.instance.contains(1), isTrue);

    await tester.tap(find.byKey(const Key('favorite-1')));
    await tester.pump();
    expect(FavoritesStore.instance.contains(1), isFalse);
  });

  testWidgets('a category opens its salons and women uses pink', (
    tester,
  ) async {
    SlidesApi.load = () async => const [HomeSlide.fallback];
    CategoriesApi.load = () async => HomeCategory.fallback;
    SalonsApi.load = () async => HomeSalon.fallback;

    await tester.pumpWidget(const MaterialApp(home: LanguageScreen()));
    await tester.pump();
    await tester.tap(find.text('العربية'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final homeScroll = find.descendant(
      of: find.byType(HomeScreen),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('category-men')),
      400,
      scrollable: homeScroll,
    );
    await tester.tap(find.byKey(const Key('category-men')));
    await tester.pump();
    await tester.pump();

    final men = find.byType(CategoryScreen);
    expect(
      find.descendant(of: men, matching: find.text('صالون الليث')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: men, matching: find.text('بيت الحلاقة')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: men, matching: find.text('لمسة جمال')),
      findsNothing,
    );
    expect(
      find.descendant(of: men, matching: find.text('نوع الخدمة')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: men, matching: find.text('الأقرب')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: men, matching: find.text('التقييم')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: men, matching: find.text('السعر')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.descendant(of: men, matching: find.text('رجالي')))
          .style
          ?.color,
      AppColors.gold,
    );
    expect(
      tester.widget<Text>(find.text('الرئيسية')).style?.color,
      AppColors.ink,
    );

    await tester.tap(find.byKey(const Key('category-back')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('category-women')),
      400,
      scrollable: homeScroll,
    );
    await tester.tap(find.byKey(const Key('category-women')));
    await tester.pump();
    await tester.pump();

    final women = find.byType(CategoryScreen);
    expect(
      find.descendant(of: women, matching: find.text('لمسة جمال')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: women, matching: find.text('دار الجمال')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: women, matching: find.text('صالون الليث')),
      findsNothing,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(of: women, matching: find.text('حريمي')),
          )
          .style
          ?.color,
      SalonPalette.blush.ink,
    );
    await tester.pump(const Duration(milliseconds: 320));
    expect(
      tester.widget<Text>(find.text('الرئيسية')).style?.color,
      Colors.white,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('header-heart')),
              matching: find.byType(Icon),
            ),
          )
          .color,
      SalonPalette.blush.accent,
    );

    await tester.tap(find.byKey(const Key('category-filter-service')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const Key('category-filter-home')));
    await tester.pump();
    expect(
      find.descendant(of: women, matching: find.text('لمسة جمال')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: women, matching: find.text('دار الجمال')),
      findsNothing,
    );

    SalonDetailApi.load = (_) async => SalonDetail.fallback;
    final categoryScroll = find.descendant(
      of: women,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      find.descendant(of: women, matching: find.text('لمسة جمال')),
      300,
      scrollable: categoryScroll,
    );
    await tester.drag(categoryScroll, const Offset(0, -220));
    await tester.pump();
    await tester.tap(
      find.descendant(of: women, matching: find.text('لمسة جمال')),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(SalonScreen), findsOneWidget);
    expect(
      tester
          .widget<Scaffold>(
            find.descendant(
              of: find.byType(SalonScreen),
              matching: find.byType(Scaffold),
            ),
          )
          .backgroundColor,
      SalonPalette.blush.background,
    );
    expect(
      tester.widget<Text>(find.text('الرئيسية')).style?.color,
      Colors.white,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('header-heart')),
              matching: find.byType(Icon),
            ),
          )
          .color,
      SalonPalette.blush.accent,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SalonScreen),
        matching: find.byType(BackButton),
      ),
    );
    await tester.pump();
    tester.state<ScrollableState>(categoryScroll).position.jumpTo(0);
    await tester.pump();

    await tester.tap(find.byKey(const Key('category-back')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('category-kids')),
      400,
      scrollable: homeScroll,
    );
    await tester.tap(find.byKey(const Key('category-kids')));
    await tester.pump();
    await tester.pump();

    final kids = find.byType(CategoryScreen);
    expect(
      find.descendant(of: kids, matching: find.text('براعم')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: kids, matching: find.text('صالون الصغير')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.descendant(of: kids, matching: find.text('أطفال')))
          .style
          ?.color,
      AppColors.gold,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('header-heart')),
              matching: find.byType(Icon),
            ),
          )
          .color,
      AppColors.gold,
    );
  });

  testWidgets('settings edits the profile and signs in', (tester) async {
    AccountStore.instance.reset();
    addTearDown(AccountStore.instance.reset);
    AuthApi.signIn = ({required String email, required String password}) async {
      return AuthSession(
        name: 'محمد',
        email: email,
        phone: '01000000000',
        address: 'القاهرة',
        role: 'customer',
        token: 'test-token',
      );
    };
    addTearDown(AuthApi.useDefaults);
    PagesApi.load = () async => const [
      SupportPage(
        slug: 'faq',
        title: 'الأسئلة الشائعة',
        titleEn: 'FAQ',
        blocks: [
          SupportBlock(
            title: 'كيف أحجز؟',
            titleEn: 'How do I book?',
            body:
                'اختر الصالون ثم الخدمة واليوم والوقت، وأكّد الاسم ورقم الهاتف.',
            bodyEn:
                'Choose the salon, the service, the day, and the time, then confirm your name and phone.',
          ),
        ],
      ),
    ];
    addTearDown(PagesApi.useDefault);
    tester.view.physicalSize = const Size(400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SlidesApi.load = () async => const [HomeSlide.fallback];
    CategoriesApi.load = () async => HomeCategory.fallback;
    SalonsApi.load = () async => HomeSalon.fallback;

    await tester.pumpWidget(const MaterialApp(home: LanguageScreen()));
    await tester.pump();
    await tester.tap(find.text('العربية'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('الإعدادات'));
    await tester.pump();

    expect(find.text('زائر'), findsOneWidget);
    expect(find.text('تعديل الملف الشخصي'), findsOneWidget);
    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.text('الوضع الداكن'), findsOneWidget);
    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('مركز المساعدة'), findsOneWidget);
    expect(find.text('الأسئلة الشائعة'), findsOneWidget);
    expect(find.text('سياسة الخصوصية'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-edit-photo')));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byKey(const Key('profile-name')), 'محمد');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('profile-save')));
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pump();
    await tester.pump();
    expect(AccountStore.instance.name, 'محمد');
    expect(find.text('حفظ'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-notifications')));
    await tester.pump();
    expect(AccountStore.instance.notifications, isFalse);

    await tester.tap(find.byKey(const Key('settings-dark-mode')));
    await tester.pump();
    expect(AccountStore.instance.darkMode, isFalse);
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('settings-root'))).color,
      SettingsTone.day.background,
    );

    await tester.tap(find.byKey(const Key('settings-faq')));
    await tester.pump();
    await tester.pump();
    expect(find.text('كيف أحجز؟'), findsOneWidget);
    Navigator.of(tester.element(find.text('كيف أحجز؟'))).pop();
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('settings-auth')));
    await tester.tap(find.byKey(const Key('settings-auth')));
    await tester.pump();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'mohamed@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'secret1');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تسجيل الخروج'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-auth')));
    await tester.pump();
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('زائر'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('language-en')));
    await tester.pump();
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
  });

  testWidgets('signup asks for a client or a salon then the same fields', (
    tester,
  ) async {
    SalonCatalogApi.load = () async => const [
      CatalogCategory(
        id: 1,
        name: 'رجالي',
        slug: 'men',
        services: [CatalogItem(id: 1, name: 'قص شعر', durationMinutes: 30)],
      ),
      CatalogCategory(
        id: 2,
        name: 'حريمي',
        slug: 'women',
        services: [
          CatalogItem(id: 11, name: 'مكياج سهرة', durationMinutes: 60),
          CatalogItem(id: 12, name: 'سشوار', durationMinutes: 40),
        ],
      ),
      CatalogCategory(id: 3, name: 'أطفال', slug: 'kids', services: []),
    ];
    addTearDown(SalonCatalogApi.useDefault);
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RegisterScreen(),
        ),
      ),
    );

    expect(find.text('عميل'), findsOneWidget);
    expect(find.text('صالون'), findsOneWidget);
    expect(find.byKey(const Key('register-name')), findsNothing);

    await tester.tap(find.byKey(const Key('register-client')));
    await tester.pump();
    expect(find.byKey(const Key('register-name')), findsOneWidget);
    expect(find.byKey(const Key('register-email')), findsOneWidget);
    expect(find.byKey(const Key('register-phone')), findsOneWidget);
    expect(find.byKey(const Key('register-address')), findsOneWidget);
    expect(find.text('اختر العنوان من الخريطة'), findsOneWidget);
    expect(find.byKey(const Key('register-password')), findsOneWidget);
    expect(find.text('أضف صورتك الشخصية (اختياري)'), findsOneWidget);

    ImageSource? asked;
    RegisterScreen.pickPhoto = (source) async {
      asked = source;
      return '/tmp/muzayen-missing-photo.jpg';
    };
    addTearDown(RegisterScreen.useDefaultPicker);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('register-photo-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('التقاط صورة بالكاميرا'), findsOneWidget);
    await tester.tap(find.byKey(const Key('register-photo-gallery')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(asked, ImageSource.gallery);
    expect(find.text('تم اختيار الصورة'), findsOneWidget);

    await tester.tap(find.byKey(const Key('register-salon')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('register-name')), findsNothing);
    expect(find.byKey(const Key('register-salon-intro')), findsOneWidget);
    expect(find.text('4. مواعيد العمل'), findsOneWidget);

    Future<void> next() async {
      await tester.tap(find.byKey(const Key('register-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await next();
    expect(find.text('الخطوة 1 من 5'), findsOneWidget);
    expect(find.text('اختر باقة الاشتراك'), findsOneWidget);
    expect(find.text('باقة الانطلاق'), findsOneWidget);
    expect(find.text('مجاناً لمدة سنة'), findsOneWidget);
    expect(find.text('لمدة سنة واحدة'), findsOneWidget);

    await next();
    expect(
      find.text('يجب الموافقة على قوانين الاشتراك أولاً.'),
      findsOneWidget,
    );
    expect(find.text('الخطوة 1 من 5'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('plan-terms-1')));
    await tester.tap(find.byKey(const Key('plan-terms-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('plan-terms-sheet')), findsOneWidget);
    expect(find.text('الاشتراك مجاني لمدة سنة.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-terms-agree')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('plan-terms-sheet')), findsNothing);

    await next();
    expect(find.text('الخطوة 2 من 5'), findsOneWidget);
    expect(find.text('اختر قسم الصالون'), findsOneWidget);
    expect(find.byKey(const Key('register-service-1')), findsNothing);
    await next();
    expect(find.text('اختر قسم الصالون أولاً.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('register-category-women')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('مكياج سهرة'), findsOneWidget);
    expect(find.text('قص شعر'), findsNothing);

    await tester.tap(find.byKey(const Key('register-service-11')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('register-services-count')))
          .data,
      startsWith('تم اختيار 1 من 2'),
    );

    await tester.tap(find.byKey(const Key('register-services-all')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<Text>(find.byKey(const Key('register-services-count')))
          .data,
      startsWith('تم اختيار 2 من 2'),
    );
    expect(find.byKey(const Key('register-service-price-11')), findsOneWidget);
    expect(find.byKey(const Key('register-service-price-12')), findsOneWidget);
    expect(find.textContaining('ج.م'), findsWidgets);

    await next();
    expect(find.text('حدد سعر كل خدمة مختارة.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register-service-price-11')),
      '٤٥٠',
    );
    await tester.enterText(
      find.byKey(const Key('register-service-price-12')),
      '120',
    );
    await tester.pump();
    await next();
    expect(find.text('الخطوة 3 من 5'), findsOneWidget);
    expect(find.text('فريق العمل'), findsOneWidget);
    expect(find.text('خبيرة تجميل'), findsOneWidget);

    await next();
    expect(
      find.text('اكتب اسم كل أخصائي أو احذف الخانة الفارغة.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('register-specialist-name-0')),
      'منى',
    );
    await tester.tap(find.text('خبيرة تجميل'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('register-specialist-add')));
    await tester.pump();
    expect(find.byKey(const Key('register-specialist-name-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('register-specialist-remove-1')));
    await tester.pump();
    expect(find.byKey(const Key('register-specialist-name-1')), findsNothing);

    await next();
    expect(find.text('الخطوة 4 من 5'), findsOneWidget);
    expect(find.text('7 أيام عمل في الأسبوع'), findsOneWidget);
    await tester.tap(find.byKey(const Key('register-hour-switch-5')));
    await tester.pump();
    expect(find.text('6 أيام عمل في الأسبوع'), findsOneWidget);
    expect(find.text('مغلق'), findsOneWidget);

    await tester.tap(find.byKey(const Key('register-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('الخطوة 3 من 5'), findsOneWidget);
    expect(find.text('منى'), findsOneWidget);
    await next();
    expect(find.text('6 أيام عمل في الأسبوع'), findsOneWidget);

    await next();
    expect(find.text('الخطوة 5 من 5'), findsOneWidget);
    expect(find.text('اسم الصالون'), findsOneWidget);
    expect(find.text('1 أخصائي'), findsOneWidget);
    expect(find.text('6 أيام عمل'), findsOneWidget);
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();
    expect(find.text('ارفع صورة الصالون.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('register-salon-photo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('register-photo-camera')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(asked, ImageSource.camera);
    expect(find.text('تم اختيار الصورة'), findsWidgets);
    expect(find.text('تغيير'), findsOneWidget);
  });

  testWidgets('the header opens favorites and notifications', (tester) async {
    FavoritesStore.instance.reset();
    AccountStore.instance.reset();
    addTearDown(FavoritesStore.instance.reset);
    addTearDown(AccountStore.instance.reset);
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SlidesApi.load = () async => const [HomeSlide.fallback];
    CategoriesApi.load = () async => HomeCategory.fallback;
    SalonsApi.load = () async => HomeSalon.fallback;

    await tester.pumpWidget(const MaterialApp(home: LanguageScreen()));
    await tester.pump();
    await tester.tap(find.text('العربية'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.byKey(const Key('header-heart')));
    await tester.pump();
    expect(find.text('لا توجد صالونات في المفضلة'), findsOneWidget);
    await tester.tap(find.byKey(const Key('favorites-back')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('header-notifications')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('notifications-screen')),
        matching: find.byKey(const Key('notifications-guest')),
      ),
      findsOneWidget,
    );
    expect(find.text('سجّل الدخول لمتابعة إشعاراتك'), findsOneWidget);
  });

  testWidgets('notifications list real notices with an unread badge', (
    tester,
  ) async {
    AccountStore.instance.reset();
    addTearDown(AccountStore.instance.reset);
    addTearDown(NotificationsStore.instance.reset);
    addTearDown(NotificationsApi.useDefaults);
    AccountStore.instance.loggedIn = true;
    AccountStore.instance.token = 'tok';
    final read = <int>[];
    var allRead = false;
    NotificationsApi.fetch = (token) async {
      expect(token, 'tok');
      return NoticePage(
        unread: 2,
        items: [
          AppNotice(
            id: 7,
            type: 'booking_confirmed',
            title: 'تم تأكيد حجزك',
            body: 'أكّد صالون الليث حجز قص شعر.',
            read: false,
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            bookingId: 3,
          ),
          AppNotice(
            id: 6,
            type: 'wallet',
            title: 'تم شحن محفظتك',
            body: 'أُضيف 200 ج.م إلى محفظتك.',
            read: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          ),
          const AppNotice(
            id: 5,
            type: 'welcome',
            title: 'أهلاً بك في المزين',
            body: 'سعداء بانضمامك!',
            read: true,
          ),
        ],
      );
    };
    NotificationsApi.markRead = (_, id) async => read.add(id);
    NotificationsApi.markAllRead = (_) async => allRead = true;
    NotificationsStore.instance.attach();
    await tester.pump();
    expect(NotificationsStore.instance.unread, 2);

    var bookings = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(
          body: NotificationsScreen(
            onBack: () {},
            onOpenBookings: () => bookings++,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('تم تأكيد حجزك'), findsOneWidget);
    expect(find.text('تم شحن محفظتك'), findsOneWidget);
    expect(find.text('منذ 5 د'), findsOneWidget);
    expect(find.byKey(const Key('notice-dot-7')), findsOneWidget);
    expect(find.byKey(const Key('notice-dot-5')), findsNothing);

    await tester.tap(find.byKey(const Key('notice-7')));
    await tester.pump();
    expect(read, [7]);
    expect(bookings, 1);
    expect(NotificationsStore.instance.unread, 1);
    expect(find.byKey(const Key('notice-dot-7')), findsNothing);

    await tester.tap(find.byKey(const Key('notifications-read-all')));
    await tester.pump();
    expect(allRead, isTrue);
    expect(NotificationsStore.instance.unread, 0);
    expect(find.byKey(const Key('notifications-read-all')), findsNothing);

    AccountStore.instance.token = '';
    AccountStore.instance.setNotifications(false);
    await tester.pump();
    expect(find.text('الإشعارات متوقفة'), findsOneWidget);
  });

  testWidgets('plan picker switches plans and resets the terms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const paid = SubscriptionPlan(
      id: 2,
      name: 'الباقة الاحترافية',
      priceLabel: '1,200 ج.م',
      durationLabel: 'سنة واحدة',
      durationUnit: 'year',
      durationValue: 1,
      price: 1200,
      maxServices: 30,
      features: ['ظهور مميز'],
      terms: ['بند'],
    );
    var selected = 1;
    var accepted = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: PlanPicker(
                  plans: const [_freePlan, paid],
                  selectedId: selected,
                  accepted: accepted,
                  tone: SettingsTone.night,
                  onSelect: (plan) => setState(() {
                    selected = plan.id;
                    accepted = false;
                  }),
                  onAccepted: (value) => setState(() => accepted = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1,200 ج.م'), findsOneWidget);
    expect(find.text('/ سنة واحدة'), findsOneWidget);
    expect(find.text('حتى 30 خدمة'), findsOneWidget);
    expect(find.text('خدمات بلا حدود'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('plan-2')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('الباقة الاحترافية'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(selected, 2);
    expect(accepted, isFalse);
    await tester.tap(find.byKey(const Key('register-terms')));
    await tester.pump();
    expect(accepted, isTrue);
  });

  testWidgets('subscription welcome celebrates the free year', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showSubscriptionWelcome(context, _freePlan, SettingsTone.night),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final until = DateTime.now();
    expect(find.text('تم تفعيل اشتراكك'), findsOneWidget);
    expect(find.text('مرحباً بك في باقة الانطلاق'), findsOneWidget);
    expect(find.text('مجاناً لمدة سنة واحدة'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('subscription-welcome-until')))
          .data,
      contains('${until.year + 1}/'),
    );
    await tester.tap(find.byKey(const Key('subscription-welcome-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('subscription-welcome')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('favorites screen lists a saved salon', (tester) async {
    FavoritesStore.instance.reset();
    addTearDown(FavoritesStore.instance.reset);
    FavoritesStore.instance.toggle(1);
    SalonsApi.load = () async => HomeSalon.fallback;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: FavoritesScreen(onBack: () {}, onOpenSalon: (_, _) {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('صالون الليث'), findsOneWidget);
  });

  testWidgets('salon cards show a photo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SalonPhoto(url: null, asset: 'asset/salons/layth.jpg'),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, 'asset/salons/layth.jpg');
    expect(find.byIcon(Icons.storefront_outlined), findsNothing);
  });

  testWidgets('search shows the customer location and filters salons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SalonsApi.load = () async => HomeSalon.fallback;
    CategoriesApi.load = () async => HomeCategory.fallback;
    SearchScreen.locate = () async => (30.0561, 31.3300);
    MapGeocoder.resolve = (lat, lng) async => MapAddress(
      address: 'مدينة نصر، القاهرة',
      city: 'القاهرة',
      latitude: lat,
      longitude: lng,
    );
    addTearDown(MapGeocoder.useDefault);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SearchScreen(
              locale: const Locale('ar'),
              onOpenSalon: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('موقعك الحالي'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('search-location-text'))).data,
      'مدينة نصر، القاهرة',
    );
    expect(find.byKey(const Key('search-map')), findsOneWidget);
    expect(find.text('6 مكان'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-field')), 'المعادي');
    await tester.pump();
    expect(find.text('1 مكان'), findsOneWidget);
    expect(find.text('بيت الحلاقة'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-reset')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('search-category-women')));
    await tester.pump();
    expect(find.text('2 مكان'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('search-place-bar-home')));
    await tester.tap(find.byKey(const Key('search-place-bar-home')));
    await tester.pump();
    expect(find.text('1 مكان'), findsOneWidget);
    expect(find.text('لمسة جمال'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-place-bar-salon')));
    await tester.pump();
    expect(find.text('1 مكان'), findsOneWidget);
    expect(find.text('لمسة جمال'), findsNothing);

    await tester.tap(find.byKey(const Key('search-filters')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('مكان الخدمة'), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-place-home')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('search-filters-apply')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('search-filters-apply')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 مكان'), findsOneWidget);
    expect(find.text('لمسة جمال'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-place-bar-any')));
    await tester.pump();
    expect(find.text('2 مكان'), findsOneWidget);
  });

  testWidgets('services groups salons and opens one', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CategoriesApi.load = () async => HomeCategory.fallback;
    int? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ServicesScreen(
              locale: const Locale('ar'),
              onOpenSalon: (id, _) => opened = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('الأكثر طلباً'), findsWidgets);
    expect(find.text('كل الخدمات (5)'), findsOneWidget);
    expect(find.text('100 – 120'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('services-category-kids')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('services-category-kids')));
    await tester.pump();
    expect(find.text('كل الخدمات (1)'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('services-category-all')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('services-category-all')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('services-search')), 'قص');
    await tester.pump();
    await tester.tap(find.byKey(const Key('service-قص شعر')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('متوفرة في 2 صالون'), findsOneWidget);
    expect(find.text('أفضل سعر'), findsOneWidget);

    await tester.tap(find.byKey(const Key('services-offer-3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, 4);
  });

  testWidgets('bookings lists the customer visit', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AccountStore.instance.loggedIn = true;
    AccountStore.instance.token = 'test-token';
    addTearDown(AccountStore.instance.reset);

    final visit = CustomerBooking(
      id: 4,
      status: 'confirmed',
      date: '2026-10-08',
      time: '18:30',
      total: 180,
      subtotal: 180,
      discount: 0,
      points: 0,
      canCancel: true,
      canReview: false,
      reviewed: false,
      salonId: 1,
      salonName: 'صالون الليث',
      categorySlug: 'men',
      city: 'القاهرة',
      district: 'مدينة نصر',
      serviceName: 'حلاقة كلاسيك',
      durationMinutes: 30,
      specialistName: 'كريم',
    );
    BookingsApi.load = () async => [visit];

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: BookingsScreen(onOpenSalon: (_, _) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('الموعد القادم'), findsOneWidget);
    expect(find.textContaining('حلاقة كلاسيك'), findsOneWidget);
    expect(find.textContaining('18:30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bookings-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('مؤكد'), findsOneWidget);
    expect(find.text('كريم'), findsOneWidget);
    expect(find.text('180 ج.م'), findsWidgets);

    await tester.tap(find.text('صفحة الصالون'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(
      find.byKey(const Key('bookings-filter-cancelled')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookings-filter-cancelled')));
    await tester.pump();
    expect(find.text('لا توجد مواعيد هنا'), findsOneWidget);
  });

  testWidgets('wallet shows the balance, points, and transactions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AccountStore.instance.reset();
    AccountStore.instance.loggedIn = true;
    AccountStore.instance.token = 'test-token';
    addTearDown(AccountStore.instance.reset);
    String? usedToken;
    WalletApi.load = (token) async {
      usedToken = token;
      return WalletSummary(
        balance: 150,
        points: 40,
        totalIn: 200,
        totalOut: 50,
        entries: [
          WalletEntry(
            id: 2,
            type: 'payment',
            label: 'دفع حجز',
            amount: -50,
            balanceAfter: 150,
            note: 'حجز #2',
            createdAt: DateTime(2026, 10, 2, 12),
          ),
          WalletEntry(
            id: 1,
            type: 'deposit',
            label: 'شحن رصيد',
            amount: 200,
            balanceAfter: 200,
            createdAt: DateTime(2026, 10, 1, 9),
          ),
        ],
      );
    };
    addTearDown(WalletApi.useDefault);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: WalletScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(usedToken, 'test-token');
    expect(
      tester.widget<Text>(find.byKey(const Key('wallet-balance'))).data,
      '150.00 ج.م',
    );
    expect(find.text('40 نقطة ولاء'), findsOneWidget);
    expect(AccountStore.instance.walletBalance, 150);
    expect(find.byKey(const Key('wallet-entry-1')), findsOneWidget);
    expect(find.byKey(const Key('wallet-entry-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('wallet-filter-credit')));
    await tester.pump();
    expect(find.byKey(const Key('wallet-entry-1')), findsOneWidget);
    expect(find.byKey(const Key('wallet-entry-2')), findsNothing);

    await tester.tap(find.byKey(const Key('wallet-filter-debit')));
    await tester.pump();
    expect(find.byKey(const Key('wallet-entry-1')), findsNothing);
    expect(find.byKey(const Key('wallet-entry-2')), findsOneWidget);
  });

  testWidgets('loyalty screen shows points, next reward, rules and history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AccountStore.instance.reset();
    AccountStore.instance.loggedIn = true;
    AccountStore.instance.token = 'test-token';
    addTearDown(AccountStore.instance.reset);
    String? usedToken;
    LoyaltyApi.load = (token) async {
      usedToken = token;
      return LoyaltySummary(
        points: 250,
        active: true,
        redeemablePoints: 200,
        redeemableValue: 20,
        nextTarget: 300,
        nextRemaining: 50,
        nextValue: 30,
        rules: const LoyaltyRules(
          earnAmount: 10,
          earnPoints: 1,
          redeemPoints: 100,
          redeemValue: 10,
          minRedeemPoints: 100,
          expireDays: 365,
        ),
        earned: 300,
        redeemed: 50,
        expired: 0,
        expiringPoints: 40,
        expiringDate: DateTime(2026, 10, 20),
        entries: [
          LoyaltyEntry(
            id: 2,
            type: 'redeem',
            label: 'استبدال نقاط',
            points: -50,
            salon: 'صالون الليث',
            createdAt: DateTime(2026, 10, 2, 12),
          ),
          LoyaltyEntry(
            id: 1,
            type: 'earn',
            label: 'نقاط مكتسبة',
            points: 300,
            expiresAt: DateTime(2027, 10, 1),
            createdAt: DateTime(2026, 10, 1, 9),
          ),
        ],
      );
    };
    addTearDown(LoyaltyApi.useDefault);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: LoyaltyScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(usedToken, 'test-token');
    expect(AccountStore.instance.loyaltyPoints, 250);
    expect(
      tester.widget<Text>(find.byKey(const Key('loyalty-points'))).data,
      '250',
    );
    expect(find.text('تساوي خصماً بقيمة 20 ج.م'), findsOneWidget);
    expect(find.text('باقي 50 نقطة لتحصل على خصم 30 ج.م'), findsOneWidget);
    expect(find.byKey(const Key('loyalty-expiring')), findsOneWidget);
    expect(find.byKey(const Key('loyalty-paused')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('loyalty-rule-earn')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('loyalty-rule-earn')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('loyalty-entry-1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.byKey(const Key('loyalty-entry-1')), findsOneWidget);
    expect(find.byKey(const Key('loyalty-entry-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('loyalty-filter-earn')));
    await tester.pump();
    expect(find.byKey(const Key('loyalty-entry-1')), findsOneWidget);
    expect(find.byKey(const Key('loyalty-entry-2')), findsNothing);

    await tester.tap(find.byKey(const Key('loyalty-filter-redeem')));
    await tester.pump();
    expect(find.byKey(const Key('loyalty-entry-1')), findsNothing);
    expect(find.byKey(const Key('loyalty-entry-2')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('loyalty-filter-expire')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('loyalty-filter-expire')));
    await tester.pump();
    expect(find.byKey(const Key('loyalty-empty')), findsOneWidget);
  });

  testWidgets('forgot password sends a code then resets and signs in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AccountStore.instance.reset();
    addTearDown(AccountStore.instance.reset);

    String? sentTo;
    String? usedCode;
    AuthApi.requestReset = ({required String email}) async => sentTo = email;
    AuthApi.resetPassword =
        ({
          required String email,
          required String code,
          required String password,
        }) async {
          usedCode = code;
          return AuthSession(
            name: 'محمد',
            email: email,
            phone: '01000000000',
            address: 'القاهرة',
            role: 'customer',
            token: 'reset-token',
          );
        };
    addTearDown(AuthApi.useDefaults);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'client@muzayen.test',
    );
    await tester.tap(find.byKey(const Key('login-forgot')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('نسيت كلمة المرور'), findsOneWidget);
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pump();
    await tester.pump();
    expect(sentTo, 'client@muzayen.test');
    expect(find.byKey(const Key('forgot-code')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('forgot-code')), '123456');
    await tester.enterText(
      find.byKey(const Key('forgot-password')),
      'newpass1',
    );
    await tester.enterText(find.byKey(const Key('forgot-confirm')), 'newpass2');
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pump();
    expect(find.text('تأكيد كلمة المرور غير مطابق.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('forgot-confirm')), 'newpass1');
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(usedCode, '123456');
    expect(AccountStore.instance.loggedIn, isTrue);
    expect(AccountStore.instance.token, 'reset-token');
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('salon bookings show the next client booking and act on it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AccountStore.instance.reset();
    AccountStore.instance.loggedIn = true;
    AccountStore.instance.token = 'salon-token';
    AccountStore.instance.role = 'salon';
    AccountStore.instance.name = 'صالون الأناقة';
    addTearDown(AccountStore.instance.reset);

    String day(int offset) {
      final d = DateTime.now().add(Duration(days: offset));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    SalonBooking row(
      int id,
      String status,
      int offset, {
      bool open = true,
      String? notes,
    }) {
      return SalonBooking(
        id: id,
        status: status,
        date: day(offset),
        time: '14:30',
        customerName: id == 1 ? 'محمد علي' : 'عميل $id',
        customerPhone: '0111$id',
        customerEmail: id == 1 ? 'mo@test.local' : null,
        serviceName: id == 1 ? 'قص شعر' : 'تهذيب لحية',
        durationMinutes: 45,
        specialistName: 'أحمد',
        specialistTitle: 'حلاق',
        subtotal: 200,
        discount: id == 1 ? 30 : 0,
        couponCode: id == 1 ? 'WELCOME' : null,
        total: id == 1 ? 170 : 90,
        registered: true,
        visits: id == 1 ? 3 : 1,
        notes: notes,
        canConfirm: open && status == 'pending',
        canCancel: open && status != 'cancelled' && status != 'completed',
      );
    }

    var items = [
      row(1, 'pending', 1, notes: 'يفضل المقص'),
      row(2, 'pending', 3),
      row(3, 'completed', -2, open: false),
    ];
    SalonBookingsApi.load = () async => items;
    final confirmed = <int>[];
    final cancelled = <String>[];
    SalonBookingsApi.confirm = (id) async {
      confirmed.add(id);
      final updated = row(id, 'confirmed', id == 1 ? 1 : 3);
      items = [for (final r in items) r.id == id ? updated : r];
      return updated;
    };
    SalonBookingsApi.cancel = (id, reason) async {
      cancelled.add('$id:$reason');
      final updated = row(id, 'cancelled', 1, open: false);
      items = [for (final r in items) r.id == id ? updated : r];
      return updated;
    };
    addTearDown(SalonBookingsApi.useDefaults);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: BookingsScreen(onOpenSalon: (_, _) {})),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('salon-bookings-screen')), findsOneWidget);
    expect(find.text('حجوزات الصالون'), findsOneWidget);
    final next = find.byKey(const Key('salon-next'));
    expect(next, findsOneWidget);
    Finder inNext(Finder f) => find.descendant(of: next, matching: f);
    expect(inNext(find.text('محمد علي')), findsOneWidget);
    expect(inNext(find.text('01111')), findsOneWidget);
    expect(inNext(find.text('mo@test.local')), findsOneWidget);
    expect(inNext(find.text('يفضل المقص')), findsOneWidget);
    expect(inNext(find.text('زيارة رقم 3')), findsOneWidget);
    expect(inNext(find.text('كوبون WELCOME')), findsOneWidget);
    expect(inNext(find.text('170 ج.م')), findsOneWidget);
    expect(inNext(find.text('بانتظار التأكيد')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('salon-stat-pending')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('salon-confirm-1')));
    await tester.pump();
    await tester.pump();
    expect(confirmed, [1]);
    expect(inNext(find.text('مؤكد')), findsOneWidget);
    expect(find.byKey(const Key('salon-confirm-1')), findsNothing);
    expect(find.byKey(const Key('salon-confirmed-note-1')), findsOneWidget);
    expect(find.text('تم تأكيد الحجز وسيظهر مؤكداً للعميل.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('salon-cancel-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const Key('salon-cancel-reason')),
      'الأخصائي مريض',
    );
    await tester.tap(find.byKey(const Key('salon-cancel-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(cancelled, ['1:الأخصائي مريض']);
    expect(inNext(find.text('عميل 2')), findsOneWidget);
    expect(inNext(find.text('أول زيارة')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('salon-filter-cancelled')));
    await tester.tap(find.byKey(const Key('salon-filter-cancelled')));
    await tester.pump();
    expect(find.byKey(const Key('salon-booking-1')), findsOneWidget);
    expect(find.byKey(const Key('salon-booking-3')), findsNothing);

    await tester.tap(find.byKey(const Key('salon-filter-past')));
    await tester.pump();
    expect(find.byKey(const Key('salon-booking-3')), findsOneWidget);
  });

  testWidgets('the cart lists added bookings and confirms them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CartStore.instance.reset();
    addTearDown(CartStore.instance.reset);
    final booked = <BookingRequest>[];
    SalonDetailApi.book = (request) async {
      booked.add(request);
      return null;
    };
    addTearDown(() => SalonDetailApi.book = SalonDetailApi.useDefaultBook);

    final salon = SalonDetail.fallback;
    final day = DateTime.now().add(const Duration(days: 2));
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final item = CartStore.instance.add(
      salon: salon,
      service: salon.services.first,
      date: date,
      time: '18:00',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: CartScreen(highlightKey: item.key)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('سلة الحجوزات'), findsOneWidget);
    expect(find.byKey(Key('cart-item-${item.key}')), findsOneWidget);
    expect(find.text(salon.services.first.name), findsWidgets);
    expect(find.byKey(const Key('cart-total')), findsOneWidget);

    await tester.tap(find.byKey(Key('cart-item-${item.key}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تفاصيل الحجز'), findsOneWidget);
    expect(find.byKey(Key('cart-detail-${item.key}')), findsOneWidget);
    expect(find.text('من 18:00 إلى 18:30'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cart-name')), '');
    await tester.tap(find.byKey(const Key('cart-to-payment')));
    await tester.pump();
    expect(find.byKey(const Key('cart-error')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cart-name')), 'محمد');
    await tester.enterText(find.byKey(const Key('cart-phone')), '0500000000');
    await tester.tap(find.byKey(const Key('cart-to-payment')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('الدفع عند الوصول'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cart-pay-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('cart-card-form')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('cart-card-number')),
      '4242424242424241',
    );
    await tester.enterText(
      find.byKey(const Key('cart-card-holder')),
      'MOHAMED',
    );
    await tester.enterText(find.byKey(const Key('cart-card-expiry')), '1230');
    await tester.enterText(find.byKey(const Key('cart-card-cvv')), '123');
    await tester.tap(find.byKey(const Key('cart-pay')));
    await tester.pump();
    expect(find.text('رقم البطاقة غير صحيح.'), findsOneWidget);
    expect(booked, isEmpty);

    await tester.enterText(
      find.byKey(const Key('cart-card-number')),
      '4242424242424242',
    );
    expect(find.text('4242 4242 4242 4242'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cart-pay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(booked, hasLength(1));
    expect(booked.single.time, '18:00');
    expect(booked.single.paymentMethod, 'card');
    expect(booked.single.cardLast4, '4242');
    expect(find.text('تم الدفع بالفيزا'), findsOneWidget);
    expect(find.byKey(const Key('cart-confetti')), findsOneWidget);
    expect(find.byKey(const Key('cart-success')), findsOneWidget);
    expect(CartStore.instance.count, 0);
  });

  testWidgets('a salon edits its details, services, team, and hours', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AccountStore.instance
      ..loggedIn = true
      ..role = 'salon'
      ..token = 'token';
    addTearDown(AccountStore.instance.reset);
    addTearDown(SalonProfileApi.useDefaults);

    final calls = <String>[];
    final state = <String, dynamic>{
      'id': 1,
      'name': 'صالون الليث',
      'city': 'القاهرة',
      'address': 'شارع التحرير',
      'offers_home_service': false,
      'verification_status': 'verified',
      'verification_label': 'موثق',
      'category': 'رجالي',
      'services': <Map<String, dynamic>>[
        {
          'id': 5,
          'name': 'قص شعر',
          'price': 120,
          'duration_minutes': 30,
          'is_active': true,
          'specialist_ids': <int>[],
        },
      ],
      'specialists': <Map<String, dynamic>>[],
      'hours': [
        for (final (day, label) in [
          (6, 'السبت'),
          (0, 'الأحد'),
          (1, 'الإثنين'),
          (2, 'الثلاثاء'),
          (3, 'الأربعاء'),
          (4, 'الخميس'),
          (5, 'الجمعة'),
        ])
          {
            'day': day,
            'label': label,
            'is_closed': false,
            'opens_at': '10:00',
            'closes_at': '22:00',
          },
      ],
    };
    var catalog = <Map<String, dynamic>>[
      {'id': 9, 'name': 'تهذيب لحية', 'duration_minutes': 20},
    ];
    SalonProfileApi.send = (method, path, [body]) async {
      calls.add('$method $path');
      final services = state['services'] as List<Map<String, dynamic>>;
      final team = state['specialists'] as List<Map<String, dynamic>>;
      if (method == 'PATCH' && path == '/api/salon/profile') {
        state.addAll(body!);
      } else if (method == 'POST' && path == '/api/salon/services') {
        services.add({
          'id': 6,
          'name': 'تهذيب لحية',
          'price': body!['price'],
          'duration_minutes': body['duration_minutes'] ?? 20,
          'is_active': true,
          'specialist_ids': <int>[],
        });
        catalog = [];
      } else if (method == 'PATCH' && path.startsWith('/api/salon/services/')) {
        final id = int.parse(path.split('/').last);
        services.firstWhere((row) => row['id'] == id).addAll(body!);
      } else if (method == 'POST' && path == '/api/salon/specialists') {
        team.add({'id': 3, ...body!, 'is_active': true});
      } else if (method == 'PUT' && path == '/api/salon/hours') {
        final rows = body!['hours'] as List;
        for (final hour in state['hours'] as List) {
          final row = rows.firstWhere((item) => item['day'] == hour['day']);
          hour['is_closed'] = row['is_closed'];
        }
      }
      return SalonProfile.fromJson({'data': state, 'catalog': catalog});
    };

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const ProfileEditScreen(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-salon-manage')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('إدارة الصالون'), findsOneWidget);
    expect(find.text('موثق'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('manage-name')),
      'صالون الليث الجديد',
    );
    await tester.ensureVisible(find.byKey(const Key('manage-home-service')));
    await tester.tap(find.byKey(const Key('manage-home-service')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('manage-save-details')));
    await tester.tap(find.byKey(const Key('manage-save-details')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, contains('PATCH /api/salon/profile'));
    expect(state['name'], 'صالون الليث الجديد');
    expect(state['offers_home_service'], true);

    await tester.ensureVisible(find.byKey(const Key('manage-tab-services')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('manage-tab-services')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('قص شعر'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manage-add-service')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('manage-service-save')));
    await tester.pump();
    expect(find.text('اختر الخدمة.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manage-catalog-9')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('manage-service-price')), '٨٠');
    await tester.tap(find.byKey(const Key('manage-service-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, contains('POST /api/salon/services'));
    expect(find.text('تهذيب لحية'), findsOneWidget);
    expect(find.text('80 ج.م'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manage-service-5')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.byKey(const Key('manage-service-price')),
      '150',
    );
    await tester.tap(find.byKey(const Key('manage-service-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, contains('PATCH /api/salon/services/5'));
    expect(find.text('150 ج.م'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('manage-tab-team')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('manage-tab-team')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('manage-add-specialist')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.byKey(const Key('manage-specialist-name')),
      'كريم',
    );
    await tester.enterText(
      find.byKey(const Key('manage-specialist-title')),
      'حلاق',
    );
    await tester.tap(find.byKey(const Key('manage-specialist-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('كريم'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('manage-tab-hours')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('manage-tab-hours')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('manage-hour-switch-5')));
    await tester.pump();
    expect(find.text('مغلق'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('manage-save-hours')));
    await tester.tap(find.byKey(const Key('manage-save-hours')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, contains('PUT /api/salon/hours'));
    final friday = (state['hours'] as List).firstWhere(
      (row) => row['day'] == 5,
    );
    expect(friday['is_closed'], true);
  });
}

const _freePlan = SubscriptionPlan(
  id: 1,
  name: 'باقة الانطلاق',
  tagline: 'اشتراك مجاني لمدة سنة كاملة',
  badge: 'مجاناً لمدة سنة',
  priceLabel: 'مجاناً',
  durationLabel: 'سنة واحدة',
  durationUnit: 'year',
  durationValue: 1,
  isFree: true,
  isFeatured: true,
  features: ['ظهور صالونك لكل العملاء', 'استقبال الحجوزات'],
  terms: ['الاشتراك مجاني لمدة سنة.', 'الالتزام بمواعيد العملاء.'],
);
