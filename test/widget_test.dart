import 'package:flutter_test/flutter_test.dart';
import 'package:lifebox/models.dart';

void main() {
  test('목표 진행률 계산', () {
    final g = Goal(title: 'N1', tasks: [GoalTask(text: 'a', done: true), GoalTask(text: 'b')]);
    expect(g.progress, 0.5);
    expect(g.isComplete, false);
    final copy = Goal.fromJson(g.toJson());
    expect(copy.tasks.length, 2);
  });
}
