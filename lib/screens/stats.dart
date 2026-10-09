import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';
import 'year_review.dart';
import '../i18n.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _moodRecent = true; // 최근 30일 / 전체

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr.stats),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.card_giftcard_outlined),
            label: Text(tr.yearReview),
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const YearReviewScreen())),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final today = DateUtils.dateOnly(DateTime.now());
          final diaryDays = <DateTime, int>{};
          for (final e in store.diaries) {
            final d = DateUtils.dateOnly(e.date);
            diaryDays[d] = (diaryDays[d] ?? 0) + 1;
          }
          final thisMonth = store.diaries
              .where((e) => e.date.year == today.year && e.date.month == today.month)
              .length;

          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            SectionTitle(tr.diary),
            Row(children: [
              _Tile(tr.streak, tr.countDays(diaryStreak(diaryDays.keys.toSet(), today))),
              const SizedBox(width: 8),
              _Tile(tr.thisMonth, tr.countEntries(thisMonth)),
              const SizedBox(width: 8),
              _Tile(tr.all, tr.countEntries(store.diaries.length)),
            ]),
            const SizedBox(height: 12),
            _Card(
              title: tr.last15Weeks,
              child: _Heatmap(days: diaryDays, today: today),
            ),
            const SizedBox(height: 12),
            _Card(
              title: tr.mood,
              trailing: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: true, label: Text(tr.days30)),
                  ButtonSegment(value: false, label: Text(tr.all)),
                ],
                selected: {_moodRecent},
                onSelectionChanged: (s) => setState(() => _moodRecent = s.first),
              ),
              child: _MoodBars(
                entries: _moodRecent
                    ? store.diaries
                        .where((e) => today.difference(DateUtils.dateOnly(e.date)).inDays < 30)
                        .toList()
                    : store.diaries,
              ),
            ),
            SectionTitle(tr.goalsAndBuckets),
            _GoalStats(goals: store.goals),
            const SizedBox(height: 12),
            _BucketStats(items: store.buckets, year: today.year),
            SectionTitle(tr.tabCareer),
            _CareerStats(items: store.careers),
          ]);
        },
      ),
    );
  }

}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  const _Tile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: t.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const _Card({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: t.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

/// 일기 잔디: 한 칸 = 하루, 진할수록 많이 씀 (한 가지 색의 진하기만 사용)
class _Heatmap extends StatelessWidget {
  final Map<DateTime, int> days;
  final DateTime today;
  const _Heatmap({required this.days, required this.today});

  static const _weeks = 15;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    // 이번 주 월요일 기준으로 15주 전 월요일부터
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final start = DateUtils.dateOnly(thisMonday.subtract(const Duration(days: 7 * (_weeks - 1))));

    Color cellColor(int n) => switch (n) {
          0 => c.surfaceContainerHighest,
          1 => c.primary.withValues(alpha: 0.35),
          2 => c.primary.withValues(alpha: 0.65),
          _ => c.primary,
        };

    return LayoutBuilder(builder: (context, box) {
      const gap = 3.0;
      const labelW = 16.0;
      final cell = ((box.maxWidth - labelW - gap * _weeks) / _weeks).clamp(8.0, 22.0);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var row = 0; row < 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: Row(children: [
              SizedBox(
                width: labelW,
                child: Text(row % 2 == 0 ? weekday(start.add(Duration(days: row))) : '',
                    style: TextStyle(fontSize: 9, color: c.onSurfaceVariant)),
              ),
              for (var w = 0; w < _weeks; w++)
                Builder(builder: (context) {
                  final d = DateUtils.dateOnly(start.add(Duration(days: w * 7 + row)));
                  final future = d.isAfter(today);
                  final n = days[d] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(left: gap),
                    child: GestureDetector(
                      onTap: future ? null : () => toast(context, tr.heatTap(fmtDateW(d), n)),
                      child: Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: future ? Colors.transparent : cellColor(n),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                }),
            ]),
          ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('${tr.less} ', style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
          for (final n in [0, 1, 2, 3])
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(color: cellColor(n), borderRadius: BorderRadius.circular(2)),
            ),
          Text(' ${tr.more}', style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
        ]),
      ]);
    });
  }
}

/// 가로 막대 (값은 막대 옆에 글자로 표시)
class _Bar extends StatelessWidget {
  final Widget label;
  final int value;
  final int max;
  final String? valueText;
  const _Bar({required this.label, required this.value, required this.max, this.valueText});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final frac = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 72, child: label),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: value == 0 ? 0 : (box.maxWidth * frac).clamp(4.0, box.maxWidth),
                height: 12,
                decoration: BoxDecoration(
                  color: t.colorScheme.primary,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(valueText ?? '$value',
              textAlign: TextAlign.right, style: t.textTheme.bodySmall),
        ),
      ]),
    );
  }
}

class _MoodBars extends StatelessWidget {
  final List<DiaryEntry> entries;
  const _MoodBars({required this.entries});

  @override
  Widget build(BuildContext context) {
    final counts = {for (final m in moods) m: 0};
    for (final e in entries) {
      if (counts.containsKey(e.mood)) counts[e.mood] = counts[e.mood]! + 1;
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return Text(tr.noMoodYet);
    final max = counts.values.reduce((a, b) => a > b ? a : b);
    return Column(children: [
      for (final m in moods)
        _Bar(
          label: Text(m, style: const TextStyle(fontSize: 20)),
          value: counts[m]!,
          max: max,
          valueText: '${counts[m]}',
        ),
    ]);
  }
}

class _GoalStats extends StatelessWidget {
  final List<Goal> goals;
  const _GoalStats({required this.goals});

  @override
  Widget build(BuildContext context) {
    final done = goals.where((g) => g.isComplete).length;
    final active = goals.where((g) => !g.isComplete).toList();
    final avg = active.isEmpty ? 0.0 : active.map((g) => g.progress).reduce((a, b) => a + b) / active.length;
    return _Card(
      title: tr.goals,
      child: goals.isEmpty
          ? Text(tr.noGoalsYet)
          : Column(children: [
              Row(children: [
                _Tile(tr.done, tr.countItems(done)),
                const SizedBox(width: 8),
                _Tile(tr.inProgress, tr.countItems(active.length)),
                const SizedBox(width: 8),
                _Tile(tr.avgProgress, '${(avg * 100).round()}%'),
              ]),
              const SizedBox(height: 12),
              for (final p in goalPeriods)
                if (goals.any((g) => g.period == p))
                  _Bar(
                    label: Text(goalPeriodLabel(p)),
                    value: goals.where((g) => g.period == p && g.isComplete).length,
                    max: goals.where((g) => g.period == p).length,
                    valueText:
                        '${goals.where((g) => g.period == p && g.isComplete).length}/${goals.where((g) => g.period == p).length}',
                  ),
            ]),
    );
  }
}

class _BucketStats extends StatelessWidget {
  final List<BucketItem> items;
  final int year;
  const _BucketStats({required this.items, required this.year});

  @override
  Widget build(BuildContext context) {
    final done = items.where((b) => b.done).toList();
    final thisYear = done.where((b) => b.doneAt?.year == year).length;
    return _Card(
      title: tr.bucketList,
      child: items.isEmpty
          ? Text(tr.noBucketsYet)
          : Column(children: [
              Row(children: [
                _Tile(tr.achieveRate, '${(done.length * 100 / items.length).round()}%'),
                const SizedBox(width: 8),
                _Tile(tr.achievedInYear(year), tr.countItems(thisYear)),
                const SizedBox(width: 8),
                _Tile(tr.remaining, tr.countItems(items.length - done.length)),
              ]),
            ]),
    );
  }
}

class _CareerStats extends StatelessWidget {
  final List<CareerItem> items;
  const _CareerStats({required this.items});

  @override
  Widget build(BuildContext context) {
    final skillCount = <String, int>{};
    for (final c in items) {
      for (final s in c.skills) {
        skillCount[s] = (skillCount[s] ?? 0) + 1;
      }
    }
    final top = skillCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(8).toList();
    return _Card(
      title: tr.topSkills,
      child: shown.isEmpty
          ? Text(tr.noSkillsYet)
          : Column(children: [
              for (final e in shown)
                _Bar(
                  label: Text(e.key, overflow: TextOverflow.ellipsis),
                  value: e.value,
                  max: shown.first.value,
                ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final t in careerTypes)
                  if (items.any((c) => c.type == t))
                    Chip(label: Text('${careerTypeLabel(t)} ${items.where((c) => c.type == t).length}')),
              ]),
            ]),
    );
  }
}
