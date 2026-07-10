import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const repository = SharedPreferencesNoteRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists, updates, archives, and deletes notes', () async {
    final createdAt = DateTime.utc(2026, 7, 10, 8);
    final original = Note(
      id: 'note-1',
      title: '第一条笔记',
      content: '本地持久化内容',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    await repository.upsertNote(original);
    expect(await repository.getNoteById(original.id), isNotNull);

    final updated = original.copyWith(
      content: '已更新的内容',
      updatedAt: createdAt.add(const Duration(minutes: 5)),
    );
    await repository.upsertNote(updated);

    final loaded = await repository.getNotes();
    expect(loaded, hasLength(1));
    expect(loaded.single.content, '已更新的内容');
    expect(loaded.single.createdAt, createdAt);

    await repository.archiveNote(original.id, isArchived: true);
    expect((await repository.getNoteById(original.id))?.isArchived, isTrue);

    await repository.deleteNote(original.id);
    expect(await repository.getNotes(), isEmpty);
  });

  test('merges restored notes and overwrites matching IDs', () async {
    final original = Note(
      id: 'same-id',
      title: '现有笔记',
      content: '旧内容',
      createdAt: DateTime.utc(2026, 7, 9),
      updatedAt: DateTime.utc(2026, 7, 9),
    );
    final untouched = Note(
      id: 'keep-id',
      title: '保留笔记',
      content: '保持不变',
      createdAt: DateTime.utc(2026, 7, 8),
      updatedAt: DateTime.utc(2026, 7, 8),
    );
    final restored = original.copyWith(
      title: '备份笔记',
      content: '新内容',
      updatedAt: DateTime.utc(2026, 7, 10),
    );

    await repository.upsertNote(original);
    await repository.upsertNote(untouched);
    await repository.mergeNotes([restored]);

    final notes = await repository.getNotes();
    expect(notes, hasLength(2));
    expect(notes.firstWhere((note) => note.id == 'same-id').content, '新内容');
    expect(notes.firstWhere((note) => note.id == 'keep-id').content, '保持不变');
  });
}
