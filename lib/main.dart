import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';

import 'backup.dart';
import 'home_widget_sync.dart';
import 'lock.dart';
import 'prefs.dart';
import 'screens/bucket.dart';
import 'screens/career.dart';
import 'screens/diary.dart';
import 'screens/stats.dart';
import 'screens/goals.dart';
import 'screens/home.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.instance.load();
  await AppPrefs.instance.load();
  AppLock.instance.lockOnStart();
  registerFontLicenses();
  HomeWidgetSync.start();
  runApp(const LifeBoxApp());
  // 구글 로그인 복구 → 필요하면 자동 백업 (화면 표시를 막지 않음)
  unawaited(BackupService.instance.init().then((_) => BackupService.instance.autoBackupIfNeeded()));
}

class LifeBoxApp extends StatelessWidget {
  const LifeBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = AppPrefs.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => MaterialApp(
        title: 'LifeBox',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(colorIndex: prefs.colorIndex, brightness: Brightness.light, font: prefs.font),
        darkTheme: buildTheme(colorIndex: prefs.colorIndex, brightness: Brightness.dark, font: prefs.font),
        themeMode: prefs.themeMode,
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: const [
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
        home: const Shell(),
      ),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 홈 화면 위젯을 눌러서 들어온 경우
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_openFromWidget);
    _widgetClicks = HomeWidget.widgetClicked.listen(_openFromWidget);
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: '버킷'),
          NavigationDestination(icon: Icon(Icons.track_changes), label: '목표'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '일기'),
          NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: '커리어'),
        ],
      ),
    );
  }
}
