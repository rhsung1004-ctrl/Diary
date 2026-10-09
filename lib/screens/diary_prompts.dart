import 'dart:math';

import 'package:flutter/material.dart';

import '../i18n.dart';

/// 일기 쓸 거리 질문 템플릿 (언어별)
class _Template {
  final String emoji;
  final String name;
  final String body;
  const _Template(this.emoji, this.name, this.body);
}

const _templates = {
  'ko': [
    _Template('🙏', '감사 일기', '오늘 감사했던 일 3가지\n1. \n2. \n3. '),
    _Template('🌙', '하루 돌아보기', '오늘 가장 기억에 남는 순간은?\n\n\n오늘 잘한 일은?\n\n\n내일 해보고 싶은 것은?\n'),
    _Template('💭', '감정 일기', '지금 기분은 어떤가요?\n\n\n그렇게 느낀 이유는?\n\n\n나에게 해주고 싶은 말은?\n'),
    _Template('🎯', '목표 점검', '오늘 목표를 위해 한 일은?\n\n\n막혔던 점은?\n\n\n내일 할 딱 한 가지는?\n'),
    _Template('📚', '배운 것', '오늘 새로 알게 된 것은?\n\n\n어디에 써먹을 수 있을까?\n'),
  ],
  'en': [
    _Template('🙏', 'Gratitude', '3 things I\'m grateful for today\n1. \n2. \n3. '),
    _Template('🌙', 'Daily reflection', 'What was the most memorable moment today?\n\n\nWhat did I do well?\n\n\nWhat do I want to try tomorrow?\n'),
    _Template('💭', 'Feelings', 'How am I feeling right now?\n\n\nWhy do I feel this way?\n\n\nWhat would I like to tell myself?\n'),
    _Template('🎯', 'Goal check-in', 'What did I do today toward my goals?\n\n\nWhere did I get stuck?\n\n\nThe one thing I\'ll do tomorrow:\n'),
    _Template('📚', 'What I learned', 'What did I learn today?\n\n\nWhere could I use it?\n'),
  ],
  'ja': [
    _Template('🙏', '感謝日記', '今日感謝したこと3つ\n1. \n2. \n3. '),
    _Template('🌙', '1日の振り返り', '今日いちばん心に残った瞬間は？\n\n\n今日うまくできたことは？\n\n\n明日やってみたいことは？\n'),
    _Template('💭', '気持ち日記', '今の気分はどうですか？\n\n\nそう感じた理由は？\n\n\n自分にかけてあげたい言葉は？\n'),
    _Template('🎯', '目標チェック', '今日、目標のためにしたことは？\n\n\nつまずいたことは？\n\n\n明日やることを一つだけ：\n'),
    _Template('📚', '学んだこと', '今日新しく知ったことは？\n\n\nどこで活かせそう？\n'),
  ],
};

const _questions = {
  'ko': [
    '오늘 나를 웃게 만든 건 뭐였나요?',
    '오늘 하루를 한 단어로 표현한다면?',
    '요즘 가장 많이 생각하는 것은?',
    '오늘 누군가에게 고마웠던 순간은?',
    '1년 뒤의 나에게 하고 싶은 말은?',
    '오늘 먹은 것 중 가장 맛있었던 건?',
    '최근에 용기 냈던 일이 있나요?',
    '지금 가장 기대되는 일은?',
    '요즘 나를 지치게 하는 건 뭘까요?',
    '오늘 내가 나에게 칭찬해 주고 싶은 점은?',
    '어릴 적 나는 지금의 나를 보면 뭐라고 할까요?',
    '이번 주에 꼭 해내고 싶은 한 가지는?',
    '최근 들은 말 중 마음에 남은 말은?',
    '오늘 가장 오래 머문 장소는 어디였나요?',
    '요즘 빠져 있는 것은?',
    '오늘 아쉬웠던 순간이 있다면?',
    '나를 편안하게 만드는 것 3가지는?',
    '올해 가장 잘한 선택은?',
    '지금 듣고 싶은 노래와 그 이유는?',
    '오늘 처음 해본 일이 있나요?',
    '나만 아는 작은 행복은?',
    '최근 누군가에게 해주고 싶었지만 못 한 말은?',
    '내일 아침 눈뜨면 제일 먼저 하고 싶은 것은?',
    '요즘 나에게 필요한 건 뭘까요?',
    '오늘의 날씨와 그때 내 기분은?',
    '지금 이 순간 떠오르는 사람은?',
    '최근 내 마음을 움직인 장면은?',
    '다시 돌아가고 싶은 하루가 있다면?',
    '오늘 버리고 싶은 생각 하나는?',
    '10년 뒤에도 하고 있으면 좋겠는 것은?',
  ],
  'en': [
    'What made me smile today?',
    'If today were one word, what would it be?',
    'What have I been thinking about most lately?',
    'Who was I grateful for today?',
    'What would I tell myself a year from now?',
    'What was the best thing I ate today?',
    'When did I last do something brave?',
    'What am I looking forward to most?',
    'What has been wearing me out lately?',
    'What would I like to praise myself for today?',
    'What would my younger self say about me now?',
    'What is the one thing I want to get done this week?',
    'What words have stayed with me recently?',
    'Where did I spend most of my time today?',
    'What am I into these days?',
    'Was there a moment I wish had gone differently?',
    '3 things that make me feel at ease:',
    'What was my best decision this year?',
    'What song do I want to hear right now, and why?',
    'Did I try anything for the first time today?',
    'What small joy do only I know about?',
    'What have I wanted to say to someone but haven\'t?',
    'What\'s the first thing I want to do tomorrow morning?',
    'What do I need most right now?',
    'What was the weather like today, and how did I feel?',
    'Who comes to mind right now?',
    'What scene moved me recently?',
    'If I could relive one day, which would it be?',
    'What thought do I want to let go of today?',
    'What do I hope I\'m still doing 10 years from now?',
  ],
  'ja': [
    '今日、私を笑顔にしたものは？',
    '今日を一言で表すなら？',
    '最近いちばんよく考えていることは？',
    '今日、誰かに感謝した瞬間は？',
    '1年後の自分に伝えたいことは？',
    '今日食べたものでいちばん美味しかったのは？',
    '最近、勇気を出したことはありますか？',
    '今いちばん楽しみにしていることは？',
    '最近、私を疲れさせているものは？',
    '今日、自分をほめてあげたいところは？',
    '子どもの頃の私が今の私を見たら何と言うかな？',
    '今週どうしてもやり遂げたいことは？',
    '最近言われて心に残った言葉は？',
    '今日いちばん長くいた場所はどこ？',
    '最近ハマっていることは？',
    '今日、心残りだった瞬間はありますか？',
    '私をほっとさせるもの3つは？',
    '今年いちばん良かった選択は？',
    '今聴きたい曲とその理由は？',
    '今日初めてやったことはありますか？',
    '私だけが知っている小さな幸せは？',
    '最近、誰かに伝えたかったけど言えなかったことは？',
    '明日の朝、目が覚めたら最初にしたいことは？',
    '最近の私に必要なものは何だろう？',
    '今日の天気と、そのときの気分は？',
    '今この瞬間に思い浮かぶ人は？',
    '最近心を動かされた場面は？',
    'もう一度戻りたい一日があるとしたら？',
    '今日手放したい考えを一つ挙げるなら？',
    '10年後も続けていたいことは？',
  ],
};

/// 질문을 고르면 본문에 넣을 글을 돌려줌
Future<String?> pickDiaryPrompt(BuildContext context) {
  final questions = _questions[appLang] ?? _questions['en']!;
  final templates = _templates[appLang] ?? _templates['en']!;
  final today = questions[Random().nextInt(questions.length)];
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            elevation: 0,
            color: Theme.of(ctx).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Text('🎲', style: TextStyle(fontSize: 24)),
              title: Text(tr.promptToday),
              subtitle: Text(today),
              onTap: () => Navigator.pop(ctx, '$today\n'),
            ),
          ),
        ),
        for (final t in templates)
          ListTile(
            leading: Text(t.emoji, style: const TextStyle(fontSize: 24)),
            title: Text(t.name),
            subtitle: Text(t.body.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(ctx, t.body),
          ),
      ]),
    ),
  );
}
