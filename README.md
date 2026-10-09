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

## 빌드
`main`에 push 하면 **Actions → Build** 가 자동으로 실행되고, 끝나면 Artifacts에 두 파일이 생깁니다.
- `LifeBox-apk-N` : 폰에 바로 설치하는 APK
- `LifeBox-aab-N` : 구글 플레이스토어 업로드용 App Bundle

빌드 번호(versionCode)는 실행 번호로 자동 증가합니다.

## 서명 키 (중요)
릴리스 서명 키는 저장소에 올리지 않고 **Settings → Secrets and variables → Actions** 에 넣습니다.
- `KEYSTORE_BASE64` : upload-keystore.jks 를 base64로 바꾼 값
- `KEYSTORE_PASSWORD` : 키 비밀번호 (별칭은 `upload`)

Secrets가 없으면 임시 디버그 키로 빌드되며, 그 APK는 테스트용입니다.
키 파일과 비밀번호는 따로 안전하게 백업해 두세요.

## 플레이스토어
- 패키지 이름: `io.github.rhsung1004.lifebox` (첫 업로드 후에는 바꿀 수 없음)
- 개인정보처리방침: [PRIVACY.md](PRIVACY.md)
- 데이터 보안 양식: 수집·공유하는 데이터 없음

## PC에서 실행
```bash
flutter pub get
flutter run
```

## 주의
- 앱을 삭제하면 기록과 사진도 같이 지워집니다. (기기의 Google 백업이 켜져 있으면 일부 복원될 수 있음)

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
