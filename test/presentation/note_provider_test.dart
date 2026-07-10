import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/repositories/repositories.dart';
import 'package:daily_notes/presentation/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const repository = SharedPreferencesNoteRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('aggregates activity by creation day and calculates streak', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    await repository.upsertNote(_note('today-1', today));
    await repository.upsertNote(_note('today-2', today, isArchived: true));
    await repository.upsertNote(_note('yesterday', yesterday));
    await repository.upsertNote(_note('two-days-ago', twoDaysAgo));

    final provider = NoteProvider(repository: repository);
    await provider.loadNotes();

    expect(provider.activityByDay[today], 2);
    expect(provider.notesForDay(today), hasLength(2));
    expect(provider.todayNotes, hasLength(1));
    expect(provider.currentStreak, 3);
  });
}

Note _note(String id, DateTime createdAt, {bool isArchived = false}) {
  return Note(
    id: id,
    title: id,
    content: '正文',
    createdAt: createdAt,
    updatedAt: createdAt,
    isArchived: isArchived,
  );
}
