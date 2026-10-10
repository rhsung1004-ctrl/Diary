import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backup.dart';
import '../common.dart';
import '../lock.dart';
import '../prefs.dart';
import '../reminder.dart';
import '../theme.dart';
import '../i18n.dart';
import '../pro.dart';

const _langNames = {'ko': '한국어', 'en': 'English', 'ja': '日本語'};
const _privacyUrl = 'https://github.com/rhsung1004-ctrl/Diary/blob/main/PRIVACY.md';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr.settings)),
      // 메뉴만 짧게 보여주고, 누르면 각 설정 화면으로
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Card(
          child: Column(children: [
            ListTile(
              leading: const Text('💎', style: TextStyle(fontSize: 22)),
              title: Text(tr.proName),
              subtitle: ListenableBuilder(
                listenable: AppPrefs.instance,
                builder: (context, _) =>
                    Text(AppPrefs.instance.isPro ? tr.proActive : tr.proTagline),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProScreen())),
            ),
            const Divider(height: 1),
            _menu(context, Icons.palette_outlined, tr.display, tr.setDisplaySub, const _AppearanceSection()),
            _menu(context, Icons.notifications_outlined, tr.notifications, tr.setNotifSub, const _ReminderSection()),
            _menu(context, Icons.lock_outline, tr.security, tr.setSecuritySub, const _LockSection()),
            _menu(context, Icons.cloud_outlined, tr.driveBackup, tr.setBackupSub, const _BackupSection()),
            _menu(context, Icons.info_outline, tr.about, tr.setAboutSub, const _AboutSection()),
          ]),
        ),
      ]),
    );
  }

  Widget _menu(BuildContext context, IconData icon, String title, String sub, Widget section) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [section]),
            ),
          ),
        ),
      );
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
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(tr.language),
                subtitle: Text(prefs.language == 'system'
                    ? '${tr.languageSystem} (${_langNames[appLang]})'
                    : _langNames[prefs.language] ?? prefs.language),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickLanguage(context),
              ),
              ListTile(title: Text(tr.themeColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 12, runSpacing: 12, children: [
                  for (var i = 0; i < themeColors.length; i++)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        // 기본 색(숲) 외에는 프로
                        if (i != 0 && !await requirePro(context)) return;
                        await prefs.update((p) => p.colorIndex = i);
                      },
                      child: Column(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: themeColors[i].seed,
                          child: prefs.colorIndex == i
                              ? const Icon(Icons.check, color: Colors.white)
                              : (i != 0 && !ProService.instance.isPro
                                  ? const Icon(Icons.lock_outline, color: Colors.white70, size: 16)
                                  : null),
                        ),
                        const SizedBox(height: 4),
                        Text(themeColors[i].name, style: t.textTheme.labelSmall),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              ListTile(title: Text(tr.darkMode)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: ThemeMode.system, label: Text(tr.modeSystem)),
                    ButtonSegment(value: ThemeMode.light, label: Text(tr.modeLight)),
                    ButtonSegment(value: ThemeMode.dark, label: Text(tr.modeDark)),
                  ],
                  selected: {prefs.themeMode},
                  onSelectionChanged: (s) => prefs.update((p) => p.themeMode = s.first),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(tr.font),
                subtitle: Text(font.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickFont(context),
              ),
              ListTile(
                title: Text(tr.textSize),
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

  void _pickLanguage(BuildContext context) {
    final prefs = AppPrefs.instance;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final code in ['system', ...supportedLangs])
            ListTile(
              leading: Icon(prefs.language == code
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(code == 'system' ? tr.languageSystem : _langNames[code]!),
              onTap: () async {
                Navigator.pop(ctx);
                await prefs.update((p) => p.language = code);
                await Reminder.reschedule(); // 알림 문구도 새 언어로
              },
            ),
        ]),
      ),
    );
  }

  void _pickFont(BuildContext context) {
    final prefs = AppPrefs.instance;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final f in fontsFor(appLang))
            ListTile(
              leading: Icon(fontByKey(prefs.font).key == f.key
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              trailing: f.key != fontsFor(appLang).first.key ? const ProBadge() : null,
              onTap: () async {
                // 언어별 기본 글꼴 외에는 프로
                if (f.key != fontsFor(appLang).first.key && !await requirePro(ctx)) return;
                await prefs.update((p) => p.font = f.key);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              title: Text(f.label,
                  style: TextStyle(fontFamily: f.family, fontSize: 16 * f.sizeFactor)),
              subtitle: Text(tr.fontSample,
                  style: TextStyle(fontFamily: f.family, fontSize: 14 * f.sizeFactor)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(tr.fontLicenseNote, style: const TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── 알림 ─────────────────────────
class _ReminderSection extends StatelessWidget {
  const _ReminderSection();

  Future<void> _toggle(BuildContext context, bool on) async {
    if (on && !await AppLock.instance.runExternal(Reminder.requestPermission)) {
      if (context.mounted) toast(context, tr.notifPermissionOff);
      return;
    }
    await AppPrefs.instance.update((p) => p.reminderOn = on);
    await Reminder.reschedule();
  }

  Future<void> _pickTime(BuildContext context) async {
    final prefs = AppPrefs.instance;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.reminderHour, minute: prefs.reminderMinute),
    );
    if (t == null) return;
    await prefs.update((p) {
      p.reminderHour = t.hour;
      p.reminderMinute = t.minute;
    });
    await Reminder.reschedule();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppPrefs.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Card(
        child: Column(children: [
          SwitchListTile(
            title: Text(tr.dailyReminder),
            subtitle: Text(tr.dailyReminderSub),
            value: prefs.reminderOn,
            onChanged: (v) => _toggle(context, v),
          ),
          if (prefs.reminderOn)
            ListTile(
              title: Text(tr.reminderTime),
              trailing: Text(
                TimeOfDay(hour: prefs.reminderHour, minute: prefs.reminderMinute).format(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => _pickTime(context),
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
        tr.lockNoAccountTitle,
        tr.lockNoAccountBody,
        tr.turnOn,
      );
      if (!go || !mounted) return;
    }
    final pin = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
    if (pin == null) return;
    await AppLock.instance.setPin(pin, recoveryEmail: email);
    if (mounted) toast(context, tr.lockOnDone);
  }

  Future<void> _changePin() async {
    final pin = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
    if (pin == null) return;
    await AppLock.instance.setPin(pin,
        recoveryEmail: BackupService.instance.account?.email ?? AppPrefs.instance.lockRecoveryEmail);
    if (mounted) toast(context, tr.pinChanged);
  }

  Future<void> _toggleBio(bool v) async {
    if (v && !await requirePro(context)) return;
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
            title: Text(tr.appLock),
            subtitle: Text(tr.appLockSub),
            value: prefs.lockEnabled,
            onChanged: (v) async {
              if (v) {
                await _enable();
              } else if (await confirmDialog(context, tr.appLockOffTitle, '', tr.turnOff)) {
                await AppLock.instance.disable();
              }
            },
          ),
          if (prefs.lockEnabled) ...[
            ListTile(
              title: Text(tr.changePin),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePin,
            ),
            if (_bioAvailable)
              SwitchListTile(
                title: Text(tr.useBiometric),
                value: prefs.biometric,
                onChanged: _toggleBio,
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.info_outline, size: 20),
              title: Text(prefs.lockRecoveryEmail == null
                  ? tr.pinNoRecovery
                  : tr.pinRecoveryWith(prefs.lockRecoveryEmail!)),
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
          return Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(tr.backupPreparing),
              subtitle: Text(tr.backupPreparingSub),
            ),
          );
        }
        if (acc == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr.backupIntro,
                    style: t.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text(tr.backupPrivacy,
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: Text(tr.connectGoogle),
                  onPressed: svc.busy ? null : () => _run(context, svc.connect, tr.connected),
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
                  child: Text(tr.disconnect),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(tr.lastBackup),
                subtitle: Text(svc.lastBackup == null ? tr.noneYet : fmtDateTime(svc.lastBackup!)),
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
                      label: Text(tr.backupNow),
                      onPressed: svc.busy ? null : () => _run(context, svc.backup, tr.backedUp),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: Text(tr.restore),
                      onPressed: svc.busy ? null : () => _restore(context),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          Card(
            child: SwitchListTile(
              title: Text(tr.autoBackup),
              subtitle: Text(tr.autoBackupSub),
              value: svc.autoBackup,
              onChanged: (v) async {
                if (v && !await requirePro(context)) return;
                await svc.setAutoBackup(v);
              },
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
    final ok = await confirmDialog(context, tr.disconnectTitle, tr.disconnectBody, tr.disconnectAction);
    if (ok && context.mounted) await _run(context, BackupService.instance.disconnect, tr.disconnected);
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
      toast(context, tr.bkNoBackup);
      return;
    }
    final ok = await confirmDialog(
      context,
      tr.restoreTitle,
      tr.restoreBody(fmtDateTime(remoteTime)),
      tr.restore,
    );
    if (ok && context.mounted) await _run(context, svc.restore, tr.restored);
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
          title: Text(tr.privacyPolicy),
          subtitle: Text(tr.copyAddress),
          onTap: () {
            Clipboard.setData(const ClipboardData(text: _privacyUrl));
            toast(context, tr.addressCopied);
          },
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(tr.openSourceLicenses),
          onTap: () => showLicensePage(context: context, applicationName: 'LifeBox'),
        ),
      ]),
    );
  }
}
