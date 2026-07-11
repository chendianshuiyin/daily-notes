import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'note_block_editor_controller.dart';

class NoteBlockEditor extends StatefulWidget {
  const NoteBlockEditor({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onPreviewImage,
    required this.onEditImageCaption,
    required this.onReplaceImage,
  });

  final NoteBlockEditorController controller;
  final bool enabled;
  final ValueChanged<String> onPreviewImage;
  final ValueChanged<String> onEditImageCaption;
  final ValueChanged<String> onReplaceImage;

  @override
  State<NoteBlockEditor> createState() => _NoteBlockEditorState();
}

class _NoteBlockEditorState extends State<NoteBlockEditor> {
  late EditorScrollController _scrollController;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _scrollController = _createScrollController();
  }

  @override
  void didUpdateWidget(covariant NoteBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _scrollController.dispose();
      _scrollController = _createScrollController();
    }
  }

  EditorScrollController _createScrollController() {
    return EditorScrollController(
      editorState: widget.controller.editorState,
      shrinkWrap: false,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = AppFlowyEditor(
      key: const ValueKey('noteContentEditor'),
      editorState: widget.controller.editorState,
      editorScrollController: _scrollController,
      editable: widget.enabled,
      editorStyle: _editorStyle(context),
      blockComponentBuilders: _blockBuilders(context),
      blockWrapper: _blockWrapper,
      showMagnifier: _isMobile,
      footer: const SizedBox(height: 120),
    );
    if (!_isMobile) {
      return editor;
    }
    return MobileFloatingToolbar(
      editorState: widget.controller.editorState,
      editorScrollController: _scrollController,
      floatingToolbarHeight: 44,
      toolbarBuilder: (context, anchor, closeToolbar) {
        return AdaptiveTextSelectionToolbar.editable(
          clipboardStatus: ClipboardStatus.pasteable,
          onCopy: () {
            copyCommand.execute(widget.controller.editorState);
            closeToolbar();
          },
          onCut: () {
            cutCommand.execute(widget.controller.editorState);
            closeToolbar();
          },
          onPaste: () {
            pasteCommand.execute(widget.controller.editorState);
            closeToolbar();
          },
          onSelectAll: () {
            selectAllCommand.execute(widget.controller.editorState);
            closeToolbar();
          },
          onLiveTextInput: null,
          onLookUp: null,
          onSearchWeb: null,
          onShare: null,
          anchors: TextSelectionToolbarAnchors(primaryAnchor: anchor),
        );
      },
      child: editor,
    );
  }

  EditorStyle _editorStyle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textStyles = TextStyleConfiguration(
      text: (textTheme.bodyLarge ?? const TextStyle()).copyWith(
        color: colors.onSurface,
        height: 1.55,
      ),
      code: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
        color: colors.onSurfaceVariant,
        backgroundColor: colors.surfaceContainerHighest,
        fontFamily: 'monospace',
      ),
      bold: const TextStyle(fontWeight: FontWeight.w700),
    );
    return _isMobile
        ? EditorStyle.mobile(
            padding: const EdgeInsets.symmetric(vertical: 12),
            cursorColor: colors.primary,
            dragHandleColor: colors.primary,
            selectionColor: colors.primary.withValues(alpha: 0.18),
            textStyleConfiguration: textStyles,
          )
        : EditorStyle.desktop(
            padding: const EdgeInsets.symmetric(vertical: 12),
            cursorColor: colors.primary,
            selectionColor: colors.primary.withValues(alpha: 0.18),
            textStyleConfiguration: textStyles,
          );
  }

  Map<String, BlockComponentBuilder> _blockBuilders(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final builders = {...standardBlockComponentBuilderMap};
    builders[ParagraphBlockKeys.type] = ParagraphBlockComponentBuilder(
      showPlaceholder: (editorState, node) {
        return editorState.document.root.children.length == 1 &&
            (node.delta?.toPlainText().isEmpty ?? false);
      },
      configuration: BlockComponentConfiguration(
        padding: (_) => const EdgeInsets.symmetric(vertical: 8),
        placeholderText: (_) => '记录想法，可输入 Markdown 与 #标签...',
        placeholderTextStyle: (_, {textSpan}) => TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 16,
          height: 1.55,
        ),
      ),
    );
    builders[ImageBlockKeys.type] = ImageBlockComponentBuilder(
      showMenu: true,
      menuBuilder: (node, _) => _imageMenu(context, node),
    );
    return builders;
  }

  Widget _imageMenu(BuildContext context, Node node) {
    final colors = Theme.of(context).colorScheme;
    final imageId = node.attributes[noteImageIdAttribute] as String?;
    if (imageId == null) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(6),
        color: colors.surfaceContainerHigh,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => widget.onPreviewImage(imageId),
              icon: const Icon(Icons.open_in_full, size: 18),
              tooltip: '预览图片',
            ),
            IconButton(
              onPressed: () => widget.controller.moveImage(imageId, -1),
              icon: const Icon(Icons.arrow_upward, size: 18),
              tooltip: '上移图片',
            ),
            IconButton(
              onPressed: () => widget.controller.moveImage(imageId, 1),
              icon: const Icon(Icons.arrow_downward, size: 18),
              tooltip: '下移图片',
            ),
            PopupMenuButton<String>(
              tooltip: '更多图片操作',
              onSelected: (value) {
                if (value == 'caption') {
                  widget.onEditImageCaption(imageId);
                } else if (value == 'replace') {
                  widget.onReplaceImage(imageId);
                } else if (value == 'delete') {
                  widget.controller.removeImage(imageId);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'caption', child: Text('编辑说明')),
                PopupMenuItem(value: 'replace', child: Text('替换图片')),
                PopupMenuItem(value: 'delete', child: Text('删除图片')),
              ],
              icon: const Icon(Icons.more_horiz, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockWrapper(
    BuildContext context, {
    required Node node,
    required Widget child,
  }) {
    if (node.type != ImageBlockKeys.type) {
      return child;
    }
    final caption = node.attributes[noteImageCaptionAttribute] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Text(
              caption,
              key: ValueKey('imageCaption-${node.id}'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
