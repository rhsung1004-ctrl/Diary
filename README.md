# LifeBox

버킷리스트 · 목표 · 일기(사진) · 커리어(포트폴리오)를 한 앱에 기록하는 개인용 안드로이드 앱 (Flutter).

## 기능
- **홈**: 오늘 날짜, 각 영역 요약, 오늘 일기 여부, 진행 중 목표, 최근 달성한 버킷
- **버킷리스트**: 체크로 달성 처리(달성일 자동 기록), 분류, 메모, 인증 사진
- **목표**: 기간(올해/이번 달/이번 주/장기), 마감일 D-day, 하위 할 일 체크 → 진행률
- **일기**: 날짜, 기분 이모지, 제목/본문, 사진 여러 장(갤러리·카메라), 월별 목록, 사진 확대 보기
- **커리어**: 프로젝트/경력/학력/자격·수상/활동, 기간, 설명, 기술 태그, 링크, 이미지
- 데이터는 폰 안(앱 전용 폴더)에만 저장 → 인터넷·계정 필요 없음
- 다크 모드 지원

## APK 받는 법 (PC에 아무것도 설치 안 해도 됨)
1. GitHub에 **비공개(Private)** 저장소를 새로 만들고 이 폴더 내용을 올립니다.
2. 저장소의 **Actions** 탭 → `Build APK` 실행이 끝나면(약 5~8분) 아래 **Artifacts**에서 `LifeBox-apk`를 받습니다.
3. 압축을 풀어 `app-release.apk`를 폰으로 옮겨 설치합니다. ("출처를 알 수 없는 앱 설치" 허용 필요)

코드를 고쳐 다시 push 하면 새 APK가 만들어지고, 덮어 설치해도 기록이 유지됩니다.

## PC에서 직접 실행하려면
```bash
flutter create --platforms=android --org com.lifebox --project-name lifebox .
flutter run
```
폰에 이미 Actions 버전이 깔려 있다면, 서명 키가 달라 덮어 설치가 안 됩니다.
`ci/debug.keystore`를 `%USERPROFILE%\.android\debug.keystore`(Windows)에 복사해 두면 같은 키로 빌드됩니다.

## 주의
- **앱을 삭제하면 기록과 사진도 같이 지워집니다.** (클라우드 백업은 다음 단계에서 추가 예정)
- `ci/debug.keystore`는 서명 키라서 저장소는 비공개로 두세요.

## 구조
```
lib/
  main.dart          앱 시작, 하단 탭
  models.dart        데이터 모델 (JSON 변환)
  store.dart         저장/불러오기, 사진 보관
  common.dart        날짜 형식, 공용 위젯
  photos.dart        사진 추가·썸네일·확대 보기
  screens/           home, bucket, goals, diary, career
```
