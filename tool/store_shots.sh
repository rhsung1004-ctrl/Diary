#!/usr/bin/env bash
# 에뮬레이터에서 스크린샷 테스트 실행 (출력은 drive.log 에 저장)
set -o pipefail
mkdir -p screenshots
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d emulator-5554 2>&1 | tee screenshots/drive.log
code=$?
# 실패 원인을 Actions 화면에 보이게
if [ $code -ne 0 ]; then
  grep -iE "error|exception|failed|══|Expected|Actual|\.dart:[0-9]+" screenshots/drive.log | tail -40 | while IFS= read -r l; do echo "::error::$l"; done
fi
exit $code
