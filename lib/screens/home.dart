import 'package:flutter/material.dart';

import '../common.dart';
import '../store.dart';
import 'bucket.dart';
import 'diary.dart';
import 'goals.dart';
import 'settings.dart';
import 'search.dart';
import 'stats.dart';
import 'year_review.dart';
import '../i18n.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: tr.search,
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: tr.stats,
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: tr.settings,
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          final bucketDone = store.buckets.where((b) => b.done).length;
          final activeGoals = store.goals.where((g) => !g.isComplete).toList()
            ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
          final todayDiaries = store.diaries.where((e) => sameDay(e.date, now)).toList();
          final pastToday = store.diaries
              .where((e) => e.date.month == now.month && e.date.day == now.day && e.date.year < now.year)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          // 12월·1월엔 결산 카드 안내
          final reviewYear = now.month == 12 ? now.year : (now.month == 1 ? now.year - 1 : null);
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
                _StatCard(Icons.flag_outlined, tr.bucketList, '$bucketDone / ${store.buckets.length}',
                    () => onNavigate(1)),
                _StatCard(Icons.track_changes, tr.activeGoals, tr.countItems(activeGoals.length),
                    () => onNavigate(2)),
                _StatCard(Icons.menu_book_outlined, tr.diary, tr.countEntries(store.diaries.length),
                    () => onNavigate(3)),
                _StatCard(Icons.work_outline, tr.tabCareer, tr.countItems(store.careers.length),
                    () => onNavigate(4)),
              ],
            ),
            SectionTitle(tr.todaysDiary),
            if (todayDiaries.isEmpty)
              Card(
                elevation: 0,
                color: t.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(tr.notWrittenToday),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openDiaryEditor(context, null),
                ),
              )
            else
              ...todayDiaries.map((e) => DiaryCard(entry: e)),
            if (pastToday.isNotEmpty) ...[
              SectionTitle(tr.pastToday),
              for (final e in pastToday) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(tr.yearsAgoToday(now.year - e.date.year),
                      style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.primary)),
                ),
                DiaryCard(entry: e),
              ],
            ],
            if (reviewYear != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: t.colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Text('🎁', style: TextStyle(fontSize: 28)),
                  title: Text(tr.yearReviewCard(reviewYear)),
                  subtitle: Text(tr.yearReviewCardSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => YearReviewScreen(initialYear: reviewYear))),
                ),
              ),
            ],
            SectionTitle(tr.goalsInProgress, onMore: activeGoals.isEmpty ? null : () => onNavigate(2)),
            if (activeGoals.isEmpty)
              _Hint(tr.goalsHomeHint, () => openGoalEditor(context, null))
            else
              ...activeGoals.take(3).map((g) => GoalCard(goal: g)),
            if (recentDone.isNotEmpty) ...[
              SectionTitle(tr.recentBuckets, onMore: () => onNavigate(1)),
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
