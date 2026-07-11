import 'note_block.dart';

/// Converts the app-owned block model to and from the supported Markdown subset.
class NoteMarkdownCodec {
  const NoteMarkdownCodec();

  NoteDocument decode(
    String markdown, {
    List<NoteBlock> existingBlocks = const [],
  }) {
    final reusableIds = existingBlocks
        .where((block) => block.isText)
        .map((block) => block.id)
        .toList();
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final blocks = <NoteBlock>[];
    var index = 0;

    String nextId() =>
        index < reusableIds.length ? reusableIds[index++] : 'text-${index++}';

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      if (line.startsWith('```')) {
        final codeLines = <String>[];
        lineIndex++;
        while (lineIndex < lines.length &&
            !lines[lineIndex].startsWith('```')) {
          codeLines.add(lines[lineIndex]);
          lineIndex++;
        }
        blocks.add(
          NoteBlock(
            id: nextId(),
            type: NoteBlockType.code,
            text: codeLines.join('\n'),
          ),
        );
        continue;
      }

      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        blocks.add(
          NoteBlock(
            id: nextId(),
            type: NoteBlockType.heading,
            text: heading.group(2)!,
            level: heading.group(1)!.length,
          ),
        );
        continue;
      }

      final bullet = RegExp(r'^(\s*)[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        blocks.add(
          NoteBlock(
            id: nextId(),
            type: NoteBlockType.bulletList,
            text: bullet.group(2)!,
            indent: bullet.group(1)!.length ~/ 2,
          ),
        );
        continue;
      }

      final numbered = RegExp(r'^(\s*)\d+\.\s+(.*)$').firstMatch(line);
      if (numbered != null) {
        blocks.add(
          NoteBlock(
            id: nextId(),
            type: NoteBlockType.numberList,
            text: numbered.group(2)!,
            indent: numbered.group(1)!.length ~/ 2,
          ),
        );
        continue;
      }

      final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (quote != null) {
        blocks.add(
          NoteBlock(
            id: nextId(),
            type: NoteBlockType.quote,
            text: quote.group(1)!,
          ),
        );
        continue;
      }

      if (RegExp(r'^\s*---+\s*$').hasMatch(line)) {
        blocks.add(NoteBlock(id: nextId(), type: NoteBlockType.divider));
        continue;
      }

      blocks.add(
        NoteBlock(id: nextId(), type: NoteBlockType.paragraph, text: line),
      );
    }

    return NoteDocument(List.unmodifiable(blocks));
  }

  String encode(NoteDocument document) => document.toTextShadow();
}
