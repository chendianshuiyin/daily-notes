import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/presentation/pages/editor/note_block_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const image = NoteImage(
    id: 'image-1',
    name: 'pixel.png',
    mimeType: 'image/png',
    base64Data:
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  test('round-trips ordered text and image blocks', () {
    final controller = NoteBlockEditorController(
      blocks: const [
        NoteBlock(
          id: 'heading-1',
          type: NoteBlockType.heading,
          text: 'Plan',
          level: 2,
        ),
        NoteBlock(
          id: 'image-block-1',
          type: NoteBlockType.image,
          imageId: 'image-1',
        ),
        NoteBlock(
          id: 'paragraph-1',
          type: NoteBlockType.paragraph,
          text: 'After image #work',
        ),
      ],
      images: const [image],
    );
    addTearDown(controller.dispose);

    expect(controller.blocks.map((block) => block.type), [
      NoteBlockType.heading,
      NoteBlockType.image,
      NoteBlockType.paragraph,
    ]);
    expect(controller.blocks[1].imageId, 'image-1');
    expect(controller.markdown, '## Plan\nAfter image #work');
  });

  test('inserts multiple images after the selected root block', () async {
    const secondImage = NoteImage(
      id: 'image-2',
      name: 'pixel-2.png',
      mimeType: 'image/png',
      base64Data:
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final controller = NoteBlockEditorController(
      blocks: const [
        NoteBlock(id: 'before', type: NoteBlockType.paragraph, text: 'Before'),
        NoteBlock(id: 'after', type: NoteBlockType.paragraph, text: 'After'),
      ],
      images: const [],
    );
    addTearDown(controller.dispose);
    controller.editorState.selection = Selection.collapsed(
      Position(path: const [0], offset: 6),
    );

    await controller.insertImages([image, secondImage]);

    expect(controller.blocks.map((block) => block.type), [
      NoteBlockType.paragraph,
      NoteBlockType.image,
      NoteBlockType.image,
      NoteBlockType.paragraph,
      NoteBlockType.paragraph,
    ]);
    expect(
      controller.blocks
          .where((block) => block.type == NoteBlockType.image)
          .map((block) => block.imageId),
      ['image-1', 'image-2'],
    );
  });

  test(
    'moves and removes an image block without losing surrounding text',
    () async {
      final controller = NoteBlockEditorController(
        blocks: const [
          NoteBlock(
            id: 'before',
            type: NoteBlockType.paragraph,
            text: 'Before',
          ),
          NoteBlock(
            id: 'image-block',
            type: NoteBlockType.image,
            imageId: 'image-1',
          ),
          NoteBlock(id: 'after', type: NoteBlockType.paragraph, text: 'After'),
        ],
        images: const [image],
      );
      addTearDown(controller.dispose);

      await controller.moveImage('image-1', 1);
      expect(controller.blocks[2].type, NoteBlockType.image);
      await controller.removeImage('image-1');

      expect(controller.images, isEmpty);
      expect(controller.markdown, 'Before\nAfter');
    },
  );

  test('normalizes a heading shortcut missed by an IME update', () async {
    final controller = NoteBlockEditorController(
      blocks: const [NoteBlock(id: 'paragraph', type: NoteBlockType.paragraph)],
      images: const [],
    );
    addTearDown(controller.dispose);
    controller.editorState.selection = Selection.collapsed(
      Position(path: const [0]),
    );

    await controller.insertText('## ');
    await Future<void>.delayed(Duration.zero);

    expect(controller.blocks.single.type, NoteBlockType.heading);
    expect(controller.blocks.single.level, 2);
    expect(controller.blocks.single.text, isEmpty);
  });

  test('updates caption and replaces image without moving its block', () async {
    const replacement = NoteImage(
      id: 'image-replacement',
      name: 'replacement.png',
      mimeType: 'image/png',
      base64Data:
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final controller = NoteBlockEditorController(
      blocks: const [
        NoteBlock(id: 'before', type: NoteBlockType.paragraph, text: 'Before'),
        NoteBlock(
          id: 'image-block',
          type: NoteBlockType.image,
          imageId: 'image-1',
          caption: 'Old caption',
        ),
        NoteBlock(id: 'after', type: NoteBlockType.paragraph, text: 'After'),
      ],
      images: const [image],
    );
    addTearDown(controller.dispose);

    await controller.setImageCaption('image-1', 'Updated caption');
    await controller.replaceImage('image-1', replacement);

    expect(controller.blocks[1].id, 'image-block');
    expect(controller.blocks[1].imageId, 'image-replacement');
    expect(controller.blocks[1].caption, 'Updated caption');
    expect(controller.images.single.id, 'image-replacement');
  });

  test('applies formatting to the captured selection', () async {
    final controller = NoteBlockEditorController(
      blocks: const [
        NoteBlock(
          id: 'paragraph',
          type: NoteBlockType.paragraph,
          text: 'Hello',
        ),
      ],
      images: const [],
    );
    addTearDown(controller.dispose);
    controller.editorState.selection = Selection.single(
      path: const [0],
      startOffset: 0,
      endOffset: 5,
    );
    controller.captureInsertionSelection();

    controller.applyFormat(NoteFormatAction.bold);
    await Future<void>.delayed(Duration.zero);

    expect(controller.blocks.single.text, '**Hello**');
  });

  test('inserts at the document end when editor selection is stale', () async {
    final controller = NoteBlockEditorController(
      blocks: const [NoteBlock(id: 'paragraph', type: NoteBlockType.paragraph)],
      images: const [],
    );
    addTearDown(controller.dispose);
    controller.editorState.selection = Selection.collapsed(
      Position(path: const [99], offset: 12),
    );

    await controller.insertText('Inserted', atCapturedSelection: true);

    expect(controller.markdown, 'Inserted');
  });
}
