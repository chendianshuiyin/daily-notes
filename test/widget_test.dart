import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_notes/main.dart';
import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/services/services.dart';
import 'package:daily_notes/domain/repositories/repositories.dart';

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final testRepository = _MemoryNoteRepository();
  final testApp = DailyNotesApp(noteRepository: testRepository);
  String clipboardText = '';

  setUp(() {
    testRepository.clear();
    SharedPreferences.setMockInitialValues({});
    clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = Map<String, dynamic>.from(call.arguments as Map);
            clipboardText = arguments['text'] as String? ?? '';
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    expect(find.text('Daily Notes'), findsOneWidget);
    expect(find.text('记录热力图'), findsNothing);
    expect(find.textContaining('最近 '), findsOneWidget);
  });

  testWidgets('Selects a day from the activity heatmap', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    await testRepository.upsertNote(
      Note(
        id: 'activity-note',
        title: '热力图记录',
        content: '当天详情',
        createdAt: day,
        updatedAt: day,
      ),
    );

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    final key = ValueKey(
      'activity-cell-${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
    );

    expect(find.byKey(key), findsOneWidget);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(find.text('每日详情 · ${day.month}月${day.day}日'), findsOneWidget);
    expect(find.text('热力图记录'), findsWidgets);
  });

  testWidgets('Creates and lists a note', (WidgetTester tester) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('添加图片'), findsOneWidget);
    expect(find.byKey(const ValueKey('voiceInputButton')), findsOneWidget);
    expect(find.byTooltip('开始语音输入'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('noteTitleField')),
      '可用性测试笔记',
    );
    await tester.enterText(
      find.byKey(const ValueKey('noteContentField')),
      '这是一条可以保存并显示在首页的笔记。',
    );
    await tester.enterText(find.byKey(const ValueKey('noteTagField')), '工作');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('#工作'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('saveNoteButton')));
    await tester.pumpAndSettle();

    expect(find.text('可用性测试笔记'), findsWidgets);
    expect(find.textContaining('可以保存并显示'), findsWidgets);
  });

  testWidgets('Displays and removes an existing image attachment', (
    WidgetTester tester,
  ) async {
    final date = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'image-note',
        title: '图文笔记',
        content: '带有一张图片',
        createdAt: date,
        updatedAt: date,
        images: const [
          NoteImage(
            id: 'image-1',
            name: 'pixel.png',
            mimeType: 'image/png',
            base64Data:
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
        ],
      ),
    );

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('图文笔记'));
    expect(find.text('图文笔记'), findsWidgets);

    await tester.tap(find.text('图文笔记').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('noteImage-image-1')), findsOneWidget);

    final removeImageButton = find.byKey(
      const ValueKey('removeNoteImage-image-1'),
    );
    await tester.ensureVisible(removeImageButton);
    await tester.tap(removeImageButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('noteImage-image-1')), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的更改？'), findsOneWidget);
  });

  testWidgets('Searches and filters active and archived notes', (
    WidgetTester tester,
  ) async {
    final date = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'active-note',
        title: '当前项目',
        content: '#工作 正在推进',
        createdAt: date,
        updatedAt: date,
      ),
    );
    await testRepository.upsertNote(
      Note(
        id: 'archived-note',
        title: '归档生活记录',
        content: '#生活 已完成',
        createdAt: date.subtract(const Duration(days: 1)),
        updatedAt: date,
        isArchived: true,
      ),
    );

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('historySearchField')), findsOneWidget);
    expect(find.text('全部 2'), findsOneWidget);
    expect(find.text('当前 1'), findsOneWidget);
    expect(find.text('已归档 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('historyTag-#工作')), findsOneWidget);
    expect(find.byKey(const ValueKey('historyTag-#生活')), findsOneWidget);
    final workTagChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('historyTag-#工作')),
    );
    final colorScheme = Theme.of(
      tester.element(find.byKey(const ValueKey('historyTag-#工作'))),
    ).colorScheme;
    expect(workTagChip.labelStyle?.color, colorScheme.onSurface);

    await tester.tap(find.byKey(const ValueKey('historyTag-#工作')));
    await tester.pumpAndSettle();
    expect(find.text('当前项目'), findsOneWidget);
    expect(find.text('归档生活记录'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('historyTag-all')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('已归档 1'));
    await tester.pumpAndSettle();
    expect(find.text('归档生活记录'), findsOneWidget);
    expect(find.text('当前项目'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('historySearchField')),
      '#工作',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的笔记'), findsOneWidget);
  });

  testWidgets('Persists theme mode from settings', (WidgetTester tester) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_notes.theme_mode'), 'dark');
  });

  testWidgets('Shows data backup and restore actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('复制笔记备份'), findsOneWidget);
    expect(find.text('从剪贴板恢复'), findsOneWidget);
    expect(find.text('WebDAV 同步'), findsNothing);
  });

  testWidgets('Copies a valid backup to the clipboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('noteTitleField')),
      '需要备份的笔记',
    );
    await tester.enterText(
      find.byKey(const ValueKey('noteContentField')),
      '备份正文',
    );
    await tester.tap(find.byKey(const ValueKey('saveNoteButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制笔记备份'));
    await tester.pump(const Duration(milliseconds: 100));

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final backup = const NoteBackupService().decode(clipboardData!.text!);
    expect(backup.notes, hasLength(1));
    expect(backup.notes.single.title, '需要备份的笔记');
  });

  testWidgets('Restores a backup from the clipboard', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final note = Note(
      id: 'restore-note',
      title: '从备份恢复的笔记',
      content: '恢复后的正文',
      createdAt: now,
      updatedAt: now,
    );
    final source = const NoteBackupService().encode([note]);
    await Clipboard.setData(ClipboardData(text: source));

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从剪贴板恢复'));
    await tester.pumpAndSettle();

    expect(find.text('恢复笔记备份？'), findsOneWidget);
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已恢复 1 条笔记'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('从备份恢复的笔记'));
    expect(find.text('从备份恢复的笔记'), findsWidgets);
  });

  testWidgets('Confirms before discarding an unsaved note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp);
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
    await tester.tap(find.byKey(const ValueKey('saveNoteButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('保存失败，请重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('noteTitleField')), findsOneWidget);
    expect(find.text('不要丢失这条草稿'), findsOneWidget);
  });
}

class _MemoryNoteRepository implements NoteRepository {
  final List<Note> _notes = [];

  void clear() => _notes.clear();

  @override
  Future<List<Note>> getNotes() async {
    return List.of(_notes)
      ..sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
  }

  @override
  Future<Note?> getNoteById(String id) async {
    for (final note in _notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  @override
  Future<void> upsertNote(Note note) async {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) {
      _notes.add(note);
    } else {
      _notes[index] = note;
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.removeWhere((note) => note.id == id);
  }

  @override
  Future<void> archiveNote(String id, {required bool isArchived}) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      return;
    }
    _notes[index] = _notes[index].copyWith(
      isArchived: isArchived,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> mergeNotes(List<Note> notes) async {
    for (final note in notes) {
      await upsertNote(note);
    }
  }
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
  Future<void> mergeNotes(List<Note> notes) async {}

  @override
  Future<void> upsertNote(Note note) async {
    throw StateError('Simulated persistence failure');
  }
}
