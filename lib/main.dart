import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/bucket.dart';
import 'screens/career.dart';
import 'screens/diary.dart';
import 'screens/goals.dart';
import 'screens/home.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.instance.load();
  runApp(const LifeBoxApp());
}

class LifeBoxApp extends StatelessWidget {
  const LifeBoxApp({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3D7A6E),
        brightness: b,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeBox',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

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
