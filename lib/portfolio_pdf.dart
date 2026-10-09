import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'common.dart';
import 'models.dart';
import 'store.dart';
import 'i18n.dart';

/// 포트폴리오 PDF 순서
const portfolioOrder = ['경력', '프로젝트', '학력', '자격·수상', '활동'];

String _period(CareerItem c) {
  if (c.startDate == null) return '';
  final end = c.ongoing ? tr.present : (c.endDate == null ? '' : fmtMonth(c.endDate!));
  return end.isEmpty ? fmtMonth(c.startDate!) : '${fmtMonth(c.startDate!)} – $end';
}

Future<Uint8List> buildPortfolioPdf({
  required Profile profile,
  required List<CareerItem> items,
  required Set<String> types,
  required bool includeImages,
  required int accentArgb,
}) async {
  // 한글·영문은 프리텐다드, 일본어 화면이면 Zen 마루 고딕을 기본으로 (서로 대체 글꼴)
  final kr = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
  final krBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
  final jp = pw.Font.ttf(await rootBundle.load('assets/fonts/ZenMaruGothic-Regular.ttf'));
  final jpBold = pw.Font.ttf(await rootBundle.load('assets/fonts/ZenMaruGothic-Bold.ttf'));
  final isJa = appLang == 'ja';
  final regular = isJa ? jp : kr;
  final bold = isJa ? jpBold : krBold;
  final fallback = isJa ? [kr, krBold] : [jp, jpBold];
  final accent = PdfColor.fromInt(accentArgb);
  const muted = PdfColors.grey700;
  final store = AppStore.instance;

  Future<pw.MemoryImage?> image(String name) async {
    final f = store.photoFile(name);
    if (!await f.exists()) return null;
    return pw.MemoryImage(await f.readAsBytes());
  }

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold, fontFallback: fallback),
    title: profile.name.isEmpty ? tr.portfolio : tr.portfolioOf(profile.name),
    author: profile.name,
  );

  final body = <pw.Widget>[];

  // ───── 표지 머리말 ─────
  final photo = profile.photo.isEmpty ? null : await image(profile.photo);
  final contacts = [profile.email, profile.phone, profile.link].where((s) => s.isNotEmpty).join('   ·   ');
  body.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
    if (photo != null) ...[
      pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Image(photo, width: 72, height: 72, fit: pw.BoxFit.cover),
      ),
      pw.SizedBox(width: 16),
    ],
    pw.Expanded(
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(profile.name.isEmpty ? tr.portfolio : profile.name,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        if (profile.headline.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(profile.headline, style: pw.TextStyle(fontSize: 12, color: accent)),
        ],
        if (contacts.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(contacts, style: const pw.TextStyle(fontSize: 9, color: muted)),
        ],
      ]),
    ),
  ]));
  if (profile.intro.isNotEmpty) {
    body.add(pw.SizedBox(height: 14));
    for (final line in profile.intro.split('\n')) {
      body.add(pw.Paragraph(text: line, style: const pw.TextStyle(fontSize: 10, lineSpacing: 3)));
    }
  }
  body.add(pw.SizedBox(height: 8));
  body.add(pw.Divider(color: PdfColors.grey400, thickness: 0.5));

  // ───── 유형별 섹션 ─────
  for (final type in portfolioOrder) {
    if (!types.contains(type)) continue;
    final list = items.where((c) => c.type == type).toList()
      ..sort((a, b) {
        if (a.ongoing != b.ongoing) return a.ongoing ? -1 : 1;
        return (b.startDate ?? b.createdAt).compareTo(a.startDate ?? a.createdAt);
      });
    if (list.isEmpty) continue;

    body.add(pw.SizedBox(height: 14));
    body.add(pw.Row(children: [
      pw.Container(width: 4, height: 14, color: accent),
      pw.SizedBox(width: 8),
      pw.Text(careerTypeLabel(type), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
    ]));
    body.add(pw.SizedBox(height: 8));

    for (final c in list) {
      body.add(pw.SizedBox(height: 6));
      body.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Text(c.title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 12),
        pw.Text(_period(c), style: const pw.TextStyle(fontSize: 9, color: muted)),
      ]));
      if (c.org.isNotEmpty) {
        body.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(c.org, style: const pw.TextStyle(fontSize: 10, color: muted)),
        ));
      }
      if (c.description.isNotEmpty) {
        body.add(pw.SizedBox(height: 4));
        for (final line in c.description.split('\n')) {
          body.add(pw.Paragraph(
            text: line,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
            margin: const pw.EdgeInsets.only(bottom: 2),
          ));
        }
      }
      if (c.skills.isNotEmpty) {
        body.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Wrap(spacing: 4, runSpacing: 4, children: [
            for (final s in c.skills)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(s, style: const pw.TextStyle(fontSize: 8)),
              ),
          ]),
        ));
      }
      if (c.link.isNotEmpty) {
        body.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.UrlLink(
            destination: c.link.startsWith('http') ? c.link : 'https://${c.link}',
            child: pw.Text(c.link, style: pw.TextStyle(fontSize: 9, color: accent)),
          ),
        ));
      }
      if (includeImages && c.photos.isNotEmpty) {
        final imgs = <pw.MemoryImage>[];
        for (final p in c.photos.take(3)) {
          final img = await image(p);
          if (img != null) imgs.add(img);
        }
        if (imgs.isNotEmpty) {
          body.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Row(children: [
              for (final img in imgs)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 6),
                  child: pw.ClipRRect(
                    horizontalRadius: 4,
                    verticalRadius: 4,
                    child: pw.Image(img, width: 150, height: 95, fit: pw.BoxFit.cover),
                  ),
                ),
            ]),
          ));
        }
      }
      body.add(pw.SizedBox(height: 8));
    }
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 32),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ),
    build: (_) => body,
  ));
  return doc.save();
}
