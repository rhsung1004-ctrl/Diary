import 'package:flutter/material.dart';

import '../common.dart';
import '../store.dart';
import 'bucket.dart';
import 'career.dart';
import 'diary.dart';
import 'goals.dart';
import '../i18n.dart';

/// 일기·버킷·목표·커리어 통합 검색
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool _has(String text) => text.toLowerCase().contains(_q);

  /// 검색어 주변만 잘라서 보여주기
  String _snippet(String text) {
    final flat = text.replaceAll('\n', ' ');
    final i = flat.toLowerCase().indexOf(_q);
    if (i < 0) return flat.length > 80 ? '${flat.substring(0, 80)}…' : flat;
    final start = (i - 20).clamp(0, flat.length);
    final end = (i + _q.length + 50).clamp(0, flat.length);
    return '${start > 0 ? '…' : ''}${flat.substring(start, end)}${end < flat.length ? '…' : ''}';
  }

  List<Widget> _results(BuildContext context) {
    final store = AppStore.instance;
    final results = <Widget>[];

    if (_q.isNotEmpty) {
      final diaries = store.diaries
          .where((e) => _has(e.title) || _has(e.body) || e.tags.any(_has))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final buckets = store.buckets
          .where((b) => _has(b.title) || _has(b.note) || _has(b.category))
          .toList();
      final goals = store.goals
          .where((g) => _has(g.title) || _has(g.note) || g.tasks.any((t) => _has(t.text)))
          .toList();
      final careers = store.careers
          .where((c) =>
              _has(c.title) || _has(c.org) || _has(c.description) || c.skills.any(_has))
          .toList();

      if (diaries.isNotEmpty) {
        results.add(SectionTitle(tr.searchSection(tr.diary, diaries.length)));
        for (final e in diaries) {
          results.add(Card(
            child: ListTile(
              leading: Text(e.mood.isEmpty ? '📔' : e.mood, style: const TextStyle(fontSize: 22)),
              title: Text(e.title.isNotEmpty ? e.title : fmtDateW(e.date),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${e.title.isNotEmpty ? '${fmtDate(e.date)} · ' : ''}${_snippet(e.body)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => DiaryView(id: e.id))),
            ),
          ));
        }
      }
      if (buckets.isNotEmpty) {
        results.add(SectionTitle(tr.searchSection(tr.bucketList, buckets.length)));
        results.addAll(buckets.map((b) => BucketTile(item: b)));
      }
      if (goals.isNotEmpty) {
        results.add(SectionTitle(tr.searchSection(tr.goals, goals.length)));
        results.addAll(goals.map((g) => GoalCard(goal: g)));
      }
      if (careers.isNotEmpty) {
        results.add(SectionTitle(tr.searchSection(tr.tabCareer, careers.length)));
        results.addAll(careers.map((c) => CareerCard(item: c)));
      }
      if (results.isEmpty) {
        results.add(EmptyState(icon: Icons.search_off, text: tr.searchNoResult(_q)));
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: tr.searchHint,
            border: InputBorder.none,
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _ctl.clear();
                      setState(() => _q = '');
                    },
                  ),
          ),
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase().replaceFirst('#', '')),
        ),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => _q.isEmpty
            ? EmptyState(icon: Icons.search, text: tr.searchEmpty)
            : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: _results(context)),
      ),
    );
  }
}
