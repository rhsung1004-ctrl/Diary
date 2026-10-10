// 플레이스토어 스크린샷 자동 캡처: 예시 데이터를 넣고 화면별로 찍음 (ko → en → ja)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:lifebox/diary_pdf.dart';
import 'package:lifebox/main.dart' as app;
import 'package:lifebox/prefs.dart';
import 'package:lifebox/review.dart';
import 'package:lifebox/screens/diary.dart';
import 'package:lifebox/screens/goals.dart';
import 'package:lifebox/screens/stats.dart';
import 'package:lifebox/screens/timeline.dart';
import 'package:lifebox/screens/year_review.dart';
import 'package:lifebox/store.dart';

import 'demo_data.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    // ───── 예시 데이터와 설정을 앱 폴더에 미리 써 둠 ─────
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/photos');
    await photoDir.create(recursive: true);
    for (final p in demoPhotoNames) {
      await File('${photoDir.path}/demo_$p.png').writeAsBytes(await demoPhoto(p));
    }
    await File('${dir.path}/data.json').writeAsString(jsonEncode(demoData('ko')));
    await File('${dir.path}/prefs.json').writeAsString(jsonEncode({
      'colorIndex': 0,
      'themeMode': 'light',
      'font': 'pretendard',
      'textScale': 1.0,
      'language': 'ko',
      'onboarded': true,
      'notifAsked': true, // 알림 권한 창 안 띄움
      'reviewNextAt': 0, // 리뷰 요청 안 띄움
    }));

    await app.main();
    await binding.convertFlutterSurfaceToImage();

    Future<void> settle() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      try {
        await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 8));
      } catch (_) {
        await tester.pump(const Duration(seconds: 1));
      }
      // 사진(파일) 로딩 기다리기
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();
    }

    Future<void> shot(String lang, String name) async {
      await settle();
      await binding.takeScreenshot('${lang}_$name');
    }

    NavigatorState nav() => ReviewPrompt.navigatorKey.currentState!;

    Future<void> push(Widget page) async {
      nav().push(MaterialPageRoute<void>(builder: (_) => page));
      await settle();
    }

    Future<void> popAll() async {
      nav().popUntil((r) => r.isFirst);
      await settle();
    }

    Future<void> tapTab(IconData icon) async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(icon)));
      await settle();
    }

    for (final lang in ['ko', 'en', 'ja']) {
      if (lang != 'ko') {
        await AppStore.instance.replaceAll(demoData(lang));
        await AppPrefs.instance.update((p) => p.language = lang);
      }
      await settle();

      // 1. 홈
      await shot(lang, '1_home');

      // 2. 일기 달력
      await tapTab(Icons.menu_book_outlined);
      final cal = find.byIcon(Icons.calendar_month_outlined);
      if (cal.evaluate().isNotEmpty) {
        await tester.tap(cal.first);
        await settle();
      }
      await shot(lang, '2_calendar');

      // 3. 오늘 일기 (사진)
      final today = AppStore.instance.diaries.firstWhere((e) => e.photos.isNotEmpty);
      await push(DiaryView(id: today.id));
      await shot(lang, '3_diary');
      await popAll();

      // 4. 목표 + 연결된 일기
      final goal = AppStore.instance.goals.firstWhere((g) => g.id == 'g1');
      await push(GoalEditor(goal: goal));
      await tester.drag(find.byType(ListView).last, const Offset(0, -250));
      await shot(lang, '4_goal');
      await popAll();

      // 5. 타임라인
      await push(const TimelineScreen());
      await shot(lang, '5_timeline');
      await popAll();

      // 6. 커리어
      await tapTab(Icons.work_outline);
      await shot(lang, '6_career');

      // 7. 통계
      await push(const StatsScreen());
      await shot(lang, '7_stats');
      await popAll();

      // 8. 연말 결산 카드
      await push(YearReviewScreen(initialYear: DateTime.now().year));
      await shot(lang, '8_review');
      await popAll();

      // 다음 언어를 위해 홈으로
      await tapTab(Icons.home_outlined);
    }

    // 일기장 PDF 샘플 (확인용) → 드라이버가 파일로 저장
    await AppStore.instance.replaceAll(demoData('ko'));
    await AppPrefs.instance.update((p) => p.language = 'ko');
    await settle();
    final pdfs = <String, String>{};
    for (final font in ['gowunBatang', 'nanumPen']) {
      final bytes = await buildDiaryPdf(
        entries: AppStore.instance.diaries.where((e) => DateTime.now().difference(e.date).inDays < 40).toList(),
        title: '한여름의 일기장',
        from: DateTime.now().subtract(const Duration(days: 40)),
        to: DateTime.now(),
        includePhotos: true,
        fontKey: font,
        sizeFactor: font == 'nanumPen' ? 1.3 : 1.0,
        accentArgb: 0xFF3D7A6E,
      );
      pdfs['diary_$font'] = base64Encode(bytes);
    }
    binding.reportData = pdfs;
  });
}
