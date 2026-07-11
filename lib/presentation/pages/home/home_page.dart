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
  final TextEditingController _quickController = TextEditingController();
  DateTime _selectedDate = _dateOnly(DateTime.now());
  DateTime? _selectedDateFilter;
  String? _selectedTag;
  bool _isQuickSaving = false;

  static const _untagged = '__untagged__';

  @override
  void dispose() {
    _quickController.dispose();
    super.dispose();
  }

  bool _matchesSelectedTag(Note note) {
    return _selectedTag == null ||
        (_selectedTag == _untagged
            ? note.tags.isEmpty
            : Note.matchesTag(note.tags, _selectedTag!));
  }

  bool _matchesHomeFilter(Note note) {
    final date = _selectedDateFilter;
    return _matchesSelectedTag(note) &&
        (date == null || DateUtil.isSameDay(note.createdAt, date));
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

    List<Note> notesForScope(_AskNotesScope value) {
      final notes = switch (value) {
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

    String scopeLabel(_AskNotesScope value) {
      return switch (value) {
        _AskNotesScope.filtered =>
          _selectedTag == _untagged
              ? '当前筛选：无标签'
              : '当前筛选：${_selectedTag ?? '全部'}',
        _AskNotesScope.selectedDay => '日期：${_formatDay(_selectedDate)}',
        _AskNotesScope.all => '全部活动笔记',
      };
    }

    _AskNotesRequest? request;
    try {
      request = await showDialog<_AskNotesRequest>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final scopedNotes = notesForScope(scope);
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
                              child: Text(scopeLabel(_AskNotesScope.filtered)),
                            ),
                          DropdownMenuItem(
                            value: _AskNotesScope.selectedDay,
                            child: Text(scopeLabel(_AskNotesScope.selectedDay)),
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
                      const Text('不会发送图片、归档笔记、WebDAV 凭据或隐藏元数据。'),
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
                        sources: [
                          for (final note in scopedNotes)
                            AiSourceNote(
                              id: note.id,
                              date: note.createdAt,
                              title: note.title,
                              content: note.content,
                              tags: note.tags,
                            ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final aiConfigured = context.watch<AiProvider>().isConfigured;
    return Scaffold(
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
          );
        },
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            key: const ValueKey('homeSidebarButton'),
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
            tooltip: '打开标签侧边栏',
          ),
        ),
        title: const Row(
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
            icon: const Icon(Icons.view_stream_outlined),
            onPressed: () => context.push(AppRouter.history),
            tooltip: '全部笔记',
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
                    _QuickCapture(
                      controller: _quickController,
                      isSaving: _isQuickSaving,
                      onChanged: () => setState(() {}),
                      onInsertTag: _insertQuickTag,
                      onExpand: _openQuickInEditor,
                      onSave: _saveQuickNote,
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: _selectedDateFilter != null
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
                    if (note.bodyPreview.isNotEmpty)
                      Text(
                        note.bodyPreview,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: note.tags
                            .map(
                              (tag) => _InlineTag(
                                tag: tag,
                                onTap: () => onTagSelected(tag),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Text(
                      DateUtil.formatDateTime(note.updatedAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (note.images.isNotEmpty) ...[
                const SizedBox(width: 12),
                NoteThumbnail(image: note.images.first, size: 72),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineTag extends StatelessWidget {
  const _InlineTag({required this.tag, required this.onTap});

  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        tag,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HomeTagDrawer extends StatelessWidget {
  const _HomeTagDrawer({
    required this.activityByDay,
    required this.selectedDate,
    required this.selectedDateFilter,
    required this.tags,
    required this.counts,
    required this.totalCount,
    required this.untaggedCount,
    required this.selectedTag,
    required this.onSelected,
    required this.onDateSelected,
    required this.onClearDate,
  });

  final Map<DateTime, int> activityByDay;
  final DateTime selectedDate;
  final DateTime? selectedDateFilter;
  final List<String> tags;
  final Map<String, int> counts;
  final int totalCount;
  final int untaggedCount;
  final String? selectedTag;
  final ValueChanged<String?> onSelected;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onClearDate;

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
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: NoteActivityHeatmap(
                activityByDay: activityByDay,
                selectedDate: selectedDate,
                onDateSelected: onDateSelected,
              ),
            ),
            if (selectedDateFilter case final date?)
              ListTile(
                key: const ValueKey('homeDateFilter'),
                dense: true,
                leading: const Icon(Icons.calendar_today_outlined, size: 18),
                title: Text('${date.month}月${date.day}日的笔记'),
                trailing: IconButton(
                  onPressed: onClearDate,
                  icon: const Icon(Icons.close),
                  tooltip: '清除日期筛选',
                ),
              ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                children: [
                  _DrawerTagTile(
                    key: const ValueKey('homeTag-all'),
                    label: '全部笔记',
                    count: totalCount,
                    selected: selectedTag == null && selectedDateFilter == null,
                    icon: Icons.view_stream_outlined,
                    onTap: () => onSelected(null),
                  ),
                  if (untaggedCount > 0)
                    _DrawerTagTile(
                      key: const ValueKey('homeTag-untagged'),
                      label: '无标签',
                      count: untaggedCount,
                      selected: selectedTag == _HomePageState._untagged,
                      icon: Icons.label_off_outlined,
                      onTap: () => onSelected(_HomePageState._untagged),
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
                  for (final tag in tags)
                    _DrawerTagTile(
                      key: ValueKey('homeTag-$tag'),
                      label: tag.substring(1).split('/').last,
                      count: counts[tag] ?? 0,
                      selected: selectedTag == tag,
                      depth: tag.substring(1).split('/').length - 1,
                      icon: Icons.tag,
                      onTap: () => onSelected(tag),
                    ),
                  if (tags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '正文中的 #标签 会显示在这里',
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
    required this.icon,
    required this.onTap,
    this.depth = 0,
  });

  final String label;
  final int count;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      minTileHeight: 40,
      contentPadding: EdgeInsets.only(left: 12 + depth * 18, right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      selected: selected,
      selectedTileColor: colors.primaryContainer,
      leading: Icon(icon, size: 18),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(count.toString()),
      onTap: onTap,
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.edit_note_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('还没有笔记，在上方写下第一个想法。')),
          ],
        ),
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
