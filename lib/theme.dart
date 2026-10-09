import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeColor {
  final String name;
  final Color seed;
  const ThemeColor(this.name, this.seed);
}

const themeColors = [
  ThemeColor('숲', Color(0xFF3D7A6E)),
  ThemeColor('바다', Color(0xFF2F6FB0)),
  ThemeColor('라벤더', Color(0xFF7A5CC2)),
  ThemeColor('코랄', Color(0xFFD9654B)),
  ThemeColor('벚꽃', Color(0xFFC2557E)),
  ThemeColor('모노', Color(0xFF5F6368)),
];

class FontOption {
  final String key;
  final String label;
  final String? family; // null = 기기 기본 글꼴
  final double sizeFactor; // 글꼴마다 눈에 보이는 크기가 달라 보정
  const FontOption(this.key, this.label, this.family, {this.sizeFactor = 1.0});
}

/// 모두 SIL Open Font License 1.1 — 상업적 이용 가능
const fontOptions = [
  FontOption('pretendard', '프리텐다드', 'Pretendard'),
  FontOption('gowunDodum', '고운돋움', 'GowunDodum'),
  FontOption('gowunBatang', '고운바탕', 'GowunBatang'),
  FontOption('nanumPen', '나눔손글씨 펜', 'NanumPenScript', sizeFactor: 1.3),
  FontOption('system', '기기 기본', null),
];

FontOption fontByKey(String key) =>
    fontOptions.firstWhere((f) => f.key == key, orElse: () => fontOptions.first);

ThemeData buildTheme({required int colorIndex, required Brightness brightness, required String font}) {
  final color = themeColors[colorIndex.clamp(0, themeColors.length - 1)];
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: color.seed,
    brightness: brightness,
    fontFamily: fontByKey(font).family,
  );
}

/// 앱 안 "오픈소스 라이선스" 화면에 폰트 라이선스 표시
void registerFontLicenses() {
  const files = {
    'Pretendard': 'assets/fonts/licenses/Pretendard-OFL.txt',
    'Gowun Dodum': 'assets/fonts/licenses/GowunDodum-OFL.txt',
    'Gowun Batang': 'assets/fonts/licenses/GowunBatang-OFL.txt',
    'Nanum Pen Script': 'assets/fonts/licenses/NanumPenScript-OFL.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final e in files.entries) {
      final text = await rootBundle.loadString(e.value);
      yield LicenseEntryWithLineBreaks([e.key], text);
    }
  });
}
