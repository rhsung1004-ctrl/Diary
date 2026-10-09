import 'package:flutter/material.dart';

import '../common.dart';
import '../store.dart';
import 'bucket.dart';
import 'diary.dart';
import 'goals.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('LifeBox')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          final bucketDone = store.buckets.where((b) => b.done).length;
          final activeGoals = store.goals.where((g) => !g.isComplete).toList()
            ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
          final todayDiaries = store.diaries.where((e) => sameDay(e.date, now)).toList();
          final recentDone = store.buckets.where((b) => b.done && b.doneAt != null).toList()
            ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));

          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            Text(fmtDateW(now),
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.9,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _StatCard(Icons.flag_outlined, '버킷리스트', '$bucketDone / ${store.buckets.length}',
                    () => onNavigate(1)),
                _StatCard(Icons.track_changes, '진행 중 목표', '${activeGoals.length}개',
                    () => onNavigate(2)),
                _StatCard(Icons.menu_book_outlined, '일기', '${store.diaries.length}편',
                    () => onNavigate(3)),
                _StatCard(Icons.work_outline, '커리어', '${store.careers.length}개',
                    () => onNavigate(4)),
              ],
            ),
            const SectionTitle('오늘의 일기'),
            if (todayDiaries.isEmpty)
              Card(
                elevation: 0,
                color: t.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('아직 오늘 일기를 안 썼어요'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openDiaryEditor(context, null),
                ),
              )
            else
              ...todayDiaries.map((e) => DiaryCard(entry: e)),
            SectionTitle('진행 중인 목표', onMore: activeGoals.isEmpty ? null : () => onNavigate(2)),
            if (activeGoals.isEmpty)
              _Hint('목표를 세우면 여기에서 진행률을 볼 수 있어요', () => openGoalEditor(context, null))
            else
              ...activeGoals.take(3).map((g) => GoalCard(goal: g)),
            if (recentDone.isNotEmpty) ...[
              SectionTitle('최근 달성한 버킷리스트', onMore: () => onNavigate(1)),
              ...recentDone.take(3).map((b) => BucketTile(item: b)),
            ],
          ]);
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _StatCard(this.icon, this.label, this.value, this.onTap);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 0,
      color: t.colorScheme.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: t.colorScheme.primary),
                const SizedBox(width: 6),
                Flexible(child: Text(label, style: t.textTheme.labelLarge, overflow: TextOverflow.ellipsis)),
              ]),
              Text(value, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Hint(this.text, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ListTile(
        title: Text(text),
        trailing: const Icon(Icons.add),
        onTap: onTap,
      ),
    );
  }
}
