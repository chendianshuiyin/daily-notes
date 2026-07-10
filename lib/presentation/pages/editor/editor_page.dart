import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
  final SpeechToText _speech = SpeechToText();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoadedInitialNote = false;
  bool _isDirty = false;
  bool _allowPop = false;
  bool _isPickingImages = false;
  bool _isStartingVoice = false;
  bool _isListening = false;
  Note? _currentNote;
  List<NoteImage> _images = [];
  String _initialTitle = '';
  String _initialContent = '';
  String _initialImageIds = '';
  String _voiceBaseContent = '';

  bool get _isNewNote => widget.noteId == null;

  bool get _voiceInputSupported {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

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
    _speech.cancel();
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
    final editorContent = _contentWithInlineTags(note);
    _initialTitle = note.title;
    _initialContent = editorContent;
    _initialImageIds = _imageIds(note.images);
    _images = List.of(note.images);
    _titleController.text = note.title;
    _contentController.text = editorContent;
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
        tags: Note.extractTags('$title $content'),
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

  String _contentWithInlineTags(Note note) {
    final inlineTags = Note.normalizeTags(
      Note.extractTags('${note.title} ${note.content}'),
    ).map((tag) => tag.toLowerCase()).toSet();
    final missingTags = note.tags
        .where((tag) => !inlineTags.contains(tag.toLowerCase()))
        .toList();
    if (missingTags.isEmpty) {
      return note.content;
    }
    final content = note.content.trimRight();
    return content.isEmpty
        ? missingTags.join(' ')
        : '$content\n\n${missingTags.join(' ')}';
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

  void _insertCurrentTime() {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final value = _contentController.value;
    final selection = value.selection;
    final offset = selection.isValid ? selection.start : value.text.length;
    final prefix = offset > 0 && !value.text.substring(0, offset).endsWith('\n')
        ? '\n'
        : '';
    final insertion = '$prefix$timestamp ';
    final updatedText = value.text.replaceRange(offset, offset, insertion);
    _contentController.value = value.copyWith(
      text: updatedText,
      selection: TextSelection.collapsed(offset: offset + insertion.length),
      composing: TextRange.empty,
    );
    _updateDirtyState();
  }

  void _insertTagMarker() {
    final value = _contentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : start;
    final selected = value.text
        .substring(start, end)
        .trim()
        .replaceAll(' ', '_');
    final needsSpace =
        start > 0 && !RegExp(r'\s').hasMatch(value.text[start - 1]);
    final insertion =
        '${needsSpace ? ' ' : ''}#${selected.isEmpty ? '' : selected}';
    final updatedText = value.text.replaceRange(start, end, insertion);
    _contentController.value = value.copyWith(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + insertion.length),
      composing: TextRange.empty,
    );
    _updateDirtyState();
  }

  Future<void> _toggleVoiceInput() async {
    if (!_voiceInputSupported) {
      return;
    }
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    setState(() => _isStartingVoice = true);
    try {
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      if (!mounted) {
        return;
      }
      if (!available) {
        _showError('语音输入不可用，请检查麦克风权限和系统语音服务');
        return;
      }

      _voiceBaseContent = _contentController.text;
      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      if (mounted) {
        setState(() => _isListening = _speech.isListening);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to start speech recognition: $error\n$stackTrace');
      if (mounted) {
        _showError('无法启动语音输入，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingVoice = false);
      }
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }
    final listening = status == SpeechToText.listeningStatus;
    if (_isListening != listening) {
      setState(() => _isListening = listening);
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) {
      return;
    }
    setState(() => _isListening = false);
    final message = error.errorMsg.contains('permission')
        ? '麦克风或语音识别权限未授权'
        : error.errorMsg.contains('network')
        ? '语音识别网络不可用'
        : '没有识别到语音，请重试';
    _showError(message);
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (!mounted || words.isEmpty) {
      return;
    }
    final separator = _voiceBaseContent.isEmpty
        ? ''
        : RegExp(r'\s$').hasMatch(_voiceBaseContent)
        ? ''
        : '\n';
    final text = '$_voiceBaseContent$separator$words';
    _contentController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _updateDirtyState();
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
            tooltip: '返回',
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: '更多操作',
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
            : LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: constraints.maxWidth > 900
                        ? 900
                        : constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _editorDateLabel(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (_isDirty
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.tertiary
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.secondary)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(_isDirty ? '未保存' : '已保存'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(),
                              TextField(
                                key: const ValueKey('noteTitleField'),
                                controller: _titleController,
                                onChanged: _handleDraftChanged,
                                textInputAction: TextInputAction.next,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                                decoration: const InputDecoration(
                                  hintText: '标题',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
                                    hintText: '记录想法，可直接输入 #标签/子标签...',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
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
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: _isLoading
            ? null
            : SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.center,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Container(
                      height: 64,
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
                                : const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                            tooltip: '添加图片',
                          ),
                          Text(
                            '${_images.length}/${NoteImageService.maxImagesPerNote}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          IconButton(
                            onPressed: _insertCurrentTime,
                            icon: const Icon(Icons.schedule_outlined),
                            tooltip: '插入当前时间',
                          ),
                          IconButton(
                            key: const ValueKey('inlineTagButton'),
                            onPressed: _insertTagMarker,
                            icon: const Icon(Icons.tag_outlined),
                            tooltip: '插入 #标签',
                          ),
                          IconButton(
                            key: const ValueKey('voiceInputButton'),
                            onPressed: !_voiceInputSupported || _isStartingVoice
                                ? null
                                : _toggleVoiceInput,
                            icon: _isStartingVoice
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _isListening
                                        ? Icons.stop_circle_outlined
                                        : Icons.mic_none_outlined,
                                    color: _isListening
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                                  ),
                            tooltip: !_voiceInputSupported
                                ? '当前平台不支持语音输入'
                                : _isListening
                                ? '停止语音输入'
                                : '开始语音输入',
                          ),
                          const Spacer(),
                          Text(
                            _isListening
                                ? '听写中'
                                : '${_contentController.text.trim().length} 字',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            key: const ValueKey('saveNoteButton'),
                            onPressed: _isSaving ? null : _saveNote,
                            icon: _isSaving
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: const Text('保存'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  String _editorDateLabel() {
    final date = _currentNote?.createdAt ?? DateTime.now();
    return '${date.year}年${date.month}月${date.day}日';
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
                  key: ValueKey('removeNoteImage-${image.id}'),
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
