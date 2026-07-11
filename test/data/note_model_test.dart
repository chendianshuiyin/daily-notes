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
    expect(note.blocks, hasLength(1));
    expect(note.blocks.single.type, NoteBlockType.paragraph);
    expect(note.blocks.single.text, '正文里有 #旧标签');
  });

  test('expands and matches hierarchical inline tags', () {
    expect(Note.expandTagHierarchy(['#工作/项目/发布']), [
      '#工作',
      '#工作/项目',
      '#工作/项目/发布',
    ]);
    expect(Note.matchesTag(['#工作/项目'], '#工作'), isTrue);
    expect(Note.matchesTag(['#生活'], '#工作'), isFalse);
  });

  test('round-trips ordered text and image blocks', () {
    final note = Note(
      id: 'block-note',
      title: '混排笔记',
      content: '加粗内容',
      createdAt: DateTime.utc(2026, 7, 11),
      updatedAt: DateTime.utc(2026, 7, 11),
      images: const [
        NoteImage(
          id: 'image-1',
          name: 'sketch.png',
          mimeType: 'image/png',
          base64Data: 'AQ==',
        ),
      ],
      blocks: const [
        NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: '加粗内容',
          marks: [NoteTextMark(type: NoteTextMarkType.bold, start: 0, end: 2)],
        ),
        NoteBlock(
          id: 'image-block-1',
          type: NoteBlockType.image,
          imageId: 'image-1',
          caption: '草图',
        ),
      ],
    );

    final encoded = note.toJson();
    final decoded = Note.fromJson(encoded);

    expect(encoded['contentVersion'], NoteDocument.contentVersion);
    expect(decoded.blocks, hasLength(2));
    expect(decoded.blocks.first.marks.single.type, NoteTextMarkType.bold);
    expect(decoded.blocks.last.imageId, 'image-1');
    expect(decoded.blocks.last.caption, '草图');
  });
}
