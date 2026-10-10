import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';

import 'backup.dart';
import 'home_widget_sync.dart';
import 'lock.dart';
import 'prefs.dart';
import 'reminder.dart';
import 'review.dart';
import 'screens/onboarding.dart';
import 'screens/bucket.dart';
import 'screens/career.dart';
import 'screens/diary.dart';
import 'screens/stats.dart';
import 'screens/goals.dart';
import 'screens/home.dart';
import 'store.dart';
import 'theme.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'i18n.dart';
import 'pro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.instance.load();
  await AppPrefs.instance.load();
  // 이미 기록이 있는 사용자(업데이트)는 첫 실행 안내를 건너뜀
  final s = AppStore.instance;
  if (!AppPrefs.instance.onboarded &&
      (s.diaries.isNotEmpty || s.buckets.isNotEmpty || s.goals.isNotEmpty || s.careers.isNotEmpty)) {
    await AppPrefs.instance.update((p) => p.onboarded = true);
  }
  ReviewPrompt.start();
  await initializeDateFormatting();
  AppLock.instance.lockOnStart();
  registerFontLicenses();
  HomeWidgetSync.start();
  await Reminder.init(); // 알림을 눌러 열린 경우를 알아야 해서 먼저
  runApp(const LifeBoxApp());
  // 구글 로그인 복구 → 필요하면 자동 백업 (화면 표시를 막지 않음)
  unawaited(ProService.instance.init());
  unawaited(BackupService.instance.init().then((_) => BackupService.instance.autoBackupIfNeeded()));
}

class LifeBoxApp extends StatelessWidget {
  const LifeBoxApp({super.key});

  static String? _navLang;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPrefs.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        // 언어가 바뀌거나 첫 실행 안내가 끝나면 화면 전체를 새로 그림 (Navigator 키도 새로)
        final appKey = '$appLang/${prefs.onboarded}';
        if (_navLang != appKey) {
          _navLang = appKey;
          ReviewPrompt.navigatorKey = GlobalKey<NavigatorState>();
        }
        return MaterialApp(
        key: ValueKey(appKey),
        navigatorKey: ReviewPrompt.navigatorKey,
        title: 'LifeBox',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(colorIndex: prefs.colorIndex, brightness: Brightness.light, font: prefs.font),
        darkTheme: buildTheme(colorIndex: prefs.colorIndex, brightness: Brightness.dark, font: prefs.font),
        themeMode: prefs.themeMode,
        locale: Locale(appLang),
        supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          // 글자 크기: 기기 설정 × 앱 설정 × 글꼴 보정
          final mq = MediaQuery.of(context);
          final factor = prefs.textScale * fontByKey(prefs.font).sizeFactor;
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * factor)),
            child: ListenableBuilder(
              listenable: AppLock.instance,
              builder: (context, _) => Stack(children: [
                child ?? const SizedBox.shrink(),
                if (AppLock.instance.locked) const Positioned.fill(child: LockOverlay()),
              ]),
            ),
          );
        },
        home: prefs.onboarded ? const Shell() : const OnboardingScreen(),
      );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 0;

  StreamSubscription<Uri?>? _widgetClicks;
  StreamSubscription<String?>? _notificationTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 홈 화면 위젯을 눌러서 들어온 경우
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_openFromWidget);
    _widgetClicks = HomeWidget.widgetClicked.listen(_openFromWidget);
    // 처음 홈이 열리면 알림 권한을 묻고 매일 일기 알림을 기본으로 켬
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted) AppLock.instance.runExternal(Reminder.askOnFirstUse);
      });
    });
    // 일기 알림을 눌러서 들어온 경우
    if (Reminder.launchPayload == 'diary') _openFromWidget(Uri.parse('lifebox://diary/new'));
    _notificationTaps = Reminder.taps.listen((p) {
      if (p == 'diary') _openFromWidget(Uri.parse('lifebox://diary/new'));
    });
  }

  void _openFromWidget(Uri? uri) {
    if (uri == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      switch (uri.host) {
        case 'diary':
          setState(() => _index = 3);
          openDiaryEditor(context, null);
        case 'stats':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
        default:
          setState(() => _index = 0);
      }
    });
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    _notificationTaps?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) => AppPrefs.instance.refresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLock.instance.onLifecycle(state);
    // 앱을 나갈 때 자동 백업
    if (state == AppLifecycleState.paused) {
      BackupService.instance.autoBackupIfNeeded();
    } else if (state == AppLifecycleState.resumed) {
      HomeWidgetSync.schedule(); // 날짜가 바뀌었을 수 있음
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        HomeScreen(onNavigate: (i) => setState(() => _index = i)),
        const BucketScreen(),
        const GoalScreen(),
        const DiaryScreen(),
        const CareerScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: tr.tabHome),
          NavigationDestination(icon: const Icon(Icons.flag_outlined), selectedIcon: const Icon(Icons.flag), label: tr.tabBucket),
          NavigationDestination(icon: const Icon(Icons.track_changes), label: tr.tabGoals),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: tr.tabDiary),
          NavigationDestination(icon: const Icon(Icons.work_outline), selectedIcon: const Icon(Icons.work), label: tr.tabCareer),
        ],
      ),
    );
  }
}
