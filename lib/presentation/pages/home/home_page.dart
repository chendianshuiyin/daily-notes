import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../providers/providers.dart';
import '../../routers/app_router.dart';

/// Home dashboard with activity history and recent notes.
enum _AskNotesScope { filtered, selectedDay, all }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _quickController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = _dateOnly(DateTime.now());
  DateTime? _selectedDateFilter;
  String? _selectedTag;
  bool _isQuickSaving = false;
  bool _isSearching = false;
  bool _isDrawerOpen = false;
  String _searchQuery = '';
  Timer? _updateCheckTimer;

  static const _untagged = '__untagged__';

  @override
  void initState() {
    super.initState();
    if (kReleaseMode) {
      _updateCheckTimer = Timer(
        const Duration(seconds: 3),
        _checkAutomaticUpdate,
      );
    }
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    _quickController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAutomaticUpdate() async {
    if (!mounted) return;
    final updates = context.read<AppUpdateProvider>();
    if (!updates.shouldAutoCheck) return;
    final release = await updates.checkForUpdates();
    if (!mounted || release == null) return;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AppUpdateDialog(
        currentVersion: updates.currentVersion,
        release: release,
      ),
    );
    if (shouldOpen == true && mounted) {
      final opened = await updates.openAvailableUpdate();
      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开更新下载地址')));
      }
    }
  }

  bool _matchesSelectedTag(Note note) {
    return _selectedTag == null ||
        (_selectedTag == _untagged
            ? note.tags.isEmpty
            : Note.matchesTag(note.tags, _selectedTag!));
  }

  bool _matchesHomeFilter(Note note) {
    final date = _selectedDateFilter;
    final query = _searchQuery.trim().toLowerCase();
    final matchesSearch =
        query.isEmpty ||
        note.title.toLowerCase().contains(query) ||
        note.content.toLowerCase().contains(query) ||
        note.tags.any((tag) => tag.toLowerCase().contains(query));
    return _matchesSelectedTag(note) &&
        matchesSearch &&
        (date == null || DateUtil.isSameDay(note.createdAt, date));
  }

  void _openSearch() {
    setState(() => _isSearching = true);
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
  }

  Future<void> _saveQuickNote() async {
    final content = _quickController.text.trim();
    if (content.isEmpty || _isQuickSaving) {
      return;
    }
    setState(() => _isQuickSaving = true);
    try {
      await context.read<NoteProvider>().saveNote(
        title: '',
        content: content,
        tags: Note.extractTags(content),
      );
      _quickController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已记录')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('记录失败，草稿仍保留')));
      }
    } finally {
      if (mounted) {
        setState(() => _isQuickSaving = false);
      }
    }
  }

  Future<void> _openQuickInEditor() async {
    final draft = _quickController.text;
    final saved = await context.push<bool>(AppRouter.editor, extra: draft);
    if (saved == true && mounted) {
      _quickController.clear();
      setState(() {});
    }
  }

  void _insertQuickTag() {
    final value = _quickController.value;
    final selection = value.selection;
    final offset = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final updated = value.text.replaceRange(offset, end, '#');
    _quickController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: offset + 1),
    );
  }

  List<Note> _notesForAiScope(NoteProvider noteProvider, _AskNotesScope scope) {
    final notes = switch (scope) {
      _AskNotesScope.filtered =>
        noteProvider.activeNotes.where(_matchesSelectedTag).toList(),
      _AskNotesScope.selectedDay =>
        noteProvider
            .notesForDay(_selectedDate)
            .where((note) => !note.isArchived)
            .toList(),
      _AskNotesScope.all => noteProvider.activeNotes,
    };
    return notes
        .where(
          (note) =>
              note.title.trim().isNotEmpty || note.content.trim().isNotEmpty,
        )
        .take(30)
        .toList();
  }

  String _aiScopeLabel(_AskNotesScope scope) {
    return switch (scope) {
      _AskNotesScope.filtered =>
        _selectedTag == _untagged ? '当前筛选：无标签' : '当前筛选：${_selectedTag ?? '全部'}',
      _AskNotesScope.selectedDay => '日期：${_formatDay(_selectedDate)}',
      _AskNotesScope.all => '全部活动笔记',
    };
  }

  List<AiSourceNote> _toAiSources(Iterable<Note> notes) {
    return [
      for (final note in notes)
        AiSourceNote(
          id: note.id,
          date: note.createdAt,
          title: note.title,
          content: note.content,
          tags: note.tags,
        ),
    ];
  }

  Future<void> _showAskNotes() async {
    final ai = context.read<AiProvider>();
    final noteProvider = context.read<NoteProvider>();
    final config = ai.config;
    if (config == null) {
      return;
    }
    final questionController = TextEditingController();
    var scope = _selectedTag == null
        ? _AskNotesScope.all
        : _AskNotesScope.filtered;
    String? errorMessage;

    _AskNotesRequest? request;
    try {
      request = await showDialog<_AskNotesRequest>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final scopedNotes = _notesForAiScope(noteProvider, scope);
            return AlertDialog(
              key: const ValueKey('askNotesScopeDialog'),
              title: const Text('问我的笔记'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('askNotesQuestionField'),
                        controller: questionController,
                        autofocus: true,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: '问题',
                          hintText: '例如：最近关于发布流程有哪些结论？',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<_AskNotesScope>(
                        key: const ValueKey('askNotesScopeField'),
                        initialValue: scope,
                        decoration: const InputDecoration(labelText: '来源范围'),
                        items: [
                          if (_selectedTag != null)
                            DropdownMenuItem(
                              value: _AskNotesScope.filtered,
                              child: Text(
                                _aiScopeLabel(_AskNotesScope.filtered),
                              ),
                            ),
                          DropdownMenuItem(
                            value: _AskNotesScope.selectedDay,
                            child: Text(
                              _aiScopeLabel(_AskNotesScope.selectedDay),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: _AskNotesScope.all,
                            child: Text('全部活动笔记'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              scope = value;
                              errorMessage = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ExpansionTile(
                        key: const ValueKey('askNotesSourceDetails'),
                        tilePadding: EdgeInsets.zero,
                        title: Text('将发送 ${scopedNotes.length} 条笔记'),
                        subtitle: const Text('每条仅发送标题、日期、标签和前 2000 字'),
                        children: [
                          for (final note in scopedNotes)
                            ListTile(
                              dense: true,
                              title: Text(note.displayTitle),
                              subtitle: Text(
                                '${note.createdAt.year}-${note.createdAt.month.toString().padLeft(2, '0')}-${note.createdAt.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                        ],
                      ),
                      const Text('不会发送图片、回收站笔记、WebDAV 凭据或隐藏元数据。'),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  key: const ValueKey('confirmAskNotesButton'),
                  onPressed: () {
                    final question = questionController.text.trim();
                    if (question.isEmpty) {
                      setDialogState(() => errorMessage = '请输入问题');
                      return;
                    }
                    if (scopedNotes.isEmpty) {
                      setDialogState(() => errorMessage = '当前范围没有可发送的笔记');
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _AskNotesRequest(
                        question: question,
                        sources: _toAiSources(scopedNotes),
                      ),
                    );
                  },
                  child: const Text('确认发送'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      await Future<void>.delayed(kThemeAnimationDuration);
      questionController.dispose();
    }
    if (request == null || !mounted) {
      return;
    }
    final result = await showDialog<_AskNotesResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _AskNotesProgressDialog(provider: ai, request: request!),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!.message)));
      return;
    }
    await _showGroundedAnswer(result.answer!, request.sources);
  }

  Future<void> _showGroundedAnswer(
    AiGroundedAnswer answer,
    List<AiSourceNote> sources,
  ) async {
    final sourceById = {for (final source in sources) source.id: source};
    final noteId = await showModalBottomSheet<String>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 720),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.question_answer_outlined),
                    const SizedBox(width: 8),
                    Text(
                      '来自我的笔记',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭回答',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    SelectableText(
                      answer.answer,
                      key: const ValueKey('askNotesAnswerText'),
                      style: Theme.of(sheetContext).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '来源',
                      style: Theme.of(sheetContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (answer.citations.isEmpty)
                      const Text('这次回答没有足够的笔记证据。')
                    else
                      for (final citation in answer.citations)
                        if (sourceById[citation.noteId] case final source?)
                          Card(
                            child: ListTile(
                              key: ValueKey(
                                'askNotesCitation-${citation.noteId}',
                              ),
                              title: Text(
                                source.title.trim().isEmpty
                                    ? '未命名笔记'
                                    : source.title,
                              ),
                              subtitle: Text(citation.reason),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(
                                sheetContext,
                              ).pop(citation.noteId),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (noteId != null && mounted) {
      context.push('${AppRouter.editor}?noteId=${Uri.encodeComponent(noteId)}');
    }
  }

  Future<void> _showReviewInsight() async {
    final ai = context.read<AiProvider>();
    final noteProvider = context.read<NoteProvider>();
    if (ai.config == null) {
      return;
    }
    var scope = _selectedDateFilter != null
        ? _AskNotesScope.selectedDay
        : _selectedTag != null
        ? _AskNotesScope.filtered
        : _AskNotesScope.all;
    String? errorMessage;
    final sources = await showDialog<List<AiSourceNote>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final scopedNotes = _notesForAiScope(noteProvider, scope);
          return AlertDialog(
            key: const ValueKey('reviewInsightScopeDialog'),
            title: const Text('生成回顾洞察'),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<_AskNotesScope>(
                      key: const ValueKey('reviewInsightScopeField'),
                      initialValue: scope,
                      decoration: const InputDecoration(labelText: '来源范围'),
                      items: [
                        if (_selectedTag != null)
                          DropdownMenuItem(
                            value: _AskNotesScope.filtered,
                            child: Text(_aiScopeLabel(_AskNotesScope.filtered)),
                          ),
                        DropdownMenuItem(
                          value: _AskNotesScope.selectedDay,
                          child: Text(
                            _aiScopeLabel(_AskNotesScope.selectedDay),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: _AskNotesScope.all,
                          child: Text('全部活动笔记'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            scope = value;
                            errorMessage = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      key: const ValueKey('reviewInsightSourceDetails'),
                      tilePadding: EdgeInsets.zero,
                      title: Text('将发送 ${scopedNotes.length} 条笔记'),
                      subtitle: const Text('每条仅发送标题、日期、标签和前 2000 字'),
                      children: [
                        for (final note in scopedNotes)
                          ListTile(
                            dense: true,
                            title: Text(note.displayTitle),
                            subtitle: Text(_formatSourceDate(note.createdAt)),
                          ),
                      ],
                    ),
                    const Text('不会发送图片、回收站笔记、WebDAV 凭据或隐藏元数据。'),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirmReviewInsightButton'),
                onPressed: () {
                  if (scopedNotes.isEmpty) {
                    setDialogState(() => errorMessage = '当前范围没有可发送的笔记');
                    return;
                  }
                  Navigator.of(dialogContext).pop(_toAiSources(scopedNotes));
                },
                child: const Text('确认发送'),
              ),
            ],
          );
        },
      ),
    );
    if (sources == null || !mounted) {
      return;
    }
    final result = await showDialog<_ReviewInsightResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _ReviewInsightProgressDialog(provider: ai, sources: sources),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!.message)));
      return;
    }
    await _showReviewInsightResult(result.insight!, sources);
  }

  Future<void> _showReviewInsightResult(
    AiReviewInsight insight,
    List<AiSourceNote> sources,
  ) async {
    final sourceById = {for (final source in sources) source.id: source};
    final outcome = await showModalBottomSheet<_ReviewInsightOutcome>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 720),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          key: const ValueKey('reviewInsightSheet'),
          height: MediaQuery.sizeOf(sheetContext).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.insights_outlined),
                    const SizedBox(width: 8),
                    Text(
                      '回顾洞察',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭洞察',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    SelectableText(
                      insight.summary,
                      key: const ValueKey('reviewInsightSummary'),
                      style: Theme.of(sheetContext).textTheme.bodyLarge,
                    ),
                    _ReviewInsightSection(title: '反复主题', items: insight.themes),
                    _ReviewInsightSection(
                      title: '观点变化',
                      items: insight.viewpointChanges,
                    ),
                    _ReviewInsightSection(
                      title: '未解决问题',
                      items: insight.openQuestions,
                    ),
                    _ReviewInsightSection(
                      title: '可能的矛盾',
                      items: insight.contradictions,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '来源',
                      style: Theme.of(sheetContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    for (final sourceId in insight.sourceNoteIds)
                      if (sourceById[sourceId] case final source?)
                        ListTile(
                          key: ValueKey('reviewInsightSource-$sourceId'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(_sourceTitle(source)),
                          subtitle: Text(_formatSourceDate(source.date)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(
                            sheetContext,
                          ).pop(_ReviewInsightOutcome.source(sourceId)),
                        ),
                    const Divider(),
                    Text(
                      '${insight.model} · ${_formatGeneratedAt(insight.generatedAt)}',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const ValueKey('saveReviewInsightButton'),
                  onPressed: () => Navigator.of(
                    sheetContext,
                  ).pop(const _ReviewInsightOutcome.save()),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('保存为笔记'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || outcome == null) {
      return;
    }
    if (outcome.sourceId case final sourceId?) {
      context.push(
        '${AppRouter.editor}?noteId=${Uri.encodeComponent(sourceId)}',
      );
      return;
    }
    if (outcome.save) {
      await _confirmAndSaveReviewInsight(insight, sourceById);
    }
  }

  Future<void> _confirmAndSaveReviewInsight(
    AiReviewInsight insight,
    Map<String, AiSourceNote> sourceById,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('saveReviewInsightConfirmDialog'),
        title: const Text('保存回顾洞察？'),
        content: const Text('将创建一条可继续编辑或移到回收站的普通笔记。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmSaveReviewInsightButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认保存'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      final content = _reviewInsightMarkdown(insight, sourceById);
      await context.read<NoteProvider>().saveNote(
        title: '回顾洞察 ${_formatDay(insight.generatedAt)}',
        content: content,
        tags: Note.extractTags(content),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('回顾洞察已保存')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }

  String _reviewInsightMarkdown(
    AiReviewInsight insight,
    Map<String, AiSourceNote> sourceById,
  ) {
    String section(String title, List<String> items) {
      if (items.isEmpty) return '';
      return '## $title\n${items.map((item) => '- $item').join('\n')}';
    }

    final sourceLines = [
      for (final id in insight.sourceNoteIds)
        if (sourceById[id] case final source?)
          '- ${_sourceTitle(source)} (${_formatSourceDate(source.date)})',
    ];
    return [
      insight.summary,
      section('反复主题', insight.themes),
      section('观点变化', insight.viewpointChanges),
      section('未解决问题', insight.openQuestions),
      section('可能的矛盾', insight.contradictions),
      if (sourceLines.isNotEmpty) '## 来源\n${sourceLines.join('\n')}',
      '模型：${insight.model}\n生成时间：${_formatGeneratedAt(insight.generatedAt)}',
      '#回顾/AI洞察',
    ].where((part) => part.isNotEmpty).join('\n\n');
  }

  static String _sourceTitle(AiSourceNote source) {
    return source.title.trim().isEmpty ? '未命名笔记' : source.title.trim();
  }

  static String _formatSourceDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  static String _formatGeneratedAt(DateTime value) {
    return '${_formatSourceDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final aiConfigured = context.watch<AiProvider>().isConfigured;
    final appSettings = context.watch<AppSettingsProvider>();
    return PopScope(
      canPop: !_isDrawerOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isDrawerOpen) {
          _scaffoldKey.currentState?.closeDrawer();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        onDrawerChanged: (isOpened) {
          if (_isDrawerOpen != isOpened) {
            setState(() => _isDrawerOpen = isOpened);
          }
        },
        drawer: Consumer<NoteProvider>(
          builder: (context, notes, child) {
            final activeNotes = notes.activeNotes;
            final counts = <String, int>{};
            for (final note in activeNotes) {
              for (final tag in Note.expandTagHierarchy(note.tags)) {
                counts.update(tag, (value) => value + 1, ifAbsent: () => 1);
              }
            }
            final tags = counts.keys.toList()..sort();
            return _HomeTagDrawer(
              activityByDay: notes.activityByDay,
              selectedDate: _selectedDateFilter ?? _selectedDate,
              selectedDateFilter: _selectedDateFilter,
              tags: tags,
              counts: counts,
              totalCount: activeNotes.length,
              untaggedCount: activeNotes
                  .where((note) => note.tags.isEmpty)
                  .length,
              selectedTag: _selectedTag,
              heatmapRange: appSettings.heatmapRange,
              onHeatmapRangeSelected: appSettings.setHeatmapRange,
              showReviewInsight: aiConfigured,
              onReviewInsight: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showReviewInsight();
                  }
                });
              },
              onSelected: (tag) {
                setState(() {
                  _selectedTag = tag;
                  _selectedDateFilter = null;
                });
                Navigator.of(context).pop();
              },
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = _dateOnly(date);
                  _selectedDateFilter = _dateOnly(date);
                  _selectedTag = null;
                });
                Navigator.of(context).pop();
              },
              onClearDate: () {
                setState(() => _selectedDateFilter = null);
              },
              onOpenTrash: () {
                Navigator.of(context).pop();
                context.push(AppRouter.history);
              },
            );
          },
        ),
        appBar: AppBar(
          leading: IconButton(
            key: const ValueKey('homeSidebarButton'),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu),
            tooltip: '打开标签侧边栏',
          ),
          title: _isSearching
              ? TextField(
                  key: const ValueKey('homeSearchField'),
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: '搜索标题、正文或 #标签',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                )
              : const Row(
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Daily Notes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
          actions: [
            if (aiConfigured)
              IconButton(
                key: const ValueKey('askNotesButton'),
                icon: const Icon(Icons.question_answer_outlined),
                onPressed: _showAskNotes,
                tooltip: '问我的笔记',
              ),
            IconButton(
              key: const ValueKey('homeSearchButton'),
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: _isSearching ? _closeSearch : _openSearch,
              tooltip: _isSearching ? '关闭搜索' : '搜索笔记',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push(AppRouter.settings),
              tooltip: '设置',
            ),
          ],
        ),
        body: Consumer<NoteProvider>(
          builder: (context, noteProvider, child) {
            if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (noteProvider.errorMessage != null) {
              return _ErrorState(
                message: noteProvider.errorMessage!,
                onRetry: noteProvider.loadNotes,
              );
            }

            final visibleNotes = noteProvider.activeNotes
                .where(_matchesHomeFilter)
                .toList();

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: RefreshIndicator(
                  onRefresh: noteProvider.loadNotes,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                    children: [
                      if (!_isSearching) ...[
                        _QuickCapture(
                          controller: _quickController,
                          isSaving: _isQuickSaving,
                          onChanged: () => setState(() {}),
                          onInsertTag: _insertQuickTag,
                          onExpand: _openQuickInEditor,
                          onSave: _saveQuickNote,
                        ),
                        const SizedBox(height: 24),
                      ],
                      _SectionHeader(
                        title: _searchQuery.trim().isNotEmpty
                            ? '搜索结果'
                            : _selectedDateFilter != null
                            ? '${_formatDay(_selectedDateFilter!)} 的笔记'
                            : _selectedTag == _untagged
                            ? '无标签笔记'
                            : _selectedTag ?? '全部笔记',
                        count: visibleNotes.length,
                      ),
                      const SizedBox(height: 10),
                      if (visibleNotes.isEmpty)
                        const _InlineEmptyState()
                      else
                        ...visibleNotes.map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _NoteCard(
                              note: note,
                              onTagSelected: (tag) {
                                setState(() {
                                  _selectedTag = tag;
                                  _selectedDateFilter = null;
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push(AppRouter.editor),
          tooltip: '新建笔记',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _formatDay(DateTime value) {
    return '${value.month}月${value.day}日';
  }
}

class _AskNotesRequest {
  const _AskNotesRequest({required this.question, required this.sources});

  final String question;
  final List<AiSourceNote> sources;
}

class _AskNotesResult {
  const _AskNotesResult.success(this.answer) : error = null;
  const _AskNotesResult.failure(this.error) : answer = null;

  final AiGroundedAnswer? answer;
  final AiRemoteException? error;
}

class _AskNotesProgressDialog extends StatefulWidget {
  const _AskNotesProgressDialog({
    required this.provider,
    required this.request,
  });

  final AiProvider provider;
  final _AskNotesRequest request;

  @override
  State<_AskNotesProgressDialog> createState() =>
      _AskNotesProgressDialogState();
}

class _AskNotesProgressDialogState extends State<_AskNotesProgressDialog> {
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final answer = await widget.provider.askNotes(
        question: widget.request.question,
        sources: widget.request.sources,
      );
      if (mounted) {
        Navigator.of(context).pop(_AskNotesResult.success(answer));
      }
    } on AiRemoteException catch (error) {
      if (mounted) {
        Navigator.of(context).pop(_AskNotesResult.failure(error));
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(
          const _AskNotesResult.failure(
            AiRemoteException(AiRemoteError.network, '笔记问答失败，请重试'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('askNotesProgressDialog'),
      title: const Text('正在查找笔记证据'),
      content: const Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('回答只允许引用刚才确认的来源')),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancelAskNotesButton'),
          onPressed: _isCancelling
              ? null
              : () {
                  setState(() => _isCancelling = true);
                  widget.provider.cancel();
                },
          child: Text(_isCancelling ? '正在取消' : '取消请求'),
        ),
      ],
    );
  }
}

class _ReviewInsightResult {
  const _ReviewInsightResult.success(this.insight) : error = null;
  const _ReviewInsightResult.failure(this.error) : insight = null;

  final AiReviewInsight? insight;
  final AiRemoteException? error;
}

class _ReviewInsightProgressDialog extends StatefulWidget {
  const _ReviewInsightProgressDialog({
    required this.provider,
    required this.sources,
  });

  final AiProvider provider;
  final List<AiSourceNote> sources;

  @override
  State<_ReviewInsightProgressDialog> createState() =>
      _ReviewInsightProgressDialogState();
}

class _ReviewInsightProgressDialogState
    extends State<_ReviewInsightProgressDialog> {
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final insight = await widget.provider.createReviewInsight(widget.sources);
      if (mounted) {
        Navigator.of(context).pop(_ReviewInsightResult.success(insight));
      }
    } on AiRemoteException catch (error) {
      if (mounted) {
        Navigator.of(context).pop(_ReviewInsightResult.failure(error));
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(
          const _ReviewInsightResult.failure(
            AiRemoteException(AiRemoteError.network, '回顾洞察生成失败，请重试'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('reviewInsightProgressDialog'),
      title: const Text('正在回顾笔记'),
      content: const Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('洞察只基于刚才确认的来源')),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancelReviewInsightButton'),
          onPressed: _isCancelling
              ? null
              : () {
                  setState(() => _isCancelling = true);
                  widget.provider.cancel();
                },
          child: Text(_isCancelling ? '正在取消' : '取消请求'),
        ),
      ],
    );
  }
}

class _ReviewInsightOutcome {
  const _ReviewInsightOutcome.source(this.sourceId) : save = false;
  const _ReviewInsightOutcome.save() : sourceId = null, save = true;

  final String? sourceId;
  final bool save;
}

class _ReviewInsightSection extends StatelessWidget {
  const _ReviewInsightSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              '未发现',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 5),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: SelectableText(item)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _QuickCapture extends StatelessWidget {
  const _QuickCapture({
    required this.controller,
    required this.isSaving,
    required this.onChanged,
    required this.onInsertTag,
    required this.onExpand,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onChanged;
  final VoidCallback onInsertTag;
  final VoidCallback onExpand;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      key: const ValueKey('quickCapture'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('quickCaptureField'),
            controller: controller,
            onChanged: (_) => onChanged(),
            minLines: 3,
            maxLines: 8,
            maxLength: 4000,
            decoration: const InputDecoration(
              hintText: '现在在想什么？',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              counterText: '',
              contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('quickCaptureTagButton'),
                    onPressed: onInsertTag,
                    icon: const Icon(Icons.tag_outlined),
                    tooltip: '插入 #标签',
                  ),
                  IconButton(
                    key: const ValueKey('quickCaptureExpandButton'),
                    onPressed: onExpand,
                    icon: const Icon(Icons.open_in_full),
                    tooltip: '打开完整编辑器',
                  ),
                  const Spacer(),
                  Text(
                    '${controller.text.trim().length} 字',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    key: const ValueKey('quickCaptureSaveButton'),
                    onPressed: hasText && !isSaving ? onSave : null,
                    icon: isSaving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined, size: 18),
                    label: const Text('记录'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Text('($count)', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTagSelected});

  final Note note;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          context.push(
            '${AppRouter.editor}?noteId=${Uri.encodeComponent(note.id)}',
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeDateBadge(date: note.createdAt),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.title.trim().isNotEmpty) ...[
                      Text(
                        note.title.trim(),
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (note.content.trim().isNotEmpty)
                      NoteInlinePreview(
                        note: note,
                        onTagSelected: onTagSelected,
                      ),
                    const SizedBox(height: 9),
                    Text(
                      DateUtil.formatDateTime(note.updatedAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (note.coverImage case final cover?) ...[
                const SizedBox(width: 12),
                NoteThumbnail(image: cover, size: 72),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeDateBadge extends StatelessWidget {
  const _HomeDateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Column(
        children: [
          Text(
            date.day.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text('${date.month}月', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _HomeTagDrawer extends StatefulWidget {
  const _HomeTagDrawer({
    required this.activityByDay,
    required this.selectedDate,
    required this.selectedDateFilter,
    required this.tags,
    required this.counts,
    required this.totalCount,
    required this.untaggedCount,
    required this.selectedTag,
    required this.heatmapRange,
    required this.onHeatmapRangeSelected,
    required this.showReviewInsight,
    required this.onReviewInsight,
    required this.onSelected,
    required this.onDateSelected,
    required this.onClearDate,
    required this.onOpenTrash,
  });

  final Map<DateTime, int> activityByDay;
  final DateTime selectedDate;
  final DateTime? selectedDateFilter;
  final List<String> tags;
  final Map<String, int> counts;
  final int totalCount;
  final int untaggedCount;
  final String? selectedTag;
  final HeatmapRange heatmapRange;
  final ValueChanged<HeatmapRange> onHeatmapRangeSelected;
  final bool showReviewInsight;
  final VoidCallback onReviewInsight;
  final ValueChanged<String?> onSelected;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onClearDate;
  final VoidCallback onOpenTrash;

  @override
  State<_HomeTagDrawer> createState() => _HomeTagDrawerState();
}

class _HomeTagDrawerState extends State<_HomeTagDrawer> {
  final Set<String> _collapsedTags = {};

  List<_TagTreeNode> _buildTagTree() {
    final roots = <_TagTreeNode>[];
    final nodesByTag = <String, _TagTreeNode>{};
    for (final tag in widget.tags) {
      final parts = tag.substring(1).split('/');
      for (var index = 0; index < parts.length; index++) {
        final fullTag = '#${parts.take(index + 1).join('/')}';
        final node = nodesByTag.putIfAbsent(
          fullTag,
          () => _TagTreeNode(fullTag: fullTag, label: parts[index]),
        );
        if (index == 0) {
          if (!roots.contains(node)) {
            roots.add(node);
          }
        } else {
          final parentTag = '#${parts.take(index).join('/')}';
          final parent = nodesByTag[parentTag]!;
          if (!parent.children.contains(node)) {
            parent.children.add(node);
          }
        }
      }
    }
    return roots;
  }

  List<Widget> _buildTagTiles(List<_TagTreeNode> nodes, [int depth = 0]) {
    final tiles = <Widget>[];
    for (final node in nodes) {
      final expanded = !_collapsedTags.contains(node.fullTag);
      tiles.add(
        _DrawerTagTile(
          key: ValueKey('homeTag-${node.fullTag}'),
          label: node.label,
          count: widget.counts[node.fullTag] ?? 0,
          selected: widget.selectedTag == node.fullTag,
          depth: depth,
          hasChildren: node.children.isNotEmpty,
          expanded: expanded,
          onToggle: node.children.isEmpty
              ? null
              : () {
                  setState(() {
                    if (expanded) {
                      _collapsedTags.add(node.fullTag);
                    } else {
                      _collapsedTags.remove(node.fullTag);
                    }
                  });
                },
          onTap: () => widget.onSelected(node.fullTag),
        ),
      );
      if (expanded && node.children.isNotEmpty) {
        tiles.addAll(_buildTagTiles(node.children, depth + 1));
      }
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '我的笔记',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭侧边栏',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
              child: Row(
                children: [
                  Text(
                    '最近 ${widget.heatmapRange.label}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<HeatmapRange>(
                    key: const ValueKey('heatmapRangeMenu'),
                    tooltip: '设置热力图范围',
                    icon: const Icon(Icons.calendar_view_month_outlined),
                    onSelected: widget.onHeatmapRangeSelected,
                    itemBuilder: (context) => [
                      for (final range in HeatmapRange.values)
                        PopupMenuItem(
                          value: range,
                          child: Row(
                            children: [
                              if (range == widget.heatmapRange)
                                const Icon(Icons.check, size: 18)
                              else
                                const SizedBox(width: 18),
                              const SizedBox(width: 10),
                              Text('最近 ${range.label}'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: NoteActivityHeatmap(
                activityByDay: widget.activityByDay,
                selectedDate: widget.selectedDate,
                onDateSelected: widget.onDateSelected,
                weeks: widget.heatmapRange.weeks,
              ),
            ),
            if (widget.selectedDateFilter case final date?)
              ListTile(
                key: const ValueKey('homeDateFilter'),
                dense: true,
                leading: const Icon(Icons.calendar_today_outlined, size: 18),
                title: Text('${date.month}月${date.day}日的笔记'),
                trailing: IconButton(
                  onPressed: widget.onClearDate,
                  icon: const Icon(Icons.close),
                  tooltip: '清除日期筛选',
                ),
              ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                children: [
                  if (widget.showReviewInsight)
                    ListTile(
                      key: const ValueKey('reviewInsightDrawerItem'),
                      dense: true,
                      minTileHeight: 40,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      leading: const Icon(Icons.insights_outlined, size: 18),
                      title: const Text('回顾洞察'),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: widget.onReviewInsight,
                    ),
                  if (widget.showReviewInsight) const Divider(),
                  ListTile(
                    key: const ValueKey('trashDrawerItem'),
                    dense: true,
                    minTileHeight: 40,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.delete_sweep_outlined, size: 18),
                    title: const Text('回收站'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: widget.onOpenTrash,
                  ),
                  const Divider(),
                  _DrawerTagTile(
                    key: const ValueKey('homeTag-all'),
                    label: '全部笔记',
                    count: widget.totalCount,
                    selected:
                        widget.selectedTag == null &&
                        widget.selectedDateFilter == null,
                    icon: Icons.view_stream_outlined,
                    onTap: () => widget.onSelected(null),
                  ),
                  if (widget.untaggedCount > 0)
                    _DrawerTagTile(
                      key: const ValueKey('homeTag-untagged'),
                      label: '无标签',
                      count: widget.untaggedCount,
                      selected: widget.selectedTag == _HomePageState._untagged,
                      icon: Icons.label_off_outlined,
                      onTap: () => widget.onSelected(_HomePageState._untagged),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
                    child: Text(
                      '标签',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ..._buildTagTiles(_buildTagTree()),
                  if (widget.tags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '正文标签会显示在这里',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTagTile extends StatelessWidget {
  const _DrawerTagTile({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.icon,
    this.depth = 0,
    this.hasChildren = false,
    this.expanded = false,
    this.onToggle,
  });

  final String label;
  final int count;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      minTileHeight: 40,
      contentPadding: EdgeInsets.only(left: 8 + depth * 16, right: 12),
      horizontalTitleGap: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      selected: selected,
      selectedTileColor: colors.primary.withValues(alpha: 0.1),
      selectedColor: colors.primary,
      leading: icon != null
          ? Icon(icon, size: 18)
          : hasChildren
          ? IconButton(
              key: ValueKey('tagToggle-$label-$depth'),
              onPressed: onToggle,
              icon: Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                size: 20,
              ),
              tooltip: expanded ? '折叠 $label' : '展开 $label',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            )
          : const SizedBox(width: 32),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(count.toString()),
      onTap: onTap,
    );
  }
}

class _TagTreeNode {
  _TagTreeNode({required this.fullTag, required this.label});

  final String fullTag;
  final String label;
  final List<_TagTreeNode> children = [];
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.edit_note_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '还没有笔记，在上方写下第一个想法。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
