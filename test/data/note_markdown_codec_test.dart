import 'package:daily_notes/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = NoteMarkdownCodec();

  test('decodes supported block shortcuts without treating tags as headings', () {
    final document = codec.decode(
      '# Heading\n#tag stays inline\n- task\n  1. nested\n> quote\n---\n```\ncode\n```',
    );

    expect(document.blocks.map((block) => block.type), [
      NoteBlockType.heading,
      NoteBlockType.paragraph,
      NoteBlockType.bulletList,
      NoteBlockType.numberList,
      NoteBlockType.quote,
      NoteBlockType.divider,
      NoteBlockType.code,
    ]);
    expect(document.blocks[0].level, 1);
    expect(document.blocks[1].text, '#tag stays inline');
    expect(document.blocks[3].indent, 1);
  });

  test('round-trips the supported Markdown subset', () {
    const source =
        '## Plan\n\n- first\n  - nested\n> remember #work\n---\n```\nfinal x = 1;\n```';

    expect(codec.encode(codec.decode(source)), source);
  });

  test('reuses text block identities across edits', () {
    final original = codec.decode('first\nsecond');
    final edited = codec.decode(
      'changed\nsecond',
      existingBlocks: original.blocks,
    );

    expect(edited.blocks.map((block) => block.id), ['text-0', 'text-1']);
  });
}
