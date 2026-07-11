import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_notes/main.dart';
import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/services/services.dart';
import 'package:daily_notes/domain/repositories/repositories.dart';
import 'package:daily_notes/presentation/pages/editor/note_block_editor.dart';

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> enterNoteBody(WidgetTester tester, String text) async {
  final editor = tester.widget<NoteBlockEditor>(find.byType(NoteBlockEditor));
  await editor.controller.insertText(text);
  await tester.pump();
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
    expect(find.byKey(const ValueKey('inlineTagButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('noteTagField')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('noteTitleField')),
      '可用性测试笔记',
    );
    await enterNoteBody(tester, '这是一条可以保存并显示在首页的笔记。 #工作/项目');
    await tester.tap(find.byKey(const ValueKey('saveNoteButton')));
    await tester.pumpAndSettle();

    expect(find.text('可用性测试笔记'), findsWidgets);
    expect(find.textContaining('可以保存并显示'), findsWidgets);
  });

  testWidgets('Previews Markdown without changing the draft', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();
    await enterNoteBody(tester, '# Preview heading\n- first item\n#tag');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    final previewMenuItem = find.byKey(
      const ValueKey('markdownPreviewMenuItem'),
    );
    expect(previewMenuItem, findsOneWidget);
    await tester.tap(previewMenuItem);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('markdownPreview')), findsOneWidget);
    final preview = find.byKey(const ValueKey('markdownPreview'));
    expect(
      find.descendant(
        of: preview,
        matching: find.text('Preview heading', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.textContaining('first item', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.textContaining('#tag', findRichText: true),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('closeMarkdownPreviewButton')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('noteContentEditor')),
        matching: find.textContaining('Preview heading', findRichText: true),
      ),
      findsWidgets,
    );
  });

  testWidgets('Suggests and confirms private local tags', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'tag-source',
        title: 'Flutter 编辑器记录',
        content: 'Flutter 编辑器状态管理和发布检查',
        createdAt: now,
        updatedAt: now,
        tags: const ['#开发/Flutter'],
      ),
    );
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();
    await enterNoteBody(tester, '继续完善 Flutter 编辑器');

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('smartTagMenuItem')));
    await tester.pumpAndSettle();

    expect(find.text('本次分析仅在设备上进行'), findsOneWidget);
    expect(find.text('#开发/Flutter'), findsWidgets);
    expect(find.textContaining('将插入：#开发/Flutter'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('applySmartTagsButton')));
    await tester.pumpAndSettle();

    final editor = tester.widget<NoteBlockEditor>(find.byType(NoteBlockEditor));
    expect(editor.controller.markdown, contains('#开发/Flutter'));
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
    final inlineImage = find.descendant(
      of: find.byKey(const ValueKey('noteContentEditor')),
      matching: find.byType(Image),
    );
    expect(inlineImage, findsOneWidget);
    final blockEditor = tester.widget<NoteBlockEditor>(
      find.byType(NoteBlockEditor),
    );
    final imageIndex = blockEditor.controller.blocks.indexWhere(
      (block) => block.type == NoteBlockType.image,
    );
    blockEditor.controller.editorState.selection = Selection.single(
      path: [imageIndex],
      startOffset: 0,
      endOffset: 1,
    );
    await tester.pump();
    final imageMoreButton = find.byKey(
      const ValueKey('selectedImageMoreButton'),
    );
    expect(imageMoreButton, findsOneWidget);
    await tester.tap(imageMoreButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑说明').last);
    await tester.pumpAndSettle();
    final captionField = tester.widget<TextField>(
      find.byKey(const ValueKey('imageCaptionField')),
    );
    captionField.controller!.text = '测试图片说明';
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saveImageCaptionButton')));
    await tester.pumpAndSettle();
    expect(find.text('测试图片说明'), findsOneWidget);

    await tester.tap(imageMoreButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除图片').last);
    await tester.pumpAndSettle();
    expect(inlineImage, findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的更改？'), findsOneWidget);
  });

  testWidgets('Persists mixed text and image block order', (
    WidgetTester tester,
  ) async {
    final date = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'mixed-note',
        title: '混排笔记',
        content: 'Before\nAfter',
        createdAt: date,
        updatedAt: date,
        images: const [
          NoteImage(
            id: 'mixed-image',
            name: 'pixel.png',
            mimeType: 'image/png',
            base64Data:
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
        ],
        blocks: const [
          NoteBlock(
            id: 'before',
            type: NoteBlockType.paragraph,
            text: 'Before',
          ),
          NoteBlock(
            id: 'mixed-image-block',
            type: NoteBlockType.image,
            imageId: 'mixed-image',
          ),
          NoteBlock(id: 'after', type: NoteBlockType.paragraph, text: 'After'),
        ],
      ),
    );

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.text('混排笔记').first);
    await tester.pumpAndSettle();
    final editor = tester.widget<NoteBlockEditor>(find.byType(NoteBlockEditor));
    editor.controller.editorState.selection = Selection.single(
      path: const [1],
      startOffset: 0,
      endOffset: 1,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('moveSelectedImageDownButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveNoteButton')));
    await tester.pumpAndSettle();

    final saved = await testRepository.getNoteById('mixed-note');
    expect(saved!.blocks.map((block) => block.type), [
      NoteBlockType.paragraph,
      NoteBlockType.paragraph,
      NoteBlockType.image,
    ]);
    expect(saved.blocks[2].imageId, 'mixed-image');
  });

  testWidgets('Searches and filters active and archived notes', (
    WidgetTester tester,
  ) async {
    final date = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'active-note',
        title: '当前项目',
        content: '#工作/项目 正在推进',
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
    expect(find.byKey(const ValueKey('historyTag-#工作/项目')), findsOneWidget);
    expect(find.byKey(const ValueKey('historyTag-#生活')), findsOneWidget);
    expect(find.byKey(const ValueKey('randomReviewButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('randomReviewButton')));
    await tester.pumpAndSettle();
    final reviewedTitle = tester.widget<TextField>(
      find.byKey(const ValueKey('noteTitleField')),
    );
    expect(reviewedTitle.controller?.text, '当前项目');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

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

  testWidgets('Moves legacy explicit tags into the note body', (
    WidgetTester tester,
  ) async {
    final date = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'legacy-explicit-tag',
        title: '旧标签笔记',
        content: '原始正文',
        tags: const ['#迁移/待办'],
        createdAt: date,
        updatedAt: date,
      ),
    );

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('旧标签笔记'));
    await tester.pumpAndSettle();

    final editor = find.byKey(const ValueKey('noteContentEditor'));
    expect(
      find.descendant(
        of: editor,
        matching: find.textContaining('原始正文', findRichText: true),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: editor,
        matching: find.textContaining('#迁移/待办', findRichText: true),
      ),
      findsWidgets,
    );
  });

  testWidgets('Filters untagged notes and clears a stale tag filter', (
    WidgetTester tester,
  ) async {
    final date = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'untagged-note',
        title: '尚未整理',
        content: '没有标签的内容',
        createdAt: date,
        updatedAt: date,
      ),
    );
    await testRepository.upsertNote(
      Note(
        id: 'tagged-note',
        title: '已经整理',
        content: '#项目 已归类',
        createdAt: date,
        updatedAt: date,
      ),
    );

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('historyTag-untagged')));
    await tester.pumpAndSettle();
    expect(find.text('尚未整理'), findsOneWidget);
    expect(find.text('已经整理'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('historySearchField')),
      '已经整理',
    );
    await tester.pumpAndSettle();
    expect(find.text('已经整理'), findsWidgets);
    expect(find.text('尚未整理'), findsNothing);
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
    expect(find.byKey(const ValueKey('webDavConfigItem')), findsOneWidget);
    expect(find.byKey(const ValueKey('webDavSyncItem')), findsOneWidget);
    expect(find.byKey(const ValueKey('webDavUploadItem')), findsOneWidget);
    expect(find.byKey(const ValueKey('webDavDownloadItem')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('webDavConfigItem')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('webDavConfigItem')));
    await tester.pumpAndSettle();

    expect(find.text('WebDAV 同步'), findsOneWidget);
    expect(find.byKey(const ValueKey('webDavServerField')), findsOneWidget);
    expect(find.byKey(const ValueKey('webDavUsernameField')), findsOneWidget);
    expect(find.byKey(const ValueKey('webDavPasswordField')), findsOneWidget);
    expect(find.byKey(const ValueKey('webDavDirectoryField')), findsOneWidget);
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
    await enterNoteBody(tester, '备份正文');
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
