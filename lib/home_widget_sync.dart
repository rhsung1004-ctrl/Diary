import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'common.dart';
import 'prefs.dart';
import 'store.dart';
import 'theme.dart';
import 'i18n.dart';

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
        'goal_count': goals.length.toString(),
        // 위젯 문구도 앱 언어로 ({n}은 위젯이 채움)
        'lang': appLang,
        't_done': tr.wDone,
        't_todo': tr.wTodo,
        't_streak': tr.wStreak('{n}'),
        't_write': tr.wWrite,
        't_no_goals': tr.wNoGoals,
        // 위젯 색은 앱 테마(테마 색 + 다크 모드 설정)를 따라감
        'mode': AppPrefs.instance.themeMode.name,
      };
      final seed = themeColors[AppPrefs.instance.colorIndex.clamp(0, themeColors.length - 1)].seed;
      for (final b in Brightness.values) {
        final cs = ColorScheme.fromSeed(seedColor: seed, brightness: b);
        final p = b == Brightness.dark ? 'd' : 'l';
        data['c_${p}_bg'] = cs.surfaceContainer.toARGB32().toString();
        data['c_${p}_text'] = cs.onSurface.toARGB32().toString();
        data['c_${p}_sub'] = cs.onSurfaceVariant.toARGB32().toString();
        data['c_${p}_accent'] = cs.primary.toARGB32().toString();
        data['c_${p}_track'] = cs.surfaceContainerHighest.toARGB32().toString();
      }
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
