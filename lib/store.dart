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

  File get _dataFile => File('${_dir.path}/data.json');

  Future<void> load() async {
    _dir = await getApplicationDocumentsDirectory();
    photoDir = Directory('${_dir.path}/photos');
    if (!await photoDir.exists()) await photoDir.create(recursive: true);

    var loadedOk = true;
    if (await _dataFile.exists()) {
      try {
        final m = jsonDecode(await _dataFile.readAsString()) as Map<String, dynamic>;
        buckets = _list(m['buckets'], BucketItem.fromJson);
        goals = _list(m['goals'], Goal.fromJson);
        diaries = _list(m['diaries'], DiaryEntry.fromJson);
        careers = _list(m['careers'], CareerItem.fromJson);
      } catch (e) {
        // 파일이 깨졌으면 지우지 않고 옆에 보관해 둔다
        loadedOk = false;
        debugPrint('data.json 읽기 실패: $e');
        final ts = DateTime.now().millisecondsSinceEpoch;
        await _dataFile.copy('${_dir.path}/data.broken-$ts.json');
      }
    }
    if (loadedOk) await _cleanUnusedPhotos();
  }

  List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) => v is List
      ? v.map((e) => f(Map<String, dynamic>.from(e as Map))).toList()
      : <T>[];

  Future<void> save() async {
    final tmp = File('${_dir.path}/data.json.tmp');
    await tmp.writeAsString(jsonEncode({
      'version': 1,
      'buckets': buckets.map((e) => e.toJson()).toList(),
      'goals': goals.map((e) => e.toJson()).toList(),
      'diaries': diaries.map((e) => e.toJson()).toList(),
      'careers': careers.map((e) => e.toJson()).toList(),
    }));
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
    final used = <String>{
      ...buckets.expand((e) => e.photos),
      ...diaries.expand((e) => e.photos),
      ...careers.expand((e) => e.photos),
    };
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
  Future<void> removeCareer(String id) => _remove(careers, id, (CareerItem e) => e.id);
}
