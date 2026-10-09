import 'package:flutter/material.dart';

import '../backup.dart';
import '../common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = BackupService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListenableBuilder(
        listenable: svc,
        builder: (context, _) {
          final t = Theme.of(context);
          final acc = svc.account;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            const SectionTitle('구글 드라이브 백업'),
            if (!svc.configured)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('백업 기능 준비 중'),
                  subtitle: Text('구글 연동 설정이 끝나면 사용할 수 있어요.'),
                ),
              )
            else if (acc == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('구글 계정을 연결하면 기록과 사진을 내 구글 드라이브에 보관해요.',
                        style: t.textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text('드라이브의 숨김 앱 폴더에 저장되어 이 앱만 볼 수 있고, 개발자에게는 전송되지 않아요.',
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Google 계정 연결'),
                      onPressed: svc.busy ? null : () => _run(context, svc.connect, '연결됐어요'),
                    ),
                  ]),
                ),
              )
            else ...[
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('자동 백업'),
                subtitle: const Text('기록이 바뀌었으면 앱을 나갈 때 알아서 백업해요'),
                value: svc.autoBackup,
                onChanged: svc.setAutoBackup,
              ),
            ],
          ]);
        },
      ),
    );
  }

  Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
    try {
      await action();
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
      remoteTime = await svc.remoteBackupTime();
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
