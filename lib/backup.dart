import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'config.dart';
import 'store.dart';
import 'i18n.dart';

class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => message;
}

/// 구글 드라이브 "앱 전용 폴더(appDataFolder)"에 백업.
/// - 사용자 드라이브에 숨김 폴더로 저장되어 이 앱만 접근 가능
/// - 사진은 한 번 올리면 다시 안 올림 (바뀐 것만 업로드)
/// - 기록(JSON)은 사진을 다 올린 뒤 마지막에 덮어씀 → 백업이 중간에 끊겨도 깨지지 않음
class BackupService extends ChangeNotifier {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _scopes = [drive.DriveApi.driveAppdataScope];
  static const _dataName = 'lifebox_data.json';
  static const _photoPrefix = 'photo_';
  static const _autoInterval = Duration(minutes: 30);

  final _ready = Completer<void>();
  GoogleSignInAccount? account;
  bool busy = false;
  String? progress; // 진행 상황 문구
  DateTime? lastBackup;
  bool autoBackup = true;

  bool get configured => kGoogleServerClientId.isNotEmpty;
  File get _settingsFile => File('${AppStore.instance.dirPath}/backup_settings.json');

  /// 앱 시작 시 한 번 호출 (화면 표시를 막지 않도록 기다리지 않아도 됨)
  Future<void> init() async {
    try {
      await _loadSettings();
      if (!configured) return;
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(serverClientId: kGoogleServerClientId);
      signIn.authenticationEvents.listen((e) {
        account = e is GoogleSignInAuthenticationEventSignIn ? e.user : null;
        notifyListeners();
      }, onError: (Object e) => debugPrint('로그인 이벤트 오류: $e'));
      // 이전에 연결했다면 조용히 다시 로그인
      account = await signIn.attemptLightweightAuthentication();
      notifyListeners();
    } catch (e) {
      debugPrint('백업 초기화 실패: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  // ───── 설정 저장 ─────
  Future<void> _loadSettings() async {
    try {
      if (!await _settingsFile.exists()) return;
      final m = jsonDecode(await _settingsFile.readAsString()) as Map<String, dynamic>;
      autoBackup = m['autoBackup'] as bool? ?? true;
      lastBackup = DateTime.tryParse(m['lastBackup'] as String? ?? '');
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    await _settingsFile.writeAsString(jsonEncode({
      'autoBackup': autoBackup,
      'lastBackup': lastBackup?.toIso8601String(),
    }));
  }

  Future<void> setAutoBackup(bool v) async {
    autoBackup = v;
    notifyListeners();
    await _saveSettings();
  }

  // ───── 계정 ─────
  Future<void> connect() async {
    await _ready.future;
    if (!configured) throw BackupException(tr.bkNotConfigured);
    account = await GoogleSignIn.instance.authenticate();
    // 드라이브 권한도 바로 받아 둔다
    await account!.authorizationClient.authorizeScopes(_scopes);
    notifyListeners();
  }

  /// 잠금 해제용: 구글 로그인 후 이메일 반환
  Future<String?> verifyGoogleAccount() async {
    await _ready.future;
    if (!configured) throw BackupException(tr.bkNotConfigured);
    final acc = await GoogleSignIn.instance.authenticate();
    account = acc;
    notifyListeners();
    return acc.email;
  }

  Future<void> disconnect() async {
    await _ready.future;
    if (configured) await GoogleSignIn.instance.disconnect();
    account = null;
    notifyListeners();
  }

  Future<drive.DriveApi> _api({required bool interactive}) async {
    await _ready.future;
    if (!configured) throw BackupException(tr.bkNotConfigured);
    var acc = account;
    if (acc == null) {
      if (!interactive) throw BackupException(tr.bkConnectFirst);
      acc = account = await GoogleSignIn.instance.authenticate();
    }
    var authz = await acc.authorizationClient.authorizationForScopes(_scopes);
    if (authz == null) {
      if (!interactive) throw BackupException(tr.bkNeedPermission);
      authz = await acc.authorizationClient.authorizeScopes(_scopes);
    }
    return drive.DriveApi(authz.authClient(scopes: _scopes));
  }

  Future<Map<String, drive.File>> _listRemote(drive.DriveApi api) async {
    final result = <String, drive.File>{};
    String? token;
    do {
      final page = await api.files.list(
        spaces: 'appDataFolder',
        $fields: 'nextPageToken, files(id, name, modifiedTime)',
        pageSize: 1000,
        pageToken: token,
      );
      for (final f in page.files ?? <drive.File>[]) {
        if (f.name != null) result[f.name!] = f;
      }
      token = page.nextPageToken;
    } while (token != null);
    return result;
  }

  void _setProgress(String? p) {
    progress = p;
    notifyListeners();
  }

  /// 드라이브에 있는 백업 시각 (없으면 null)
  Future<DateTime?> remoteBackupTime() async {
    final api = await _api(interactive: true);
    return (await _listRemote(api))[_dataName]?.modifiedTime?.toLocal();
  }

  // ───── 백업 ─────
  Future<void> backup({bool interactive = true}) async {
    if (busy) return;
    busy = true;
    _setProgress(tr.bkChecking);
    try {
      final api = await _api(interactive: interactive);
      final store = AppStore.instance;
      final remote = await _listRemote(api);
      final photos = store.usedPhotos;

      final toUpload = photos.where((p) => !remote.containsKey('$_photoPrefix$p')).toList();
      for (var i = 0; i < toUpload.length; i++) {
        _setProgress(tr.bkUploadingPhotos(i + 1, toUpload.length));
        final file = store.photoFile(toUpload[i]);
        if (!await file.exists()) continue;
        await api.files.create(
          drive.File()
            ..name = '$_photoPrefix${toUpload[i]}'
            ..parents = ['appDataFolder'],
          uploadMedia: drive.Media(file.openRead(), await file.length()),
        );
      }

      _setProgress(tr.bkSavingData);
      final bytes = utf8.encode(jsonEncode(store.toMap()));
      final media = drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/json');
      final existing = remote[_dataName];
      if (existing?.id != null) {
        await api.files.update(drive.File(), existing!.id!, uploadMedia: media);
      } else {
        await api.files.create(
          drive.File()
            ..name = _dataName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
        );
      }

      // 더 이상 안 쓰는 사진은 드라이브에서도 정리
      for (final e in remote.entries) {
        if (e.key.startsWith(_photoPrefix) &&
            !photos.contains(e.key.substring(_photoPrefix.length)) &&
            e.value.id != null) {
          await api.files.delete(e.value.id!);
        }
      }

      lastBackup = DateTime.now();
      await _saveSettings();
    } finally {
      busy = false;
      _setProgress(null);
    }
  }

  // ───── 복원 ─────
  Future<void> restore() async {
    if (busy) return;
    busy = true;
    _setProgress(tr.bkFinding);
    try {
      final api = await _api(interactive: true);
      final remote = await _listRemote(api);
      final dataFile = remote[_dataName];
      if (dataFile?.id == null) throw BackupException(tr.bkNoBackup);

      final media = await api.files.get(dataFile!.id!,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final text = await utf8.decodeStream(media.stream);
      final map = jsonDecode(text) as Map<String, dynamic>;

      // 사진 먼저 받아 두고, 마지막에 기록을 교체
      final store = AppStore.instance;
      final needed = <String>{
        for (final key in const ['buckets', 'diaries', 'careers'])
          if (map[key] is List)
            for (final item in map[key] as List)
              if (item is Map && item['photos'] is List)
                ...(item['photos'] as List).map((p) => p.toString()),
        if (map['profile'] is Map && ((map['profile'] as Map)['photo'] ?? '') != '')
          (map['profile'] as Map)['photo'].toString(),
      };

      final missing = <String>[];
      for (final p in needed) {
        if (!await store.photoFile(p).exists()) missing.add(p);
      }
      for (var i = 0; i < missing.length; i++) {
        _setProgress(tr.bkDownloadingPhotos(i + 1, missing.length));
        final f = remote['$_photoPrefix${missing[i]}'];
        if (f?.id == null) continue;
        final m = await api.files.get(f!.id!, downloadOptions: drive.DownloadOptions.fullMedia)
            as drive.Media;
        final tmp = File('${store.photoFile(missing[i]).path}.part');
        final sink = tmp.openWrite();
        await m.stream.pipe(sink);
        await tmp.rename(store.photoFile(missing[i]).path);
      }

      _setProgress(tr.bkRestoring);
      await store.replaceAll(map);
    } finally {
      busy = false;
      _setProgress(null);
    }
  }

  /// 자동 백업: 연결돼 있고, 기록이 바뀌었고, 마지막 백업 후 30분이 지났을 때만
  Future<void> autoBackupIfNeeded() async {
    if (!autoBackup || busy || !configured) return;
    await _ready.future;
    if (account == null) return;
    final modified = await AppStore.instance.dataModifiedAt();
    if (modified == null) return;
    final last = lastBackup;
    if (last != null) {
      if (!modified.isAfter(last)) return;
      if (DateTime.now().difference(last) < _autoInterval) return;
    }
    try {
      await backup(interactive: false);
    } catch (e) {
      debugPrint('자동 백업 실패: $e');
    }
  }
}

String backupErrorText(Object e) {
  if (e is BackupException) return e.message;
  if (e is GoogleSignInException) {
    if (e.code == GoogleSignInExceptionCode.canceled) return tr.errCanceled;
    return tr.errGoogle(e.code.name);
  }
  if (e is SocketException || e is TimeoutException) return tr.errNetwork;
  return tr.errGeneric(e);
}
