import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'prefs.dart';
import 'store.dart';
import 'i18n.dart';

/// 매일 일기 알림.
/// 오늘 일기를 이미 썼으면 첫 알림을 내일로 미뤄서, 쓴 날엔 울리지 않게 함.
class Reminder {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 1;
  static final _taps = StreamController<String?>.broadcast();
  static bool _ready = false;

  /// 알림을 눌러 앱이 열렸을 때의 payload
  static String? launchPayload;
  static Stream<String?> get taps => _taps.stream;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (r) => _taps.add(r.payload),
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        launchPayload = launch!.notificationResponse?.payload;
      }
      _ready = true;
      AppStore.instance.addListener(_onDataChanged);
      await reschedule();
    } catch (e) {
      debugPrint('알림 초기화 실패: $e');
    }
  }

  static bool _wroteToday = false;
  static void _onDataChanged() {
    final now = DateTime.now();
    final wrote = AppStore.instance.diaries.any((e) =>
        e.date.year == now.year && e.date.month == now.month && e.date.day == now.day);
    if (wrote != _wroteToday) reschedule();
  }

  static Future<bool> requestPermission() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  static Future<void> reschedule() async {
    if (!_ready) return;
    final prefs = AppPrefs.instance;
    await _plugin.cancel(id: _id);
    final now = DateTime.now();
    _wroteToday = AppStore.instance.diaries.any((e) =>
        e.date.year == now.year && e.date.month == now.month && e.date.day == now.day);
    if (!prefs.reminderOn) return;

    var at = DateTime(now.year, now.month, now.day, prefs.reminderHour, prefs.reminderMinute);
    if (!at.isAfter(now) || _wroteToday) at = at.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _id,
      title: tr.reminderTitle,
      body: tr.reminderBody,
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_diary',
          tr.reminderChannel,
          channelDescription: tr.reminderChannelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'diary',
    );
  }
}
