import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../routers/app_router.dart';

/// 编辑页面
///
/// 笔记编辑器页面，支持富文本编辑
class EditorPage extends StatefulWidget {
  const EditorPage({super.key, this.noteId});

  /// 要编辑的笔记 ID，如果为 null 则创建新笔记
  final String? noteId;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoadedInitialNote = false;
  bool _isDirty = false;
  bool _allowPop = false;
  Note? _currentNote;
  String _initialTitle = '';
  String _initialContent = '';

  bool get _isNewNote => widget.noteId == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedInitialNote) {
      _hasLoadedInitialNote = true;
      _loadInitialNote();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialNote() async {
    final noteId = widget.noteId;
    if (noteId == null) {
      return;
    }

    setState(() => _isLoading = true);
    Note? note;
    try {
      note = await context.read<NoteProvider>().ensureNoteById(noteId);
    } catch (error, stackTrace) {
      debugPrint('Failed to load note: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showError('加载笔记失败，请重试');
      return;
    }

    if (!mounted) {
      return;
    }

    if (note == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未找到这条笔记')));
      return;
    }

    _currentNote = note;
    _initialTitle = note.title;
    _initialContent = note.content;
    _titleController.text = note.title;
    _contentController.text = note.content;
    setState(() {
      _isLoading = false;
      _isDirty = false;
    });
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入标题或正文')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final note = await context.read<NoteProvider>().saveNote(
        id: _currentNote?.id ?? widget.noteId,
        title: title,
        content: content,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentNote = note;
        _initialTitle = note.title;
        _initialContent = note.content;
        _isDirty = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('笔记已保存')));
      _popEditor();
    } catch (error, stackTrace) {
      debugPrint('Failed to save note: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      _showError('保存失败，请重试，当前内容仍保留在编辑器中');
    }
  }

  Future<void> _deleteNote() async {
    final noteId = _currentNote?.id ?? widget.noteId;
    if (noteId == null) {
      _popEditor();
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('删除后无法恢复，确认继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await context.read<NoteProvider>().deleteNote(noteId);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('笔记已删除')));
      _popEditor();
    } catch (error, stackTrace) {
      debugPrint('Failed to delete note: $error\n$stackTrace');
      if (mounted) {
        _showError('删除失败，请重试');
      }
    }
  }

  Future<void> _archiveNote() async {
    final noteId = _currentNote?.id ?? widget.noteId;
    if (noteId == null) {
      return;
    }

    final wasArchived = _currentNote?.isArchived ?? false;
    try {
      await context.read<NoteProvider>().archiveNote(
        noteId,
        isArchived: !wasArchived,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasArchived ? '笔记已取消归档' : '笔记已归档')),
      );
      _popEditor();
    } catch (error, stackTrace) {
      debugPrint('Failed to archive note: $error\n$stackTrace');
      if (mounted) {
        _showError('归档操作失败，请重试');
      }
    }
  }

  void _handleDraftChanged(String _) {
    final isDirty =
        _titleController.text.trim() != _initialTitle ||
        _contentController.text.trim() != _initialContent;
    if (_isDirty != isDirty) {
      setState(() => _isDirty = isDirty);
    }
  }

  Future<void> _requestLeaveEditor() async {
    if (!_isDirty) {
      _popEditor();
      return;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的更改？'),
        content: const Text('当前内容尚未保存，离开后将丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃更改'),
          ),
        ],
      ),
    );

    if (shouldDiscard == true && mounted) {
      _popEditor();
    }
  }

  void _popEditor() {
    if (!mounted) {
      return;
    }

    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.home);
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop || !_isDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _requestLeaveEditor();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNewNote ? '新建笔记' : '编辑笔记'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _requestLeaveEditor,
          ),
          actions: [
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: _isSaving ? null : _saveNote,
              tooltip: '保存',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'archive') {
                  _archiveNote();
                } else if (value == 'delete') {
                  _deleteNote();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: !_isNewNote,
                  value: 'archive',
                  child: Text(
                    (_currentNote?.isArchived ?? false) ? '取消归档' : '归档',
                  ),
                ),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        key: const ValueKey('noteTitleField'),
                        controller: _titleController,
                        onChanged: _handleDraftChanged,
                        textInputAction: TextInputAction.next,
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: const InputDecoration(
                          hintText: '标题',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('noteContentField'),
                          controller: _contentController,
                          onChanged: _handleDraftChanged,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: '写下今天的想法...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
