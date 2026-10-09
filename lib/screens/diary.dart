import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../photos.dart';
import '../store.dart';
import 'diary_calendar.dart';
import 'diary_prompts.dart';
import '../i18n.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  bool _calendar = false;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr.diary),
        actions: [
          IconButton(
            tooltip: _calendar ? tr.viewList : tr.viewCalendar,
            icon: Icon(_calendar ? Icons.view_agenda_outlined : Icons.calendar_month_outlined),
            onPressed: () => setState(() => _calendar = !_calendar),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_diary',
        onPressed: () => openDiaryEditor(context, null),
        icon: const Icon(Icons.edit_outlined),
        label: Text(tr.todayDiary),
      ),
      body: _calendar
          ? const DiaryCalendar()
          : ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = List.of(store.diaries)
            ..sort((a, b) {
              final c = b.date.compareTo(a.date);
              return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
            });
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80), // 하단 버튼만큼 살짝 위로
                child: EmptyState(icon: Icons.menu_book_outlined, text: tr.diaryEmpty, top: 0),
              ),
            );
          }
          final children = <Widget>[];
          String? month;
          for (final e in list) {
            final m = fmtMonthTitle(e.date);
            if (m != month) {
              month = m;
              children.add(SectionTitle(m));
            }
            children.add(DiaryCard(entry: e));
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: children);
        },
      ),
    );
  }
}

class DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  const DiaryCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final t = Theme.of(context);
    final headline = e.title.isNotEmpty ? e.title : e.body.split('\n').first;
    final preview = e.title.isNotEmpty ? e.body : e.body.split('\n').skip(1).join(' ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => DiaryView(id: e.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 44,
              child: Column(children: [
                Text('${e.date.day}',
                    style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(weekday(e.date), style: t.textTheme.bodySmall),
                if (e.mood.isNotEmpty) Text(e.mood, style: const TextStyle(fontSize: 18)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(headline.isEmpty ? tr.photoDiary : headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (preview.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(preview.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodyMedium
                          ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ],
              ]),
            ),
            if (e.photos.isNotEmpty) ...[
              const SizedBox(width: 12),
              PhotoThumb(e.photos.first, size: 64),
            ],
          ]),
        ),
      ),
    );
  }
}

/// 일기 읽기 화면
class DiaryView extends StatelessWidget {
  final String id;
  const DiaryView({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final e = findById(store.diaries, id, (DiaryEntry x) => x.id);
        if (e == null) return Scaffold(appBar: AppBar());
        final t = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(fmtDateW(e.date)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => openDiaryEditor(context, e),
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              if (e.mood.isNotEmpty) ...[
                Text(e.mood, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
              ],
              if (e.title.isNotEmpty)
                Expanded(
                  child: Text(e.title,
                      style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 16),
            PhotoGallery(e.photos),
            if (e.photos.isNotEmpty) const SizedBox(height: 16),
            SelectableText(e.body, style: t.textTheme.bodyLarge?.copyWith(height: 1.7)),
          ]),
        );
      },
    );
  }
}

/// 일기 쓰기/수정. 삭제되면 true 를 돌려줌
Future<void> openDiaryEditor(BuildContext context, DiaryEntry? entry,
    {DateTime? date, DiaryEntry? draft}) async {
  final deleted = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => DiaryEditor(entry: entry, date: date, draft: draft)),
  );
  // 읽기 화면에서 열었다가 삭제했으면 읽기 화면도 닫기
  if (deleted == true && context.mounted && entry != null) Navigator.pop(context);
}

class DiaryEditor extends StatefulWidget {
  final DiaryEntry? entry;
  final DateTime? date;
  final DiaryEntry? draft; // 새 일기를 미리 채워서 열 때 (버킷 달성 등)
  const DiaryEditor({super.key, this.entry, this.date, this.draft});

  @override
  State<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<DiaryEditor> with DirtyGuard<DiaryEditor> {
  late final DiaryEntry d = widget.entry?.copy() ?? widget.draft ?? DiaryEntry(date: widget.date);
  late final _title = TextEditingController(text: d.title);
  late final _body = TextEditingController(text: d.body);
  bool get isNew => widget.entry == null;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    d
      ..title = _title.text.trim()
      ..body = _body.text.trimRight();
    if (d.title.isEmpty && d.body.trim().isEmpty && d.photos.isEmpty) {
      toast(context, tr.diaryNeedContent);
      return;
    }
    await AppStore.instance.upsertDiary(d);
    dirty = false;
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, tr.diaryDeleteTitle, tr.cannotUndo, tr.delete)) return;
    await AppStore.instance.removeDiary(d.id);
    dirty = false;
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return guard(Scaffold(
      appBar: AppBar(
        title: Text(isNew ? tr.writeDiary : tr.diaryEdit),
        actions: [
          if (!isNew) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: Text(tr.save)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DateTile(
          label: tr.date,
          value: d.date,
          onPick: (v) {
            setState(() => d.date = v);
            markDirty();
          },
        ),
        const SizedBox(height: 4),
        Text(tr.todayMood, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final m in moods)
            ChoiceChip(
              label: Text(m, style: const TextStyle(fontSize: 20)),
              selected: d.mood == m,
              showCheckmark: false,
              onSelected: (sel) {
                setState(() => d.mood = sel ? m : '');
                markDirty();
              },
            ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          decoration: deco(tr.optional(tr.title)),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.lightbulb_outline, size: 18),
            label: Text(tr.askPrompt),
            onPressed: () async {
              final text = await pickDiaryPrompt(context);
              if (text == null) return;
              final cur = _body.text;
              _body.text = cur.trim().isEmpty ? text : '${cur.trimRight()}\n\n$text';
              _body.selection = TextSelection.collapsed(offset: _body.text.length);
              markDirty();
            },
          ),
        ),
        TextField(
          controller: _body,
          autofocus: isNew && widget.draft == null,
          minLines: 10,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: deco(tr.diaryBody, hint: tr.diaryBodyHint),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 16),
        PhotoEditor(photos: d.photos, onChanged: markDirty),
        const SizedBox(height: 24),
      ]),
    ));
  }
}
