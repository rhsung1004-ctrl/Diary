import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';

import 'models.dart';
import 'store.dart';

/// 다른 앱에서 내보낸 일기 파일 가져오기
/// 지원: Day One(JSON zip), Journey(zip), Daylio(CSV), 일반 텍스트·CSV
enum ImportFormat { dayOne, journey, daylio, csv, text }

class ImportException implements Exception {
  final String code; // notUtf8, noEntries, unsupported, broken
  ImportException(this.code);
  @override
  String toString() => code;
}

class ImportItem {
  final DateTime date;
  final String title;
  final String body;
  final String mood;
  final List<String> tags;
  final List<String> photos; // zip 안의 파일 경로
  const ImportItem(this.date, this.title, this.body, this.mood, this.tags, this.photos);

  String get key => '${date.year}-${date.month}-${date.day}|${_norm(title)}|${_norm(body)}';
}

String _norm(String s) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > 200 ? t.substring(0, 200) : t;
}

class ImportPreview {
  final String path;
  final ImportFormat format;
  final List<ImportItem> items; // 중복을 뺀 것
  final int duplicates;
  ImportPreview(this.path, this.format, this.items, this.duplicates);

  int get photoCount => items.fold<int>(0, (n, e) => n + e.photos.length);
  DateTime? get from => items.isEmpty ? null : items.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime? get to => items.isEmpty ? null : items.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
}

/// 파일을 읽어 미리보기를 만듦 (무거운 작업은 별도 isolate)
Future<ImportPreview> analyzeImport(String path) async {
  final (format, all) = await Isolate.run(() => parseImportFile(path));
  if (all.isEmpty) throw ImportException('noEntries');

  // 이미 있는 일기, 같은 파일 안의 중복 건너뛰기
  final existing = {
    for (final d in AppStore.instance.diaries) ImportItem(d.date, d.title, d.body, '', const [], const []).key,
  };
  final seen = <String>{};
  final items = <ImportItem>[];
  var dup = 0;
  for (final e in all) {
    final k = e.key;
    if (existing.contains(k) || !seen.add(k)) {
      dup++;
    } else {
      items.add(e);
    }
  }
  items.sort((a, b) => a.date.compareTo(b.date));
  return ImportPreview(path, format, items, dup);
}

/// 실제로 저장. 가져온 일기 수를 돌려줌
Future<int> applyImport(ImportPreview p) async {
  final store = AppStore.instance;
  final wanted = {for (final e in p.items) ...e.photos};
  final photoDir = store.photoDir.path;
  final saved = wanted.isEmpty
      ? <String, String>{}
      : await Isolate.run(() => _extractPhotos(p.path, wanted, photoDir));

  final now = DateTime.now();
  final entries = [
    for (final e in p.items)
      DiaryEntry(
        date: e.date,
        title: e.title,
        body: e.body,
        mood: e.mood,
        tags: List.of(e.tags),
        photos: [for (final ph in e.photos) if (saved[ph] != null) saved[ph]!],
        createdAt: now,
      ),
  ];
  await store.addDiaries(entries);
  return entries.length;
}

// ───────────────────────── 파싱 (isolate 안) ─────────────────────────

/// 파일 형식을 알아내고 일기 목록으로 바꿈 (테스트에서도 사용)
(ImportFormat, List<ImportItem>) parseImportFile(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.zip')) return _parseZip(path);
  final bytes = File(path).readAsBytesSync();
  if (_isZip(bytes)) return _parseZip(path);
  final text = _decode(bytes);
  if (lower.endsWith('.json') || text.trimLeft().startsWith('{') || text.trimLeft().startsWith('[')) {
    final j = _tryJson(text);
    if (j != null) {
      final dayOne = _dayOne(j, const {});
      if (dayOne != null) return (ImportFormat.dayOne, dayOne);
      final journey = _journey(j, const {});
      if (journey != null) return (ImportFormat.journey, [journey]);
    }
    throw ImportException('unsupported');
  }
  if (lower.endsWith('.csv') || lower.endsWith('.tsv')) {
    final rows = _csv(text);
    final daylio = _daylio(rows);
    if (daylio != null) return (ImportFormat.daylio, daylio);
    return (ImportFormat.csv, _genericCsv(rows));
  }
  return (ImportFormat.text, _plainText(text));
}

bool _isZip(List<int> b) => b.length > 4 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 0x03 && b[3] == 0x04;

String _decode(List<int> bytes) {
  var b = bytes;
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) b = b.sublist(3);
  try {
    return utf8.decode(b);
  } on FormatException {
    // 엑셀 기본 CSV(EUC-KR 등)는 읽을 수 없음 → UTF-8로 저장 안내
    throw ImportException('notUtf8');
  }
}

Object? _tryJson(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}

(ImportFormat, List<ImportItem>) _parseZip(String path) {
  try {
    final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
    final names = <String>{for (final f in archive.files) if (f.isFile) f.name};
    final jsons = archive.files.where((f) =>
        f.isFile && f.name.toLowerCase().endsWith('.json') && !f.name.split('/').last.startsWith('.'));

    // Day One: 일기장 이름.json 안에 entries 배열
    final dayOne = <ImportItem>[];
    var isDayOne = false;
    // Journey: 일기 하나당 json 하나
    final journey = <ImportItem>[];
    for (final f in jsons) {
      final List<int> bytes = f.content;
      final j = _tryJson(utf8.decode(bytes, allowMalformed: true));
      if (j == null) continue;
      final d = _dayOne(j, names);
      if (d != null) {
        isDayOne = true;
        dayOne.addAll(d);
        continue;
      }
      final e = _journey(j, names);
      if (e != null) journey.add(e);
    }
    if (isDayOne) return (ImportFormat.dayOne, dayOne);
    if (journey.isNotEmpty) return (ImportFormat.journey, journey);

    // zip 안의 csv/txt 도 시도
    for (final f in archive.files) {
      final n = f.name.toLowerCase();
      if (!f.isFile) continue;
      if (n.endsWith('.csv') || n.endsWith('.txt') || n.endsWith('.md')) {
        final List<int> bytes = f.content;
        final text = _decode(bytes);
        if (n.endsWith('.csv')) {
          final rows = _csv(text);
          final d = _daylio(rows);
          if (d != null) return (ImportFormat.daylio, d);
          return (ImportFormat.csv, _genericCsv(rows));
        }
        return (ImportFormat.text, _plainText(text));
      }
    }
    throw ImportException('unsupported');
  } on ImportException {
    rethrow;
  } catch (_) {
    throw ImportException('broken');
  }
}

/// zip 에서 필요한 사진만 꺼내 앱 사진 폴더에 저장 → {zip 경로: 새 파일 이름}
Map<String, String> _extractPhotos(String path, Set<String> wanted, String photoDir) {
  final out = <String, String>{};
  try {
    final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
    var i = 0;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (final f in archive.files) {
      if (!f.isFile || !wanted.contains(f.name)) continue;
      final base = f.name.split('/').last;
      final dot = base.lastIndexOf('.');
      final ext = dot >= 0 && base.length - dot <= 5 ? base.substring(dot).toLowerCase() : '.jpg';
      final name = 'imp_${stamp}_${i++}$ext';
      try {
        final List<int> bytes = f.content;
        File('$photoDir/$name').writeAsBytesSync(bytes, flush: false);
        out[f.name] = name;
      } catch (_) {}
    }
  } catch (_) {
    // 사진을 못 꺼내도 글은 가져옴
  }
  return out;
}

// ───── Day One ─────
const _imageTypes = {'jpeg', 'jpg', 'png', 'heic', 'heif', 'gif', 'webp'};

List<ImportItem>? _dayOne(Object? j, Set<String> names) {
  if (j is! Map || j['entries'] is! List) return null;
  final out = <ImportItem>[];
  for (final e in j['entries'] as List) {
    if (e is! Map) continue;
    final date = DateTime.tryParse(e['creationDate']?.toString() ?? '')?.toLocal();
    if (date == null) continue;
    var text = (e['text'] ?? '').toString();
    text = text
        .replaceAll(RegExp(r'!\[[^\]]*\]\(dayone-moment:[^)]*\)'), '')
        .replaceAllMapped(RegExp(r'\\([\\`*_{}\[\]()#+\-.!>|~])'), (m) => m[1]!)
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    final photos = <String>[];
    if (e['photos'] is List) {
      for (final p in e['photos'] as List) {
        if (p is! Map) continue;
        final md5 = p['md5']?.toString();
        final type = (p['type'] ?? 'jpeg').toString().toLowerCase();
        if (md5 == null || !_imageTypes.contains(type)) continue;
        final hit = names.firstWhere(
          (n) => n.split('/').last.toLowerCase().startsWith('${md5.toLowerCase()}.'),
          orElse: () => '',
        );
        if (hit.isNotEmpty) photos.add(hit);
      }
    }
    final (title, body) = _splitTitle(text);
    if (title.isEmpty && body.isEmpty && photos.isEmpty) continue;
    out.add(ImportItem(date, title, body, '', _tags(e['tags']), photos));
  }
  return out;
}

/// Day One 은 첫 줄이 "# 제목" 형식인 경우가 많음
(String, String) _splitTitle(String text) {
  final lines = text.split('\n');
  final first = lines.first.trim();
  if (first.startsWith('#')) {
    final title = first.replaceFirst(RegExp(r'^#+\s*'), '').trim();
    if (title.length <= 80) return (title, lines.skip(1).join('\n').trim());
  }
  return ('', text);
}

// ───── Journey ─────
ImportItem? _journey(Object? j, Set<String> names) {
  if (j is! Map || !j.containsKey('date_journal')) return null;
  final ms = num.tryParse(j['date_journal'].toString());
  if (ms == null) return null;
  final date = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  var text = (j['text'] ?? '').toString();
  if (text.contains('<') && RegExp(r'</?(p|br|div|span|b|i|strong|em|ul|li|h\d)\b', caseSensitive: false).hasMatch(text)) {
    text = _htmlToText(text);
  }
  final photos = <String>[];
  if (j['photos'] is List) {
    for (final p in j['photos'] as List) {
      final n = p.toString().split('/').last;
      final hit = names.firstWhere((x) => x.split('/').last == n, orElse: () => '');
      if (hit.isNotEmpty && _imageTypes.contains(n.split('.').last.toLowerCase())) photos.add(hit);
    }
  }
  text = text.trim();
  if (text.isEmpty && photos.isEmpty) return null;
  return ImportItem(date, '', text, '', _tags(j['tags']), photos);
}

// ───── Daylio ─────
List<ImportItem>? _daylio(List<List<String>> rows) {
  if (rows.isEmpty) return null;
  final h = rows.first.map((e) => e.trim().toLowerCase()).toList();
  final iMood = h.indexOf('mood');
  final iFull = h.indexOf('full_date');
  final iYear = h.indexOf('year');
  final iDate = h.indexOf('date');
  if (iMood < 0 || (iFull < 0 && (iYear < 0 || iDate < 0))) return null;
  final iTime = h.indexOf('time');
  final iAct = h.indexOf('activities');
  final iTitle = h.indexOf('note_title');
  final iNote = h.indexOf('note');
  String at(List<String> r, int i) => i >= 0 && i < r.length ? r[i] : '';

  final out = <ImportItem>[];
  for (final r in rows.skip(1)) {
    DateTime? day;
    if (iFull >= 0) {
      day = _parseDate(at(r, iFull));
    } else {
      day = _parseMonthDay(at(r, iDate), int.tryParse(at(r, iYear).trim()));
    }
    if (day == null) continue;
    final t = _parseTime(at(r, iTime));
    final date = DateTime(day.year, day.month, day.day, t?.$1 ?? 12, t?.$2 ?? 0);
    final note = _htmlToText(at(r, iNote)).trim();
    final title = _htmlToText(at(r, iTitle)).trim();
    final tags = at(r, iAct)
        .split('|')
        .map((s) => s.trim().replaceAll(RegExp(r'\s+'), '_'))
        .where((s) => s.isNotEmpty && s.length <= 20)
        .toList();
    out.add(ImportItem(date, title, note, _mood(at(r, iMood)), tags, const []));
  }
  return out;
}

// ───── 일반 CSV ─────
const _dateKeys = ['date', 'day', '날짜', '일자', '작성일', '日付', '日時'];
const _bodyKeys = ['content', 'body', 'text', 'note', 'diary', 'entry', '내용', '본문', '일기', '本文', '内容', '日記', 'メモ'];
const _titleKeys = ['title', 'subject', '제목', 'タイトル', '件名'];
const _moodKeys = ['mood', 'feeling', 'emotion', '기분', '감정', '気分'];
const _tagKeys = ['tag', 'tags', '태그', 'タグ'];

int _col(List<String> h, List<String> keys) {
  for (var i = 0; i < h.length; i++) {
    final c = h[i].trim().toLowerCase();
    if (keys.any((k) => c == k || c.contains(k))) return i;
  }
  return -1;
}

List<ImportItem> _genericCsv(List<List<String>> rows) {
  if (rows.isEmpty) throw ImportException('noEntries');
  final h = rows.first;
  var iDate = _col(h, _dateKeys);
  var iBody = _col(h, _bodyKeys);
  var iTitle = _col(h, _titleKeys);
  var iMood = _col(h, _moodKeys);
  var iTags = _col(h, _tagKeys);
  var data = rows.skip(1);
  if (iDate < 0) {
    // 머리글이 없는 파일: 날짜처럼 보이는 첫 칸 + 가장 긴 칸
    data = rows;
    final sample = rows.first;
    iDate = sample.indexWhere((c) => _parseDate(c) != null);
    if (iDate < 0) throw ImportException('noEntries');
    iTitle = iMood = iTags = -1;
  }
  if (iBody < 0) {
    var best = -1, len = -1;
    for (final r in data.take(20)) {
      for (var i = 0; i < r.length; i++) {
        if (i == iDate || i == iTitle || i == iMood || i == iTags) continue;
        if (r[i].length > len) {
          len = r[i].length;
          best = i;
        }
      }
    }
    iBody = best;
  }
  String at(List<String> r, int i) => i >= 0 && i < r.length ? r[i] : '';
  final out = <ImportItem>[];
  for (final r in data) {
    final date = _parseDate(at(r, iDate));
    if (date == null) continue;
    final body = at(r, iBody).trim();
    final title = at(r, iTitle).trim();
    if (body.isEmpty && title.isEmpty) continue;
    final tags = at(r, iTags)
        .split(RegExp(r'[\s,#|]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length <= 20)
        .toList();
    out.add(ImportItem(date, title, body, _mood(at(r, iMood)), tags, const []));
  }
  return out;
}

// ───── 일반 텍스트 ─────
// 날짜로 시작하는 줄을 기준으로 일기를 나눔. 예) "2024.03.01 (금) 봄 산책"
final _headRe = RegExp(
    r'^\s*(?:#+\s*|\[)?(\d{4})\s*[.\-/년]\s*(\d{1,2})\s*[.\-/월]\s*(\d{1,2})\s*[일.]?\]?(.*)$');

List<ImportItem> _plainText(String text) {
  final lines = const LineSplitter().convert(text);
  final out = <ImportItem>[];
  DateTime? date;
  var title = '';
  final body = <String>[];

  void flush() {
    if (date != null) {
      final b = body.join('\n').trim();
      if (b.isNotEmpty || title.isNotEmpty) out.add(ImportItem(date!, title, b, '', const [], const []));
    }
    body.clear();
  }

  for (final line in lines) {
    final m = _headRe.firstMatch(line);
    final y = m == null ? null : int.tryParse(m[1]!);
    final mo = m == null ? null : int.tryParse(m[2]!);
    final d = m == null ? null : int.tryParse(m[3]!);
    final rest = m?[4] ?? '';
    final valid = y != null && y > 1900 && y < 2200 && mo! >= 1 && mo <= 12 && d! >= 1 && d <= 31;
    if (valid && rest.trim().length <= 60) {
      flush();
      var r = rest.trim();
      // 요일·시간 떼어내기
      r = r
          .replaceFirst(
              RegExp(
                  r'^(\(\s*[월화수목금토일月火水木金土日](요일|曜日)?\s*\)|[월화수목금토일]요일|[月火水木金土日]曜日|\(?(mon|tue|wed|thu|fri|sat|sun)[a-z]*\.?\)?(?=\s|$))',
                  caseSensitive: false),
              '')
          .trim();
      var hh = 12, mm = 0;
      final tm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(r);
      if (tm != null) {
        hh = int.parse(tm[1]!).clamp(0, 23);
        mm = int.parse(tm[2]!).clamp(0, 59);
        r = r.substring(tm.end).trim();
      }
      date = DateTime(y, mo, d, hh, mm);
      title = r.replaceFirst(RegExp(r'^[-–—:|·\s]+'), '').trim();
    } else {
      body.add(line);
    }
  }
  flush();
  return out;
}

// ───── 공통 도구 ─────
List<String> _tags(Object? v) => v is List
    ? v
        .map((e) => e.toString().trim().replaceAll(RegExp(r'\s+'), '_'))
        .where((s) => s.isNotEmpty && s.length <= 20)
        .toList()
    : <String>[];

String _mood(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return '';
  for (final m in moods) {
    if (s.contains(m)) return m;
  }
  const map = {
    'rad': '😆', 'great': '😆', 'awesome': '😆', '최고': '😆', '아주 좋음': '😆', '最高': '😆',
    'good': '😊', 'happy': '😊', '좋음': '😊', '좋아': '😊', '행복': '😊', '良い': '😊', 'いい': '😊',
    'love': '🥰', '사랑': '🥰',
    'calm': '😌', 'relaxed': '😌', '평온': '😌', '편안': '😌',
    'meh': '😐', 'okay': '😐', 'ok': '😐', 'normal': '😐', '보통': '😐', '그저': '😐', '普通': '😐', 'まあまあ': '😐',
    'bad': '😢', 'sad': '😢', 'awful': '😢', '나쁨': '😢', '슬픔': '😢', '우울': '😢', '최악': '😢', '悪い': '😢', '最悪': '😢',
    'angry': '😠', '화남': '😠', '짜증': '😠',
    'tired': '😴', 'sleepy': '😴', '피곤': '😴', '疲れ': '😴',
  };
  for (final e in map.entries) {
    if (s == e.key || s.startsWith(e.key)) return e.value;
  }
  return '';
}

DateTime? _parseDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso.isUtc ? iso.toLocal() : iso;
  final m = RegExp(r'(\d{4})\s*[.\-/년]\s*(\d{1,2})\s*[.\-/월]\s*(\d{1,2})(?:\D+(\d{1,2}):(\d{2}))?').firstMatch(s);
  if (m != null) {
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final hh = m[4] == null ? 12 : int.parse(m[4]!).clamp(0, 23);
    final mm = m[5] == null ? 0 : int.parse(m[5]!).clamp(0, 59);
    return DateTime(y, mo, d, hh, mm);
  }
  // 미국식 03/01/2024
  final us = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
  if (us != null) {
    final mo = int.parse(us[1]!), d = int.parse(us[2]!), y = int.parse(us[3]!);
    if (mo <= 12 && d <= 31) return DateTime(y, mo, d, 12);
  }
  return null;
}

const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

/// Daylio 옛 형식: "23-Jan", "Jan 23", "23 January"
DateTime? _parseMonthDay(String raw, int? year) {
  if (year == null) return _parseDate(raw);
  final s = raw.trim().toLowerCase();
  final m = RegExp(r'([a-z]+)').firstMatch(s);
  final d = RegExp(r'(\d{1,2})').firstMatch(s);
  if (m == null || d == null) return _parseDate('$year-$raw');
  final mi = _months.indexWhere((x) => m[1]!.startsWith(x));
  if (mi < 0) return null;
  return DateTime(year, mi + 1, int.parse(d[1]!), 12);
}

(int, int)? _parseTime(String raw) {
  final m = RegExp(r'(\d{1,2}):(\d{2})\s*([ap]\.?m\.?|오전|오후|午前|午後)?', caseSensitive: false).firstMatch(raw.trim());
  if (m == null) return null;
  var h = int.parse(m[1]!);
  final min = int.parse(m[2]!);
  final ap = (m[3] ?? '').toLowerCase();
  final pm = ap.startsWith('p') || ap == '오후' || ap == '午後';
  final am = ap.startsWith('a') || ap == '오전' || ap == '午前';
  if (pm && h < 12) h += 12;
  if (am && h == 12) h = 0;
  return (h.clamp(0, 23), min.clamp(0, 59));
}

String _htmlToText(String s) => s
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</(p|div|li|h\d)>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n');

/// 따옴표·줄바꿈을 지원하는 간단한 CSV 읽기 (쉼표/탭/세미콜론 자동 감지)
List<List<String>> _csv(String text) {
  final firstLine = text.split('\n').first;
  final sep = ['\t', ';', ','].reduce((a, b) => firstLine.split(a).length >= firstLine.split(b).length ? a : b);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"' && cell.isEmpty) {
      quoted = true;
    } else if (c == sep) {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((x) => x.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  row.add(cell.toString());
  if (row.any((x) => x.trim().isNotEmpty)) rows.add(row);
  return rows;
}
