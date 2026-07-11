import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_notes/main.dart';
import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/services/services.dart';
import 'package:daily_notes/domain/repositories/repositories.dart';
import 'package:daily_notes/presentation/pages/editor/editor_page.dart';
import 'package:daily_notes/presentation/pages/editor/note_block_editor.dart';
import 'package:daily_notes/presentation/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

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

Future<void> openTrash(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('homeSidebarButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trashDrawerItem')));
  await tester.pumpAndSettle();
}

void main() {
  final testRepository = _MemoryNoteRepository();
  final testApp = DailyNotesApp(noteRepository: testRepository);

  setUp(() {
    testRepository.clear();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    expect(find.text('Daily Notes'), findsOneWidget);
    expect(find.text('记录热力图'), findsNothing);
    expect(find.byKey(const ValueKey('quickCapture')), findsOneWidget);
    expect(find.text('统计总览'), findsNothing);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme.primary,
      const Color(0xFF356AE6),
    );
  });

  testWidgets('System back closes the home drawer before leaving the app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('homeSidebarButton')));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen,
      isTrue,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen,
      isFalse,
    );
    expect(find.text('Daily Notes'), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey('homeSidebarButton')));
    await tester.pumpAndSettle();
    final key = ValueKey(
      'activity-cell-${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
    );

    expect(find.byKey(key), findsOneWidget);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(find.text('${day.month}月${day.day}日 的笔记'), findsOneWidget);
    expect(find.text('热力图记录'), findsWidgets);
  });

  testWidgets('Persists the selected heatmap range with aligned month labels', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('homeSidebarButton')));
    await tester.pumpAndSettle();

    expect(find.text('最近 3 个月'), findsOneWidget);
    expect(find.byKey(const ValueKey('heatmapMonthLabels')), findsOneWidget);
    final monthLabels = find.descendant(
      of: find.byKey(const ValueKey('heatmapMonthLabels')),
      matching: find.byType(Text),
    );
    final monthPositions = monthLabels
        .evaluate()
        .map((element) => tester.getTopLeft(find.byWidget(element.widget)).dx)
        .toList();
    for (var index = 1; index < monthPositions.length; index++) {
      expect(
        monthPositions[index] - monthPositions[index - 1],
        greaterThan(24),
      );
    }
    await tester.tap(find.byKey(const ValueKey('heatmapRangeMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近 6 个月'));
    await tester.pumpAndSettle();

    expect(find.text('最近 6 个月'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_notes.heatmap_range'), 'sixMonths');
  });

  testWidgets('Saves and expands a home quick-capture draft', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('quickCaptureField')),
      '快速记录内容 #收集箱',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quickCaptureSaveButton')));
    await tester.pumpAndSettle();
    final quickField = tester.widget<TextField>(
      find.byKey(const ValueKey('quickCaptureField')),
    );
    expect(quickField.controller!.text, isEmpty);
    expect(find.textContaining('快速记录内容'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('quickCaptureField')),
      '带到完整编辑器的草稿',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quickCaptureExpandButton')));
    await tester.pumpAndSettle();
    final editor = tester.widget<NoteBlockEditor>(find.byType(NoteBlockEditor));
    expect(editor.controller.markdown, '带到完整编辑器的草稿');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的更改？'), findsOneWidget);
    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();
    final retainedQuickField = tester.widget<TextField>(
      find.byKey(const ValueKey('quickCaptureField')),
    );
    expect(retainedQuickField.controller!.text, '带到完整编辑器的草稿');

    await tester.tap(find.byKey(const ValueKey('quickCaptureExpandButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveNoteButton')));
    await tester.pumpAndSettle();

    final restoredQuickField = tester.widget<TextField>(
      find.byKey(const ValueKey('quickCaptureField')),
    );
    expect(restoredQuickField.controller!.text, isEmpty);
    expect(find.textContaining('带到完整编辑器'), findsWidgets);
  });

  testWidgets('Filters the main note stream from the left tag drawer', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'drawer-tagged',
        title: '项目记录',
        content: '正在推进 #工作/项目',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await testRepository.upsertNote(
      Note(
        id: 'drawer-untagged',
        title: '随手记录',
        content: '没有标签',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('homeSidebarButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('homeTag-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('homeTag-untagged')), findsOneWidget);
    expect(find.byKey(const ValueKey('homeTag-#工作')), findsOneWidget);
    expect(find.byKey(const ValueKey('homeTag-#工作/项目')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.tag),
      ),
      findsNothing,
    );
    await tester.tap(find.byTooltip('折叠 工作'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('homeTag-#工作/项目')), findsNothing);
    await tester.tap(find.byTooltip('展开 工作'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('homeTag-#工作/项目')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('homeTag-#工作')));
    await tester.pumpAndSettle();

    expect(find.text('项目记录'), findsWidgets);
    expect(find.text('随手记录'), findsNothing);
    expect(find.byKey(const ValueKey('inlineNoteTag-#工作/项目')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('remoteAiTagMenuItem')), findsNothing);
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

  testWidgets('Confirms scope before requesting and applying remote AI tags', (
    WidgetTester tester,
  ) async {
    final store = _MemoryAiConfigStore();
    final remoteClient = _RecordingAiRemoteClient();
    final aiProvider = AiProvider(
      configStore: store,
      remoteClient: remoteClient,
    );
    await aiProvider.save(
      AiConfig.validated(
        endpoint: 'https://example.com/v1',
        model: 'model-mini',
        apiKey: 'secret',
      ),
    );
    await tester.pumpWidget(
      DailyNotesApp(noteRepository: testRepository, aiProvider: aiProvider),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();
    await enterNoteBody(tester, '准备发布 Flutter 编辑器');

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remoteAiTagMenuItem')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remoteAiTagMenuItem')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remoteAiScopeDialog')), findsOneWidget);
    expect(remoteClient.callCount, 0);
    await tester.tap(find.byKey(const ValueKey('remoteAiScopeDetails')));
    await tester.pumpAndSettle();
    expect(find.textContaining('准备发布 Flutter 编辑器'), findsOneWidget);
    expect(remoteClient.callCount, 0);
    await tester.tap(find.byKey(const ValueKey('confirmRemoteAiTagsButton')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('remoteAiProgressDialog')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    expect(remoteClient.callCount, 1);
    expect(find.text('#开发/Flutter'), findsWidgets);
    final editor = tester.widget<NoteBlockEditor>(find.byType(NoteBlockEditor));
    expect(editor.controller.markdown, isNot(contains('#开发/Flutter')));
    await tester.tap(find.byKey(const ValueKey('applySmartTagsButton')));
    await tester.pumpAndSettle();
    expect(editor.controller.markdown, contains('#开发/Flutter'));
  });

  testWidgets('Reviews AI-cleaned voice text before inserting a version', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _MemoryAiConfigStore();
    final remoteClient = _RecordingAiRemoteClient();
    final aiProvider = AiProvider(
      configStore: store,
      remoteClient: remoteClient,
    );
    await aiProvider.save(
      AiConfig.validated(
        endpoint: 'https://example.com/v1',
        model: 'model-mini',
        apiKey: 'secret',
      ),
    );
    final noteProvider = NoteProvider(repository: testRepository);
    await noteProvider.loadNotes();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NoteProvider>.value(value: noteProvider),
          ChangeNotifierProvider<AiProvider>.value(value: aiProvider),
        ],
        child: const MaterialApp(
          home: EditorPage(initialVoiceTranscript: '嗯今天要整理发布计划'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('cleanVoiceWithAiButton')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('cleanVoiceWithAiButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('voiceAiScopeDialog')), findsOneWidget);
    expect(remoteClient.cleanCallCount, 0);
    await tester.tap(find.byKey(const ValueKey('confirmVoiceAiButton')));
    await tester.pump();
    expect(find.byKey(const ValueKey('voiceAiProgressDialog')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(remoteClient.cleanCallCount, 1);
    expect(find.byKey(const ValueKey('voiceVersionSegment')), findsOneWidget);
    expect(
      find.textContaining('今天要整理发布计划。', findRichText: true),
      findsOneWidget,
    );
    final editor = tester.widget<NoteBlockEditor>(find.byType(NoteBlockEditor));
    expect(editor.controller.markdown, isEmpty);
    await tester.tap(find.text('原文'));
    await tester.pumpAndSettle();
    expect(find.textContaining('嗯今天要整理'), findsOneWidget);
    await tester.tap(find.text('AI 建议'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('今天要整理发布计划。', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('insertVoiceInputButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('voiceInputPanel')), findsNothing);
    final updatedEditor = tester.widget<NoteBlockEditor>(
      find.byType(NoteBlockEditor),
    );
    expect(updatedEditor.controller.markdown, contains('今天要整理发布计划。'));
  });

  testWidgets('Finds and opens explainable local related notes', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'related-source',
        title: 'Flutter 发布复盘',
        content: 'Flutter 编辑器发布检查与状态管理 #开发',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await testRepository.upsertNote(
      Note(
        id: 'unrelated-source',
        title: '采购清单',
        content: '牛奶和水果 #生活',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();
    await enterNoteBody(tester, '继续完善 Flutter 编辑器发布流程 #开发');

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relatedNotesMenuItem')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('relatedNote-related-source')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('relatedNote-unrelated-source')),
      findsNothing,
    );
    expect(find.textContaining('共同标签'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('relatedNote-related-source')));
    await tester.pumpAndSettle();

    final titleField = tester.widget<TextField>(
      find.byKey(const ValueKey('noteTitleField')),
    );
    expect(titleField.controller!.text, 'Flutter 发布复盘');
  });

  testWidgets('Asks selected notes and opens a validated citation', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'ask-source',
        title: '发布流程结论',
        content: '发布前需要完成完整回归测试。 #开发',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await testRepository.upsertNote(
      Note(
        id: 'ask-archived',
        title: '不应发送的归档笔记',
        content: '归档内容',
        createdAt: now,
        updatedAt: now,
        isArchived: true,
      ),
    );
    final store = _MemoryAiConfigStore();
    final remoteClient = _RecordingAiRemoteClient();
    final aiProvider = AiProvider(
      configStore: store,
      remoteClient: remoteClient,
    );
    await aiProvider.save(
      AiConfig.validated(
        endpoint: 'https://example.com/v1',
        model: 'model-mini',
        apiKey: 'secret',
      ),
    );
    await tester.pumpWidget(
      DailyNotesApp(noteRepository: testRepository, aiProvider: aiProvider),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('askNotesButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('askNotesQuestionField')),
      '发布前要完成什么？',
    );
    await tester.tap(find.byKey(const ValueKey('askNotesSourceDetails')));
    await tester.pumpAndSettle();
    expect(find.text('发布流程结论'), findsWidgets);
    expect(find.text('不应发送的归档笔记'), findsNothing);
    expect(remoteClient.askCallCount, 0);
    await tester.tap(find.byKey(const ValueKey('confirmAskNotesButton')));
    await tester.pumpAndSettle();

    expect(remoteClient.askCallCount, 1);
    final answerText = tester.widget<SelectableText>(
      find.byKey(const ValueKey('askNotesAnswerText')),
    );
    expect(answerText.data, '发布前需要完成完整回归测试。');
    expect(
      find.byKey(const ValueKey('askNotesCitation-ask-source')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('askNotesCitation-ask-source')));
    await tester.pumpAndSettle();
    final titleField = tester.widget<TextField>(
      find.byKey(const ValueKey('noteTitleField')),
    );
    expect(titleField.controller!.text, '发布流程结论');
  });

  testWidgets('Reviews confirmed notes and saves insight only after approval', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'review-source',
        title: '本周发布复盘',
        content: '本周开始把稳定性放在发布速度之前。 #开发',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await testRepository.upsertNote(
      Note(
        id: 'review-archived',
        title: '不应回顾的归档笔记',
        content: '归档内容',
        createdAt: now,
        updatedAt: now,
        isArchived: true,
      ),
    );
    final remoteClient = _RecordingAiRemoteClient();
    final aiProvider = AiProvider(
      configStore: _MemoryAiConfigStore(),
      remoteClient: remoteClient,
    );
    await aiProvider.save(
      AiConfig.validated(
        endpoint: 'https://example.com/v1',
        model: 'model-mini',
        apiKey: 'secret',
      ),
    );
    await tester.pumpWidget(
      DailyNotesApp(noteRepository: testRepository, aiProvider: aiProvider),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('homeSidebarButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reviewInsightDrawerItem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reviewInsightSourceDetails')));
    await tester.pumpAndSettle();
    expect(find.text('本周发布复盘'), findsWidgets);
    expect(find.text('不应回顾的归档笔记'), findsNothing);
    expect(remoteClient.reviewCallCount, 0);
    expect((await testRepository.getNotes()).length, 2);

    await tester.tap(find.byKey(const ValueKey('confirmReviewInsightButton')));
    await tester.pumpAndSettle();

    expect(remoteClient.reviewCallCount, 1);
    expect(find.byKey(const ValueKey('reviewInsightSummary')), findsOneWidget);
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('reviewInsightSheet')),
        matching: find.byType(ListView),
      ),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reviewInsightSource-review-source')),
      findsOneWidget,
    );
    expect((await testRepository.getNotes()).length, 2);

    await tester.tap(find.byKey(const ValueKey('saveReviewInsightButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('saveReviewInsightConfirmDialog')),
      findsOneWidget,
    );
    expect((await testRepository.getNotes()).length, 2);
    await tester.tap(
      find.byKey(const ValueKey('confirmSaveReviewInsightButton')),
    );
    await tester.pumpAndSettle();

    final savedNotes = await testRepository.getNotes();
    expect(savedNotes, hasLength(3));
    final insightNote = savedNotes.firstWhere(
      (note) => note.title.startsWith('回顾洞察'),
    );
    expect(insightNote.content, contains('## 反复主题'));
    expect(insightNote.content, contains('#回顾/AI洞察'));
    expect(insightNote.tags, contains('#回顾/AI洞察'));
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
    await tester.tap(find.byKey(const ValueKey('selectedImageMoreButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setCoverImageMenuItem')));
    await tester.pumpAndSettle();
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
    expect(saved.coverImageId, 'mixed-image');
    expect(saved.coverImage?.id, 'mixed-image');
  });

  testWidgets('Searches home and restores or permanently deletes trash', (
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
        id: 'delete-archived-note',
        title: '需要永久删除',
        content: '废弃内容',
        createdAt: date.subtract(const Duration(days: 2)),
        updatedAt: date,
        isArchived: true,
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

    await tester.tap(find.byKey(const ValueKey('homeSearchButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('homeSearchField')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('homeSearchField')),
      '当前项目',
    );
    await tester.pumpAndSettle();
    expect(find.text('当前项目'), findsWidgets);
    expect(find.text('归档生活记录'), findsNothing);
    await tester.tap(find.byTooltip('关闭搜索'));
    await tester.pumpAndSettle();

    await openTrash(tester);

    expect(find.text('回收站'), findsOneWidget);
    expect(find.byKey(const ValueKey('trashSearchField')), findsOneWidget);
    expect(find.text('归档生活记录'), findsOneWidget);
    expect(find.text('当前项目'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('trashSearchField')),
      '#工作',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的笔记'), findsOneWidget);
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('restoreTrash-archived-note')));
    await tester.pumpAndSettle();
    expect(find.text('归档生活记录'), findsNothing);
    expect(
      (await testRepository.getNoteById('archived-note'))!.isArchived,
      isFalse,
    );

    await tester.tap(
      find.byKey(const ValueKey('deleteTrash-delete-archived-note')),
    );
    await tester.pumpAndSettle();
    expect(find.text('永久删除？'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirmPermanentDeleteButton')),
    );
    await tester.pumpAndSettle();
    expect(await testRepository.getNoteById('delete-archived-note'), isNull);
  });

  testWidgets('Moves a saved note to trash without deleting it', (
    WidgetTester tester,
  ) async {
    final date = DateTime.now();
    await testRepository.upsertNote(
      Note(
        id: 'move-to-trash-note',
        title: '稍后恢复',
        content: '仍需保留的内容',
        createdAt: date,
        updatedAt: date,
      ),
    );

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.text('稍后恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moveToTrashMenuItem')));
    await tester.pumpAndSettle();
    expect(find.text('移到回收站？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmMoveToTrashButton')));
    await tester.pumpAndSettle();

    final stored = await testRepository.getNoteById('move-to-trash-note');
    expect(stored, isNotNull);
    expect(stored!.isArchived, isTrue);
    expect(find.text('稍后恢复'), findsNothing);
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

  testWidgets('Combines home tag and text filters', (
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
    await tester.tap(find.byKey(const ValueKey('homeSidebarButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('homeTag-untagged')));
    await tester.pumpAndSettle();
    expect(find.text('尚未整理'), findsOneWidget);
    expect(find.text('已经整理'), findsNothing);
    expect(find.textContaining('已归类'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('homeSearchButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('homeSearchField')),
      '已经整理',
    );
    await tester.pumpAndSettle();
    expect(find.text('已经整理'), findsOneWidget);
    expect(find.textContaining('已归类'), findsNothing);
    expect(find.text('尚未整理'), findsNothing);
  });

  testWidgets('Persists theme mode from settings', (WidgetTester tester) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_notes.theme_mode'), 'dark');
  });

  testWidgets('Persists color palette from settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('东京'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_notes.color_palette'), 'tokyoNight');
    expect(
      Theme.of(
        tester.element(
          find.byKey(const ValueKey('colorPaletteSegmentedButton')),
        ),
      ).colorScheme.primary,
      const Color(0xFF2959AA),
    );
  });

  testWidgets('Shows file export, import, and synchronization actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('导出笔记'), findsOneWidget);
    expect(find.text('导入笔记'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exportNotesItem')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('exportMarkdownZipOption')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('exportJsonOption')), findsOneWidget);
    expect(find.text('跨应用迁移，包含 Markdown 与图片目录'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

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

  testWidgets('Shows automatic and manual update controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('checkAppUpdateItem')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('autoUpdateSwitch')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkAppUpdateItem')), findsOneWidget);
    expect(find.text('每 24 小时检查一次，不会自动安装'), findsOneWidget);
  });

  testWidgets('Shows and validates encrypted AI configuration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('aiConfigItem')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    final aiConfigItem = find.byKey(const ValueKey('aiConfigItem'));
    await Scrollable.ensureVisible(
      tester.element(aiConfigItem),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(aiConfigItem);
    await tester.pumpAndSettle();

    expect(find.text('AI 配置'), findsOneWidget);
    expect(find.byKey(const ValueKey('aiEndpointField')), findsOneWidget);
    expect(find.byKey(const ValueKey('aiModelField')), findsOneWidget);
    expect(find.byKey(const ValueKey('aiApiKeyField')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('aiEndpointField')),
      'http://example.com/v1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('aiModelField')),
      'model-mini',
    );
    await tester.tap(find.byKey(const ValueKey('saveAiConfigButton')));
    await tester.pumpAndSettle();

    expect(find.text('远端 AI 地址必须使用 HTTPS'), findsOneWidget);
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

class _MemoryAiConfigStore implements AiConfigStore {
  AiConfig? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AiConfig?> load() async => value;

  @override
  Future<void> save(AiConfig config) async => value = config;
}

class _RecordingAiRemoteClient extends AiRemoteClient {
  int callCount = 0;
  int cleanCallCount = 0;
  int askCallCount = 0;
  int reviewCallCount = 0;

  @override
  Future<List<AiTagSuggestion>> suggestTags(
    AiConfig config,
    AiNoteContext context, {
    CancelToken? cancelToken,
  }) async {
    callCount++;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return const [
      AiTagSuggestion(tag: '#开发/Flutter', reason: '正文提到了 Flutter 编辑器'),
    ];
  }

  @override
  Future<AiTranscriptSuggestion> cleanTranscript(
    AiConfig config,
    String transcript, {
    CancelToken? cancelToken,
  }) async {
    cleanCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return AiTranscriptSuggestion(
      original: transcript,
      suggested: '今天要整理发布计划。',
    );
  }

  @override
  Future<AiGroundedAnswer> askNotes(
    AiConfig config, {
    required String question,
    required List<AiSourceNote> sources,
    CancelToken? cancelToken,
  }) async {
    askCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return AiGroundedAnswer(
      answer: '发布前需要完成完整回归测试。',
      citations: [
        AiGroundedCitation(noteId: sources.single.id, reason: '来源笔记明确记录了发布前步骤'),
      ],
    );
  }

  @override
  Future<AiReviewInsight> createReviewInsight(
    AiConfig config, {
    required List<AiSourceNote> sources,
    CancelToken? cancelToken,
  }) async {
    reviewCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return AiReviewInsight(
      summary: '近期更重视发布稳定性。',
      themes: const ['回归测试与稳定性'],
      viewpointChanges: const ['从快速发布转向稳定优先'],
      openQuestions: const ['自动化覆盖是否足够？'],
      contradictions: const ['速度与稳定性的取舍仍需明确'],
      sourceNoteIds: sources.map((source) => source.id).toList(),
      model: config.model,
      generatedAt: DateTime(2026, 7, 11, 10, 30),
    );
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
