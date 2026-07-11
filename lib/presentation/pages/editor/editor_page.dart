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
import 'note_block_editor.dart';
import 'note_block_editor_controller.dart';
import 'note_markdown_preview.dart';

enum _VoicePhase { idle, starting, listening, reviewing }

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
  final NoteMarkdownCodec _markdownCodec = const NoteMarkdownCodec();
  final SpeechToText _speech = SpeechToText();
  late NoteBlockEditorController _blockController;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoadedInitialNote = false;
  bool _isDirty = false;
  bool _allowPop = false;
  bool _isPickingImages = false;
  _VoicePhase _voicePhase = _VoicePhase.idle;
  Note? _currentNote;
  List<NoteImage> _images = [];
  String _initialTitle = '';
  String _initialContent = '';
  String _initialImageIds = '';
  String _voiceTranscript = '';
  List<LocaleName> _voiceLocales = const [];
  String? _voiceLocaleId;
  String _voiceLocaleLabel = '系统语言';

  bool get _isNewNote => widget.noteId == null;

  bool get _voiceSessionActive => _voicePhase != _VoicePhase.idle;

  bool get _isListening => _voicePhase == _VoicePhase.listening;

  List<LocaleName> get _preferredVoiceLocales {
    final preferred = _voiceLocales.where((locale) {
      final id = locale.localeId.toLowerCase();
      return id.startsWith('zh') || id.startsWith('en');
    }).toList();
    return preferred.isNotEmpty ? preferred : _voiceLocales.take(8).toList();
  }

  bool get _voiceInputSupported {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  @override
  void initState() {
    super.initState();
    _replaceBlockController(
      NoteBlockEditorController(
        blocks: _markdownCodec.decode('').blocks,
        images: const [],
      ),
      disposePrevious: false,
    );
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
    _blockController.removeListener(_handleBlockChanged);
    _blockController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _replaceBlockController(
    NoteBlockEditorController controller, {
    bool disposePrevious = true,
  }) {
    if (disposePrevious) {
      _blockController.removeListener(_handleBlockChanged);
      _blockController.dispose();
    }
    _blockController = controller;
    _blockController.addListener(_handleBlockChanged);
    _contentController.text = _blockController.markdown;
    _images = List.of(_blockController.images);
  }

  void _handleBlockChanged() {
    _contentController.text = _blockController.markdown;
    _images = List.of(_blockController.images);
    _updateDirtyState();
    if (mounted) {
      setState(() {});
    }
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
    _initialImageIds = _imageIds(note.images);
    _titleController.text = note.title;
    final sourceBlocks = editorContent == note.content
        ? note.blocks
        : [
            ..._markdownCodec
                .decode(editorContent, existingBlocks: note.blocks)
                .blocks,
            ...note.blocks.where((block) => block.type == NoteBlockType.image),
          ];
    _replaceBlockController(
      NoteBlockEditorController(blocks: sourceBlocks, images: note.images),
    );
    _initialContent = _blockController.markdown.trim();
    setState(() {
      _isLoading = false;
      _isDirty = false;
    });
  }

  Future<void> _saveNote() async {
    if (_voiceSessionActive) {
      _showError('请先插入或丢弃当前语音识别结果');
      return;
    }
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
        blocks: _blockController.blocks,
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
      _showError('每条笔记最多添加 12 张图片');
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
      await _blockController.insertImages(selected);
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

  Future<void> _insertCurrentTime() async {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await _blockController.insertText('$timestamp ');
  }

  Future<void> _insertTagMarker() async {
    await _blockController.insertText('#');
  }

  Future<void> _toggleVoiceInput() async {
    if (!_voiceInputSupported) {
      return;
    }
    if (_isListening) {
      await _stopVoiceInput();
      return;
    }
    if (_voicePhase == _VoicePhase.reviewing) {
      return;
    }

    await _startVoiceInput();
  }

  Future<void> _startVoiceInput() async {
    FocusScope.of(context).unfocus();
    _blockController.captureInsertionSelection();
    setState(() {
      _voicePhase = _VoicePhase.starting;
      _voiceTranscript = '';
    });
    try {
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      if (!mounted) {
        return;
      }
      if (!available) {
        setState(() => _voicePhase = _VoicePhase.idle);
        _showError('语音输入不可用，请检查麦克风权限和系统语音服务');
        return;
      }

      final locales = await _speech.locales();
      final systemLocale = await _speech.systemLocale();
      final selectedLocale = _voiceLocaleId == null
          ? systemLocale
          : locales
                .where((locale) => locale.localeId == _voiceLocaleId)
                .firstOrNull;
      _voiceLocales = locales;
      _voiceLocaleId = selectedLocale?.localeId;
      _voiceLocaleLabel = selectedLocale?.name ?? '系统语言';

      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          localeId: _voiceLocaleId,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      if (mounted) {
        setState(() {
          _voicePhase = _speech.isListening
              ? _VoicePhase.listening
              : _VoicePhase.idle;
        });
        if (!_speech.isListening) {
          _showError('语音服务没有开始监听，请检查权限后重试');
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to start speech recognition: $error\n$stackTrace');
      if (mounted) {
        setState(() => _voicePhase = _VoicePhase.idle);
        _showError('无法启动语音输入，请稍后重试');
      }
    }
  }

  Future<void> _stopVoiceInput() async {
    await _speech.stop();
    if (!mounted) {
      return;
    }
    _finishVoiceRecognition(showEmptyMessage: true);
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }
    if (status == SpeechToText.listeningStatus) {
      if (_voicePhase != _VoicePhase.listening) {
        setState(() => _voicePhase = _VoicePhase.listening);
      }
      return;
    }
    if ((status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) &&
        _voicePhase == _VoicePhase.listening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _voicePhase == _VoicePhase.listening) {
          _finishVoiceRecognition(showEmptyMessage: true);
        }
      });
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) {
      return;
    }
    final hasTranscript = _voiceTranscript.trim().isNotEmpty;
    setState(() {
      _voicePhase = hasTranscript ? _VoicePhase.reviewing : _VoicePhase.idle;
    });
    final message = error.errorMsg.contains('permission')
        ? '麦克风或语音识别权限未授权'
        : error.errorMsg.contains('network')
        ? '语音识别网络不可用'
        : hasTranscript
        ? '识别已中断，可插入当前结果或重试'
        : '没有识别到语音，请重试';
    _showError(message);
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (!mounted || words.isEmpty) {
      return;
    }
    setState(() {
      _voiceTranscript = words;
      if (result.finalResult) {
        _voicePhase = _VoicePhase.reviewing;
      }
    });
  }

  void _finishVoiceRecognition({required bool showEmptyMessage}) {
    final hasTranscript = _voiceTranscript.trim().isNotEmpty;
    setState(() {
      _voicePhase = hasTranscript ? _VoicePhase.reviewing : _VoicePhase.idle;
    });
    if (!hasTranscript && showEmptyMessage) {
      _showError('没有识别到语音，请重试');
    }
  }

  Future<void> _insertVoiceTranscript() async {
    final transcript = _voiceTranscript.trim();
    if (transcript.isEmpty) {
      _discardVoiceTranscript();
      return;
    }
    await _blockController.insertText(transcript, atCapturedSelection: true);
    setState(() {
      _voicePhase = _VoicePhase.idle;
      _voiceTranscript = '';
    });
  }

  Future<void> _retryVoiceInput() async {
    await _speech.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _voicePhase = _VoicePhase.idle;
      _voiceTranscript = '';
    });
    await _startVoiceInput();
  }

  Future<void> _selectVoiceLocale(String localeId) async {
    final locale = _voiceLocales
        .where((candidate) => candidate.localeId == localeId)
        .firstOrNull;
    if (locale == null) {
      return;
    }
    setState(() {
      _voiceLocaleId = locale.localeId;
      _voiceLocaleLabel = locale.name;
    });
  }

  void _discardVoiceTranscript() {
    _speech.cancel();
    setState(() {
      _voicePhase = _VoicePhase.idle;
      _voiceTranscript = '';
    });
  }

  void _previewImageById(String imageId) {
    final image = _blockController.imageById(imageId);
    if (image != null) {
      _showImagePreview(image);
    }
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

  Future<void> _showMarkdownPreview() async {
    final markdown = _contentController.text.trim();
    if (markdown.isEmpty) {
      _showError('输入正文后即可预览');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 900),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'Markdown 预览',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      key: const ValueKey('closeMarkdownPreviewButton'),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭预览',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: NoteMarkdownPreview(markdown: markdown),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestLeaveEditor() async {
    if (_voiceSessionActive) {
      final shouldDiscardVoice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('放弃语音输入？'),
          content: Text(
            _voiceTranscript.trim().isEmpty
                ? '语音识别仍在进行，离开将停止本次听写。'
                : '识别结果尚未插入正文，离开后将丢失。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('继续处理'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('放弃语音'),
            ),
          ],
        ),
      );
      if (shouldDiscardVoice != true || !mounted) {
        return;
      }
      await _speech.cancel();
      if (!mounted) {
        return;
      }
      setState(() {
        _voicePhase = _VoicePhase.idle;
        _voiceTranscript = '';
      });
    }

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
                if (value == 'preview') {
                  _showMarkdownPreview();
                } else if (value == 'archive') {
                  _archiveNote();
                } else if (value == 'delete') {
                  _deleteNote();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  key: ValueKey('markdownPreviewMenuItem'),
                  value: 'preview',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('Markdown 预览'),
                  ),
                ),
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
                                key: const ValueKey('noteContentField'),
                                child: NoteBlockEditor(
                                  controller: _blockController,
                                  enabled: !_voiceSessionActive,
                                  onPreviewImage: _previewImageById,
                                ),
                              ),
                              if (_voiceSessionActive) ...[
                                const Divider(),
                                _VoiceInputPanel(
                                  phase: _voicePhase,
                                  transcript: _voiceTranscript,
                                  localeLabel: _voiceLocaleLabel,
                                  locales: _preferredVoiceLocales,
                                  selectedLocaleId: _voiceLocaleId,
                                  onStop: _stopVoiceInput,
                                  onInsert: _insertVoiceTranscript,
                                  onRetry: _retryVoiceInput,
                                  onDiscard: _discardVoiceTranscript,
                                  onLocaleSelected: _selectVoiceLocale,
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
                          if (_blockController.selectedImageId
                              case final imageId?) ...[
                            IconButton(
                              key: const ValueKey('previewSelectedImageButton'),
                              onPressed: () => _previewImageById(imageId),
                              icon: const Icon(Icons.open_in_full),
                              tooltip: '预览图片',
                            ),
                            IconButton(
                              key: const ValueKey('moveSelectedImageUpButton'),
                              onPressed: () =>
                                  _blockController.moveImage(imageId, -1),
                              icon: const Icon(Icons.arrow_upward),
                              tooltip: '上移图片',
                            ),
                            IconButton(
                              key: const ValueKey(
                                'moveSelectedImageDownButton',
                              ),
                              onPressed: () =>
                                  _blockController.moveImage(imageId, 1),
                              icon: const Icon(Icons.arrow_downward),
                              tooltip: '下移图片',
                            ),
                            IconButton(
                              key: const ValueKey('removeSelectedImageButton'),
                              onPressed: () =>
                                  _blockController.removeImage(imageId),
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              tooltip: '删除图片',
                            ),
                          ] else ...[
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
                              onPressed:
                                  !_voiceInputSupported ||
                                      _voicePhase == _VoicePhase.starting ||
                                      _voicePhase == _VoicePhase.reviewing
                                  ? null
                                  : _toggleVoiceInput,
                              icon: _voicePhase == _VoicePhase.starting
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
                                  : _voicePhase == _VoicePhase.starting
                                  ? '正在准备语音输入'
                                  : _voicePhase == _VoicePhase.reviewing
                                  ? '请先处理识别结果'
                                  : _isListening
                                  ? '停止语音输入'
                                  : '开始语音输入',
                            ),
                          ],
                          const Spacer(),
                          SizedBox(
                            width: 64,
                            child: Text(
                              _isListening
                                  ? '听写中'
                                  : '${_blockController.characterCount} 字',
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            key: const ValueKey('saveNoteButton'),
                            onPressed: _isSaving || _voiceSessionActive
                                ? null
                                : _saveNote,
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

class _VoiceInputPanel extends StatelessWidget {
  const _VoiceInputPanel({
    required this.phase,
    required this.transcript,
    required this.localeLabel,
    required this.locales,
    required this.selectedLocaleId,
    required this.onStop,
    required this.onInsert,
    required this.onRetry,
    required this.onDiscard,
    required this.onLocaleSelected,
  });

  final _VoicePhase phase;
  final String transcript;
  final String localeLabel;
  final List<LocaleName> locales;
  final String? selectedLocaleId;
  final Future<void> Function() onStop;
  final Future<void> Function() onInsert;
  final Future<void> Function() onRetry;
  final VoidCallback onDiscard;
  final Future<void> Function(String localeId) onLocaleSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isStarting = phase == _VoicePhase.starting;
    final isListening = phase == _VoicePhase.listening;
    final canChooseLocale =
        phase == _VoicePhase.reviewing && locales.isNotEmpty;
    return Container(
      key: const ValueKey('voiceInputPanel'),
      height: 136,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (isStarting)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  isListening
                      ? Icons.graphic_eq
                      : Icons.record_voice_over_outlined,
                  size: 18,
                  color: isListening ? colorScheme.error : colorScheme.primary,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isStarting
                      ? '正在准备语音服务'
                      : isListening
                      ? '正在听写'
                      : '检查识别结果',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('voiceLocaleMenu'),
                enabled: canChooseLocale,
                tooltip: canChooseLocale ? '选择识别语言并重试' : '当前识别语言',
                initialValue: selectedLocaleId,
                onSelected: onLocaleSelected,
                itemBuilder: (context) => [
                  for (final locale in locales)
                    PopupMenuItem(
                      value: locale.localeId,
                      child: Text(locale.name),
                    ),
                ],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_outlined, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          localeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      if (canChooseLocale)
                        const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                transcript.trim().isEmpty
                    ? isStarting
                          ? '正在连接系统语音识别...'
                          : '请开始说话，识别结果会先显示在这里。'
                    : transcript,
                key: const ValueKey('voiceTranscriptText'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: transcript.trim().isEmpty
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isListening)
                  OutlinedButton.icon(
                    key: const ValueKey('stopVoiceInputButton'),
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('停止'),
                  )
                else if (phase == _VoicePhase.reviewing) ...[
                  TextButton(
                    key: const ValueKey('discardVoiceInputButton'),
                    onPressed: onDiscard,
                    child: const Text('丢弃'),
                  ),
                  TextButton(
                    key: const ValueKey('retryVoiceInputButton'),
                    onPressed: onRetry,
                    child: const Text('重试'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey('insertVoiceInputButton'),
                    onPressed: transcript.trim().isEmpty ? null : onInsert,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('插入正文'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
