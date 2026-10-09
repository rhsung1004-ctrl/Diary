import 'package:flutter/widgets.dart';

import 'l10n/app_localizations.dart';
import 'prefs.dart';

export 'l10n/app_localizations.dart';

const supportedLangs = ['ko', 'en', 'ja'];

/// 지금 앱이 쓰는 언어 코드 (설정 → 기기 언어 → 없으면 영어)
String get appLang {
  final p = AppPrefs.instance.language;
  if (supportedLangs.contains(p)) return p;
  final sys = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return supportedLangs.contains(sys) ? sys : 'en';
}

/// 어디서든 쓸 수 있는 번역 문구
AppLocalizations get tr => lookupAppLocalizations(Locale(appLang));

/// 저장 데이터에는 한국어 키를 그대로 두고, 화면에만 번역해서 보여줌
String goalPeriodLabel(String key) => switch (key) {
      '올해' => tr.periodYear,
      '이번 달' => tr.periodMonth,
      '이번 주' => tr.periodWeek,
      '장기' => tr.periodLong,
      _ => key,
    };

String careerTypeLabel(String key) => switch (key) {
      '프로젝트' => tr.typeProject,
      '경력' => tr.typeWork,
      '학력' => tr.typeEducation,
      '자격·수상' => tr.typeAward,
      '활동' => tr.typeActivity,
      _ => key,
    };
