import 'package:flutter/material.dart';

import '../common.dart';
import '../store.dart';
import 'diary.dart';
import 'goals.dart';
import 'settings.dart';
import 'search.dart';
import 'stats.dart';
import 'timeline.dart';
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
          final activeGoals = store.goals.where((g) => !g.isComplete).toList()
            ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
          final todayDiaries = store.diaries.where((e) => sameDay(e.date, now)).toList();
          final pastToday = store.diaries
              .where((e) => e.date.month == now.month && e.date.day == now.day && e.date.year < now.year)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          // 12월·1월엔 결산 카드를 강조
          final reviewYear = now.month == 12 ? now.year : (now.month == 1 ? now.year - 1 : null);

          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            Text(fmtDateW(now),
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(tr.homeGreeting,
                style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),

            // 1. 오늘의 일기
            SectionTitle(tr.todaysDiary),
            if (todayDiaries.isEmpty)
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: t.colorScheme.primaryContainer,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => openDiaryEditor(context, null),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      Icon(Icons.edit_outlined, color: t.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(tr.notWrittenToday,
                            style: t.textTheme.titleMedium
                                ?.copyWith(color: t.colorScheme.onPrimaryContainer)),
                      ),
                      Icon(Icons.chevron_right, color: t.colorScheme.onPrimaryContainer),
                    ]),
                  ),
                ),
              )
            else
              ...todayDiaries.map((e) => DiaryCard(entry: e)),

            // 2. 진행 중인 목표
            SectionTitle(tr.goalsInProgress, onMore: activeGoals.isEmpty ? null : () => onNavigate(2)),
            if (activeGoals.isEmpty)
              _Hint(tr.goalsHomeHint, () => openGoalEditor(context, null))
            else
              ...activeGoals.take(3).map((g) => GoalCard(goal: g)),

            // 3. 지난 오늘 (있을 때만)
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

            // 4. 돌아보기 (타임라인 · 통계 · 연말 결산을 한곳에)
            SectionTitle(tr.reflect),
            Row(children: [
              _ReflectTile('📜', tr.timeline,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimelineScreen()))),
              const SizedBox(width: 8),
              _ReflectTile('📊', tr.stats,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
              const SizedBox(width: 8),
              _ReflectTile(
                '🎁',
                tr.yearReview,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => YearReviewScreen(initialYear: reviewYear))),
                highlight: reviewYear != null,
              ),
            ]),
          ]);
        },
      ),
    );
  }
}

class _ReflectTile extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  const _ReflectTile(this.emoji, this.label, this.onTap, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: highlight ? t.colorScheme.tertiaryContainer : t.colorScheme.surfaceContainerHigh,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.labelLarge),
            ]),
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
