import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../common.dart';
import '../i18n.dart';
import '../importer.dart';
import '../lock.dart';

/// 다른 앱에서 일기 가져오기
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  ImportPreview? _preview;
  bool _busy = false;
  String? _error;

  String _formatName(ImportFormat f) => switch (f) {
        ImportFormat.dayOne => 'Day One',
        ImportFormat.journey => 'Journey',
        ImportFormat.daylio => 'Daylio',
        ImportFormat.csv => tr.impFmtCsv,
        ImportFormat.text => tr.impFmtText,
      };

  String _errorText(Object e) {
    if (e is ImportException) {
      return switch (e.code) {
        'notUtf8' => tr.impErrEncoding,
        'noEntries' => tr.impErrNoEntries,
        'broken' => tr.impErrBroken,
        _ => tr.impErrUnsupported,
      };
    }
    return tr.errGeneric(e);
  }

  Future<void> _pick() async {
    PlatformFile? file;
    try {
      file = await AppLock.instance.runExternal(() => FilePicker.pickFile());
    } catch (e) {
      if (mounted) toast(context, tr.errGeneric(e));
      return;
    }
    final path = file?.path;
    if (path == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final p = await analyzeImport(path);
      if (!mounted) return;
      setState(() => _preview = p);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final p = _preview;
    if (p == null || p.items.isEmpty) return;
    setState(() => _busy = true);
    try {
      final n = await applyImport(p);
      if (!mounted) return;
      toast(context, tr.impDone(n));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, tr.errGeneric(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = _preview;
    return Scaffold(
      appBar: AppBar(title: Text(tr.impTitle)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text(tr.impIntro, style: t.textTheme.bodyLarge?.copyWith(height: 1.5)),
        const SizedBox(height: 16),
        if (p == null) ...[
          // 3단계 안내
          Card(
            elevation: 0,
            color: t.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr.impHowTitle, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                for (final (i, step) in [tr.impStep1, tr.impStep2, tr.impStep3].indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: t.colorScheme.primary,
                        child: Text('${i + 1}',
                            style: TextStyle(fontSize: 12, color: t.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(step, style: t.textTheme.bodyMedium?.copyWith(height: 1.4))),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(tr.impTapForHow, style: t.textTheme.titleSmall),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                _fmt(Icons.auto_stories_outlined, 'Day One', tr.impDayOne, tr.impGuideDayOne),
                _fmt(Icons.travel_explore_outlined, 'Journey', tr.impJourney, tr.impGuideJourney),
                _fmt(Icons.mood_outlined, 'Daylio', tr.impDaylio, tr.impGuideDaylio),
                _fmt(Icons.notes_outlined, tr.impFmtText, tr.impText, tr.impGuideText, example: tr.impTextExample),
                _fmt(Icons.table_chart_outlined, tr.impFmtCsv, tr.impCsv, tr.impGuideCsv, example: tr.impCsvExample),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.error)),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              icon: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_open_outlined),
              label: Text(_busy ? tr.impReading : tr.impPick),
              onPressed: _busy ? null : _pick,
            ),
          ),
        ] else ...[
          Card(
            color: t.colorScheme.primaryContainer,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_formatName(p.format), style: t.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(tr.impFound(p.items.length),
                    style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (p.items.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('${fmtDate(p.from!)} ~ ${fmtDate(p.to!)}'),
                ],
                if (p.photoCount > 0) Text(tr.impPhotos(p.photoCount)),
                if (p.duplicates > 0) Text(tr.impDuplicates(p.duplicates)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          for (final e in p.items.reversed.take(3))
            Card(
              child: ListTile(
                leading: e.mood.isEmpty ? null : Text(e.mood, style: const TextStyle(fontSize: 22)),
                title: Text(
                  e.title.isNotEmpty ? e.title : e.body.split('\n').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(fmtDate(e.date)),
              ),
            ),
          if (p.items.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Text(tr.impMore(p.items.length - 3), style: t.textTheme.bodySmall),
            ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy || p.items.isEmpty ? null : _import,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr.impConfirm(p.items.length)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : _pick, child: Text(tr.impOther)),
          const SizedBox(height: 8),
          Text(tr.impNote,
              textAlign: TextAlign.center,
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ],
      ]),
    );
  }

  Widget _fmt(IconData icon, String name, String desc, String guide, {String? example}) => ListTile(
        leading: Icon(icon),
        title: Text(name),
        subtitle: Text(desc),
        trailing: const Icon(Icons.help_outline),
        onTap: () => _showGuide(name, guide, example),
      );

  /// 앱별 내보내는 방법
  void _showGuide(String name, String guide, String? example) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr.impHowSheetTitle(name),
                    style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Text(guide, style: t.textTheme.bodyLarge?.copyWith(height: 1.6)),
                if (example != null) ...[
                  const SizedBox(height: 14),
                  Text(tr.impExample, style: t.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(example,
                        style: t.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', height: 1.5)),
                  ),
                ],
                const SizedBox(height: 12),
                Text(tr.impGuideNote,
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(tr.impPickReady),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pick();
                    },
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
