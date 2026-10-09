import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../photos.dart';
import '../store.dart';
import 'diary.dart';
import '../i18n.dart';

class BucketScreen extends StatefulWidget {
  const BucketScreen({super.key});

  @override
  State<BucketScreen> createState() => _BucketScreenState();
}

class _BucketScreenState extends State<BucketScreen> {
  final store = AppStore.instance;
  int _filter = 0; // 0 전체, 1 도전 중, 2 달성

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr.bucketList)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_bucket',
        onPressed: () => openBucketEditor(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final all = store.buckets;
          final todo = all.where((b) => !b.done).toList();
          final done = all.where((b) => b.done).toList()
            ..sort((a, b) => (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));
          final items = switch (_filter) { 1 => todo, 2 => done, _ => [...todo, ...done] };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _ProgressHeader(done: done.length, total: all.length),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(tr.all)),
                  ButtonSegment(value: 1, label: Text(tr.bucketTrying)),
                  ButtonSegment(value: 2, label: Text(tr.bucketAchieved)),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                EmptyState(icon: Icons.flag_outlined, text: tr.bucketEmpty),
              for (final b in items) BucketTile(item: b),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressHeader({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 0,
      color: t.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr.bucketProgress(total, done),
              style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: t.colorScheme.onPrimaryContainer)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ]),
      ),
    );
  }
}

class BucketTile extends StatelessWidget {
  final BucketItem item;
  const BucketTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final b = item;
    final sub = [
      if (b.category.isNotEmpty) b.category,
      if (b.done && b.doneAt != null) tr.bucketDoneOn(fmtDate(b.doneAt!)),
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: b.done,
          onChanged: (v) async {
            b.done = v ?? false;
            b.doneAt = b.done ? DateTime.now() : null;
            await AppStore.instance.save();
            if (b.done && context.mounted && await askBucketDiary(context, b) && context.mounted) {
              openDiaryEditor(context, null, draft: bucketDiaryDraft(b));
            }
          },
        ),
        title: Text(
          b.title,
          style: b.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: sub.isEmpty ? null : Text(sub),
        trailing: b.photos.isEmpty ? null : PhotoThumb(b.photos.first, size: 44),
        onTap: () => openBucketEditor(context, b),
      ),
    );
  }
}

void openBucketEditor(BuildContext context, BucketItem? item) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => BucketEditor(item: item)));
}

class BucketEditor extends StatefulWidget {
  final BucketItem? item;
  const BucketEditor({super.key, this.item});

  @override
  State<BucketEditor> createState() => _BucketEditorState();
}

class _BucketEditorState extends State<BucketEditor> with DirtyGuard<BucketEditor> {
  late final BucketItem d = widget.item?.copy() ?? BucketItem();
  late final _title = TextEditingController(text: d.title);
  late final _category = TextEditingController(text: d.category);
  late final _note = TextEditingController(text: d.note);
  bool get isNew => widget.item == null;

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, tr.enterTitle);
      return;
    }
    d
      ..title = _title.text.trim()
      ..category = _category.text.trim()
      ..note = _note.text.trim();
    final newlyDone = d.done && !(widget.item?.done ?? false);
    await AppStore.instance.upsertBucket(d);
    dirty = false;
    if (!mounted) return;
    if (newlyDone && await askBucketDiary(context, d) && mounted) {
      // 수정 화면 대신 일기 쓰기 화면으로 바로 이동
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => DiaryEditor(draft: bucketDiaryDraft(d))));
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, tr.deleteConfirmTitle, tr.deleteItemBody(d.title), tr.delete)) return;
    await AppStore.instance.removeBucket(d.id);
    dirty = false;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return guard(Scaffold(
      appBar: AppBar(
        title: Text(isNew ? tr.bucketNew : tr.bucketEdit),
        actions: [
          if (!isNew) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: Text(tr.save)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _title,
          autofocus: isNew,
          decoration: deco(tr.bucketWhat, hint: tr.bucketWhatHint),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _category,
          decoration: deco(tr.optional(tr.category), hint: tr.bucketCategoryHint),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 8,
          decoration: deco(tr.optional(tr.memo), hint: tr.bucketMemoHint),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr.bucketDoneSwitch),
          value: d.done,
          onChanged: (v) {
            setState(() {
              d.done = v;
              d.doneAt = v ? (d.doneAt ?? DateTime.now()) : null;
            });
            markDirty();
          },
        ),
        if (d.done)
          DateTile(
            label: tr.bucketDoneDate,
            value: d.doneAt,
            onPick: (v) {
              setState(() => d.doneAt = v);
              markDirty();
            },
          ),
        const SizedBox(height: 12),
        PhotoEditor(photos: d.photos, label: tr.bucketPhotos, onChanged: markDirty),
      ]),
    ));
  }
}

/// 버킷 달성 시 일기로 남길지 물어봄
Future<bool> askBucketDiary(BuildContext context, BucketItem b) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final t = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(tr.bucketCongrats(b.title),
                textAlign: TextAlign.center,
                style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              b.photos.isEmpty ? tr.bucketAskDiary : tr.bucketAskDiaryPhotos,
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr.writeDiary)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr.later)),
          ]),
        ),
      );
    },
  );
  return r ?? false;
}

DiaryEntry bucketDiaryDraft(BucketItem b) => DiaryEntry(
      date: b.doneAt ?? DateTime.now(),
      title: tr.bucketDiaryTitle(b.title),
      mood: '😆',
      photos: List.of(b.photos),
    );
