import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_notes/main.dart';
import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/domain/repositories/repositories.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyNotesApp());
    await tester.pumpAndSettle();

    expect(find.text('Daily Notes'), findsOneWidget);
  });

  testWidgets('Creates and lists a note', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyNotesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('noteTitleField')),
      '可用性测试笔记',
    );
    await tester.enterText(
      find.byKey(const ValueKey('noteContentField')),
      '这是一条可以保存并显示在首页的笔记。',
    );
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(find.text('可用性测试笔记'), findsWidgets);
    expect(find.textContaining('可以保存并显示'), findsWidgets);
  });

  testWidgets('Persists theme mode from settings', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyNotesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_notes.theme_mode'), 'dark');
  });

  testWidgets('Confirms before discarding an unsaved note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DailyNotesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('noteTitleField')),
      '尚未保存的内容',
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('放弃未保存的更改？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('noteTitleField')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Notes'), findsOneWidget);
  });

  testWidgets('Keeps the draft visible when saving fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const DailyNotesApp(noteRepository: _FailingNoteRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('noteTitleField')),
      '不要丢失这条草稿',
    );
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('保存失败，请重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('noteTitleField')), findsOneWidget);
    expect(find.text('不要丢失这条草稿'), findsOneWidget);
  });
}

class _FailingNoteRepository implements NoteRepository {
  const _FailingNoteRepository();

  @override
  Future<void> archiveNote(String id, {required bool isArchived}) async {}

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<Note?> getNoteById(String id) async => null;

  @override
  Future<List<Note>> getNotes() async => [];

  @override
  Future<void> upsertNote(Note note) async {
    throw StateError('Simulated persistence failure');
  }
}
