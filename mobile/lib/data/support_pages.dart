import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:muzayen/data/home_slide.dart';

class SupportBlock {
  const SupportBlock({
    required this.title,
    required this.body,
    this.titleEn,
    this.bodyEn,
  });

  final String title;
  final String body;
  final String? titleEn;
  final String? bodyEn;

  String titleFor(bool english) {
    if (english && titleEn != null && titleEn!.trim().isNotEmpty) {
      return titleEn!;
    }
    return title;
  }

  String bodyFor(bool english) {
    if (english && bodyEn != null && bodyEn!.trim().isNotEmpty) return bodyEn!;
    return body;
  }
}

class SupportPage {
  const SupportPage({
    required this.slug,
    required this.title,
    required this.blocks,
    this.titleEn,
    this.intro,
    this.introEn,
  });

  final String slug;
  final String title;
  final String? titleEn;
  final String? intro;
  final String? introEn;
  final List<SupportBlock> blocks;

  String titleFor(bool english) {
    if (english && titleEn != null && titleEn!.trim().isNotEmpty) {
      return titleEn!;
    }
    return title;
  }

  String? introFor(bool english) {
    if (english && introEn != null && introEn!.trim().isNotEmpty)
      return introEn;
    if (!english && intro != null && intro!.trim().isNotEmpty) return intro;
    return null;
  }

  factory SupportPage.fromJson(Map<String, dynamic> json) {
    final blocks = json['blocks'] as List<dynamic>? ?? const [];
    return SupportPage(
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      titleEn: json['title_en'] as String?,
      intro: json['intro'] as String?,
      introEn: json['intro_en'] as String?,
      blocks: [
        for (final block in blocks)
          if (block is Map<String, dynamic>)
            SupportBlock(
              title: (block['title'] as String?) ?? '',
              titleEn: block['title_en'] as String?,
              body: (block['body'] as String?) ?? '',
              bodyEn: block['body_en'] as String?,
            ),
      ],
    );
  }
}

class PagesApi {
  static Future<List<SupportPage>> Function() load = _fetch;

  static void useDefault() => load = _fetch;

  static Future<List<SupportPage>> _fetch() async {
    final response = await http
        .get(
          Uri.parse('${SlidesApi.baseUrl}/api/pages'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 6));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return [
      for (final page in data)
        if (page is Map<String, dynamic>) SupportPage.fromJson(page),
    ];
  }
}

SupportPage fallbackPage(String slug) {
  return switch (slug) {
    'help' => SupportPage(
      slug: 'help',
      title: 'مركز المساعدة',
      titleEn: 'Help center',
      blocks: const [
        SupportBlock(
          title: 'احجز موعدًا',
          titleEn: 'Book a visit',
          body:
              'افتح صفحة الصالون، اختر الخدمة والأخصائي واليوم والوقت، ثم أدخل اسمك ورقم هاتفك.',
          bodyEn:
              'Open a salon, choose a service, a specialist, a day, and a time, then enter your name and phone.',
        ),
        SupportBlock(
          title: 'المفضلة',
          titleEn: 'Favorites',
          body:
              'اضغط القلب على الصالون لحفظه. المفضلة تفتح من علامة القلب في رأس الصفحة الرئيسية.',
          bodyEn:
              'Tap the heart on a salon to save it. Open saved salons from the heart in the home header.',
        ),
        SupportBlock(
          title: 'الخدمة المنزلية',
          titleEn: 'Home service',
          body:
              'من فلتر نوع الخدمة يمكنك إظهار الصالونات التي تقدّم زيارة منزلية.',
          bodyEn:
              'Use the service-type filter to show salons that visit you at home.',
        ),
      ],
    ),
    'privacy' => const SupportPage(
      slug: 'privacy',
      title: 'سياسة الخصوصية',
      titleEn: 'Privacy policy',
      intro: 'المزين يربط ملفك وتفضيلاتك بحسابك.',
      introEn:
          'Al-Muzayyin keeps your profile and preferences with your account.',
      blocks: [
        SupportBlock(
          title: 'ما يُحفظ مع الحساب',
          titleEn: 'What is saved with the account',
          body:
              'الاسم والهاتف والصورة والإشعارات والمظهر واللغة تُحفظ مع حسابك وتظهر في لوحة الإدارة.',
          bodyEn:
              'Your name, phone, photo, notifications, appearance, and language are saved with your account and shown in the admin panel.',
        ),
        SupportBlock(
          title: 'ماذا يُرسل مع الحجز',
          titleEn: 'What a booking sends',
          body: 'عند الحجز يُرسل اسمك ورقم هاتفك إلى الصالون لتأكيد الموعد.',
          bodyEn:
              'A booking sends your name and phone to the salon so they can confirm the visit.',
        ),
      ],
    ),
    _ => const SupportPage(
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
        SupportBlock(
          title: 'هل يصل الأخصائي إلى المنزل؟',
          titleEn: 'Can the stylist come to me?',
          body:
              'الصالونات التي عليها علامة «منزلي» تقدّم زيارة. صفِّ القائمة بنوع الخدمة.',
          bodyEn:
              'Salons marked Home offer a visit. Filter the list by Home service.',
        ),
        SupportBlock(
          title: 'أين تُحفظ المفضلة؟',
          titleEn: 'Where are my favorites kept?',
          body: 'على هذا الجهاز، وتبقى حتى تزيل علامة القلب.',
          bodyEn: 'On this device. They stay until you remove the heart.',
        ),
        SupportBlock(
          title: 'كيف أغيّر اللغة؟',
          titleEn: 'How do I change the language?',
          body: 'من الإعدادات اختر اللغة، ثم العربية أو الإنجليزية.',
          bodyEn: 'Open Settings, then Language, and choose Arabic or English.',
        ),
      ],
    ),
  };
}
