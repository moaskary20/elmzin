import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzayen/data/app_popup.dart';
import 'package:muzayen/screens/app_shell.dart';
import 'package:muzayen/data/home_category.dart';
import 'package:muzayen/data/home_salon.dart';
import 'package:muzayen/data/home_slide.dart';
import 'package:muzayen/data/notifications_store.dart';
import 'package:muzayen/data/service_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muzayen/data/account_store.dart';
import 'package:muzayen/data/customer_booking.dart';
import 'package:muzayen/screens/search_screen.dart';
import 'package:muzayen/data/subscription_plans.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AccountStore.instance.reset();
    NotificationsStore.instance.reset();
    NotificationsStore.pollEvery = null;
    NotificationsApi.fetch = (_) async =>
        const NoticePage(items: [], unread: 0);
    ServicesApi.load = () async => ServiceOffer.fallback;
    CategoriesApi.load = () async => HomeCategory.fallback;
    SalonsApi.load = () async => HomeSalon.fallback;
    SlidesApi.load = () async => const [HomeSlide.fallback];
    SearchScreen.useMap = false;
    SearchScreen.locate = () async => null;
    BookingsApi.load = () async => [];
    SubscriptionPlansApi.load = () async => const [];
  });

  testWidgets('app shell shows admin popup after open', (tester) async {
    AppPopupApi.load = () async => const AppPopup(
      id: 1,
      title: 'عرض خاص',
      titleEn: 'Special offer',
      body: 'احجز اليوم واحصل على خصم.',
      bodyEn: 'Book today and get a discount.',
      buttonLabel: 'موافق',
      buttonLabelEn: 'OK',
    );

    await tester.pumpWidget(
      const MaterialApp(home: AppShell(locale: Locale('ar'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.byKey(const Key('app-popup-dialog')), findsOneWidget);
    expect(find.text('عرض خاص'), findsOneWidget);
    expect(find.text('احجز اليوم واحصل على خصم.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-popup-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('app-popup-dialog')), findsNothing);
  });
}
