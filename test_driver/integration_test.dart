import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// 테스트에서 찍은 화면은 screenshots/*.png, 넘겨받은 PDF는 screenshots/*.pdf 로 저장
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) return;
      for (final e in data.entries) {
        if (e.value is String) {
          await File('screenshots/${e.key}.pdf').writeAsBytes(base64Decode(e.value as String));
        }
      }
    },
  );
}
