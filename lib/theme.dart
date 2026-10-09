import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'i18n.dart';

class ThemeColor {
  final String key;
  final Color seed;
  const ThemeColor(this.key, this.seed);

  String get name => switch (key) {
        'forest' => tr.colorForest,
        'ocean' => tr.colorOcean,
        'lavender' => tr.colorLavender,
        'coral' => tr.colorCoral,
        'blossom' => tr.colorBlossom,
        _ => tr.colorMono,
      };
}

const themeColors = [
  ThemeColor('forest', Color(0xFF3D7A6E)),
  ThemeColor('ocean', Color(0xFF2F6FB0)),
  ThemeColor('lavender', Color(0xFF7A5CC2)),
  ThemeColor('coral', Color(0xFFD9654B)),
  ThemeColor('blossom', Color(0xFFC2557E)),
  ThemeColor('mono', Color(0xFF5F6368)),
];

class FontOption {
  final String key;
  final Map<String, String> names; // 언어별 표시 이름 (없으면 en)
  final String? family; // null = 기기 기본 글꼴
  final double sizeFactor; // 글꼴마다 눈에 보이는 크기가 달라 보정
  const FontOption(this.key, this.names, this.family, {this.sizeFactor = 1.0});

  String get label => key == 'system' ? tr.fontSystem : (names[appLang] ?? names['en']!);
}

/// 모두 SIL Open Font License 1.1 — 상업적 이용 가능
const allFonts = [
  // 한국어
  FontOption('pretendard', {'ko': '프리텐다드', 'en': 'Pretendard', 'ja': 'Pretendard'}, 'Pretendard'),
  FontOption('gowunDodum', {'ko': '고운돋움', 'en': 'Gowun Dodum'}, 'GowunDodum'),
  FontOption('gowunBatang', {'ko': '고운바탕', 'en': 'Gowun Batang'}, 'GowunBatang'),
  FontOption('nanumPen', {'ko': '나눔손글씨 펜', 'en': 'Nanum Pen Script'}, 'NanumPenScript', sizeFactor: 1.3),
  // 영어
  FontOption('lora', {'en': 'Lora'}, 'Lora'),
  FontOption('caveat', {'en': 'Caveat'}, 'Caveat', sizeFactor: 1.25),
  // 일본어
  FontOption('zenMaru', {'ja': 'Zen丸ゴシック', 'en': 'Zen Maru Gothic'}, 'ZenMaruGothic'),
  FontOption('shippori', {'ja': 'しっぽり明朝', 'en': 'Shippori Mincho'}, 'ShipporiMincho'),
  FontOption('klee', {'ja': 'クレー', 'en': 'Klee One'}, 'KleeOne', sizeFactor: 1.05),
  FontOption('system', {'en': 'System'}, null),
];

/// 언어마다 고를 수 있는 글꼴 (첫 번째가 기본값)
const _fontsByLang = {
  'ko': ['pretendard', 'gowunDodum', 'gowunBatang', 'nanumPen', 'system'],
  'en': ['pretendard', 'lora', 'caveat', 'system'],
  'ja': ['system', 'zenMaru', 'shippori', 'klee'],
};

List<FontOption> fontsFor(String lang) =>
    [for (final k in _fontsByLang[lang] ?? _fontsByLang['en']!) allFonts.firstWhere((f) => f.key == k)];

/// 저장된 글꼴이 지금 언어에 없으면 그 언어의 기본 글꼴
FontOption fontByKey(String key) {
  final list = fontsFor(appLang);
  return list.firstWhere((f) => f.key == key, orElse: () => list.first);
}

ThemeData buildTheme({required int colorIndex, required Brightness brightness, required String font}) {
  final color = themeColors[colorIndex.clamp(0, themeColors.length - 1)];
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: color.seed,
    brightness: brightness,
    fontFamily: fontByKey(font).family,
  );
  // 다른 언어 글자가 섞여도 깨지지 않게 (한글 → 프리텐다드, 그 외 → 기기 글꼴)
  const fallback = ['Pretendard'];
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
  );
}

/// 앱 안 "오픈소스 라이선스" 화면에 폰트 라이선스 표시
void registerFontLicenses() {
  const files = {
    'Pretendard': 'assets/fonts/licenses/Pretendard-OFL.txt',
    'Gowun Dodum': 'assets/fonts/licenses/GowunDodum-OFL.txt',
    'Gowun Batang': 'assets/fonts/licenses/GowunBatang-OFL.txt',
    'Nanum Pen Script': 'assets/fonts/licenses/NanumPenScript-OFL.txt',
    'Lora': 'assets/fonts/licenses/Lora-OFL.txt',
    'Caveat': 'assets/fonts/licenses/Caveat-OFL.txt',
    'Zen Maru Gothic': 'assets/fonts/licenses/ZenMaruGothic-OFL.txt',
    'Shippori Mincho': 'assets/fonts/licenses/ShipporiMincho-OFL.txt',
    'Klee One': 'assets/fonts/licenses/KleeOne-OFL.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final e in files.entries) {
      final text = await rootBundle.loadString(e.value);
      yield LicenseEntryWithLineBreaks([e.key], text);
    }
  });
}
