import 'dart:io';

import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('daily-notes-hive-');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>(
      '${HiveNoteRepository.boxName}-${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
    await tempDirectory.delete(recursive: true);
  });

  test('migrates existing SharedPreferences notes once', () async {
    const legacyRepository = SharedPreferencesNoteRepository();
    final legacyNote = _note(id: 'legacy', title: '旧版笔记');
    await legacyRepository.upsertNote(legacyNote);

    final repository = HiveNoteRepository(
      openBox: () async => box,
      legacyRepository: legacyRepository,
    );

    expect((await repository.getNotes()).single.title, '旧版笔记');

    await legacyRepository.upsertNote(_note(id: 'later', title: '不应重复迁移'));
    final notes = await repository.getNotes();
    expect(notes, hasLength(1));
    expect(notes.single.id, 'legacy');
  });

  test('persists, updates, archives, merges, and deletes notes', () async {
    final repository = HiveNoteRepository(
      openBox: () async => box,
      legacyRepository: const SharedPreferencesNoteRepository(),
    );
    final original = _note(id: 'one', title: '第一条');

    await repository.upsertNote(original);
    expect((await repository.getNoteById('one'))?.title, '第一条');

    await repository.archiveNote('one', isArchived: true);
    expect((await repository.getNoteById('one'))?.isArchived, isTrue);

    await repository.mergeNotes([
      original.copyWith(title: '备份覆盖'),
      _note(id: 'two', title: '第二条'),
    ]);
    final notes = await repository.getNotes();
    expect(notes, hasLength(2));
    expect(notes.firstWhere((note) => note.id == 'one').title, '备份覆盖');

    await repository.deleteNote('one');
    expect(await repository.getNoteById('one'), isNull);
    expect(await repository.getNotes(), hasLength(1));
  });
}

Note _note({required String id, required String title}) {
  final date = DateTime.utc(2026, 7, 10);
  return Note(
    id: id,
    title: title,
    content: '正文',
    createdAt: date,
    updatedAt: date,
  );
}
