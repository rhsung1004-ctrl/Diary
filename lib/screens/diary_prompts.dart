import 'dart:math';

import 'package:flutter/material.dart';

/// 일기 쓸 거리 질문 템플릿
class _Template {
  final String emoji;
  final String name;
  final String body;
  const _Template(this.emoji, this.name, this.body);
}

const _templates = [
  _Template('🙏', '감사 일기', '오늘 감사했던 일 3가지\n1. \n2. \n3. '),
  _Template('🌙', '하루 돌아보기', '오늘 가장 기억에 남는 순간은?\n\n\n오늘 잘한 일은?\n\n\n내일 해보고 싶은 것은?\n'),
  _Template('💭', '감정 일기', '지금 기분은 어떤가요?\n\n\n그렇게 느낀 이유는?\n\n\n나에게 해주고 싶은 말은?\n'),
  _Template('🎯', '목표 점검', '오늘 목표를 위해 한 일은?\n\n\n막혔던 점은?\n\n\n내일 할 딱 한 가지는?\n'),
  _Template('📚', '배운 것', '오늘 새로 알게 된 것은?\n\n\n어디에 써먹을 수 있을까?\n'),
];

const _questions = [
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
];

/// 질문을 고르면 본문에 넣을 글을 돌려줌
Future<String?> pickDiaryPrompt(BuildContext context) {
  final today = _questions[Random().nextInt(_questions.length)];
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
              title: const Text('오늘의 질문'),
              subtitle: Text(today),
              onTap: () => Navigator.pop(ctx, '$today\n'),
            ),
          ),
        ),
        for (final t in _templates)
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
