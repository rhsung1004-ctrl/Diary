import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  final store = AppStore.instance;
  int _filter = 0; // 0 진행 중, 1 완료

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('목표')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_goal',
        onPressed: () => openGoalEditor(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final active = store.goals.where((g) => !g.isComplete).toList();
          final complete = store.goals.where((g) => g.isComplete).toList();

          final children = <Widget>[
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text('진행 중 ${active.length}')),
                ButtonSegment(value: 1, label: Text('완료 ${complete.length}')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ];

          if (_filter == 0) {
            if (active.isEmpty) {
              children.add(const EmptyState(
                  icon: Icons.track_changes, text: '올해, 이번 달, 이번 주의\n목표를 세워 보세요'));
            }
            for (final p in goalPeriods) {
              final list = active.where((g) => g.period == p).toList()
                ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
              if (list.isEmpty) continue;
              children.add(SectionTitle(p));
              children.addAll(list.map((g) => GoalCard(goal: g)));
            }
          } else {
            if (complete.isEmpty) {
              children.add(const EmptyState(icon: Icons.emoji_events_outlined, text: '아직 완료한 목표가 없어요'));
            }
            children.addAll(complete.map((g) => GoalCard(goal: g)));
          }

          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: children);
        },
      ),
    );
  }
}

class GoalCard extends StatelessWidget {
  final Goal goal;
  const GoalCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final t = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openGoalEditor(context, g),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (g.isComplete) ...[
                Icon(Icons.check_circle, color: t.colorScheme.primary, size: 20),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(g.title,
                    style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (g.dueDate != null && !g.isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(dday(g.dueDate!),
                      style: t.textTheme.labelMedium
                          ?.copyWith(color: t.colorScheme.onSecondaryContainer)),
                ),
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: g.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              g.tasks.isEmpty
                  ? (g.isComplete ? '달성 완료' : '할 일을 추가해 보세요')
                  : '할 일 ${g.doneTasks}/${g.tasks.length} · ${(g.progress * 100).round()}%',
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ]),
        ),
      ),
    );
  }
}

void openGoalEditor(BuildContext context, Goal? goal) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => GoalEditor(goal: goal)));
}

class GoalEditor extends StatefulWidget {
  final Goal? goal;
  const GoalEditor({super.key, this.goal});

  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> with DirtyGuard<GoalEditor> {
  late final Goal d = widget.goal?.copy() ?? Goal();
  late final _title = TextEditingController(text: d.title);
  late final _note = TextEditingController(text: d.note);
  final _task = TextEditingController();
  bool get isNew => widget.goal == null;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _task.dispose();
    super.dispose();
  }

  void _addTask() {
    final text = _task.text.trim();
    if (text.isEmpty) return;
    setState(() => d.tasks.add(GoalTask(text: text)));
    _task.clear();
    markDirty();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, '목표를 입력해 주세요');
      return;
    }
    _addTask(); // 입력창에 남은 할 일도 같이 저장
    d
      ..title = _title.text.trim()
      ..note = _note.text.trim();
    await AppStore.instance.upsertGoal(d);
    dirty = false;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, '삭제할까요?', '"${d.title}" 목표를 삭제해요.', '삭제')) return;
    await AppStore.instance.removeGoal(d.id);
    dirty = false;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return guard(Scaffold(
      appBar: AppBar(
        title: Text(isNew ? '새 목표' : '목표'),
        actions: [
          if (!isNew) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _title,
          autofocus: isNew,
          decoration: deco('목표', hint: '예) JLPT N1 합격'),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 16),
        Text('기간', style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final p in goalPeriods)
            ChoiceChip(
              label: Text(p),
              selected: d.period == p,
              onSelected: (_) {
                setState(() => d.period = p);
                markDirty();
              },
            ),
        ]),
        DateTile(
          label: '마감일 (선택)',
          value: d.dueDate,
          onPick: (v) {
            setState(() => d.dueDate = v);
            markDirty();
          },
          onClear: () {
            setState(() => d.dueDate = null);
            markDirty();
          },
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('할 일', style: t.textTheme.titleSmall),
          const Spacer(),
          if (d.tasks.isNotEmpty)
            Text('${d.doneTasks}/${d.tasks.length}', style: t.textTheme.bodySmall),
        ]),
        const SizedBox(height: 4),
        for (var i = 0; i < d.tasks.length; i++)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: d.tasks[i].done,
            title: Text(
              d.tasks[i].text,
              style: d.tasks[i].done
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            secondary: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                setState(() => d.tasks.removeAt(i));
                markDirty();
              },
            ),
            onChanged: (v) {
              setState(() => d.tasks[i].done = v ?? false);
              markDirty();
            },
          ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _task,
              decoration: const InputDecoration(hintText: '할 일 추가', isDense: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addTask(),
            ),
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: _addTask),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 8,
          decoration: deco('메모 (선택)', hint: '왜 이루고 싶은지, 회고…'),
          onChanged: (_) => markDirty(),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('목표 달성으로 표시'),
          subtitle: const Text('할 일과 상관없이 완료로 옮겨요'),
          value: d.done,
          onChanged: (v) {
            setState(() => d.done = v);
            markDirty();
          },
        ),
      ]),
    ));
  }
}
