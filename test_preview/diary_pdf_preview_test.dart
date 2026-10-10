// 일기장 PDF 미리보기용: 예시 데이터로 PDF를 만들어 screenshots/ 에 저장 (스크린샷 워크플로에서만 실행)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifebox/diary_pdf.dart';
import 'package:lifebox/models.dart';
import 'package:lifebox/prefs.dart';
import 'package:lifebox/store.dart';

import '../integration_test/demo_data.dart';

void main() {
  testWidgets('diary pdf preview', (tester) async {
    await Directory('screenshots').create(recursive: true);
    Object? err;
    await tester.runAsync(() async {
     try {
      final tmp = await Directory.systemTemp.createTemp('lb');
      AppStore.instance.photoDir = tmp;
      for (final p in demoPhotoNames) {
        await File('${tmp.path}/demo_$p.png').writeAsBytes(await demoPhoto(p));
      }
      AppPrefs.instance.language = 'ko';
      final data = demoData('ko');
      final entries = [
        for (final e in data['diaries'] as List) DiaryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
      for (final font in ['gowunBatang', 'nanumPen']) {
        final bytes = await buildDiaryPdf(
          entries: entries.where((e) => DateTime.now().difference(e.date).inDays < 40).toList(),
          title: '한여름의 일기장',
          from: DateTime.now().subtract(const Duration(days: 40)),
          to: DateTime.now(),
          includePhotos: true,
          fontKey: font,
          sizeFactor: font == 'nanumPen' ? 1.3 : 1.0,
          accentArgb: 0xFF3D7A6E,
        );
        await Directory('screenshots').create(recursive: true);
        await File('screenshots/diary_$font.pdf').writeAsBytes(bytes);
      }
     } catch (e, st) {
      err = e;
      await File('screenshots/pdf_error.txt').writeAsString('$e\n$st');
     }
    });
    final ex = tester.takeException();
    if (ex != null) await File('screenshots/pdf_exception.txt').writeAsString('$ex');
    expect(err, isNull);
  });
}
