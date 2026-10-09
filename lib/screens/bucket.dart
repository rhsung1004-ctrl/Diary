import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../photos.dart';
import '../store.dart';

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
      appBar: AppBar(title: const Text('버킷리스트')),
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
                segments: const [
                  ButtonSegment(value: 0, label: Text('전체')),
                  ButtonSegment(value: 1, label: Text('도전 중')),
                  ButtonSegment(value: 2, label: Text('달성')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const EmptyState(icon: Icons.flag_outlined, text: '살면서 꼭 해보고 싶은 일을\n추가해 보세요'),
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
          Text('$total개 중 $done개 달성',
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
      if (b.done && b.doneAt != null) '${fmtDate(b.doneAt!)} 달성',
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: b.done,
          onChanged: (v) async {
            b.done = v ?? false;
            b.doneAt = b.done ? DateTime.now() : null;
            await AppStore.instance.save();
            if (b.done && context.mounted) {
              toast(context, '🎉 "${b.title}" 달성!',
                  action: SnackBarAction(
                      label: '사진 남기기', onPressed: () => openBucketEditor(context, b)));
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
      toast(context, '제목을 입력해 주세요');
      return;
    }
    d
      ..title = _title.text.trim()
      ..category = _category.text.trim()
      ..note = _note.text.trim();
    await AppStore.instance.upsertBucket(d);
    dirty = false;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, '삭제할까요?', '"${d.title}"을(를) 삭제해요.', '삭제')) return;
    await AppStore.instance.removeBucket(d.id);
    dirty = false;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return guard(Scaffold(
      appBar: AppBar(
        title: Text(isNew ? '새 버킷리스트' : '버킷리스트 수정'),
        actions: [
          if (!isNew) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _title,
          autofocus: isNew,
          decoration: deco('하고 싶은 일', hint: '예) 오로라 보러 가기'),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _category,
          decoration: deco('분류 (선택)', hint: '여행, 도전, 배움, 경험…'),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 8,
          decoration: deco('메모 (선택)', hint: '왜 하고 싶은지, 계획, 달성 소감…'),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('달성했어요'),
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
            label: '달성한 날',
            value: d.doneAt,
            onPick: (v) {
              setState(() => d.doneAt = v);
              markDirty();
            },
          ),
        const SizedBox(height: 12),
        PhotoEditor(photos: d.photos, label: '사진 (인증샷, 참고 이미지)', onChanged: markDirty),
      ]),
    ));
  }
}
