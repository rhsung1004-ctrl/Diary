import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'common.dart';
import 'prefs.dart';
import 'store.dart';

/// 안드로이드 홈 화면 위젯에 보여줄 값을 넘겨줌.
/// 날짜가 바뀐 경우(오늘 일기 여부, 연속 기록)는 위젯 쪽(Kotlin)에서 다시 판단함.
class HomeWidgetSync {
  static const _provider = 'io.github.rhsung1004.lifebox.LifeBoxWidgetProvider';
  static Timer? _debounce;

  static void start() {
    AppStore.instance.addListener(schedule);
    AppPrefs.instance.addListener(schedule);
    schedule();
  }

  static void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), update);
  }

  static Future<void> update() async {
    try {
      final store = AppStore.instance;
      final today = DateUtils.dateOnly(DateTime.now());
      final days = store.diaries.map((e) => DateUtils.dateOnly(e.date)).toSet();
      final goals = store.goals.where((g) => !g.isComplete).toList()
        ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));

      final data = <String, String>{
        'saved_day': '${today.year}-${two(today.month)}-${two(today.day)}',
        'diary_done': days.contains(today).toString(),
        'streak': diaryStreak(days, today).toString(),
        'hidden': AppPrefs.instance.lockEnabled.toString(), // 잠금 중엔 목표 제목 숨김
        'goal_count': goals.length.toString(),
      };
      for (var i = 0; i < 2; i++) {
        final g = i < goals.length ? goals[i] : null;
        data['goal${i + 1}_title'] = g?.title ?? '';
        data['goal${i + 1}_pct'] = g == null ? '0' : (g.progress * 100).round().toString();
      }
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e) {
      debugPrint('위젯 갱신 실패: $e');
    }
  }
}
