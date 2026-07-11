import 'package:flutter/material.dart';

import '../../data/models/note.dart';

class NoteInlinePreview extends StatelessWidget {
  const NoteInlinePreview({
    super.key,
    required this.note,
    this.onTagSelected,
    this.maxLines = 4,
    this.emptyText,
    this.style,
  });

  final Note note;
  final ValueChanged<String>? onTagSelected;
  final int maxLines;
  final String? emptyText;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final source = _cleanPreviewSource(note.content);
    if (source.isEmpty) {
      return Text(
        emptyText ?? '',
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final tagStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w500,
    );
    final matches = RegExp(r'#[^\s#，。,.!?！？；;：:]+').allMatches(source);
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in matches) {
      if (match.start > offset) {
        spans.add(TextSpan(text: source.substring(offset, match.start)));
      }
      final tag = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: InkWell(
            key: ValueKey('inlineNoteTag-$tag'),
            onTap: onTagSelected == null ? null : () => onTagSelected!(tag),
            child: Text(tag, style: tagStyle),
          ),
        ),
      );
      offset = match.end;
    }
    if (offset < source.length) {
      spans.add(TextSpan(text: source.substring(offset)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      key: ValueKey('noteInlinePreview-${note.id}'),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  static String _cleanPreviewSource(String source) {
    return source
        .replaceAll(RegExp(r'(^|\n)\s*(#{1,3}\s+|[-*>]\s+|\d+\.\s+)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
