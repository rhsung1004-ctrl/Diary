import 'package:flutter/material.dart';

import '../common.dart';
import '../i18n.dart';
import '../photos.dart';
import '../store.dart';
import 'bucket.dart';
import 'career.dart';
import 'diary.dart';
import 'goals.dart';

enum _Kind { diary, bucket, goalStart, goalDone, career }

class _Event {
  final _Kind kind;
  final DateTime date;
  final String title;
  final String? sub;
  final String? photo;
  final VoidCallback Function(BuildContext) onTap;
  _Event(this.kind, this.date, this.title, this.onTap, {this.sub, this.photo});
}

/// 꿈(버킷) · 목표 · 일기 · 커리어를 하나의 연대기로
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  // 필터: null = 전체
  _Kind? _filter;
  final Set<int> _collapsed = {};

  List<_Event> _events() {
    final s = AppStore.instance;
    final ev = <_Event>[];
    for (final e in s.diaries) {
      final headline = e.title.isNotEmpty ? e.title : e.body.split('\n').first;
      ev.add(_Event(
        _Kind.diary,
        e.date,
        '${e.mood.isEmpty ? '' : '${e.mood} '}${headline.isEmpty ? tr.photoDiary : headline}',
        (c) => () => Navigator.push(c, MaterialPageRoute(builder: (_) => DiaryView(id: e.id))),
        sub: e.tags.isEmpty ? null : e.tags.map((t) => '#$t').join(' '),
        photo: e.photos.isEmpty ? null : e.photos.first,
      ));
    }
    for (final b in s.buckets) {
      if (!b.done || b.doneAt == null) continue;
      ev.add(_Event(_Kind.bucket, b.doneAt!, b.title, (c) => () => openBucketEditor(c, b),
          sub: tr.tlBucketDone, photo: b.photos.isEmpty ? null : b.photos.first));
    }
    for (final g in s.goals) {
      ev.add(_Event(_Kind.goalStart, g.createdAt, g.title, (c) => () => openGoalEditor(c, g),
          sub: '${tr.tlGoalStart} · ${goalPeriodLabel(g.period)}'));
      if (g.completedAt != null) {
        ev.add(_Event(_Kind.goalDone, g.completedAt!, g.title, (c) => () => openGoalEditor(c, g),
            sub: tr.tlGoalDone));
      }
    }
    for (final c in s.careers) {
      ev.add(_Event(
        _Kind.career,
        c.startDate ?? c.createdAt,
        c.title,
        (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CareerView(id: c.id))),
        sub: [tr.tlCareer(careerTypeLabel(c.type)), if (c.org.isNotEmpty) c.org].join(' · '),
        photo: c.photos.isEmpty ? null : c.photos.first,
      ));
    }
    ev.sort((a, b) => b.date.compareTo(a.date));
    return ev;
  }

  bool _match(_Event e) {
    if (_filter == null) return true;
    if (_filter == _Kind.goalStart) return e.kind == _Kind.goalStart || e.kind == _Kind.goalDone;
    return e.kind == _filter;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return Scaffold(
      appBar: AppBar(title: Text(tr.timeline)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final all = _events().where(_match).toList();
          final filters = <(_Kind?, String)>[
            (null, tr.all),
            (_Kind.diary, tr.diary),
            (_Kind.bucket, tr.bucketList),
            (_Kind.goalStart, tr.goals),
            (_Kind.career, tr.tabCareer),
          ];
          final children = <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) => setState(() => _filter = f.$1),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ];
          if (all.isEmpty) {
            children.add(EmptyState(icon: Icons.timeline, text: tr.tlEmpty));
          }
          // 연도별로 묶기 (헤더를 누르면 접기/펴기)
          int? year;
          for (final e in all) {
            if (e.date.year != year) {
              year = e.date.year;
              final y = year;
              final count = all.where((x) => x.date.year == y).length;
              children.add(_YearHeader(
                year: y,
                count: count,
                collapsed: _collapsed.contains(y),
                onTap: () => setState(() => _collapsed.contains(y) ? _collapsed.remove(y) : _collapsed.add(y)),
              ));
            }
            if (_collapsed.contains(e.date.year)) continue;
            children.add(_EventRow(event: e));
          }
          children.add(const SizedBox(height: 32));
          return ListView(children: children);
        },
      ),
    );
  }
}

class _YearHeader extends StatelessWidget {
  final int year;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;
  const _YearHeader({required this.year, required this.count, required this.collapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Text(tr.yearLabel(year), style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(tr.tlCount(count), style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Icon(collapsed ? Icons.expand_more : Icons.expand_less),
        ]),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final _Event event;
  const _EventRow({required this.event});

  (IconData, Color) _style(ColorScheme c) => switch (event.kind) {
        _Kind.diary => (Icons.menu_book_outlined, c.secondary),
        _Kind.bucket => (Icons.flag, c.tertiary),
        _Kind.goalStart => (Icons.track_changes, c.primary),
        _Kind.goalDone => (Icons.emoji_events, c.primary),
        _Kind.career => (Icons.work, c.tertiary),
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (icon, color) = _style(t.colorScheme);
    final highlight = event.kind != _Kind.diary; // 일기 외의 순간은 강조
    return InkWell(
      onTap: event.onTap(context),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 날짜
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 14, left: 12),
              child: Text(
                '${event.date.month}/${event.date.day}',
                style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          // 세로선 + 아이콘
          SizedBox(
            width: 36,
            child: Stack(alignment: Alignment.topCenter, children: [
              Positioned.fill(
                child: Center(child: Container(width: 2, color: t.colorScheme.outlineVariant)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: CircleAvatar(
                  radius: highlight ? 14 : 11,
                  backgroundColor: highlight ? color : t.colorScheme.surfaceContainerHighest,
                  child: Icon(icon, size: highlight ? 16 : 13, color: highlight ? t.colorScheme.surface : color),
                ),
              ),
            ]),
          ),
          // 내용
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (highlight ? t.textTheme.titleSmall : t.textTheme.bodyMedium)
                          ?.copyWith(fontWeight: highlight ? FontWeight.bold : null),
                    ),
                    if (event.sub != null)
                      Text(event.sub!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodySmall?.copyWith(
                              color: highlight ? color : t.colorScheme.onSurfaceVariant)),
                  ]),
                ),
                if (event.photo != null) ...[
                  const SizedBox(width: 8),
                  PhotoThumb(event.photo!, size: 44),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
