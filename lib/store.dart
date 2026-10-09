import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// 앱 전체 데이터 저장소.
/// - 기록은 앱 전용 폴더의 data.json 한 파일에 저장
/// - 사진은 같은 폴더의 photos/ 에 복사해서 보관 (원본을 지워도 안전)
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  late Directory _dir;
  late Directory photoDir;

  List<BucketItem> buckets = [];
  List<Goal> goals = [];
  List<DiaryEntry> diaries = [];
  List<CareerItem> careers = [];
  Profile profile = Profile();

  /// 작성 중인 일기 (key: 'new' 또는 수정 중인 일기 id)
  final Map<String, DiaryDraft> drafts = {};

  /// 사용자가 기록을 저장할 때마다 호출 (리뷰 요청 횟수 세기)
  VoidCallback? onUserAction;

  File get _dataFile => File('${_dir.path}/data.json');

  Future<void> load() async {
    _dir = await getApplicationDocumentsDirectory();
    photoDir = Directory('${_dir.path}/photos');
    if (!await photoDir.exists()) await photoDir.create(recursive: true);

    var loadedOk = true;
    if (await _dataFile.exists()) {
      try {
        applyMap(jsonDecode(await _dataFile.readAsString()) as Map<String, dynamic>);
      } catch (e) {
        // 파일이 깨졌으면 지우지 않고 옆에 보관해 둔다
        loadedOk = false;
        debugPrint('data.json 읽기 실패: $e');
        final ts = DateTime.now().millisecondsSinceEpoch;
        await _dataFile.copy('${_dir.path}/data.broken-$ts.json');
      }
    }
    await _loadDrafts();
    if (loadedOk) await _cleanUnusedPhotos();
  }

  List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) => v is List
      ? v.map((e) => f(Map<String, dynamic>.from(e as Map))).toList()
      : <T>[];

  String get dirPath => _dir.path;

  Map<String, dynamic> toMap() => {
        'version': 1,
        'buckets': buckets.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'diaries': diaries.map((e) => e.toJson()).toList(),
        'careers': careers.map((e) => e.toJson()).toList(),
        'profile': profile.toJson(),
      };

  void applyMap(Map<String, dynamic> m) {
    buckets = _list(m['buckets'], BucketItem.fromJson);
    goals = _list(m['goals'], Goal.fromJson);
    diaries = _list(m['diaries'], DiaryEntry.fromJson);
    careers = _list(m['careers'], CareerItem.fromJson);
    profile = m['profile'] is Map
        ? Profile.fromJson(Map<String, dynamic>.from(m['profile'] as Map))
        : Profile();
  }

  /// 모든 기록이 쓰고 있는 사진 파일 이름
  Set<String> get usedPhotos => {
        ...buckets.expand((e) => e.photos),
        ...diaries.expand((e) => e.photos),
        ...careers.expand((e) => e.photos),
        if (profile.photo.isNotEmpty) profile.photo,
        ...drafts.values.expand((d) => d.entry.photos), // 임시 저장 사진도 지우지 않음
      };

  /// 일기 태그별 개수 (많이 쓴 순)
  List<MapEntry<String, int>> get diaryTagCounts {
    final m = <String, int>{};
    for (final e in diaries) {
      for (final t in e.tags) {
        m[t] = (m[t] ?? 0) + 1;
      }
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  // ───── 일기 임시 저장 ─────
  File get _draftFile => File('${_dir.path}/drafts.json');

  Future<void> _loadDrafts() async {
    try {
      if (!await _draftFile.exists()) return;
      final m = jsonDecode(await _draftFile.readAsString()) as Map<String, dynamic>;
      m.forEach((k, v) {
        final mm = Map<String, dynamic>.from(v as Map);
        drafts[k] = DiaryDraft(
          DiaryEntry.fromJson(Map<String, dynamic>.from(mm['entry'] as Map)),
          DateTime.tryParse(mm['savedAt'] as String? ?? '') ?? DateTime.now(),
        );
      });
    } catch (e) {
      debugPrint('임시 저장 읽기 실패: $e');
    }
  }

  Future<void> _saveDrafts() async {
    final tmp = File('${_draftFile.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      for (final e in drafts.entries)
        e.key: {'entry': e.value.entry.toJson(), 'savedAt': e.value.savedAt.toIso8601String()},
    }));
    await tmp.rename(_draftFile.path);
  }

  Future<void> saveDraft(String key, DiaryEntry entry) async {
    drafts[key] = DiaryDraft(entry.copy(), DateTime.now());
    await _saveDrafts();
  }

  Future<void> clearDraft(String key) async {
    if (drafts.remove(key) != null) await _saveDrafts();
  }

  /// 마지막으로 기록이 바뀐 시각 (자동 백업 판단용)
  Future<DateTime?> dataModifiedAt() async =>
      await _dataFile.exists() ? await _dataFile.lastModified() : null;

  /// 백업에서 복원: 현재 데이터는 data.before-restore.json 으로 남겨둠
  Future<void> replaceAll(Map<String, dynamic> m) async {
    if (await _dataFile.exists()) {
      await _dataFile.copy('${_dir.path}/data.before-restore.json');
    }
    applyMap(m);
    await save();
  }

  Future<void> save() async {
    final tmp = File('${_dir.path}/data.json.tmp');
    await tmp.writeAsString(jsonEncode(toMap()));
    await tmp.rename(_dataFile.path); // 저장 중 꺼져도 기존 파일이 안 깨지게
    notifyListeners();
  }

  // ───── 사진 ─────
  File photoFile(String name) => File('${photoDir.path}/$name');

  Future<String> importPhoto(String srcPath) async {
    final dot = srcPath.lastIndexOf('.');
    final ext = dot >= 0 && srcPath.length - dot <= 5 ? srcPath.substring(dot) : '.jpg';
    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(srcPath).copy(photoFile(name).path);
    return name;
  }

  /// 편집 중 취소하거나 지운 사진 파일을 앱 시작 시 정리
  Future<void> _cleanUnusedPhotos() async {
    final used = usedPhotos;
    try {
      await for (final ent in photoDir.list()) {
        if (ent is File) {
          final name = ent.uri.pathSegments.last;
          if (!used.contains(name)) await ent.delete();
        }
      }
    } catch (e) {
      debugPrint('사진 정리 실패: $e');
    }
  }

  // ───── 추가 / 수정 / 삭제 ─────
  Future<void> _upsert<T>(List<T> list, T item, String Function(T) idOf) async {
    final i = list.indexWhere((e) => idOf(e) == idOf(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.insert(0, item);
    }
    await save();
    onUserAction?.call();
  }

  Future<void> _remove<T>(List<T> list, String id, String Function(T) idOf) async {
    list.removeWhere((e) => idOf(e) == id);
    await save(); // 사진 파일은 다음 실행 때 정리됨
  }

  Future<void> upsertBucket(BucketItem v) => _upsert(buckets, v, (e) => e.id);
  Future<void> removeBucket(String id) => _remove(buckets, id, (BucketItem e) => e.id);

  Future<void> upsertGoal(Goal v) => _upsert(goals, v, (e) => e.id);
  Future<void> removeGoal(String id) => _remove(goals, id, (Goal e) => e.id);

  Future<void> upsertDiary(DiaryEntry v) => _upsert(diaries, v, (e) => e.id);
  Future<void> removeDiary(String id) => _remove(diaries, id, (DiaryEntry e) => e.id);

  Future<void> upsertCareer(CareerItem v) => _upsert(careers, v, (e) => e.id);
  Future<void> saveProfile(Profile p) async {
    profile = p;
    await save();
  }

  Future<void> removeCareer(String id) => _remove(careers, id, (CareerItem e) => e.id);
}

class DiaryDraft {
  final DiaryEntry entry;
  final DateTime savedAt;
  DiaryDraft(this.entry, this.savedAt);
}
