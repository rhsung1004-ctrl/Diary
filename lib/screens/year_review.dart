import 'dart:io';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../common.dart';
import '../lock.dart';
import '../store.dart';

/// 한 해 통계 요약
class _YearData {
  final int year;
  final int diaries;
  final int daysWritten;
  final int longestStreak;
  final String? topMood;
  final int topMoodCount;
  final List<String> bucketsDone;
  final int goalsSet;
  final int goalsDone;
  final int careers;
  final List<String> topSkills;

  _YearData._(this.year, this.diaries, this.daysWritten, this.longestStreak, this.topMood,
      this.topMoodCount, this.bucketsDone, this.goalsSet, this.goalsDone, this.careers, this.topSkills);

  factory _YearData.of(AppStore s, int year) {
    final ds = s.diaries.where((e) => e.date.year == year).toList();
    final days = ds.map((e) => DateUtils.dateOnly(e.date)).toSet().toList()..sort();
    var longest = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > longest) longest = run;
      prev = d;
    }
    final moodCount = <String, int>{};
    for (final e in ds) {
      if (e.mood.isNotEmpty) moodCount[e.mood] = (moodCount[e.mood] ?? 0) + 1;
    }
    String? topMood;
    var topMoodCount = 0;
    moodCount.forEach((m, c) {
      if (c > topMoodCount) {
        topMood = m;
        topMoodCount = c;
      }
    });
    final buckets = s.buckets.where((b) => b.done && b.doneAt?.year == year).toList()
      ..sort((a, b) => a.doneAt!.compareTo(b.doneAt!));
    final goals = s.goals.where((g) => g.createdAt.year == year).toList();
    final careers = s.careers.where((c) => (c.startDate ?? c.createdAt).year == year).toList();
    final skillCount = <String, int>{};
    for (final c in careers) {
      for (final k in c.skills) {
        skillCount[k] = (skillCount[k] ?? 0) + 1;
      }
    }
    final skills = skillCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _YearData._(
      year,
      ds.length,
      days.length,
      longest,
      topMood,
      topMoodCount,
      buckets.map((b) => b.title).toList(),
      goals.length,
      goals.where((g) => g.isComplete).length,
      careers.length,
      skills.take(3).map((e) => e.key).toList(),
    );
  }
}

class YearReviewScreen extends StatefulWidget {
  final int? initialYear;
  const YearReviewScreen({super.key, this.initialYear});

  @override
  State<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends State<YearReviewScreen> {
  final _cardKey = GlobalKey();
  late int _year = widget.initialYear ?? DateTime.now().year;
  bool _sharing = false;

  List<int> get _years {
    final s = AppStore.instance;
    final ys = <int>{
      DateTime.now().year,
      ...s.diaries.map((e) => e.date.year),
      ...s.buckets.where((b) => b.doneAt != null).map((b) => b.doneAt!.year),
      ...s.goals.map((g) => g.createdAt.year),
    };
    return ys.toList()..sort((a, b) => b.compareTo(a));
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lifebox_$_year.png');
      await file.writeAsBytes(png!.buffer.asUint8List());
      await AppLock.instance.runExternal(() => SharePlus.instance.share(ShareParams(
            files: [XFile(file.path, mimeType: 'image/png')],
            text: '나의 $_year년 #LifeBox',
          )));
    } catch (e) {
      if (mounted) toast(context, '이미지를 만들지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _YearData.of(AppStore.instance, _year);
    return Scaffold(
      appBar: AppBar(title: const Text('연말 결산')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final y in _years)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$y년'),
                  selected: y == _year,
                  onSelected: (_) => setState(() => _year = y),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        RepaintBoundary(key: _cardKey, child: _ReviewCard(data: data)),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: _sharing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.ios_share),
          label: const Text('이미지로 공유'),
          onPressed: _sharing ? null : _share,
        ),
      ]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _YearData data;
  const _ReviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: LayoutBuilder(builder: (context, box) {
        final k = box.maxWidth / 360; // 화면 크기와 상관없이 같은 비율로
        TextStyle st(double size, {FontWeight? w, double opacity = 1}) => TextStyle(
              fontSize: size * k,
              fontWeight: w,
              color: Colors.white.withValues(alpha: opacity),
              height: 1.3,
            );
        Widget stat(String emoji, String big, String small) => Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(emoji, style: TextStyle(fontSize: 22 * k)),
                SizedBox(height: 4 * k),
                Text(big, style: st(22, w: FontWeight.bold)),
                Text(small, style: st(11, opacity: 0.8)),
              ]),
            );

        return Container(
          padding: EdgeInsets.all(24 * k),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24 * k),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.primary, Color.lerp(c.primary, c.tertiary, 0.7)!],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LifeBox', style: st(12, w: FontWeight.bold, opacity: 0.8)),
            SizedBox(height: 4 * k),
            Text('나의 ${data.year}년', style: st(30, w: FontWeight.bold)),
            SizedBox(height: 20 * k),
            Row(children: [
              stat('📔', '${data.diaries}편', '일기 · ${data.daysWritten}일 기록'),
              stat('🔥', '${data.longestStreak}일', '최장 연속 기록'),
              stat(data.topMood ?? '🙂', data.topMood == null ? '-' : '${data.topMoodCount}번', '가장 많이 느낀 기분'),
            ]),
            SizedBox(height: 20 * k),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.3)),
            SizedBox(height: 16 * k),
            Text('🏆 버킷리스트 ${data.bucketsDone.length}개 달성', style: st(15, w: FontWeight.bold)),
            SizedBox(height: 6 * k),
            if (data.bucketsDone.isEmpty)
              Text('내년엔 하나씩 이뤄봐요', style: st(12, opacity: 0.8))
            else
              for (final b in data.bucketsDone.take(3))
                Padding(
                  padding: EdgeInsets.only(bottom: 2 * k),
                  child: Text('· $b', maxLines: 1, overflow: TextOverflow.ellipsis, style: st(12, opacity: 0.9)),
                ),
            if (data.bucketsDone.length > 3)
              Text('외 ${data.bucketsDone.length - 3}개', style: st(11, opacity: 0.7)),
            SizedBox(height: 14 * k),
            Text(
              data.goalsSet == 0 ? '🎯 세운 목표 없음' : '🎯 목표 ${data.goalsSet}개 중 ${data.goalsDone}개 완료',
              style: st(15, w: FontWeight.bold),
            ),
            SizedBox(height: 14 * k),
            Text('💼 새 커리어 기록 ${data.careers}개', style: st(15, w: FontWeight.bold)),
            if (data.topSkills.isNotEmpty) ...[
              SizedBox(height: 4 * k),
              Text(data.topSkills.join(' · '), style: st(12, opacity: 0.85)),
            ],
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(_closing(data), style: st(12, w: FontWeight.w600, opacity: 0.9)),
            ),
          ]),
        );
      }),
    );
  }

  String _closing(_YearData d) {
    if (d.diaries >= 200) return '매일을 기록한 한 해, 정말 대단해요 ✨';
    if (d.bucketsDone.length >= 3) return '꿈을 하나씩 현실로 만든 한 해 🌱';
    if (d.diaries > 0) return '기록한 만큼 단단해진 한 해 💪';
    return '새로운 기록을 시작해 봐요 ✍️';
  }
}
