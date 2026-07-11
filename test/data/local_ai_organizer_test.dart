import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const organizer = LocalAiOrganizer();
  final now = DateTime(2026, 7, 11);

  Note note(String id, String content, List<String> tags) => Note(
    id: id,
    title: '',
    content: content,
    createdAt: now,
    updatedAt: now,
    tags: tags,
  );

  test(
    'suggests existing tags from related notes with deterministic reasons',
    () {
      final suggestions = organizer.suggestTags(
        title: 'Flutter 编辑器计划',
        content: '继续完善 Flutter 笔记编辑器和离线同步',
        notes: [
          note('one', 'Flutter 编辑器状态管理', ['#开发/Flutter']),
          note('two', '离线同步测试与 Flutter 发布', ['#开发/Flutter', '#发布']),
          note('three', '周末采购清单', ['#生活']),
        ],
      );

      expect(suggestions.first.tag, '#开发/Flutter');
      expect(suggestions.first.reason, '正文提到了这个主题');
      expect(suggestions.map((item) => item.tag), isNot(contains('#生活')));
    },
  );

  test('excludes current, archived, and already applied tags', () {
    final suggestions = organizer.suggestTags(
      title: '同步记录',
      content: 'WebDAV 同步 #已有',
      currentNoteId: 'current',
      notes: [
        note('current', 'WebDAV 同步', ['#当前']),
        note('active', 'WebDAV 远端同步', ['#已有', '#同步']),
        note('archived', 'WebDAV 同步归档', ['#归档']).copyWith(isArchived: true),
      ],
    );

    expect(suggestions.map((item) => item.tag), ['#同步']);
  });

  test('returns no suggestions for empty content', () {
    expect(
      organizer.suggestTags(title: '', content: '', notes: const []),
      isEmpty,
    );
  });

  test('finds related active notes with a transparent reason', () {
    final suggestions = organizer.findRelatedNotes(
      title: 'Flutter 发布计划',
      content: '检查 Flutter 编辑器和 WebDAV 同步 #开发',
      currentNoteId: 'current',
      notes: [
        note('current', 'Flutter 编辑器', ['#开发']),
        note('related', 'Flutter 编辑器发布和同步检查', ['#开发']),
        note('weak', 'Flutter 布局', ['#其他']),
        note('unrelated', '周末采购', ['#生活']),
        note('archived', 'Flutter 发布', ['#开发']).copyWith(isArchived: true),
      ],
    );

    expect(suggestions.first.noteId, 'related');
    expect(suggestions.first.reason, '共同标签 #开发');
    expect(suggestions.map((item) => item.noteId), isNot(contains('current')));
    expect(suggestions.map((item) => item.noteId), isNot(contains('archived')));
    expect(
      suggestions.map((item) => item.noteId),
      isNot(contains('unrelated')),
    );
  });
}
