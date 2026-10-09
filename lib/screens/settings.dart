import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backup.dart';
import '../common.dart';
import '../lock.dart';
import '../prefs.dart';
import '../theme.dart';

const _privacyUrl = 'https://github.com/rhsung1004-ctrl/Diary/blob/main/PRIVACY.md';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: const [
        SectionTitle('화면'),
        _AppearanceSection(),
        SectionTitle('보안'),
        _LockSection(),
        SectionTitle('구글 드라이브 백업'),
        _BackupSection(),
        SectionTitle('정보'),
        _AboutSection(),
      ]),
    );
  }
}

// ───────────────────────── 화면 ─────────────────────────
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final prefs = AppPrefs.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final t = Theme.of(context);
        final font = fontByKey(prefs.font);
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ListTile(title: Text('테마 색')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 12, runSpacing: 12, children: [
                  for (var i = 0; i < themeColors.length; i++)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => prefs.update((p) => p.colorIndex = i),
                      child: Column(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: themeColors[i].seed,
                          child: prefs.colorIndex == i
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(themeColors[i].name, style: t.textTheme.labelSmall),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              const ListTile(title: Text('다크 모드')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('기기 설정')),
                    ButtonSegment(value: ThemeMode.light, label: Text('밝게')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('어둡게')),
                  ],
                  selected: {prefs.themeMode},
                  onSelectionChanged: (s) => prefs.update((p) => p.themeMode = s.first),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('글꼴'),
                subtitle: Text(font.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickFont(context),
              ),
              ListTile(
                title: const Text('글자 크기'),
                trailing: Text('${(prefs.textScale * 100).round()}%'),
              ),
              Slider(
                value: prefs.textScale,
                min: 0.85,
                max: 1.3,
                divisions: 9,
                label: '${(prefs.textScale * 100).round()}%',
                onChanged: (v) => prefs.update((p) => p.textScale = v),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _pickFont(BuildContext context) {
    final prefs = AppPrefs.instance;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final f in fontOptions)
            ListTile(
              leading: Icon(prefs.font == f.key
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              onTap: () {
                prefs.update((p) => p.font = f.key);
                Navigator.pop(ctx);
              },
              title: Text(f.label,
                  style: TextStyle(fontFamily: f.family, fontSize: 16 * f.sizeFactor)),
              subtitle: Text('오늘 하루도 기록해 볼까요? 123 ABC',
                  style: TextStyle(fontFamily: f.family, fontSize: 14 * f.sizeFactor)),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text('모든 글꼴은 SIL 오픈 폰트 라이선스로 무료 사용 가능해요.',
                style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── 보안 ─────────────────────────
class _LockSection extends StatefulWidget {
  const _LockSection();

  @override
  State<_LockSection> createState() => _LockSectionState();
}

class _LockSectionState extends State<_LockSection> {
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    AppLock.instance.biometricAvailable().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  Future<void> _enable() async {
    final email = BackupService.instance.account?.email;
    if (email == null) {
      final go = await confirmDialog(
        context,
        '구글 계정이 연결되지 않았어요',
        'PIN을 잊었을 때 잠금을 풀 방법이 없어요.\n아래 "구글 드라이브 백업"에서 계정을 먼저 연결하는 걸 추천해요.\n\n그래도 잠금을 켤까요?',
        '켜기',
      );
      if (!go || !mounted) return;
    }
    final pin = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
    if (pin == null) return;
    await AppLock.instance.setPin(pin, recoveryEmail: email);
    if (mounted) toast(context, '앱 잠금을 켰어요');
  }

  Future<void> _changePin() async {
    final pin = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
    if (pin == null) return;
    await AppLock.instance.setPin(pin,
        recoveryEmail: BackupService.instance.account?.email ?? AppPrefs.instance.lockRecoveryEmail);
    if (mounted) toast(context, 'PIN을 바꿨어요');
  }

  Future<void> _toggleBio(bool v) async {
    if (v && !await AppLock.instance.authenticateBiometric()) return;
    await AppPrefs.instance.update((p) => p.biometric = v);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppPrefs.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Card(
        child: Column(children: [
          SwitchListTile(
            title: const Text('앱 잠금'),
            subtitle: const Text('앱을 열 때 PIN을 물어봐요'),
            value: prefs.lockEnabled,
            onChanged: (v) async {
              if (v) {
                await _enable();
              } else if (await confirmDialog(context, '앱 잠금을 끌까요?', '', '끄기')) {
                await AppLock.instance.disable();
              }
            },
          ),
          if (prefs.lockEnabled) ...[
            ListTile(
              title: const Text('PIN 변경'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePin,
            ),
            if (_bioAvailable)
              SwitchListTile(
                title: const Text('지문·얼굴 인식으로 열기'),
                value: prefs.biometric,
                onChanged: _toggleBio,
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.info_outline, size: 20),
              title: Text(prefs.lockRecoveryEmail == null
                  ? 'PIN을 잊으면 복구할 수 없어요'
                  : 'PIN을 잊으면 ${prefs.lockRecoveryEmail} 계정으로 풀 수 있어요'),
            ),
          ],
        ]),
      ),
    );
  }
}

// ───────────────────────── 백업 ─────────────────────────
class _BackupSection extends StatelessWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context) {
    final svc = BackupService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final t = Theme.of(context);
        final acc = svc.account;
        if (!svc.configured) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text('백업 기능 준비 중'),
              subtitle: Text('구글 연동 설정이 끝나면 사용할 수 있어요.'),
            ),
          );
        }
        if (acc == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('구글 계정을 연결하면 기록과 사진을 내 구글 드라이브에 보관해요.',
                    style: t.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text('드라이브의 숨김 앱 폴더에 저장되어 이 앱만 볼 수 있고, 개발자에게는 전송되지 않아요.',
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Google 계정 연결'),
                  onPressed: svc.busy ? null : () => _run(context, svc.connect, '연결됐어요'),
                ),
              ]),
            ),
          );
        }
        return Column(children: [
          Card(
            child: Column(children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(acc.displayName ?? acc.email),
                subtitle: Text(acc.email),
                trailing: TextButton(
                  onPressed: svc.busy ? null : () => _disconnect(context),
                  child: const Text('연결 해제'),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: const Text('마지막 백업'),
                subtitle: Text(svc.lastBackup == null ? '아직 없어요' : fmtDateTime(svc.lastBackup!)),
              ),
              if (svc.busy)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    Text(svc.progress ?? '', style: t.textTheme.bodySmall),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('지금 백업'),
                      onPressed: svc.busy ? null : () => _run(context, svc.backup, '백업했어요'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('복원'),
                      onPressed: svc.busy ? null : () => _restore(context),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('자동 백업'),
              subtitle: const Text('기록이 바뀌었으면 앱을 나갈 때 알아서 백업해요'),
              value: svc.autoBackup,
              onChanged: svc.setAutoBackup,
            ),
          ),
        ]);
      },
    );
  }

  Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
    try {
      await AppLock.instance.runExternal(action);
      if (context.mounted) toast(context, done);
    } catch (e) {
      if (context.mounted) toast(context, backupErrorText(e));
    }
  }

  Future<void> _disconnect(BuildContext context) async {
    final ok = await confirmDialog(context, '연결을 해제할까요?',
        '드라이브에 있는 백업은 지워지지 않아요. 다시 연결하면 복원할 수 있어요.', '해제');
    if (ok && context.mounted) await _run(context, BackupService.instance.disconnect, '연결을 해제했어요');
  }

  Future<void> _restore(BuildContext context) async {
    final svc = BackupService.instance;
    DateTime? remoteTime;
    try {
      remoteTime = await AppLock.instance.runExternal(svc.remoteBackupTime);
    } catch (e) {
      if (context.mounted) toast(context, backupErrorText(e));
      return;
    }
    if (!context.mounted) return;
    if (remoteTime == null) {
      toast(context, '드라이브에 백업이 없어요');
      return;
    }
    final ok = await confirmDialog(
      context,
      '백업으로 복원할까요?',
      '${fmtDateTime(remoteTime)} 백업으로 지금 폰의 기록을 바꿔요.\n그 이후에 쓴 기록은 사라질 수 있어요.',
      '복원',
    );
    if (ok && context.mounted) await _run(context, svc.restore, '복원했어요');
  }
}

// ───────────────────────── 정보 ─────────────────────────
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('개인정보처리방침'),
          subtitle: const Text('주소 복사'),
          onTap: () {
            Clipboard.setData(const ClipboardData(text: _privacyUrl));
            toast(context, '주소를 복사했어요. 브라우저에 붙여넣어 보세요');
          },
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('오픈소스 라이선스'),
          onTap: () => showLicensePage(context: context, applicationName: 'LifeBox'),
        ),
      ]),
    );
  }
}
