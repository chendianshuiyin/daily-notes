import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class NoteMarkdownPreview extends StatefulWidget {
  const NoteMarkdownPreview({super.key, required this.markdown});

  final String markdown;

  @override
  State<NoteMarkdownPreview> createState() => _NoteMarkdownPreviewState();
}

class _NoteMarkdownPreviewState extends State<NoteMarkdownPreview> {
  late final EditorState _editorState = EditorState(
    document: markdownToDocument(widget.markdown),
  );

  @override
  void dispose() {
    _editorState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AppFlowyEditor(
      key: const ValueKey('markdownPreview'),
      editorState: _editorState,
      editable: false,
      shrinkWrap: false,
      showMagnifier: false,
      editorStyle: EditorStyle.desktop(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.16),
        textStyleConfiguration: TextStyleConfiguration(
          text: (textTheme.bodyLarge ?? const TextStyle()).copyWith(
            color: colors.onSurface,
          ),
          code: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
            color: colors.onSurfaceVariant,
            backgroundColor: colors.surfaceContainerHighest,
            fontFamily: 'monospace',
          ),
          bold: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
