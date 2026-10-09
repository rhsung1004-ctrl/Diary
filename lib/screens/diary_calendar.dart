import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';
import 'diary.dart';

/// 월 달력: 날짜마다 그날 기분(없으면 점) 표시, 누르면 그날 일기
class DiaryCalendar extends StatefulWidget {
  const DiaryCalendar({super.key});

  @override
  State<DiaryCalendar> createState() => _DiaryCalendarState();
}

class _DiaryCalendarState extends State<DiaryCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _move(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _openDay(DateTime day, List<DiaryEntry> entries) {
    if (entries.isEmpty) {
      openDiaryEditor(context, null, date: day);
    } else if (entries.length == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DiaryView(id: entries.first.id)));
    } else {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            Text(fmtDateW(day), style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in entries)
              DiaryCard(entry: e),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('이 날 일기 더 쓰기'),
              onPressed: () {
                Navigator.pop(ctx);
                openDiaryEditor(context, null, date: day);
              },
            ),
          ]),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final t = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final byDay = <DateTime, List<DiaryEntry>>{};
        for (final e in store.diaries) {
          if (e.date.year == _month.year && e.date.month == _month.month) {
            byDay.putIfAbsent(DateUtils.dateOnly(e.date), () => []).add(e);
          }
        }
        final today = DateUtils.dateOnly(DateTime.now());
        final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
        final lead = _month.weekday - 1; // 월요일 시작
        final cells = lead + daysInMonth;
        final rows = (cells / 7).ceil();

        return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 96), children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _move(-1)),
            Expanded(
              child: Text('${_month.year}년 ${_month.month}월',
                  textAlign: TextAlign.center,
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _move(1)),
          ]),
          Row(children: [
            for (final w in ['월', '화', '수', '목', '금', '토', '일'])
              Expanded(
                child: Center(
                  child: Text(w,
                      style: t.textTheme.labelMedium?.copyWith(
                          color: w == '일'
                              ? t.colorScheme.error
                              : t.colorScheme.onSurfaceVariant)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Row(children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(context, r * 7 + c - lead + 1, daysInMonth, byDay, today)),
            ]),
          const SizedBox(height: 12),
          Text('이번 달 ${byDay.values.fold(0, (a, b) => a + b.length)}편 · 날짜를 누르면 일기를 보거나 쓸 수 있어요',
              textAlign: TextAlign.center,
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ]);
      },
    );
  }

  Widget _cell(BuildContext context, int dayNum, int daysInMonth,
      Map<DateTime, List<DiaryEntry>> byDay, DateTime today) {
    if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox(height: 64);
    final t = Theme.of(context);
    final day = DateTime(_month.year, _month.month, dayNum);
    final entries = byDay[day] ?? const <DiaryEntry>[];
    final isToday = day == today;
    final future = day.isAfter(today);
    String? mood;
    for (final e in entries) {
      if (e.mood.isNotEmpty) {
        mood = e.mood;
        break;
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: future ? null : () => _openDay(day, entries),
      child: Container(
        height: 64,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: entries.isNotEmpty ? t.colorScheme.primaryContainer.withValues(alpha: 0.6) : null,
          border: isToday ? Border.all(color: t.colorScheme.primary, width: 1.5) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$dayNum',
              style: t.textTheme.bodySmall?.copyWith(
                color: future ? t.colorScheme.outline : null,
                fontWeight: isToday ? FontWeight.bold : null,
              )),
          const SizedBox(height: 2),
          if (mood != null)
            Text(mood, style: const TextStyle(fontSize: 20))
          else if (entries.isNotEmpty)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: t.colorScheme.primary, shape: BoxShape.circle),
            )
          else
            const SizedBox(height: 6),
        ]),
      ),
    );
  }
}
