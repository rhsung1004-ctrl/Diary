// 플레이스토어 스크린샷용 예시 데이터 (한국어 · 영어 · 일본어)
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:lifebox/models.dart';

typedef L = Map<String, String>; // {'ko': .., 'en': .., 'ja': ..}

String _t(L m, String lang) => m[lang] ?? m['en']!;

DateTime _daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 21).subtract(Duration(days: n));
}

class _Entry {
  final int ago;
  final L title;
  final L body;
  final String mood;
  final List<L> tags;
  final String? goal;
  final String? photo;
  const _Entry(this.ago, this.title, this.body, this.mood, this.tags, {this.goal, this.photo});
}

const _run = {'ko': '러닝', 'en': 'running', 'ja': 'ランニング'};
const _study = {'ko': '토익', 'en': 'TOEIC', 'ja': 'TOEIC'};
const _read = {'ko': '독서', 'en': 'reading', 'ja': '読書'};
const _cafe = {'ko': '카페', 'en': 'cafe', 'ja': 'カフェ'};
const _friend = {'ko': '친구', 'en': 'friends', 'ja': '友だち'};
const _family = {'ko': '가족', 'en': 'family', 'ja': '家族'};
const _art = {'ko': '전시', 'en': 'art', 'ja': '展示'};
const _weekend = {'ko': '주말', 'en': 'weekend', 'ja': '週末'};
const _retro = {'ko': '회고', 'en': 'retro', 'ja': '振り返り'};
const _river = {'ko': '한강', 'en': 'river', 'ja': '川沿い'};

const _entries = <_Entry>[
  _Entry(0, {'ko': '한강 10km 완주!', 'en': 'Ran 10km by the river!', 'ja': '川沿い10km完走！'},
      {
        'ko': '처음으로 쉬지 않고 10km를 달렸다. 마지막 2km는 정말 힘들었지만 노을이 너무 예뻐서 끝까지 버틸 수 있었다.\n\n다음 목표는 15km!',
        'en': 'Ran 10km without stopping for the first time. The last 2km were tough, but the sunset kept me going.\n\nNext goal: 15km!',
        'ja': '初めて休まずに10kmを走った。最後の2kmはきつかったけど、夕焼けがきれいで最後までがんばれた。\n\n次の目標は15km！',
      },
      '😆', [_run, _river], goal: 'g1', photo: 'sunset'),
  _Entry(1, {'ko': '모의고사 5회차', 'en': 'Mock test #5', 'ja': '模試5回目'},
      {'ko': 'LC 450, RC 410. 파트 7 시간이 아직 부족하다. 내일은 오답 정리부터.', 'en': 'LC 450, RC 410. Still short on time for Part 7. Reviewing mistakes tomorrow.', 'ja': 'LC 450、RC 410。Part 7の時間がまだ足りない。明日は復習から。'},
      '😌', [_study], goal: 'g2'),
  _Entry(2, {'ko': '비 오는 날 카페', 'en': 'Rainy day at a cafe', 'ja': '雨の日のカフェ'},
      {'ko': '창가 자리에 앉아 책을 읽었다. 이런 날이 제일 좋다.', 'en': 'Read by the window all afternoon. Days like this are the best.', 'ja': '窓際の席で本を読んだ。こういう日がいちばん好き。'},
      '🥰', [_cafe, _read], photo: 'cafe'),
  _Entry(3, {'ko': '주 3회 달리기 성공', 'en': 'Three runs this week', 'ja': '週3回ランニング達成'},
      {'ko': '이번 주도 계획대로 세 번 달렸다. 몸이 가벼워지는 게 느껴진다.', 'en': 'Stuck to the plan and ran three times. I can feel my body getting lighter.', 'ja': '今週も計画どおり3回走った。体が軽くなってきた。'},
      '😊', [_run], goal: 'g1'),
  _Entry(5, {'ko': '친구 생일 파티', 'en': "Friend's birthday", 'ja': '友だちの誕生日'},
      {'ko': '오랜만에 다 같이 모였다. 웃느라 배가 아팠던 날.', 'en': 'Everyone got together for the first time in ages. Laughed until it hurt.', 'ja': '久しぶりにみんなで集まった。笑いすぎてお腹が痛い。'},
      '😆', [_friend]),
  _Entry(6, {'ko': '단어 200개 복습', 'en': 'Reviewed 200 words', 'ja': '単語200個復習'},
      {'ko': '지루하지만 꾸준히.', 'en': 'Boring, but steady wins.', 'ja': '地味だけどコツコツと。'}, '😐', [_study], goal: 'g2'),
  _Entry(8, {'ko': '새 러닝화 개시', 'en': 'New running shoes', 'ja': '新しいランニングシューズ'},
      {'ko': '발이 정말 편하다. 장비빨도 실력!', 'en': 'So comfortable. Good gear matters!', 'ja': '足がすごく楽。道具も大事！'},
      '😊', [_run], goal: 'g1', photo: 'shoes'),
  _Entry(9, {'ko': '조금 지친 하루', 'en': 'A bit tired today', 'ja': '少し疲れた一日'},
      {'ko': '오늘은 일찍 자야지.', 'en': 'Going to bed early tonight.', 'ja': '今日は早く寝よう。'}, '😴', []),
  _Entry(11, {'ko': '주말 전시회', 'en': 'Weekend exhibition', 'ja': '週末の展示会'},
      {'ko': '색감이 너무 좋아서 한참 서 있었다.', 'en': 'The colors were so good I stood there for ages.', 'ja': '色づかいが素敵で、しばらく見入ってしまった。'},
      '🥰', [_art, _weekend], photo: 'gallery'),
  _Entry(12, {'ko': '모의고사 4회차', 'en': 'Mock test #4', 'ja': '模試4回目'},
      {'ko': '점수가 떨어졌다. 그래도 포기하지 않기.', 'en': 'Score dropped. Not giving up.', 'ja': '点数が下がった。でもあきらめない。'}, '😢', [_study], goal: 'g2'),
  _Entry(14, {'ko': '8km 페이스 6분', 'en': '8km at 6 min/km', 'ja': '8kmをキロ6分で'},
      {'ko': '조금씩 빨라지고 있다.', 'en': 'Getting a little faster.', 'ja': '少しずつ速くなっている。'}, '😊', [_run], goal: 'g1'),
  _Entry(16, {'ko': '가족 저녁', 'en': 'Family dinner', 'ja': '家族で夕ごはん'},
      {'ko': '엄마표 김치찌개 최고.', 'en': "Mom's stew is the best.", 'ja': '母の手料理がいちばん。'}, '😊', [_family]),
  _Entry(18, {'ko': '프로젝트 회고', 'en': 'Project retrospective', 'ja': 'プロジェクトの振り返り'},
      {'ko': '잘한 점, 아쉬운 점을 정리했다.', 'en': 'Wrote down what went well and what didn’t.', 'ja': '良かった点と反省点をまとめた。'}, '😌', [_retro]),
  _Entry(19, {'ko': '독서 모임', 'en': 'Book club', 'ja': '読書会'},
      {'ko': '같은 책을 읽어도 다들 다르게 느낀다.', 'en': 'Same book, so many different takes.', 'ja': '同じ本でも感じ方はみんな違う。'}, '😊', [_read]),
  _Entry(21, {'ko': '처음으로 5km', 'en': 'First 5km', 'ja': '初めての5km'},
      {'ko': '시작이 반!', 'en': 'Well begun is half done!', 'ja': '始めれば半分終わったようなもの！'}, '😆', [_run], goal: 'g1'),
  _Entry(24, {'ko': '평범한 화요일', 'en': 'An ordinary Tuesday', 'ja': 'ふつうの火曜日'},
      {'ko': '별일 없는 것도 감사한 일.', 'en': 'Grateful for a quiet day.', 'ja': '何もない日にも感謝。'}, '😐', []),
  _Entry(26, {'ko': '공원 산책', 'en': 'Walk in the park', 'ja': '公園を散歩'},
      {'ko': '바람이 시원했다.', 'en': 'The breeze felt great.', 'ja': '風が気持ちよかった。'}, '😊', [_weekend]),
  _Entry(29, {'ko': '요가 첫 수업', 'en': 'First yoga class', 'ja': '初めてのヨガ'},
      {'ko': '몸이 이렇게 굳어 있었다니.', 'en': "Didn't know I was this stiff.", 'ja': 'こんなに体が硬いとは。'}, '😌', []),
  _Entry(31, {'ko': '목표 세운 날', 'en': 'Set my goals', 'ja': '目標を立てた日'},
      {'ko': '하프 마라톤, 토익 900. 해보자!', 'en': 'Half marathon, TOEIC 900. Let’s go!', 'ja': 'ハーフマラソンとTOEIC900。やってみよう！'}, '😆', [_retro]),
  _Entry(33, {'ko': '비 오는 출근길', 'en': 'Rainy commute', 'ja': '雨の通勤'},
      {'ko': '우산이 뒤집혔다.', 'en': 'My umbrella flipped inside out.', 'ja': '傘がひっくり返った。'}, '😠', []),
  _Entry(36, {'ko': '새 노트 개시', 'en': 'New notebook', 'ja': '新しいノート'},
      {'ko': '첫 장은 늘 설렌다.', 'en': 'The first page is always exciting.', 'ja': '最初のページはいつもワクワクする。'}, '😊', []),
  _Entry(365, {'ko': '인턴 첫 출근', 'en': 'First day as an intern', 'ja': 'インターン初日'},
      {'ko': '긴장했지만 팀원들이 정말 친절했다. 1년 뒤의 나는 어떤 모습일까?', 'en': 'Nervous, but the team was so kind. Where will I be a year from now?', 'ja': '緊張したけど、チームのみんなが優しかった。1年後の自分はどうなっているかな？'},
      '😊', []),
];

/// 언어별 예시 데이터 (AppStore 저장 형식)
Map<String, dynamic> demoData(String lang) {
  final now = DateTime.now();
  final y = now.year;

  final goals = <Goal>[
    Goal(
      id: 'g1',
      title: _t({'ko': '하프 마라톤 완주', 'en': 'Finish a half marathon', 'ja': 'ハーフマラソン完走'}, lang),
      period: '올해',
      dueDate: DateTime(y, 11, 15),
      createdAt: _daysAgo(31),
      tasks: [
        GoalTask(text: _t({'ko': '주 3회 5km 달리기', 'en': 'Run 5km three times a week', 'ja': '週3回5km走る'}, lang), done: true),
        GoalTask(text: _t({'ko': '10km 1시간 안에 완주', 'en': 'Run 10km under an hour', 'ja': '10kmを1時間以内で'}, lang), done: true),
        GoalTask(text: _t({'ko': '러닝화 새로 사기', 'en': 'Buy new running shoes', 'ja': 'ランニングシューズを買う'}, lang), done: true),
        GoalTask(text: _t({'ko': '15km 장거리 연습', 'en': 'Long run: 15km', 'ja': '15kmの長距離練習'}, lang)),
      ],
    ),
    Goal(
      id: 'g2',
      title: _t({'ko': '토익 900점', 'en': 'TOEIC 900', 'ja': 'TOEIC 900点'}, lang),
      period: '올해',
      dueDate: DateTime(y, 12, 20),
      createdAt: _daysAgo(31),
      tasks: [
        GoalTask(text: _t({'ko': '단어장 1회독', 'en': 'Finish the vocab book', 'ja': '単語帳を1周'}, lang), done: true),
        GoalTask(text: _t({'ko': '모의고사 5회', 'en': '5 mock tests', 'ja': '模試5回'}, lang), done: true),
        GoalTask(text: _t({'ko': '모의고사 10회', 'en': '10 mock tests', 'ja': '模試10回'}, lang)),
      ],
    ),
    Goal(
      id: 'g3',
      title: _t({'ko': '매일 30분 독서', 'en': 'Read 30 minutes a day', 'ja': '毎日30分読書'}, lang),
      period: '이번 달',
      createdAt: _daysAgo(9),
      tasks: [
        GoalTask(text: _t({'ko': '1주차', 'en': 'Week 1', 'ja': '1週目'}, lang), done: true),
        GoalTask(text: _t({'ko': '2주차', 'en': 'Week 2', 'ja': '2週目'}, lang)),
        GoalTask(text: _t({'ko': '3주차', 'en': 'Week 3', 'ja': '3週目'}, lang)),
        GoalTask(text: _t({'ko': '4주차', 'en': 'Week 4', 'ja': '4週目'}, lang)),
      ],
    ),
    Goal(
      id: 'g4',
      title: _t({'ko': '포트폴리오 사이트 만들기', 'en': 'Build a portfolio site', 'ja': 'ポートフォリオサイトを作る'}, lang),
      period: '올해',
      done: true,
      createdAt: DateTime(y, 3, 2),
      completedAt: DateTime(y, 5, 20),
    ),
    Goal(
      id: 'g5',
      title: _t({'ko': '운전면허 따기', 'en': "Get a driver's license", 'ja': '運転免許を取る'}, lang),
      period: '올해',
      done: true,
      createdAt: DateTime(y, 1, 10),
      completedAt: DateTime(y, 2, 25),
    ),
  ];

  final buckets = <BucketItem>[
    BucketItem(
      title: _t({'ko': '오로라 보기', 'en': 'See the northern lights', 'ja': 'オーロラを見る'}, lang),
      category: _t({'ko': '여행', 'en': 'Travel', 'ja': '旅行'}, lang),
      done: true,
      doneAt: DateTime(y, 2, 14),
      photos: ['demo_aurora.png'],
      createdAt: DateTime(y - 1, 9, 1),
    ),
    BucketItem(
      title: _t({'ko': '기타로 노래 한 곡 완주', 'en': 'Play a full song on guitar', 'ja': 'ギターで1曲弾ききる'}, lang),
      category: _t({'ko': '배움', 'en': 'Learning', 'ja': '学び'}, lang),
      done: true,
      doneAt: DateTime(y, 6, 30),
      createdAt: DateTime(y, 1, 1),
    ),
    BucketItem(
      title: _t({'ko': '제주도 한 달 살기', 'en': 'Live in Jeju for a month', 'ja': '済州島で1か月暮らす'}, lang),
      category: _t({'ko': '여행', 'en': 'Travel', 'ja': '旅行'}, lang),
      createdAt: DateTime(y, 1, 1),
    ),
    BucketItem(
      title: _t({'ko': '풀코스 마라톤 완주', 'en': 'Finish a full marathon', 'ja': 'フルマラソン完走'}, lang),
      category: _t({'ko': '도전', 'en': 'Challenge', 'ja': '挑戦'}, lang),
      createdAt: DateTime(y, 1, 1),
    ),
    BucketItem(
      title: _t({'ko': '부모님과 유럽 여행', 'en': 'Trip to Europe with my parents', 'ja': '両親とヨーロッパ旅行'}, lang),
      category: _t({'ko': '여행', 'en': 'Travel', 'ja': '旅行'}, lang),
      createdAt: DateTime(y, 1, 1),
    ),
    BucketItem(
      title: _t({'ko': '스카이다이빙', 'en': 'Go skydiving', 'ja': 'スカイダイビング'}, lang),
      category: _t({'ko': '도전', 'en': 'Challenge', 'ja': '挑戦'}, lang),
      done: true,
      doneAt: DateTime(y - 1, 8, 20),
      createdAt: DateTime(y - 1, 1, 1),
    ),
  ];

  final diaries = <DiaryEntry>[
    for (final e in _entries)
      DiaryEntry(
        date: _daysAgo(e.ago),
        title: _t(e.title, lang),
        body: _t(e.body, lang),
        mood: e.mood,
        tags: [for (final t in e.tags) _t(t, lang)],
        goalId: e.goal,
        photos: e.photo == null ? [] : ['demo_${e.photo}.png'],
        createdAt: _daysAgo(e.ago),
      ),
  ];

  final careers = <CareerItem>[
    CareerItem(
      type: '프로젝트',
      title: _t({'ko': '여행 기록 앱 개발', 'en': 'Travel journal app', 'ja': '旅行記録アプリの開発'}, lang),
      org: _t({'ko': '개인 프로젝트 · 기획/개발', 'en': 'Personal project · Design & development', 'ja': '個人プロジェクト・企画/開発'}, lang),
      startDate: DateTime(y, 3, 1),
      endDate: DateTime(y, 5, 31),
      description: _t({
        'ko': '여행 사진과 경로를 지도에 기록하는 앱을 기획부터 출시까지 혼자 만들었어요. 베타 테스터 120명.',
        'en': 'Designed and shipped a map-based travel journal app on my own. 120 beta testers.',
        'ja': '旅行の写真とルートを地図に記録するアプリを、企画からリリースまで一人で作りました。ベータテスター120人。',
      }, lang),
      skills: ['Flutter', 'Figma', 'Firebase'],
      link: 'github.com/example/travel-app',
      photos: ['demo_app.png'],
    ),
    CareerItem(
      type: '경력',
      title: _t({'ko': 'UX 디자인 인턴', 'en': 'UX Design Intern', 'ja': 'UXデザインインターン'}, lang),
      org: _t({'ko': '○○스튜디오 · 디자인팀', 'en': '○○ Studio · Design team', 'ja': '○○スタジオ・デザインチーム'}, lang),
      startDate: DateTime(y - 1, 10, 1),
      endDate: DateTime(y, 1, 31),
      skills: ['Figma', _t({'ko': '사용자 인터뷰', 'en': 'User interviews', 'ja': 'ユーザーインタビュー'}, lang)],
    ),
    CareerItem(
      type: '자격·수상',
      title: _t({'ko': '교내 해커톤 대상', 'en': 'Campus hackathon — Grand prize', 'ja': '学内ハッカソン大賞'}, lang),
      org: _t({'ko': '○○대학교', 'en': '○○ University', 'ja': '○○大学'}, lang),
      startDate: DateTime(y - 1, 11, 20),
      skills: ['Flutter', _t({'ko': '팀워크', 'en': 'Teamwork', 'ja': 'チームワーク'}, lang)],
    ),
    CareerItem(
      type: '학력',
      title: _t({'ko': '시각디자인과 학사', 'en': 'B.F.A. Visual Design', 'ja': '視覚デザイン学科 学士'}, lang),
      org: _t({'ko': '○○대학교', 'en': '○○ University', 'ja': '○○大学'}, lang),
      startDate: DateTime(y - 5, 3, 1),
      endDate: DateTime(y, 2, 28),
    ),
  ];

  final profile = Profile(
    name: _t({'ko': '한여름', 'en': 'Alex Kim', 'ja': '佐藤 ゆい'}, lang),
    headline: _t({'ko': '기록하며 성장하는 디자이너', 'en': 'A designer who grows by recording', 'ja': '記録しながら成長するデザイナー'}, lang),
  );

  return {
    'version': 1,
    'buckets': buckets.map((e) => e.toJson()).toList(),
    'goals': goals.map((e) => e.toJson()).toList(),
    'diaries': diaries.map((e) => e.toJson()).toList(),
    'careers': careers.map((e) => e.toJson()).toList(),
    'profile': profile.toJson(),
  };
}

/// 예시 사진 (그림으로 그려서 PNG로)
const demoPhotoNames = ['sunset', 'cafe', 'shoes', 'gallery', 'aurora', 'app'];

Future<Uint8List> demoPhoto(String kind) async {
  const w = 900.0, h = 675.0;
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec, const ui.Rect.fromLTWH(0, 0, w, h));
  void grad(List<ui.Color> colors, {bool vertical = true}) {
    final p = ui.Paint()
      ..shader = ui.Gradient.linear(
          const ui.Offset(0, 0),
          vertical ? const ui.Offset(0, h) : const ui.Offset(w, h),
          colors,
          [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)]);
    c.drawRect(const ui.Rect.fromLTWH(0, 0, w, h), p);
  }

  final rnd = Random(kind.hashCode);
  switch (kind) {
    case 'sunset':
      grad([const ui.Color(0xFF2E2A6B), const ui.Color(0xFFE0607E), const ui.Color(0xFFF7B267)]);
      c.drawCircle(const ui.Offset(450, 430), 90, ui.Paint()..color = const ui.Color(0xFFFFE3A3));
      c.drawRect(const ui.Rect.fromLTWH(0, 470, w, h - 470), ui.Paint()..color = const ui.Color(0xFF3A3560));
      for (var i = 0; i < 8; i++) {
        c.drawRect(ui.Rect.fromLTWH(330 + rnd.nextDouble() * 200, 490 + i * 18.0, 60 + rnd.nextDouble() * 80, 4),
            ui.Paint()..color = const ui.Color(0x88FFE3A3));
      }
      final city = ui.Paint()..color = const ui.Color(0xFF262248);
      for (var x = 0.0; x < w; x += 60) {
        final bh = 40 + rnd.nextDouble() * 90;
        c.drawRect(ui.Rect.fromLTWH(x, 470 - bh, 52, bh), city);
      }
    case 'aurora':
      grad([const ui.Color(0xFF0B1630), const ui.Color(0xFF14284A)]);
      for (var i = 0; i < 60; i++) {
        c.drawCircle(ui.Offset(rnd.nextDouble() * w, rnd.nextDouble() * 300), 1.6,
            ui.Paint()..color = const ui.Color(0xCCFFFFFF));
      }
      for (var i = 0; i < 3; i++) {
        final path = ui.Path()..moveTo(0, 260.0 + i * 40);
        for (var x = 0.0; x <= w; x += 30) {
          path.lineTo(x, 230 + i * 40 + sin(x / 90 + i) * 50);
        }
        c.drawPath(
            path,
            ui.Paint()
              ..color = (i == 1 ? const ui.Color(0x99B57BFF) : const ui.Color(0xAA4DFFB0))
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 46
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 28));
      }
      final hill = ui.Path()
        ..moveTo(0, h)
        ..lineTo(0, 560)
        ..quadraticBezierTo(250, 500, 480, 570)
        ..quadraticBezierTo(700, 620, w, 540)
        ..lineTo(w, h)
        ..close();
      c.drawPath(hill, ui.Paint()..color = const ui.Color(0xFF060C1A));
    case 'cafe':
      grad([const ui.Color(0xFFE9D8C4), const ui.Color(0xFFB98B67)]);
      c.drawRect(const ui.Rect.fromLTWH(0, 470, w, h - 470), ui.Paint()..color = const ui.Color(0xFF7A5038));
      c.drawCircle(const ui.Offset(330, 450), 95, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
      c.drawCircle(const ui.Offset(330, 450), 72, ui.Paint()..color = const ui.Color(0xFF6B4026));
      c.drawCircle(const ui.Offset(330, 450), 30, ui.Paint()..color = const ui.Color(0x55FFFFFF));
      c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(520, 330, 220, 150), const ui.Radius.circular(8)),
          ui.Paint()..color = const ui.Color(0xFF3F6E8C));
      c.drawRect(const ui.Rect.fromLTWH(628, 330, 4, 150), ui.Paint()..color = const ui.Color(0xFFEDE3D2));
      for (var i = 0; i < 25; i++) {
        c.drawLine(ui.Offset(rnd.nextDouble() * w, rnd.nextDouble() * 200),
            ui.Offset(rnd.nextDouble() * w, 0), ui.Paint()..color = const ui.Color(0x22FFFFFF)..strokeWidth = 2);
      }
    case 'shoes':
      grad([const ui.Color(0xFF9FD8CB), const ui.Color(0xFF3D7A6E)], vertical: false);
      final shoe = ui.Path()
        ..moveTo(170, 470)
        ..quadraticBezierTo(190, 330, 330, 330)
        ..lineTo(460, 380)
        ..quadraticBezierTo(700, 400, 740, 470)
        ..close();
      c.drawPath(shoe, ui.Paint()..color = const ui.Color(0xFFFF7A59));
      c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(160, 465, 600, 40), const ui.Radius.circular(20)),
          ui.Paint()..color = const ui.Color(0xFFFFFFFF));
      for (var i = 0; i < 4; i++) {
        c.drawLine(ui.Offset(330 + i * 30.0, 350), ui.Offset(350 + i * 30.0, 400),
            ui.Paint()..color = const ui.Color(0xFFFFFFFF)..strokeWidth = 6);
      }
    case 'gallery':
      grad([const ui.Color(0xFFF4F1EC), const ui.Color(0xFFE2DDD5)]);
      c.drawRect(const ui.Rect.fromLTWH(0, 540, w, h - 540), ui.Paint()..color = const ui.Color(0xFFBFB6A8));
      final frames = [
        (const ui.Rect.fromLTWH(110, 150, 220, 290), const ui.Color(0xFFE76F51)),
        (const ui.Rect.fromLTWH(380, 120, 160, 160), const ui.Color(0xFF2A9D8F)),
        (const ui.Rect.fromLTWH(380, 310, 160, 130), const ui.Color(0xFFE9C46A)),
        (const ui.Rect.fromLTWH(590, 170, 200, 250), const ui.Color(0xFF264653)),
      ];
      for (final f in frames) {
        c.drawRect(f.$1.inflate(10), ui.Paint()..color = const ui.Color(0xFF2B2B2B));
        c.drawRect(f.$1, ui.Paint()..color = f.$2);
      }
    default: // app
      grad([const ui.Color(0xFF4F7CAC), const ui.Color(0xFF2F4A6D)], vertical: false);
      for (var i = 0; i < 3; i++) {
        final r = ui.Rect.fromLTWH(110 + i * 240.0, 90, 200, 500);
        c.drawRRect(ui.RRect.fromRectAndRadius(r, const ui.Radius.circular(26)),
            ui.Paint()..color = const ui.Color(0xFFF7F7F2));
        c.drawRRect(ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(r.left + 16, 120, 168, 130), const ui.Radius.circular(14)),
            ui.Paint()..color = [const ui.Color(0xFF9FD8CB), const ui.Color(0xFFF7B267), const ui.Color(0xFFE0607E)][i]);
        for (var j = 0; j < 4; j++) {
          c.drawRRect(
              ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(r.left + 16, 280 + j * 60.0, 168 - j * 25.0, 18),
                  const ui.Radius.circular(9)),
              ui.Paint()..color = const ui.Color(0xFFD5D9DE));
        }
      }
  }
  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
