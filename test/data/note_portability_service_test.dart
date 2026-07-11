import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = NotePortabilityService();

  test('exports and restores a lossless Daily Notes JSON file', () async {
    final note = _mixedNote();
    final bytes = await service.export([note], NoteExportFormat.dailyNotesJson);
    final bundle = await service.inspectImport('backup.json', bytes);

    expect(bundle.formatLabel, 'Daily Notes JSON');
    expect(bundle.notes, hasLength(1));
    expect(bundle.notes.single.toJson(), note.toJson());
  });

  test('exports portable Markdown and image assets in a ZIP', () async {
    final bytes = await service.export([
      _mixedNote(),
    ], NoteExportFormat.markdownZip);
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final names = archive.map((entry) => entry.name).toList();
    final markdownEntry = archive.firstWhere(
      (entry) => entry.name.startsWith('notes/'),
    );
    final markdown = utf8.decode(markdownEntry.content);

    expect(names, contains('README.md'));
    expect(names.where((name) => name.startsWith('media/')), hasLength(1));
    expect(markdown, contains('daily_notes_id: "portable-note"'));
    expect(markdown, contains('# 发布复盘'));
    expect(markdown, contains('**稳定性**'));
    expect(markdown, contains('![架构草图](../media/'));

    final imported = await service.inspectImport('notes.zip', bytes);
    final note = imported.notes.single;
    expect(imported.formatLabel, 'Markdown ZIP');
    expect(note.id, 'portable-note');
    expect(note.title, '发布复盘');
    expect(note.tags, contains('#开发/发布'));
    expect(note.images.single.name, 'diagram.png');
    final blockTypes = note.blocks.map((block) => block.type).toList();
    expect(blockTypes, contains(NoteBlockType.image));
    expect(
      blockTypes.indexOf(NoteBlockType.image),
      greaterThan(blockTypes.indexOf(NoteBlockType.paragraph)),
    );
  });

  test('imports a generic Markdown file from another notes app', () async {
    final bundle = await service.inspectImport(
      'meeting-notes.md',
      Uint8List.fromList(
        utf8.encode('# 周会记录\n\n发布前完成回归测试。 #工作/发布\n\n- 整理检查清单'),
      ),
    );

    final note = bundle.notes.single;
    expect(note.title, '周会记录');
    expect(note.content, contains('发布前完成回归测试'));
    expect(note.tags, contains('#工作/发布'));
    expect(
      note.blocks.any((block) => block.type == NoteBlockType.bulletList),
      isTrue,
    );
  });
}

Note _mixedNote() {
  return Note(
    id: 'portable-note',
    title: '发布复盘',
    content: '**稳定性** 优先 #开发/发布\n图片之后继续记录。',
    createdAt: DateTime.utc(2026, 7, 11, 8),
    updatedAt: DateTime.utc(2026, 7, 11, 9),
    images: const [
      NoteImage(
        id: 'diagram-image',
        name: 'diagram.png',
        mimeType: 'image/png',
        base64Data: 'AQID',
      ),
    ],
    coverImageId: 'diagram-image',
    blocks: const [
      NoteBlock(
        id: 'text-before',
        type: NoteBlockType.paragraph,
        text: '稳定性 优先 #开发/发布',
        marks: [NoteTextMark(type: NoteTextMarkType.bold, start: 0, end: 3)],
      ),
      NoteBlock(
        id: 'image-block',
        type: NoteBlockType.image,
        imageId: 'diagram-image',
        caption: '架构草图',
      ),
      NoteBlock(
        id: 'text-after',
        type: NoteBlockType.paragraph,
        text: '图片之后继续记录。',
      ),
    ],
    tags: const ['#开发/发布'],
  );
}
