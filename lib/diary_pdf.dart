import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'i18n.dart';
import 'models.dart';
import 'store.dart';

/// 일기장 PDF에서 쓸 수 있는 글꼴 (앱 글꼴 키 → 파일)
const _fontFiles = {
  'pretendard': ('Pretendard-Regular.ttf', 'Pretendard-Bold.ttf'),
  'gowunDodum': ('GowunDodum-Regular.ttf', 'GowunDodum-Regular.ttf'),
  'gowunBatang': ('GowunBatang-Regular.ttf', 'GowunBatang-Bold.ttf'),
  'nanumPen': ('NanumPenScript-Regular.ttf', 'NanumPenScript-Regular.ttf'),
  'lora': ('Lora.ttf', 'Lora.ttf'),
  'caveat': ('Caveat.ttf', 'Caveat.ttf'),
  'zenMaru': ('ZenMaruGothic-Regular.ttf', 'ZenMaruGothic-Bold.ttf'),
  'shippori': ('ShipporiMincho-Regular.ttf', 'ShipporiMincho-Bold.ttf'),
  'klee': ('KleeOne-Regular.ttf', 'KleeOne-Regular.ttf'),
};

bool diaryPdfFontAvailable(String key) => _fontFiles.containsKey(key);

Future<pw.Font> _font(String file) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));

/// PDF 글꼴에는 컬러 이모지가 없어서, 본문의 이모지는 빼고 기분 이모지는 그림으로 넣음
final _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{20E3}\u{E0020}-\u{E007F}]',
    unicode: true);
String _clean(String s) => s.replaceAll(_emoji, '').replaceAll(RegExp(r'[ \t]+\n'), '\n');

Future<Uint8List> _emojiPng(String e) async {
  final tp = TextPainter(
    text: TextSpan(text: e, style: const TextStyle(fontSize: 96)),
    textDirection: TextDirection.ltr,
  )..layout();
  final rec = ui.PictureRecorder();
  tp.paint(ui.Canvas(rec), Offset.zero);
  final img = await rec.endRecording().toImage(tp.width.ceil(), tp.height.ceil());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<Uint8List> buildDiaryPdf({
  required List<DiaryEntry> entries,
  required String title,
  required DateTime from,
  required DateTime to,
  required bool includePhotos,
  required String fontKey,
  required double sizeFactor,
  required int accentArgb,
}) async {
  final files = _fontFiles[fontKey] ?? _fontFiles['pretendard']!;
  final regular = await _font(files.$1);
  final bold = await _font(files.$2);
  // 고른 글꼴에 없는 글자(다른 언어, 드문 글자)는 대체 글꼴로
  final fallback = <pw.Font>[
    if (fontKey != 'pretendard') await _font('Pretendard-Regular.ttf'),
    if (fontKey != 'zenMaru') await _font('ZenMaruGothic-Regular.ttf'),
  ];

  final accent = PdfColor.fromInt(accentArgb);
  const paper = PdfColor.fromInt(0xFFFBF8F1);
  const ink = PdfColor.fromInt(0xFF2B2B2B);
  const muted = PdfColor.fromInt(0xFF8A8478);
  final k = sizeFactor;
  final lang = appLang;

  final moods = <String, pw.MemoryImage>{};
  for (final e in entries) {
    if (e.mood.isNotEmpty && !moods.containsKey(e.mood)) {
      moods[e.mood] = pw.MemoryImage(await _emojiPng(e.mood));
    }
  }

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold, fontFallback: fallback),
    title: title,
  );
  const format = PdfPageFormat.a5;
  final pageTheme = pw.PageTheme(
    pageFormat: format,
    margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 40),
    buildBackground: (_) => pw.FullPage(ignoreMargins: true, child: pw.Container(color: paper)),
  );

  // ───── 표지 ─────
  final range = '${DateFormat.yMd(lang).format(from)} – ${DateFormat.yMd(lang).format(to)}';
  doc.addPage(pw.Page(
    pageTheme: pageTheme,
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(width: 40, height: 4, color: accent),
      pw.Spacer(),
      pw.Text(title, style: pw.TextStyle(fontSize: 30 * k, fontWeight: pw.FontWeight.bold, color: ink)),
      pw.SizedBox(height: 12),
      pw.Text(range, style: pw.TextStyle(fontSize: 12 * k, color: muted)),
      pw.SizedBox(height: 4),
      pw.Text(tr.dpCount(entries.length), style: pw.TextStyle(fontSize: 12 * k, color: muted)),
      pw.Spacer(flex: 2),
      pw.Row(children: [
        pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle)),
        pw.SizedBox(width: 6),
        pw.Text('LifeBox', style: const pw.TextStyle(fontSize: 9, color: muted)),
      ]),
    ]),
  ));

  // ───── 월별로 ─────
  final sorted = List.of(entries)..sort((a, b) => a.date.compareTo(b.date));
  final months = <String, List<DiaryEntry>>{};
  for (final e in sorted) {
    months.putIfAbsent('${e.date.year}-${e.date.month}', () => []).add(e);
  }

  for (final list in months.values) {
    final m = list.first.date;
    // 월 구분 페이지
    doc.addPage(pw.Page(
      pageTheme: pageTheme,
      build: (_) => pw.Center(
        child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Text(DateFormat.MMMM(lang).format(m),
              style: pw.TextStyle(fontSize: 34 * k, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.SizedBox(height: 6),
          pw.Text(DateFormat.y(lang).format(m), style: pw.TextStyle(fontSize: 14 * k, color: muted)),
          pw.SizedBox(height: 18),
          pw.Container(width: 30, height: 1, color: muted),
          pw.SizedBox(height: 18),
          pw.Text(tr.dpCount(list.length), style: pw.TextStyle(fontSize: 11 * k, color: muted)),
        ]),
      ),
    ));

    final body = <pw.Widget>[];
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (i > 0) {
        body.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 18),
          child: pw.Center(
            child: pw.Text('·  ·  ·', style: pw.TextStyle(fontSize: 12, color: muted, letterSpacing: 2)),
          ),
        ));
      }
      // 날짜 머리
      body.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text('${e.date.day}',
            style: pw.TextStyle(fontSize: 26 * k, fontWeight: pw.FontWeight.bold, color: accent, height: 1)),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(DateFormat.yMMMMEEEEd(lang).format(e.date),
                style: pw.TextStyle(fontSize: 9.5 * k, color: muted)),
          ),
        ),
        if (moods[e.mood] != null) pw.Image(moods[e.mood]!, width: 22, height: 22),
      ]));
      body.add(pw.SizedBox(height: 4));
      body.add(pw.Container(height: 0.6, color: accent));
      body.add(pw.SizedBox(height: 10));

      final t = _clean(e.title).trim();
      if (t.isNotEmpty) {
        body.add(pw.Text(t, style: pw.TextStyle(fontSize: 14 * k, fontWeight: pw.FontWeight.bold, color: ink)));
        body.add(pw.SizedBox(height: 6));
      }
      for (final para in _clean(e.body).split('\n')) {
        body.add(pw.Paragraph(
          text: para.isEmpty ? ' ' : para,
          style: pw.TextStyle(fontSize: 10.5 * k, color: ink, lineSpacing: 4),
          margin: const pw.EdgeInsets.only(bottom: 2),
        ));
      }

      if (includePhotos && e.photos.isNotEmpty) {
        final imgs = <pw.MemoryImage>[];
        for (final p in e.photos.take(4)) {
          final f = AppStore.instance.photoFile(p);
          if (await f.exists()) imgs.add(pw.MemoryImage(await f.readAsBytes()));
        }
        if (imgs.length == 1) {
          body.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.ClipRRect(
              horizontalRadius: 4,
              verticalRadius: 4,
              child: pw.Image(imgs.first, width: 340, height: 220, fit: pw.BoxFit.cover),
            ),
          ));
        } else if (imgs.isNotEmpty) {
          body.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Wrap(spacing: 6, runSpacing: 6, children: [
              for (final img in imgs)
                pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Image(img, width: 167, height: 120, fit: pw.BoxFit.cover),
                ),
            ]),
          ));
        }
      }

      if (e.tags.isNotEmpty) {
        body.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(e.tags.map((x) => '#${_clean(x)}').join('  '),
              style: pw.TextStyle(fontSize: 9 * k, color: accent)),
        ));
      }
    }

    doc.addPage(pw.MultiPage(
      pageTheme: pageTheme,
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text('${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8, color: muted)),
      ),
      build: (_) => body,
    ));
  }
  return doc.save();
}
