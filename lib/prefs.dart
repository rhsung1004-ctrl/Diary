import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'store.dart';

/// 화면·잠금 설정 (앱 전용 폴더의 prefs.json)
class AppPrefs extends ChangeNotifier {
  AppPrefs._();
  static final AppPrefs instance = AppPrefs._();

  int colorIndex = 0;
  ThemeMode themeMode = ThemeMode.system;
  String font = 'pretendard';
  double textScale = 1.0;
  String language = 'system'; // system | ko | en | ja

  // 일기 알림
  bool reminderOn = false;
  int reminderHour = 21;
  int reminderMinute = 0;

  // 앱 잠금
  String? pinHash; // sha256(salt + pin)
  String? pinSalt;
  bool biometric = false;
  String? lockRecoveryEmail; // PIN 분실 시 확인할 구글 계정

  bool get lockEnabled => pinHash != null;

  File get _file => File('${AppStore.instance.dirPath}/prefs.json');

  Future<void> load() async {
    try {
      if (!await _file.exists()) return;
      final m = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      colorIndex = m['colorIndex'] as int? ?? 0;
      themeMode = ThemeMode.values.firstWhere((e) => e.name == m['themeMode'],
          orElse: () => ThemeMode.system);
      font = m['font'] as String? ?? 'pretendard';
      textScale = (m['textScale'] as num?)?.toDouble() ?? 1.0;
      language = m['language'] as String? ?? 'system';
      pinHash = m['pinHash'] as String?;
      pinSalt = m['pinSalt'] as String?;
      biometric = m['biometric'] as bool? ?? false;
      lockRecoveryEmail = m['lockRecoveryEmail'] as String?;
      reminderOn = m['reminderOn'] as bool? ?? false;
      reminderHour = m['reminderHour'] as int? ?? 21;
      reminderMinute = m['reminderMinute'] as int? ?? 0;
    } catch (e) {
      debugPrint('설정 읽기 실패: $e');
    }
  }

  Future<void> save() async {
    notifyListeners();
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'colorIndex': colorIndex,
      'themeMode': themeMode.name,
      'font': font,
      'textScale': textScale,
      'language': language,
      'pinHash': pinHash,
      'pinSalt': pinSalt,
      'biometric': biometric,
      'lockRecoveryEmail': lockRecoveryEmail,
      'reminderOn': reminderOn,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
    }));
    await tmp.rename(_file.path);
  }

  /// 기기 언어가 바뀌었을 때 화면 다시 그리기
  void refresh() => notifyListeners();

  Future<void> update(void Function(AppPrefs p) change) async {
    change(this);
    await save();
  }
}
