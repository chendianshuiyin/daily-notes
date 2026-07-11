import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/guid_util.dart';
import '../models/models.dart';
import 'note_backup_service.dart';

enum NoteExportFormat { markdownZip, dailyNotesJson }

class NoteImportBundle {
  const NoteImportBundle({required this.notes, required this.formatLabel});

  final List<Note> notes;
  final String formatLabel;
}

class NotePortabilityService {
  const NotePortabilityService();

  static const int maxImportBytes = 256 * 1024 * 1024;

  Future<Uint8List> export(List<Note> notes, NoteExportFormat format) {
    final payload = <String, Object?>{
      'format': format.name,
      'notes': notes.map((note) => note.toJson()).toList(),
    };
    return compute(_buildExport, payload);
  }

  Future<NoteImportBundle> inspectImport(String fileName, Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('所选文件为空。');
    }
    if (bytes.length > maxImportBytes) {
      throw const FormatException('导入文件超过 256 MB，请拆分后重试。');
    }
    return compute(_inspectImport, <String, Object?>{
      'fileName': fileName,
      'bytes': bytes,
    });
  }
}

Uint8List _buildExport(Map<String, Object?> payload) {
  final notes = (payload['notes'] as List)
      .map((item) => Note.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
  final format = NoteExportFormat.values.byName(payload['format'] as String);
  if (format == NoteExportFormat.dailyNotesJson) {
    return Uint8List.fromList(
      utf8.encode(const NoteBackupService().encode(notes)),
    );
  }

  final archive = Archive();
  archive.add(
    ArchiveFile.string(
      'README.md',
      '# Daily Notes export\n\n'
          'Notes are stored as UTF-8 Markdown under `notes/`. Images are under `media/`. '
          'YAML front matter preserves Daily Notes metadata for re-import.\n',
    ),
  );
  final usedNoteNames = <String>{};
  for (final note in notes) {
    final noteFolder = _safeName(note.id, fallback: 'note');
    final baseName = _safeName(
      note.title.trim().isEmpty ? _firstText(note) : note.title,
      fallback: 'untitled',
    );
    var noteName = '${_dateStamp(note.createdAt)}-$baseName';
    var suffix = 2;
    while (!usedNoteNames.add(noteName.toLowerCase())) {
      noteName = '${_dateStamp(note.createdAt)}-$baseName-$suffix';
      suffix++;
    }
    final imageNames = <String, String>{};
    final usedImageNames = <String>{};
    for (final image in note.images) {
      var imageName = _imageFileName(image);
      var imageSuffix = 2;
      while (!usedImageNames.add(imageName.toLowerCase())) {
        final extension = p.extension(imageName);
        final stem = p.basenameWithoutExtension(imageName);
        imageName = '$stem-$imageSuffix$extension';
        imageSuffix++;
      }
      imageNames[image.id] = imageName;
    }
    final markdown = _exportNoteMarkdown(note, noteFolder, imageNames);
    archive.add(ArchiveFile.string('notes/$noteName.md', markdown));
    for (final image in note.images) {
      final imageName = imageNames[image.id]!;
      archive.add(
        ArchiveFile.bytes('media/$noteFolder/$imageName', image.bytes),
      );
    }
  }
  return ZipEncoder().encodeBytes(archive);
}

String _exportNoteMarkdown(
  Note note,
  String noteFolder,
  Map<String, String> imageNames,
) {
  final lines = <String>[
    '---',
    'daily_notes_id: ${jsonEncode(note.id)}',
    'title: ${jsonEncode(note.title)}',
    'created: ${jsonEncode(note.createdAt.toIso8601String())}',
    'updated: ${jsonEncode(note.updatedAt.toIso8601String())}',
    'archived: ${note.isArchived}',
    'tags: ${jsonEncode(note.tags)}',
    '---',
    '',
  ];
  if (note.title.trim().isNotEmpty) {
    lines.add('# ${note.title.trim()}');
    lines.add('');
  }
  final imageById = {for (final image in note.images) image.id: image};
  for (final block in note.blocks) {
    if (block.type == NoteBlockType.image) {
      final image = imageById[block.imageId];
      if (image != null) {
        final imageName = imageNames[image.id]!;
        lines.add(
          '![${_escapeMarkdownLabel(block.caption)}](../media/$noteFolder/${Uri.encodeComponent(imageName)})',
        );
      }
    } else {
      lines.add(_blockMarkdown(block));
    }
    lines.add('');
  }
  return '${lines.join('\n').trimRight()}\n';
}

String _blockMarkdown(NoteBlock block) {
  final text = _applyMarks(block.text, block.marks);
  return switch (block.type) {
    NoteBlockType.heading =>
      '${List.filled(block.level.clamp(1, 3), '#').join()} $text',
    NoteBlockType.bulletList =>
      '${List.filled(block.indent, '  ').join()}- $text',
    NoteBlockType.numberList =>
      '${List.filled(block.indent, '  ').join()}1. $text',
    NoteBlockType.quote => '> $text',
    NoteBlockType.code => '```\n${block.text}\n```',
    NoteBlockType.divider => '---',
    NoteBlockType.paragraph => text,
    NoteBlockType.image => '',
  };
}

String _applyMarks(String source, List<NoteTextMark> marks) {
  var result = source;
  final valid =
      marks
          .where((mark) => mark.start >= 0 && mark.end <= source.length)
          .toList()
        ..sort((a, b) {
          final byStart = b.start.compareTo(a.start);
          return byStart != 0 ? byStart : a.end.compareTo(b.end);
        });
  for (final mark in valid) {
    final (open, close) = switch (mark.type) {
      NoteTextMarkType.bold => ('**', '**'),
      NoteTextMarkType.italic => ('*', '*'),
      NoteTextMarkType.underline => ('<u>', '</u>'),
      NoteTextMarkType.strike => ('~~', '~~'),
      NoteTextMarkType.highlight => ('==', '=='),
      NoteTextMarkType.code => ('`', '`'),
      NoteTextMarkType.link => ('[', '](${mark.value ?? ''})'),
    };
    result = result.replaceRange(mark.end, mark.end, close);
    result = result.replaceRange(mark.start, mark.start, open);
  }
  return result;
}

NoteImportBundle _inspectImport(Map<String, Object?> payload) {
  final fileName = payload['fileName'] as String;
  final bytes = payload['bytes'] as Uint8List;
  final extension = p.extension(fileName).toLowerCase();
  return switch (extension) {
    '.json' => _importJson(bytes),
    '.md' || '.markdown' => NoteImportBundle(
      notes: [_importMarkdown(fileName, utf8.decode(bytes))],
      formatLabel: 'Markdown',
    ),
    '.zip' => _importMarkdownZip(bytes),
    _ => throw const FormatException('仅支持 .zip、.md、.markdown 或 .json 文件。'),
  };
}

NoteImportBundle _importJson(Uint8List bytes) {
  final backup = const NoteBackupService().decode(utf8.decode(bytes));
  return NoteImportBundle(notes: backup.notes, formatLabel: 'Daily Notes JSON');
}

NoteImportBundle _importMarkdownZip(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  if (archive.length > 20000) {
    throw const FormatException('ZIP 文件条目过多，已停止导入。');
  }
  var totalSize = 0;
  final files = <String, ArchiveFile>{};
  for (final entry in archive) {
    if (!entry.isFile || entry.isSymbolicLink) continue;
    totalSize += entry.size;
    if (totalSize > 512 * 1024 * 1024) {
      throw const FormatException('ZIP 解压后超过 512 MB，已停止导入。');
    }
    final normalized = p.posix.normalize(entry.name.replaceAll('\\', '/'));
    if (normalized == '..' || normalized.startsWith('../')) {
      throw const FormatException('ZIP 包含不安全的文件路径。');
    }
    files[normalized] = entry;
  }

  final markdownFiles =
      files.entries
          .where(
            (entry) =>
                p.extension(entry.key).toLowerCase() == '.md' &&
                p.basename(entry.key).toLowerCase() != 'readme.md',
          )
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  if (markdownFiles.isEmpty) {
    throw const FormatException('ZIP 中没有可导入的 Markdown 笔记。');
  }
  if (markdownFiles.length > 10000) {
    throw const FormatException('ZIP 中的 Markdown 笔记超过 10000 条，请拆分导入。');
  }

  final notes = <Note>[];
  final ids = <String>{};
  for (final entry in markdownFiles) {
    var note = _importMarkdown(
      entry.key,
      utf8.decode(entry.value.content),
      archiveFiles: files,
    );
    if (!ids.add(note.id)) {
      note = note.copyWith(id: GuidUtil.generate());
      ids.add(note.id);
    }
    notes.add(note);
  }
  return NoteImportBundle(
    notes: List.unmodifiable(notes),
    formatLabel: 'Markdown ZIP',
  );
}

Note _importMarkdown(
  String fileName,
  String markdown, {
  Map<String, ArchiveFile> archiveFiles = const {},
}) {
  final normalized = markdown.replaceAll('\r\n', '\n');
  final frontMatter = _readFrontMatter(normalized);
  var body = frontMatter.body;
  var title = frontMatter.stringValue('title') ?? '';
  if (title.trim().isEmpty) {
    final heading = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(body);
    if (heading != null) {
      title = heading.group(1)!.trim();
      body = body.replaceRange(heading.start, heading.end, '').trimLeft();
    } else {
      title = p.basenameWithoutExtension(fileName);
    }
  } else {
    final firstHeading = RegExp(r'^#\s+(.+)\n?').firstMatch(body);
    if (firstHeading != null && firstHeading.group(1)!.trim() == title.trim()) {
      body = body.substring(firstHeading.end).trimLeft();
    }
  }

  final now = DateTime.now();
  final images = <NoteImage>[];
  final blocks = <NoteBlock>[];
  final textLines = <String>[];

  void flushText() {
    if (textLines.isEmpty) return;
    final document = const NoteMarkdownCodec().decode(textLines.join('\n'));
    for (final block in document.blocks) {
      blocks.add(
        NoteBlock(
          id: GuidUtil.generate(),
          type: block.type,
          text: block.text,
          level: block.level,
          indent: block.indent,
          marks: block.marks,
        ),
      );
    }
    textLines.clear();
  }

  final imagePattern = RegExp(r'^!\[(.*)\]\(([^)]+)\)\s*$');
  for (final line in body.split('\n')) {
    final match = imagePattern.firstMatch(line.trim());
    if (match == null || archiveFiles.isEmpty) {
      textLines.add(line);
      continue;
    }
    final rawLink = Uri.decodeComponent(match.group(2)!);
    if (Uri.tryParse(rawLink)?.hasScheme == true) {
      textLines.add(line);
      continue;
    }
    final resolved = p.posix.normalize(
      p.posix.join(p.posix.dirname(fileName), rawLink),
    );
    final entry = archiveFiles[resolved];
    final mimeType = _mimeForExtension(p.extension(resolved));
    if (entry == null || mimeType == null) {
      textLines.add(line);
      continue;
    }
    flushText();
    final image = NoteImage(
      id: GuidUtil.generate(),
      name: p.posix.basename(resolved),
      mimeType: mimeType,
      base64Data: base64Encode(entry.content),
    );
    images.add(image);
    blocks.add(
      NoteBlock(
        id: GuidUtil.generate(),
        type: NoteBlockType.image,
        imageId: image.id,
        caption: match.group(1) ?? '',
      ),
    );
  }
  flushText();
  final content = NoteDocument(blocks).toTextShadow().trim();
  final tags = frontMatter.stringListValue('tags');
  return Note(
    id: frontMatter.stringValue('daily_notes_id') ?? GuidUtil.generate(),
    title: title.trim(),
    content: content,
    createdAt: frontMatter.dateValue('created') ?? now,
    updatedAt: frontMatter.dateValue('updated') ?? now,
    isArchived: frontMatter.boolValue('archived') ?? false,
    images: List.unmodifiable(images),
    blocks: List.unmodifiable(blocks),
    tags: Note.normalizeTags([...tags, ...Note.extractTags(body)]),
  );
}

_FrontMatter _readFrontMatter(String markdown) {
  if (!markdown.startsWith('---\n')) {
    return _FrontMatter(const {}, markdown);
  }
  final end = markdown.indexOf('\n---\n', 4);
  if (end == -1) {
    return _FrontMatter(const {}, markdown);
  }
  final values = <String, String>{};
  for (final line in markdown.substring(4, end).split('\n')) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    values[line.substring(0, separator).trim()] = line
        .substring(separator + 1)
        .trim();
  }
  return _FrontMatter(values, markdown.substring(end + 5).trimLeft());
}

class _FrontMatter {
  const _FrontMatter(this.values, this.body);

  final Map<String, String> values;
  final String body;

  String? stringValue(String key) {
    final value = values[key];
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is String ? decoded : value;
    } on FormatException {
      return value;
    }
  }

  List<String> stringListValue(String key) {
    final value = values[key];
    if (value == null || value.isEmpty) return const [];
    try {
      return (jsonDecode(value) as List).whereType<String>().toList();
    } catch (_) {
      return value.split(',').map((item) => item.trim()).toList();
    }
  }

  DateTime? dateValue(String key) {
    final value = stringValue(key);
    return value == null ? null : DateTime.tryParse(value);
  }

  bool? boolValue(String key) {
    return switch (values[key]) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }
}

String _firstText(Note note) {
  for (final block in note.blocks) {
    if (block.isText && block.text.trim().isNotEmpty) {
      return block.text.trim();
    }
  }
  return 'untitled';
}

String _safeName(
  String source, {
  required String fallback,
  bool keepExtension = false,
}) {
  final extension = keepExtension ? p.extension(source) : '';
  final stem = keepExtension ? p.basenameWithoutExtension(source) : source;
  final normalized = stem
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[. -]+|[. -]+$'), '')
      .toLowerCase();
  final value = normalized.isEmpty ? fallback : normalized;
  final bounded = value.length > 72 ? value.substring(0, 72) : value;
  return '$bounded$extension';
}

String _dateStamp(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _escapeMarkdownLabel(String value) {
  return value.replaceAll('\\', '\\\\').replaceAll(']', '\\]');
}

String _extensionForMime(String mimeType) {
  return switch (mimeType.toLowerCase()) {
    'image/jpeg' => 'jpg',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/bmp' => 'bmp',
    _ => 'png',
  };
}

String _imageFileName(NoteImage image) {
  final source = p.extension(image.name).isEmpty
      ? '${image.name}.${_extensionForMime(image.mimeType)}'
      : image.name;
  return _safeName(
    source,
    fallback: '${image.id}.${_extensionForMime(image.mimeType)}',
    keepExtension: true,
  );
}

String? _mimeForExtension(String extension) {
  return switch (extension.toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.bmp' => 'image/bmp',
    _ => null,
  };
}
