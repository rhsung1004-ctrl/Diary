import 'package:flutter/material.dart';

import '../common.dart';
import '../diary_pdf.dart';
import '../i18n.dart';
import '../prefs.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'portfolio.dart';

enum _Range { month, year, all, custom }

/// 일기장 PDF 만들기 (기간 · 표지 제목 · 사진 · 글꼴)
class DiaryExportScreen extends StatefulWidget {
  const DiaryExportScreen({super.key});

  @override
  State<DiaryExportScreen> createState() => _DiaryExportScreenState();
}

class _DiaryExportScreenState extends State<DiaryExportScreen> {
  final store = AppStore.instance;
  _Range _range = _Range.month;
  DateTimeRange? _custom;
  bool _photos = true;
  late String _font = diaryPdfFontAvailable(fontByKey(AppPrefs.instance.font).key)
      ? fontByKey(AppPrefs.instance.font).key
      : (appLang == 'ja' ? 'zenMaru' : 'pretendard');
  late final _title = TextEditingController(
      text: store.profile.name.isEmpty ? tr.dpCoverDefault : tr.dpCoverOf(store.profile.name));

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  (DateTime, DateTime) get _period {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    switch (_range) {
      case _Range.month:
        return (DateTime(now.year, now.month), today);
      case _Range.year:
        return (DateTime(now.year), today);
      case _Range.custom:
        final r = _custom;
        if (r != null) return (r.start, r.end);
        return (DateTime(now.year, now.month), today);
      case _Range.all:
        final ds = store.diaries.map((e) => DateUtils.dateOnly(e.date)).toList()..sort();
        return (ds.isEmpty ? today : ds.first, ds.isEmpty ? today : ds.last);
    }
  }

  List<DiaryEntry> get _entries {
    final (from, to) = _period;
    final end = to.add(const Duration(days: 1));
    return store.diaries.where((e) => !e.date.isBefore(from) && e.date.isBefore(end)).toList();
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _custom ?? DateTimeRange(start: DateTime(now.year, now.month), end: now),
    );
    if (r != null) {
      setState(() {
        _custom = r;
        _range = _Range.custom;
      });
    }
  }

  void _make() {
    final entries = _entries;
    if (entries.isEmpty) {
      toast(context, tr.dpNone);
      return;
    }
    final (from, to) = _period;
    final font = allFonts.firstWhere((f) => f.key == _font, orElse: () => allFonts.first);
    final bytes = buildDiaryPdf(
      entries: entries,
      title: _title.text.trim().isEmpty ? tr.dpCoverDefault : _title.text.trim(),
      from: from,
      to: to,
      includePhotos: _photos,
      fontKey: _font,
      sizeFactor: font.sizeFactor,
      accentArgb: themeColors[AppPrefs.instance.colorIndex.clamp(0, themeColors.length - 1)].seed.toARGB32(),
    );
    final name = '${tr.dpFile}_${from.year}${two(from.month)}${two(from.day)}-${to.year}${two(to.month)}${two(to.day)}.pdf';
    Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(bytes: bytes, fileName: name)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (from, to) = _period;
    final count = _entries.length;
    final fonts = [for (final f in fontsFor(appLang)) if (diaryPdfFontAvailable(f.key)) f];
    return Scaffold(
      appBar: AppBar(title: Text(tr.dpTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr.dpPeriod, style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (r, label) in [
            (_Range.month, tr.dpThisMonth),
            (_Range.year, tr.dpThisYear),
            (_Range.all, tr.dpAll),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _range == r,
              onSelected: (_) => setState(() => _range = r),
            ),
          ChoiceChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(tr.dpCustom),
            selected: _range == _Range.custom,
            onSelected: (_) => _pickCustom(),
          ),
        ]),
        const SizedBox(height: 8),
        Text('${fmtDate(from)} – ${fmtDate(to)} · ${tr.dpCount(count)}',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        TextField(controller: _title, decoration: deco(tr.dpCoverTitle)),
        const SizedBox(height: 20),
        Text(tr.font, style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in fonts)
            ChoiceChip(
              label: Text(f.label, style: TextStyle(fontFamily: f.family)),
              selected: _font == f.key,
              onSelected: (_) => setState(() => _font = f.key),
            ),
        ]),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr.dpPhotos),
          value: _photos,
          onChanged: (v) => setState(() => _photos = v),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(tr.dpMake),
          onPressed: count == 0 ? null : _make,
        ),
        if (count == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(tr.dpNone, textAlign: TextAlign.center, style: t.textTheme.bodySmall),
          ),
      ]),
    );
  }
}
