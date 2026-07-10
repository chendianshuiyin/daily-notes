import 'package:daily_notes/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes, deduplicates, and serializes explicit and inline tags', () {
    final note = Note(
      id: 'tagged-note',
      title: '标签笔记',
      content: '#旅行 计划内容 #work',
      createdAt: DateTime.utc(2026, 7, 11),
      updatedAt: DateTime.utc(2026, 7, 11),
      tags: const ['work', '#WORK', '#生活'],
    );

    expect(note.tags, ['#work', '#生活', '#旅行']);
    expect(Note.fromJson(note.toJson()).tags, note.tags);
  });

  test('extracts tags from legacy notes without a tags field', () {
    final note = Note.fromJson({
      'id': 'legacy-note',
      'title': '旧笔记',
      'content': '正文里有 #旧标签',
      'createdAt': '2026-07-11T00:00:00.000Z',
      'updatedAt': '2026-07-11T00:00:00.000Z',
    });

    expect(note.tags, ['#旧标签']);
  });
}
