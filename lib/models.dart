// 데이터 모델. 모두 JSON으로 저장되고, 사진은 파일 이름만 저장합니다.

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;
List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];
Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

// ───────────────────────── 버킷리스트 ─────────────────────────
class BucketItem {
  final String id;
  String title;
  String category;
  String note;
  bool done;
  DateTime? doneAt;
  List<String> photos;
  DateTime createdAt;

  BucketItem({
    String? id,
    this.title = '',
    this.category = '',
    this.note = '',
    this.done = false,
    this.doneAt,
    List<String>? photos,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        photos = photos ?? <String>[],
        createdAt = createdAt ?? DateTime.now();

  BucketItem copy() => BucketItem.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'note': note,
        'done': done,
        'doneAt': doneAt?.toIso8601String(),
        'photos': List<String>.from(photos),
        'createdAt': createdAt.toIso8601String(),
      };

  factory BucketItem.fromJson(Map<String, dynamic> j) => BucketItem(
        id: j['id'] as String?,
        title: j['title'] as String? ?? '',
        category: j['category'] as String? ?? '',
        note: j['note'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        doneAt: _date(j['doneAt']),
        photos: _strings(j['photos']),
        createdAt: _date(j['createdAt']),
      );
}

// ───────────────────────── 목표 ─────────────────────────
const goalPeriods = ['올해', '이번 달', '이번 주', '장기'];

class GoalTask {
  String text;
  bool done;
  GoalTask({required this.text, this.done = false});

  Map<String, dynamic> toJson() => {'text': text, 'done': done};
  factory GoalTask.fromJson(Map<String, dynamic> j) =>
      GoalTask(text: j['text'] as String? ?? '', done: j['done'] as bool? ?? false);
}

class Goal {
  final String id;
  String title;
  String period;
  String note;
  DateTime? dueDate;
  List<GoalTask> tasks;
  bool done; // 하위 할 일과 상관없이 직접 완료 처리
  DateTime createdAt;

  Goal({
    String? id,
    this.title = '',
    this.period = '올해',
    this.note = '',
    this.dueDate,
    List<GoalTask>? tasks,
    this.done = false,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        tasks = tasks ?? <GoalTask>[],
        createdAt = createdAt ?? DateTime.now();

  int get doneTasks => tasks.where((t) => t.done).length;

  double get progress {
    if (done) return 1;
    if (tasks.isEmpty) return 0;
    return doneTasks / tasks.length;
  }

  bool get isComplete => done || (tasks.isNotEmpty && tasks.every((t) => t.done));

  Goal copy() => Goal.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'period': period,
        'note': note,
        'dueDate': dueDate?.toIso8601String(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String?,
        title: j['title'] as String? ?? '',
        period: j['period'] as String? ?? '올해',
        note: j['note'] as String? ?? '',
        dueDate: _date(j['dueDate']),
        tasks: j['tasks'] is List
            ? (j['tasks'] as List).map((e) => GoalTask.fromJson(_map(e))).toList()
            : <GoalTask>[],
        done: j['done'] as bool? ?? false,
        createdAt: _date(j['createdAt']),
      );
}

// ───────────────────────── 일기 ─────────────────────────
const moods = ['😊', '😆', '🥰', '😌', '😐', '😢', '😠', '😴'];

class DiaryEntry {
  final String id;
  DateTime date;
  String title;
  String body;
  String mood;
  List<String> photos;
  DateTime createdAt;

  DiaryEntry({
    String? id,
    DateTime? date,
    this.title = '',
    this.body = '',
    this.mood = '',
    List<String>? photos,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        date = date ?? DateTime.now(),
        photos = photos ?? <String>[],
        createdAt = createdAt ?? DateTime.now();

  DiaryEntry copy() => DiaryEntry.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'body': body,
        'mood': mood,
        'photos': List<String>.from(photos),
        'createdAt': createdAt.toIso8601String(),
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] as String?,
        date: _date(j['date']),
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        mood: j['mood'] as String? ?? '',
        photos: _strings(j['photos']),
        createdAt: _date(j['createdAt']),
      );
}

// ───────────────────────── 커리어 / 포트폴리오 ─────────────────────────
const careerTypes = ['프로젝트', '경력', '학력', '자격·수상', '활동'];

class CareerItem {
  final String id;
  String type;
  String title;
  String org; // 소속 / 역할
  DateTime? startDate;
  DateTime? endDate;
  bool ongoing;
  String description;
  List<String> skills;
  String link;
  List<String> photos;
  DateTime createdAt;

  CareerItem({
    String? id,
    this.type = '프로젝트',
    this.title = '',
    this.org = '',
    this.startDate,
    this.endDate,
    this.ongoing = false,
    this.description = '',
    List<String>? skills,
    this.link = '',
    List<String>? photos,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        skills = skills ?? <String>[],
        photos = photos ?? <String>[],
        createdAt = createdAt ?? DateTime.now();

  CareerItem copy() => CareerItem.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'org': org,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'ongoing': ongoing,
        'description': description,
        'skills': List<String>.from(skills),
        'link': link,
        'photos': List<String>.from(photos),
        'createdAt': createdAt.toIso8601String(),
      };

  factory CareerItem.fromJson(Map<String, dynamic> j) => CareerItem(
        id: j['id'] as String?,
        type: j['type'] as String? ?? '프로젝트',
        title: j['title'] as String? ?? '',
        org: j['org'] as String? ?? '',
        startDate: _date(j['startDate']),
        endDate: _date(j['endDate']),
        ongoing: j['ongoing'] as bool? ?? false,
        description: j['description'] as String? ?? '',
        skills: _strings(j['skills']),
        link: j['link'] as String? ?? '',
        photos: _strings(j['photos']),
        createdAt: _date(j['createdAt']),
      );
}
