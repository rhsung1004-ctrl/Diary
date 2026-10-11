import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebox/importer.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('imp'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(String name, String text) {
    final f = File('${dir.path}/$name')..writeAsStringSync(text);
    return f.path;
  }

  String zip(String name, Map<String, List<int>> files) {
    final a = Archive();
    files.forEach((n, b) => a.addFile(ArchiveFile(n, b.length, b)));
    final f = File('${dir.path}/$name')..writeAsBytesSync(ZipEncoder().encode(a) as List<int>);
    return f.path;
  }

  test('일반 텍스트', () {
    final (fmt, items) = parseImportFile(write('a.txt', '2024.03.01 (금) 봄 산책\n공원에 갔다.\n\n2024년 3월 2일\n비가 왔다.\n둘째 줄'));
    expect(fmt, ImportFormat.text);
    expect(items.length, 2);
    expect(items[0].title, '봄 산책');
    expect(items[0].body, '공원에 갔다.');
    expect(items[1].date, DateTime(2024, 3, 2, 12));
    expect(items[1].body, '비가 왔다.\n둘째 줄');
  });

  test('요일처럼 보이는 제목은 그대로', () {
    final (_, items) = parseImportFile(write('b.txt', '2024-03-25 월급날\n야호'));
    expect(items.single.title, '월급날');
  });

  test('일반 CSV', () {
    final (fmt, items) = parseImportFile(write('a.csv', '날짜,제목,내용,기분\n2024-03-01,산책,"공원, 그리고\n카페",좋음\n2024/03/02,,비,'));
    expect(fmt, ImportFormat.csv);
    expect(items.length, 2);
    expect(items[0].body, '공원, 그리고\n카페');
    expect(items[0].mood, '😊');
    expect(items[1].title, '');
  });

  test('Daylio CSV', () {
    final (fmt, items) = parseImportFile(write('d.csv',
        'full_date,date,weekday,time,mood,activities,note_title,note\n2024-03-01,March 1,Friday,9:26 PM,rad,friends | good meal,Fun,"Great<br>day"'));
    expect(fmt, ImportFormat.daylio);
    expect(items.single.date, DateTime(2024, 3, 1, 21, 26));
    expect(items.single.mood, '😆');
    expect(items.single.tags, ['friends', 'good_meal']);
    expect(items.single.body, 'Great\nday');
  });

  test('Daylio 옛 형식', () {
    final (fmt, items) = parseImportFile(write('d.csv', 'year,date,weekday,time,mood,activities,note\n2023,23-Jan,Monday,9:26 AM,meh,work,hi'));
    expect(fmt, ImportFormat.daylio);
    expect(items.single.date, DateTime(2023, 1, 23, 9, 26));
  });

  test('Day One zip', () {
    final journal = jsonEncode({
      'metadata': {'version': '1.0'},
      'entries': [
        {
          'creationDate': '2024-03-01T03:00:00Z',
          'text': '# 제목\\!\n본문입니다\\.\n![](dayone-moment://ABC)',
          'tags': ['여행'],
          'photos': [
            {'identifier': 'ABC', 'md5': 'ff00', 'type': 'jpeg'}
          ],
        }
      ],
    });
    final path = zip('d1.zip', {'Journal.json': utf8.encode(journal), 'photos/ff00.jpeg': [1, 2, 3]});
    final (fmt, items) = parseImportFile(path);
    expect(fmt, ImportFormat.dayOne);
    expect(items.single.title, '제목!');
    expect(items.single.body, '본문입니다.');
    expect(items.single.tags, ['여행']);
    expect(items.single.photos, ['photos/ff00.jpeg']);
  });

  test('Journey zip', () {
    final e = jsonEncode({
      'id': 'x',
      'date_journal': DateTime(2024, 3, 1, 8).millisecondsSinceEpoch,
      'text': '<p>안녕</p><p>하세요</p>',
      'photos': ['x-1.jpg'],
      'tags': ['tag one'],
    });
    final path = zip('j.zip', {'x.json': utf8.encode(e), 'x-1.jpg': [1, 2]});
    final (fmt, items) = parseImportFile(path);
    expect(fmt, ImportFormat.journey);
    expect(items.single.body, '안녕\n하세요');
    expect(items.single.photos, ['x-1.jpg']);
    expect(items.single.tags, ['tag_one']);
  });

  test('UTF-8 아닌 파일', () {
    final f = File('${dir.path}/k.csv')..writeAsBytesSync([0xB3, 0xAF, 0xC2, 0xA5, 0x2C, 0x41]);
    expect(() => parseImportFile(f.path), throwsA(isA<ImportException>()));
  });
}
