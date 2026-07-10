import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
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
  final NoteImageService _imageService = const NoteImageService();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoadedInitialNote = false;
  bool _isDirty = false;
  bool _allowPop = false;
  bool _isPickingImages = false;
  Note? _currentNote;
  List<NoteImage> _images = [];
  String _initialTitle = '';
  String _initialContent = '';
  String _initialImageIds = '';

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
    _initialImageIds = _imageIds(note.images);
    _images = List.of(note.images);
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

    if (title.isEmpty && content.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入标题、正文或添加图片')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final note = await context.read<NoteProvider>().saveNote(
        id: _currentNote?.id ?? widget.noteId,
        title: title,
        content: content,
        images: _images,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentNote = note;
        _initialTitle = note.title;
        _initialContent = note.content;
        _initialImageIds = _imageIds(note.images);
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
    _updateDirtyState();
  }

  void _updateDirtyState() {
    final isDirty =
        _titleController.text.trim() != _initialTitle ||
        _contentController.text.trim() != _initialContent ||
        _imageIds(_images) != _initialImageIds;
    if (_isDirty != isDirty) {
      setState(() => _isDirty = isDirty);
    }
  }

  String _imageIds(Iterable<NoteImage> images) {
    return images.map((image) => image.id).join('|');
  }

  Future<void> _pickImages() async {
    final availableSlots = NoteImageService.maxImagesPerNote - _images.length;
    if (availableSlots <= 0) {
      _showError('每条笔记最多添加 4 张图片');
      return;
    }

    setState(() => _isPickingImages = true);
    try {
      final selected = await _imageService.pickImages(
        availableSlots: availableSlots,
      );
      if (!mounted || selected.isEmpty) {
        return;
      }
      setState(() => _images = [..._images, ...selected]);
      _updateDirtyState();
    } on NoteImageException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to pick note image: $error\n$stackTrace');
      if (mounted) {
        _showError('添加图片失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      }
    }
  }

  void _removeImage(NoteImage image) {
    setState(() {
      _images = _images.where((item) => item.id != image.id).toList();
    });
    _updateDirtyState();
  }

  Future<void> _showImagePreview(NoteImage image) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.memory(
                image.bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 240,
                  child: Center(child: Text('图片无法显示')),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
                tooltip: '关闭预览',
              ),
            ),
          ],
        ),
      ),
    );
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
                      if (_images.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _AttachmentStrip(
                          images: _images,
                          onPreview: _showImagePreview,
                          onRemove: _removeImage,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: _isLoading
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('addNoteImageButton'),
                        onPressed: _isPickingImages ? null : _pickImages,
                        icon: _isPickingImages
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                        tooltip: '添加图片',
                      ),
                      Text(
                        '${_images.length}/${NoteImageService.maxImagesPerNote}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        '${_contentController.text.trim().length} 字',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({
    required this.images,
    required this.onPreview,
    required this.onRemove,
  });

  final List<NoteImage> images;
  final ValueChanged<NoteImage> onPreview;
  final ValueChanged<NoteImage> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final image = images[index];
          return Stack(
            children: [
              InkWell(
                key: ValueKey('noteImage-${image.id}'),
                onTap: () => onPreview(image),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    image.bytes,
                    width: 108,
                    height: 108,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 108,
                      height: 108,
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filled(
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => onRemove(image),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '移除图片',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
