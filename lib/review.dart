import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

import 'common.dart';
import 'i18n.dart';
import 'lock.dart';
import 'prefs.dart';
import 'store.dart';

/// 기록(일기·버킷·목표·커리어)을 5번 저장하면 리뷰를 부탁하는 창을 띄움.
/// "다음에"를 누르면 20번 더 기록한 뒤 한 번만 다시 물어봄.
class ReviewPrompt {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _showing = false;

  static void start() => AppStore.instance.onUserAction = _onAction;

  static Future<void> _onAction() async {
    final prefs = AppPrefs.instance;
    prefs.actionCount++;
    await prefs.save();
    if (prefs.reviewNextAt <= 0 || prefs.actionCount < prefs.reviewNextAt || _showing) return;
    // 저장 후 화면이 닫히는 것을 기다렸다가 띄움
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted || AppLock.instance.locked) return;
    _showing = true;
    try {
      await _ask(ctx);
    } finally {
      _showing = false;
    }
  }

  static Future<void> _ask(BuildContext context) async {
    final prefs = AppPrefs.instance;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Text('⭐', style: TextStyle(fontSize: 36)),
        title: Text(tr.reviewTitle, textAlign: TextAlign.center),
        content: Text(tr.reviewBody(prefs.actionCount), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr.reviewLater)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr.reviewYes)),
        ],
      ),
    );
    if (yes == null) return; // 바깥을 눌러 닫음 → 다음 기록 때 다시
    if (yes) {
      prefs.reviewNextAt = 0; // 다시 묻지 않음
      await prefs.save();
      final review = InAppReview.instance;
      try {
        if (await review.isAvailable()) {
          await AppLock.instance.runExternal(review.requestReview);
        } else if (context.mounted) {
          // 플레이스토어에서 설치한 앱이 아니면 리뷰 창이 뜨지 않음
          toast(context, tr.reviewThanks);
        }
      } catch (_) {
        if (context.mounted) toast(context, tr.reviewThanks);
      }
    } else {
      // 첫 요청에서 "다음에" → 20번 뒤 한 번 더, 그 뒤엔 묻지 않음
      prefs.reviewNextAt = prefs.reviewNextAt <= 5 ? prefs.actionCount + 20 : 0;
      await prefs.save();
    }
  }
}
