import 'package:flutter/material.dart';

import '../backup.dart';
import '../common.dart';
import '../i18n.dart';
import '../lock.dart';
import '../prefs.dart';
import '../theme.dart';
import '../pro.dart';

const _langNames = {'ko': '한국어', 'en': 'English', 'ja': '日本語'};

/// 첫 실행 안내 (4장)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  // 언어를 바꾸면 앱 전체가 다시 그려지므로, 보던 페이지를 기억해 둠
  static int lastPage = 0;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = 4;
  late int _page = OnboardingScreen.lastPage;
  late final _ctl = PageController(initialPage: OnboardingScreen.lastPage);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    OnboardingScreen.lastPage = 0;
    await AppPrefs.instance.update((p) => p.onboarded = true);
  }

  void _next() {
    if (_page == _pages - 1) {
      _finish();
    } else {
      _ctl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _page == _pages - 1 ? null : _finish,
              child: Text(_page == _pages - 1 ? '' : tr.obSkip),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _ctl,
              onPageChanged: (i) => setState(() => _page = OnboardingScreen.lastPage = i),
              children: const [_Welcome(), _Features(), _Style(), _Backup()],
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _pages; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? t.colorScheme.primary : t.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _next,
                child: Text(_page == _pages - 1 ? tr.obStart : tr.obNext),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final Widget top;
  final String title;
  final String? body;
  final Widget? child;
  const _Page({required this.top, required this.title, this.body, this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(children: [
        const SizedBox(height: 24),
        top,
        const SizedBox(height: 28),
        Text(title,
            textAlign: TextAlign.center,
            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        if (body != null) ...[
          const SizedBox(height: 12),
          Text(body!,
              textAlign: TextAlign.center,
              style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant, height: 1.5)),
        ],
        if (child != null) ...[const SizedBox(height: 24), child!],
      ]),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return _Page(
      top: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 140,
          height: 140,
          color: Theme.of(context).colorScheme.primary,
          child: const Center(child: Text('📦', style: TextStyle(fontSize: 72))),
        ),
      ),
      title: tr.obWelcomeTitle,
      body: tr.obWelcomeBody,
    );
  }
}

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final items = [tr.obF1, tr.obF2, tr.obF3, tr.obF4, tr.obF5];
    return _Page(
      top: const Text('✨', style: TextStyle(fontSize: 72)),
      title: tr.obFeaturesTitle,
      child: Column(children: [
        for (final s in items)
          Card(
            elevation: 0,
            color: t.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [Expanded(child: Text(s, style: t.textTheme.bodyLarge))]),
            ),
          ),
      ]),
    );
  }
}

class _Style extends StatelessWidget {
  const _Style();

  @override
  Widget build(BuildContext context) {
    final prefs = AppPrefs.instance;
    final t = Theme.of(context);
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => _Page(
        top: const Text('🎨', style: TextStyle(fontSize: 72)),
        title: tr.obStyleTitle,
        body: tr.obStyleBody,
        child: Column(children: [
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (final code in ['system', ...supportedLangs])
              ChoiceChip(
                label: Text(code == 'system' ? tr.languageSystem : _langNames[code]!),
                selected: prefs.language == code,
                onSelected: (_) => prefs.update((p) => p.language = code),
              ),
          ]),
          const SizedBox(height: 24),
          Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < themeColors.length; i++)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  if (i != 0 && !await requirePro(context)) return;
                  await prefs.update((p) => p.colorIndex = i);
                },
                child: Column(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: themeColors[i].seed,
                    child: prefs.colorIndex == i ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                  const SizedBox(height: 4),
                  Text(themeColors[i].name, style: t.textTheme.labelSmall),
                ]),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _Backup extends StatelessWidget {
  const _Backup();

  @override
  Widget build(BuildContext context) {
    final svc = BackupService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) => _Page(
        top: const Text('☁️', style: TextStyle(fontSize: 72)),
        title: tr.obBackupTitle,
        body: tr.obBackupBody,
        child: !svc.configured
            ? const SizedBox.shrink()
            : svc.account != null
                ? Chip(avatar: const Icon(Icons.check_circle, size: 18), label: Text(svc.account!.email))
                : Column(children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.login),
                      label: Text(tr.connectGoogle),
                      onPressed: svc.busy
                          ? null
                          : () async {
                              try {
                                await AppLock.instance.runExternal(svc.connect);
                                if (context.mounted) toast(context, tr.connected);
                              } catch (e) {
                                if (context.mounted) toast(context, backupErrorText(e));
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    Text(tr.obBackupLater,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
      ),
    );
  }
}
