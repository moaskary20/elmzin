import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzayen/data/salon_detail.dart';
import 'package:muzayen/screens/salon_screen.dart';

void main() {
  testWidgets('salon opens under MaterialApp locale ar', (tester) async {
    SalonDetailApi.load = (_) async => SalonDetail.fallback;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SalonScreen(salonId: 1, locale: Locale('ar')),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('صالون الليث'), findsOneWidget);
    expect(find.text('اختر الخدمة'), findsOneWidget);
    expect(find.byKey(const Key('salon-back')), findsOneWidget);
  });
}
