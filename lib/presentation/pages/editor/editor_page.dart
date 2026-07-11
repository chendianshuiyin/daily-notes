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
  const EditorPage({
    super.key,
    this.noteId,
    this.initialContent,
    @visibleForTesting this.initialVoiceTranscript,
  });

  /// 要编辑的笔记 ID，如果为 null 则创建新笔记
  final String? noteId;
  final String? initialContent;

  @visibleForTesting
  final String? initialVoiceTranscript;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final NoteImageService _imageService = const NoteImageService();
  final NoteMarkdownCodec _markdownCodec = const NoteMarkdownCodec();
  final LocalAiOrganizer _localAiOrganizer = const LocalAiOrganizer();
  final SpeechToText _speech = SpeechToText();
  late NoteBlockEditorController _blockController;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoadedInitialNote = false;
  bool _isDirty = false;
  bool _allowPop = false;
  bool _isPickingImages = false;
  bool _isApplyingVoiceTranscript = false;
  _VoicePhase _voicePhase = _VoicePhase.idle;
  Note? _currentNote;
  List<NoteImage> _images = [];
  String _initialTitle = '';
  String _initialContent = '';
  String _initialImageIds = '';
  String _voiceTranscript = '';
  AiTranscriptSuggestion? _voiceSuggestion;
  bool _showSuggestedVoice = false;
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
    final initialContent = widget.initialContent?.trim() ?? '';
    _replaceBlockController(
      NoteBlockEditorController(
        blocks: _markdownCodec.decode(initialContent).blocks,
        images: const [],
      ),
      disposePrevious: false,
    );
    _isDirty = initialContent.isNotEmpty;
    final initialVoiceTranscript = widget.initialVoiceTranscript?.trim();
    if (initialVoiceTranscript != null && initialVoiceTranscript.isNotEmpty) {
      _voiceTranscript = initialVoiceTranscript;
      _voicePhase = _VoicePhase.reviewing;
    }
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
      _popEditor(saved: true);
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
      _voiceSuggestion = null;
      _showSuggestedVoice = false;
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
      _voiceSuggestion = null;
      _showSuggestedVoice = false;
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
    final transcript =
        (_showSuggestedVoice
            ? _voiceSuggestion?.suggested
            : _voiceSuggestion?.original) ??
        _voiceTranscript;
    final normalized = transcript.trim();
    if (normalized.isEmpty) {
      _discardVoiceTranscript();
      return;
    }
    setState(() => _isApplyingVoiceTranscript = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await _blockController.insertText(normalized, atCapturedSelection: true);
    } finally {
      if (mounted) {
        setState(() => _isApplyingVoiceTranscript = false);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _voicePhase = _VoicePhase.idle;
      _voiceTranscript = '';
      _voiceSuggestion = null;
      _showSuggestedVoice = false;
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
      _voiceSuggestion = null;
      _showSuggestedVoice = false;
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
      _voiceSuggestion = null;
      _showSuggestedVoice = false;
    });
  }

  Future<void> _cleanVoiceTranscript() async {
    final ai = context.read<AiProvider>();
    final config = ai.config;
    if (config == null) {
      _showError('请先在设置中配置 AI 服务');
      return;
    }
    final original = _voiceTranscript.trim();
    if (original.isEmpty) {
      return;
    }
    final payload = original.length <= 6000
        ? original
        : original.substring(0, 6000);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('voiceAiScopeDialog'),
        title: Text('发送给 ${config.model} 整理？'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('仅发送下方语音转写，不会发送笔记正文、图片或凭据。'),
                if (payload.length != original.length) ...[
                  const SizedBox(height: 8),
                  const Text('转写较长，仅发送前 6000 字。'),
                ],
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      dialogContext,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SingleChildScrollView(child: SelectableText(payload)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmVoiceAiButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认发送'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final result = await showDialog<_VoiceCleanupResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _VoiceCleanupProgressDialog(provider: ai, transcript: payload),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.error != null) {
      _showError(result.error!.message);
      return;
    }
    final suggestion = result.suggestion!;
    final untouchedTail = original.substring(payload.length);
    setState(() {
      _voiceSuggestion = AiTranscriptSuggestion(
        original: original,
        suggested: '${suggestion.suggested}$untouchedTail',
      );
      _showSuggestedVoice = true;
    });
  }

  void _previewImageById(String imageId) {
    final image = _blockController.imageById(imageId);
    if (image != null) {
      _showImagePreview(image);
    }
  }

  Future<void> _editImageCaption(String imageId) async {
    final controller = TextEditingController(
      text: _blockController.imageCaption(imageId),
    );
    final caption = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('图片说明'),
        content: TextField(
          key: const ValueKey('imageCaptionField'),
          controller: controller,
          autofocus: true,
          maxLength: 160,
          decoration: const InputDecoration(hintText: '添加简短说明'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('saveImageCaptionButton'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (caption != null) {
      await _blockController.setImageCaption(imageId, caption);
    }
    await Future<void>.delayed(kThemeAnimationDuration);
    controller.dispose();
  }

  Future<void> _replaceImage(String imageId) async {
    setState(() => _isPickingImages = true);
    try {
      final selected = await _imageService.pickImages(availableSlots: 1);
      if (selected.isNotEmpty) {
        await _blockController.replaceImage(imageId, selected.single);
      }
    } on NoteImageException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to replace note image: $error\n$stackTrace');
      if (mounted) {
        _showError('替换图片失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      }
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

  Future<void> _showFormattingTools() async {
    _blockController.captureInsertionSelection();
    await showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '格式',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭格式工具',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FormatButton(
                    label: 'H1',
                    tooltip: '一级标题',
                    onPressed: () =>
                        _blockController.applyFormat(NoteFormatAction.heading1),
                  ),
                  _FormatButton(
                    label: 'H2',
                    tooltip: '二级标题',
                    onPressed: () =>
                        _blockController.applyFormat(NoteFormatAction.heading2),
                  ),
                  _FormatButton(
                    label: 'H3',
                    tooltip: '三级标题',
                    onPressed: () =>
                        _blockController.applyFormat(NoteFormatAction.heading3),
                  ),
                  _FormatButton(
                    icon: Icons.notes,
                    tooltip: '正文',
                    onPressed: () =>
                        _blockController.applyFormat(NoteFormatAction.body),
                  ),
                  _FormatButton(
                    icon: Icons.format_bold,
                    tooltip: '加粗',
                    onPressed: () =>
                        _blockController.applyFormat(NoteFormatAction.bold),
                  ),
                  _FormatButton(
                    icon: Icons.format_italic,
                    tooltip: '斜体',
                    onPressed: () =>
                        _blockController.applyFormat(NoteFormatAction.italic),
                  ),
                  _FormatButton(
                    icon: Icons.format_underlined,
                    tooltip: '下划线',
                    onPressed: () => _blockController.applyFormat(
                      NoteFormatAction.underline,
                    ),
                  ),
                  _FormatButton(
                    icon: Icons.format_strikethrough,
                    tooltip: '删除线',
                    onPressed: () =>
                        _blockController.applyFormat(NoteFormatAction.strike),
                  ),
                  _FormatButton(
                    icon: Icons.code,
                    tooltip: '行内代码',
                    onPressed: () =>
                        _blockController.applyFormat(NoteFormatAction.code),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLocalTagSuggestions() async {
    _blockController.captureInsertionSelection();
    final suggestions = _localAiOrganizer.suggestTags(
      title: _titleController.text,
      content: _blockController.markdown,
      notes: context.read<NoteProvider>().notes,
      currentNoteId: _currentNote?.id ?? widget.noteId,
    );
    if (suggestions.isEmpty) {
      _showError('暂时没有合适的已有标签建议');
      return;
    }
    await _showTagSuggestionSheet(
      suggestions
          .map((item) => _TagOption(tag: item.tag, reason: item.reason))
          .toList(),
      subtitle: '本次分析仅在设备上进行',
    );
  }

  Future<void> _showRemoteTagSuggestions() async {
    _blockController.captureInsertionSelection();
    final ai = context.read<AiProvider>();
    final config = ai.config;
    if (config == null) {
      _showError('请先在设置中配置 AI 服务');
      return;
    }
    final draftTitle = _titleController.text.trim();
    final draftContent = _blockController.markdown.trim();
    if (draftTitle.isEmpty && draftContent.isEmpty) {
      _showError('请先输入一些笔记内容');
      return;
    }
    String bounded(String value, int limit) {
      return value.length <= limit ? value : value.substring(0, limit);
    }

    final title = bounded(draftTitle, 500);
    final content = bounded(draftContent, 12000);
    final wasTruncated =
        title.length != draftTitle.length ||
        content.length != draftContent.length;
    final captions = _blockController.blocks
        .where((block) => block.type == NoteBlockType.image)
        .map((block) => bounded(block.caption.trim(), 300))
        .where((caption) => caption.isNotEmpty)
        .toList();
    final existingTags = Note.normalizeTags(
      context.read<NoteProvider>().activeNotes.expand((note) => note.tags),
    ).take(100).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('remoteAiScopeDialog'),
        title: Text('发送给 ${config.model}？'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '将发送标题、正文、${captions.length} 条图片说明和 '
                  '${existingTags.length} 个已有标签名。',
                ),
                if (wasTruncated) ...[
                  const SizedBox(height: 8),
                  Text(
                    '草稿较长，仅发送下方预览中的前 ${title.length + content.length} 字。',
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.tertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text('不会发送图片、WebDAV 凭据、归档笔记或隐藏元数据。'),
                const SizedBox(height: 8),
                ExpansionTile(
                  key: const ValueKey('remoteAiScopeDetails'),
                  tilePadding: EdgeInsets.zero,
                  title: Text('查看发送文本（${title.length + content.length} 字）'),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          [
                            if (title.isNotEmpty) '标题：$title',
                            if (content.isNotEmpty) '正文：$content',
                            if (captions.isNotEmpty)
                              '图片说明：${captions.join('；')}',
                          ].join('\n\n'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmRemoteAiTagsButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认发送'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final result = await showDialog<_RemoteTagResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _RemoteTagProgressDialog(
        provider: ai,
        noteContext: AiNoteContext(
          title: title,
          content: content,
          existingTags: existingTags,
          imageCaptions: captions,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.error != null) {
      _showError(result.error!.message);
      return;
    }
    final suggestions = result.suggestions;
    if (suggestions.isEmpty) {
      _showError('AI 没有返回可用的标签建议');
      return;
    }
    await _showTagSuggestionSheet(
      suggestions
          .map((item) => _TagOption(tag: item.tag, reason: item.reason))
          .toList(),
      subtitle: '${config.model} 的建议，插入前请确认',
    );
  }

  Future<void> _showTagSuggestionSheet(
    List<_TagOption> suggestions, {
    required String subtitle,
  }) async {
    final selected = suggestions.map((item) => item.tag).toSet();
    final tags = await showModalBottomSheet<List<String>>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 720),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final preview = suggestions
              .where((item) => selected.contains(item.tag))
              .map((item) => item.tag)
              .join(' ');
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: Theme.of(sheetContext).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '智能标签',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: '关闭智能标签',
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  for (final suggestion in suggestions)
                    CheckboxListTile(
                      key: ValueKey('smartTag-${suggestion.tag}'),
                      value: selected.contains(suggestion.tag),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(suggestion.tag),
                      subtitle: Text(suggestion.reason),
                      onChanged: (checked) {
                        setSheetState(() {
                          if (checked ?? false) {
                            selected.add(suggestion.tag);
                          } else {
                            selected.remove(suggestion.tag);
                          }
                        });
                      },
                    ),
                  Container(
                    key: const ValueKey('smartTagPreview'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(preview.isEmpty ? '未选择标签' : '将插入：$preview'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('applySmartTagsButton'),
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.of(sheetContext).pop(
                            suggestions
                                .where((item) => selected.contains(item.tag))
                                .map((item) => item.tag)
                                .toList(),
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('插入所选标签'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (tags == null || tags.isEmpty) {
      return;
    }
    await _blockController.insertText(
      ' ${tags.join(' ')}',
      atCapturedSelection: true,
    );
  }

  Future<void> _showRelatedNotes() async {
    final noteProvider = context.read<NoteProvider>();
    final suggestions = _localAiOrganizer.findRelatedNotes(
      title: _titleController.text,
      content: _blockController.markdown,
      notes: noteProvider.activeNotes,
      currentNoteId: _currentNote?.id ?? widget.noteId,
    );
    final related = suggestions
        .map((suggestion) {
          final note = noteProvider.noteById(suggestion.noteId);
          return note == null ? null : (note: note, suggestion: suggestion);
        })
        .whereType<({Note note, RelatedNoteSuggestion suggestion})>()
        .toList();
    if (related.isEmpty) {
      _showError('暂时没有找到相关笔记');
      return;
    }
    final noteId = await showModalBottomSheet<String>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 720),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.68,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.hub_outlined),
                    const SizedBox(width: 8),
                    Text(
                      '相关笔记',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭相关笔记',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                  itemCount: related.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = related[index];
                    return Card(
                      child: ListTile(
                        key: ValueKey('relatedNote-${item.note.id}'),
                        title: Text(item.note.displayTitle),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.note.bodyPreview.isNotEmpty)
                              Text(
                                item.note.bodyPreview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 5),
                            Text(
                              item.suggestion.reason,
                              style: TextStyle(
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.of(sheetContext).pop(item.note.id),
                      ),
                    );
                  },
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

  void _popEditor({bool saved = false}) {
    if (!mounted) {
      return;
    }

    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop(saved);
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
    final aiConfigured = context.watch<AiProvider>().isConfigured;
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
                } else if (value == 'format') {
                  _showFormattingTools();
                } else if (value == 'local-tags') {
                  _showLocalTagSuggestions();
                } else if (value == 'remote-tags') {
                  _showRemoteTagSuggestions();
                } else if (value == 'related-notes') {
                  _showRelatedNotes();
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
                const PopupMenuItem(
                  key: ValueKey('formatToolsMenuItem'),
                  value: 'format',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.format_bold),
                    title: Text('格式工具'),
                  ),
                ),
                const PopupMenuItem(
                  key: ValueKey('smartTagMenuItem'),
                  value: 'local-tags',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.offline_bolt_outlined),
                    title: Text('本地智能标签'),
                  ),
                ),
                if (aiConfigured)
                  const PopupMenuItem(
                    key: ValueKey('remoteAiTagMenuItem'),
                    value: 'remote-tags',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.auto_awesome_outlined),
                      title: Text('AI 标签建议'),
                    ),
                  ),
                const PopupMenuItem(
                  key: ValueKey('relatedNotesMenuItem'),
                  value: 'related-notes',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.hub_outlined),
                    title: Text('相关笔记'),
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
                                  enabled:
                                      !_voiceSessionActive ||
                                      _isApplyingVoiceTranscript,
                                  onPreviewImage: _previewImageById,
                                  onEditImageCaption: _editImageCaption,
                                  onReplaceImage: _replaceImage,
                                ),
                              ),
                              if (_voiceSessionActive) ...[
                                const Divider(),
                                _VoiceInputPanel(
                                  phase: _voicePhase,
                                  transcript: _voiceTranscript,
                                  suggestion: _voiceSuggestion,
                                  showSuggested: _showSuggestedVoice,
                                  canUseAi: aiConfigured,
                                  localeLabel: _voiceLocaleLabel,
                                  locales: _preferredVoiceLocales,
                                  selectedLocaleId: _voiceLocaleId,
                                  onStop: _stopVoiceInput,
                                  onInsert: _insertVoiceTranscript,
                                  onRetry: _retryVoiceInput,
                                  onDiscard: _discardVoiceTranscript,
                                  onClean: _cleanVoiceTranscript,
                                  onVersionChanged: (showSuggested) {
                                    setState(
                                      () => _showSuggestedVoice = showSuggested,
                                    );
                                  },
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
                      child: LayoutBuilder(
                        builder: (context, toolbarConstraints) => Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    if (_blockController.selectedImageId
                                        case final imageId?) ...[
                                      IconButton(
                                        key: const ValueKey(
                                          'previewSelectedImageButton',
                                        ),
                                        onPressed: () =>
                                            _previewImageById(imageId),
                                        icon: const Icon(Icons.open_in_full),
                                        tooltip: '预览图片',
                                      ),
                                      IconButton(
                                        key: const ValueKey(
                                          'moveSelectedImageUpButton',
                                        ),
                                        onPressed: () => _blockController
                                            .moveImage(imageId, -1),
                                        icon: const Icon(Icons.arrow_upward),
                                        tooltip: '上移图片',
                                      ),
                                      IconButton(
                                        key: const ValueKey(
                                          'moveSelectedImageDownButton',
                                        ),
                                        onPressed: () => _blockController
                                            .moveImage(imageId, 1),
                                        icon: const Icon(Icons.arrow_downward),
                                        tooltip: '下移图片',
                                      ),
                                      PopupMenuButton<String>(
                                        key: const ValueKey(
                                          'selectedImageMoreButton',
                                        ),
                                        tooltip: '更多图片操作',
                                        onSelected: (value) {
                                          if (value == 'caption') {
                                            _editImageCaption(imageId);
                                          } else if (value == 'replace') {
                                            _replaceImage(imageId);
                                          } else if (value == 'delete') {
                                            _blockController.removeImage(
                                              imageId,
                                            );
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            key: ValueKey(
                                              'editImageCaptionMenuItem',
                                            ),
                                            value: 'caption',
                                            child: Text('编辑说明'),
                                          ),
                                          PopupMenuItem(
                                            value: 'replace',
                                            child: Text('替换图片'),
                                          ),
                                          PopupMenuItem(
                                            key: ValueKey(
                                              'deleteImageMenuItem',
                                            ),
                                            value: 'delete',
                                            child: Text('删除图片'),
                                          ),
                                        ],
                                        icon: const Icon(Icons.more_horiz),
                                      ),
                                    ] else ...[
                                      IconButton(
                                        key: const ValueKey(
                                          'addNoteImageButton',
                                        ),
                                        onPressed: _isPickingImages
                                            ? null
                                            : _pickImages,
                                        icon: _isPickingImages
                                            ? const SizedBox.square(
                                                dimension: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                              ),
                                        tooltip: '添加图片',
                                      ),
                                      Text(
                                        '${_images.length}/${NoteImageService.maxImagesPerNote}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      IconButton(
                                        onPressed: _insertCurrentTime,
                                        icon: const Icon(
                                          Icons.schedule_outlined,
                                        ),
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
                                                _voicePhase ==
                                                    _VoicePhase.starting ||
                                                _voicePhase ==
                                                    _VoicePhase.reviewing
                                            ? null
                                            : _toggleVoiceInput,
                                        icon:
                                            _voicePhase == _VoicePhase.starting
                                            ? const SizedBox.square(
                                                dimension: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                _isListening
                                                    ? Icons.stop_circle_outlined
                                                    : Icons.mic_none_outlined,
                                                color: _isListening
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.error
                                                    : null,
                                              ),
                                        tooltip: !_voiceInputSupported
                                            ? '当前平台不支持语音输入'
                                            : _voicePhase ==
                                                  _VoicePhase.starting
                                            ? '正在准备语音输入'
                                            : _voicePhase ==
                                                  _VoicePhase.reviewing
                                            ? '请先处理识别结果'
                                            : _isListening
                                            ? '停止语音输入'
                                            : '开始语音输入',
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (toolbarConstraints.maxWidth >= 430) ...[
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
                            ] else
                              const SizedBox(width: 6),
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
      ),
    );
  }

  String _editorDateLabel() {
    final date = _currentNote?.createdAt ?? DateTime.now();
    return '${date.year}年${date.month}月${date.day}日';
  }
}

class _TagOption {
  const _TagOption({required this.tag, required this.reason});

  final String tag;
  final String reason;
}

class _RemoteTagResult {
  const _RemoteTagResult.success(this.suggestions) : error = null;
  const _RemoteTagResult.failure(this.error) : suggestions = const [];

  final List<AiTagSuggestion> suggestions;
  final AiRemoteException? error;
}

class _RemoteTagProgressDialog extends StatefulWidget {
  const _RemoteTagProgressDialog({
    required this.provider,
    required this.noteContext,
  });

  final AiProvider provider;
  final AiNoteContext noteContext;

  @override
  State<_RemoteTagProgressDialog> createState() =>
      _RemoteTagProgressDialogState();
}

class _RemoteTagProgressDialogState extends State<_RemoteTagProgressDialog> {
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final suggestions = await widget.provider.suggestTags(widget.noteContext);
      if (mounted) {
        Navigator.of(context).pop(_RemoteTagResult.success(suggestions));
      }
    } on AiRemoteException catch (error) {
      if (mounted) {
        Navigator.of(context).pop(_RemoteTagResult.failure(error));
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(
          const _RemoteTagResult.failure(
            AiRemoteException(AiRemoteError.network, 'AI 请求失败，请重试'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('remoteAiProgressDialog'),
      title: const Text('正在生成标签建议'),
      content: const Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('仅处理刚才确认的文字范围')),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancelRemoteAiButton'),
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

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    this.icon,
    this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 44,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: icon == null
              ? Text(
                  label!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )
              : Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _VoiceCleanupResult {
  const _VoiceCleanupResult.success(this.suggestion) : error = null;
  const _VoiceCleanupResult.failure(this.error) : suggestion = null;

  final AiTranscriptSuggestion? suggestion;
  final AiRemoteException? error;
}

class _VoiceCleanupProgressDialog extends StatefulWidget {
  const _VoiceCleanupProgressDialog({
    required this.provider,
    required this.transcript,
  });

  final AiProvider provider;
  final String transcript;

  @override
  State<_VoiceCleanupProgressDialog> createState() =>
      _VoiceCleanupProgressDialogState();
}

class _VoiceCleanupProgressDialogState
    extends State<_VoiceCleanupProgressDialog> {
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final suggestion = await widget.provider.cleanTranscript(
        widget.transcript,
      );
      if (mounted) {
        Navigator.of(context).pop(_VoiceCleanupResult.success(suggestion));
      }
    } on AiRemoteException catch (error) {
      if (mounted) {
        Navigator.of(context).pop(_VoiceCleanupResult.failure(error));
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(
          const _VoiceCleanupResult.failure(
            AiRemoteException(AiRemoteError.network, 'AI 语音整理失败，请重试'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('voiceAiProgressDialog'),
      title: const Text('正在整理语音文本'),
      content: const Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('原始转写会一直保留到你确认插入')),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancelVoiceAiButton'),
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

class _VoiceDiffText extends StatelessWidget {
  const _VoiceDiffText({
    required this.original,
    required this.suggested,
    required this.showSuggested,
  });

  final String original;
  final String suggested;
  final bool showSuggested;

  @override
  Widget build(BuildContext context) {
    final originalRunes = original.runes.toList();
    final suggestedRunes = suggested.runes.toList();
    var prefix = 0;
    while (prefix < originalRunes.length &&
        prefix < suggestedRunes.length &&
        originalRunes[prefix] == suggestedRunes[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < originalRunes.length - prefix &&
        suffix < suggestedRunes.length - prefix &&
        originalRunes[originalRunes.length - 1 - suffix] ==
            suggestedRunes[suggestedRunes.length - 1 - suffix]) {
      suffix++;
    }
    final source = showSuggested ? suggestedRunes : originalRunes;
    final changedEnd = source.length - suffix;
    final normalStyle = Theme.of(context).textTheme.bodyMedium;
    final changedColor = showSuggested
        ? Theme.of(context).colorScheme.secondaryContainer
        : Theme.of(context).colorScheme.errorContainer;
    return Text.rich(
      key: const ValueKey('voiceTranscriptText'),
      TextSpan(
        style: normalStyle,
        children: [
          if (prefix > 0)
            TextSpan(text: String.fromCharCodes(source.take(prefix))),
          if (changedEnd > prefix)
            TextSpan(
              text: String.fromCharCodes(
                source.skip(prefix).take(changedEnd - prefix),
              ),
              style: TextStyle(
                backgroundColor: changedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (suffix > 0)
            TextSpan(text: String.fromCharCodes(source.skip(changedEnd))),
        ],
      ),
    );
  }
}

class _VoiceInputPanel extends StatelessWidget {
  const _VoiceInputPanel({
    required this.phase,
    required this.transcript,
    required this.suggestion,
    required this.showSuggested,
    required this.canUseAi,
    required this.localeLabel,
    required this.locales,
    required this.selectedLocaleId,
    required this.onStop,
    required this.onInsert,
    required this.onRetry,
    required this.onDiscard,
    required this.onClean,
    required this.onVersionChanged,
    required this.onLocaleSelected,
  });

  final _VoicePhase phase;
  final String transcript;
  final AiTranscriptSuggestion? suggestion;
  final bool showSuggested;
  final bool canUseAi;
  final String localeLabel;
  final List<LocaleName> locales;
  final String? selectedLocaleId;
  final Future<void> Function() onStop;
  final Future<void> Function() onInsert;
  final Future<void> Function() onRetry;
  final VoidCallback onDiscard;
  final Future<void> Function() onClean;
  final ValueChanged<bool> onVersionChanged;
  final Future<void> Function(String localeId) onLocaleSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final suggestionValue = suggestion;
    final isStarting = phase == _VoicePhase.starting;
    final isListening = phase == _VoicePhase.listening;
    final canChooseLocale =
        phase == _VoicePhase.reviewing && locales.isNotEmpty;
    return Container(
      key: const ValueKey('voiceInputPanel'),
      height: suggestionValue == null ? 136 : 204,
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
          if (suggestionValue != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                key: const ValueKey('voiceVersionSegment'),
                segments: const [
                  ButtonSegment(value: false, label: Text('原文')),
                  ButtonSegment(value: true, label: Text('AI 建议')),
                ],
                selected: {showSuggested},
                onSelectionChanged: (selection) {
                  onVersionChanged(selection.first);
                },
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: suggestionValue == null
                  ? Text(
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
                    )
                  : _VoiceDiffText(
                      original: suggestionValue.original,
                      suggested: suggestionValue.suggested,
                      showSuggested: showSuggested,
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
                  IconButton(
                    key: const ValueKey('discardVoiceInputButton'),
                    onPressed: onDiscard,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '丢弃语音结果',
                  ),
                  IconButton(
                    key: const ValueKey('retryVoiceInputButton'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    tooltip: '重新听写',
                  ),
                  if (canUseAi && suggestionValue == null)
                    IconButton(
                      key: const ValueKey('cleanVoiceWithAiButton'),
                      onPressed: transcript.trim().isEmpty ? null : onClean,
                      icon: const Icon(Icons.auto_fix_high_outlined),
                      tooltip: 'AI 整理语音文本',
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
