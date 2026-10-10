import 'dart:async';

import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../photos.dart';
import '../store.dart';
import 'diary_calendar.dart';
import 'diary_export.dart';
import 'diary_prompts.dart';
import '../i18n.dart';
import '../pro.dart';

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
            tooltip: tr.dpTitle,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              if (!await requirePro(context) || !context.mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryExportScreen()));
            },
          ),
          IconButton(
            tooltip: tr.tagBrowse,
            icon: const Icon(Icons.tag),
            onPressed: () => showTagBrowser(context),
          ),
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
                if (e.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(e.tags.map((x) => '#$x').join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.primary)),
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
            if (e.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final tag in e.tags)
                  ActionChip(
                    label: Text('#$tag'),
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => TagEntriesScreen(tag: tag))),
                  ),
              ]),
            ],
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

class _DiaryEditorState extends State<DiaryEditor>
    with DirtyGuard<DiaryEditor>, WidgetsBindingObserver {
  late final DiaryEntry d = widget.entry?.copy() ?? widget.draft ?? DiaryEntry(date: widget.date);
  late final _title = TextEditingController(text: d.title);
  late final _body = TextEditingController(text: d.body);
  final _tag = TextEditingController();
  bool get isNew => widget.entry == null;

  // ───── 임시 저장 ─────
  String get _draftKey => widget.entry?.id ?? 'new';
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final draft = AppStore.instance.drafts[_draftKey];
    if (draft != null && widget.draft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraft(draft));
    }
  }

  Future<void> _offerDraft(DiaryDraft draft) async {
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr.draftFoundTitle),
        content: Text(tr.draftFoundBody(fmtDateTime(draft.savedAt))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr.draftDiscard)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr.draftContinue)),
        ],
      ),
    );
    if (!mounted) return;
    if (resume == true) {
      final e = draft.entry;
      setState(() {
        d
          ..date = e.date
          ..mood = e.mood
          ..photos = List.of(e.photos)
          ..tags = List.of(e.tags)
          ..goalId = e.goalId;
        _title.text = e.title;
        _body.text = e.body;
      });
      markDirty();
    } else {
      await AppStore.instance.clearDraft(_draftKey);
    }
  }

  @override
  void markDirty() {
    super.markDirty();
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 1500), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (!dirty) return;
    d
      ..title = _title.text
      ..body = _body.text;
    await AppStore.instance.saveDraft(_draftKey, d);
  }

  @override
  void onDiscard() => AppStore.instance.clearDraft(_draftKey);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 전화가 오거나 앱을 나갈 때 바로 임시 저장
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _draftTimer?.cancel();
      _saveDraft();
    }
  }

  // ───── 태그 ─────
  void _addTag([String? raw]) {
    final parts = (raw ?? _tag.text)
        .split(RegExp(r'[\s,#]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && t.length <= 20);
    var changed = false;
    for (final t in parts) {
      if (!d.tags.contains(t)) {
        d.tags.add(t);
        changed = true;
      }
    }
    _tag.clear();
    if (changed) {
      setState(() {});
      markDirty();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _title.dispose();
    _body.dispose();
    _tag.dispose();
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
    _addTag(); // 입력칸에 남은 태그도 저장
    _draftTimer?.cancel();
    await AppStore.instance.upsertDiary(d);
    await AppStore.instance.clearDraft(_draftKey);
    dirty = false;
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, tr.diaryDeleteTitle, tr.cannotUndo, tr.delete)) return;
    _draftTimer?.cancel();
    await AppStore.instance.removeDiary(d.id);
    await AppStore.instance.clearDraft(_draftKey);
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
        // 자주 안 쓰는 항목은 접어 둠 (태그 · 관련 목표)
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            initiallyExpanded: d.tags.isNotEmpty || d.goalId != null,
            leading: const Icon(Icons.tag),
            title: Text(tr.diaryMore),
            subtitle: d.tags.isEmpty ? null : Text(d.tags.map((t) => '#$t').join(' '), maxLines: 1),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
        // 관련 목표 (목표 화면에 이 일기가 모여요)
        Builder(builder: (context) {
          final goals = [
            ...AppStore.instance.goals.where((g) => !g.isComplete),
            ...AppStore.instance.goals.where((g) => g.isComplete),
          ];
          if (goals.isEmpty) return const SizedBox.shrink();
          final value = goals.any((g) => g.id == d.goalId) ? d.goalId : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String?>(
              initialValue: value,
              isExpanded: true,
              decoration: deco(tr.linkedGoal).copyWith(prefixIcon: const Icon(Icons.track_changes)),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(tr.linkedGoalNone)),
                for (final g in goals)
                  DropdownMenuItem<String?>(
                    value: g.id,
                    child: Text('${g.isComplete ? '✓ ' : ''}${g.title}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                setState(() => d.goalId = v);
                markDirty();
              },
            ),
          );
        }),
        Text(tr.tags, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (d.tags.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in d.tags)
              InputChip(
                label: Text('#$t'),
                onDeleted: () {
                  setState(() => d.tags.remove(t));
                  markDirty();
                },
              ),
          ]),
        TextField(
          controller: _tag,
          decoration: InputDecoration(hintText: tr.tagAddHint, isDense: true, prefixText: '# '),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addTag(),
        ),
        Builder(builder: (context) {
          final suggestions = AppStore.instance.diaryTagCounts
              .map((e) => e.key)
              .where((t) => !d.tags.contains(t))
              .take(10)
              .toList();
          if (suggestions.isEmpty) return const SizedBox(height: 8);
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in suggestions)
                ActionChip(label: Text('#$t'), onPressed: () => _addTag(t)),
            ]),
          );
        }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        PhotoEditor(photos: d.photos, onChanged: markDirty),
        const SizedBox(height: 24),
      ]),
    ));
  }
}


/// 태그 목록 (많이 쓴 순) → 고르면 그 태그의 일기 모아보기
void showTagBrowser(BuildContext context) {
  final tags = AppStore.instance.diaryTagCounts;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr.tagBrowse, style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (tags.isEmpty)
            Text(tr.tagNone)
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in tags)
                ActionChip(
                  label: Text('#${e.key}  ${e.value}'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context, MaterialPageRoute(builder: (_) => TagEntriesScreen(tag: e.key)));
                  },
                ),
            ]),
        ]),
      ),
    ),
  );
}

class TagEntriesScreen extends StatelessWidget {
  final String tag;
  const TagEntriesScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.diaries.where((e) => e.tags.contains(tag)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: AppBar(title: Text(tr.tagEntries(tag, list.length))),
          body: list.isEmpty
              ? EmptyState(icon: Icons.tag, text: tr.tagNone)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [for (final e in list) DiaryCard(entry: e)],
                ),
        );
      },
    );
  }
}
