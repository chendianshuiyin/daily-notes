import 'note_image.dart';

enum NoteBlockType {
  paragraph,
  heading,
  bulletList,
  numberList,
  quote,
  code,
  image,
  divider,
}

enum NoteTextMarkType { bold, italic, underline, strike, highlight, code, link }

class NoteTextMark {
  const NoteTextMark({
    required this.type,
    required this.start,
    required this.end,
    this.value,
  });

  final NoteTextMarkType type;
  final int start;
  final int end;
  final String? value;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'start': start,
    'end': end,
    if (value != null) 'value': value,
  };

  factory NoteTextMark.fromJson(Map<String, dynamic> json) {
    final type = NoteTextMarkType.values.asNameMap()[json['type']];
    final start = json['start'];
    final end = json['end'];
    final value = json['value'];
    if (type == null ||
        start is! int ||
        end is! int ||
        start < 0 ||
        end < start) {
      throw const FormatException('Invalid note text mark.');
    }
    if (value != null && value is! String) {
      throw const FormatException('Invalid note text mark value.');
    }
    return NoteTextMark(
      type: type,
      start: start,
      end: end,
      value: value as String?,
    );
  }
}

class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.imageId,
    this.caption = '',
    this.level = 0,
    this.indent = 0,
    this.marks = const [],
  });

  final String id;
  final NoteBlockType type;
  final String text;
  final String? imageId;
  final String caption;
  final int level;
  final int indent;
  final List<NoteTextMark> marks;

  bool get isText =>
      type != NoteBlockType.image && type != NoteBlockType.divider;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    if (text.isNotEmpty) 'text': text,
    if (imageId != null) 'imageId': imageId,
    if (caption.isNotEmpty) 'caption': caption,
    if (level != 0) 'level': level,
    if (indent != 0) 'indent': indent,
    if (marks.isNotEmpty) 'marks': marks.map((mark) => mark.toJson()).toList(),
  };

  factory NoteBlock.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = NoteBlockType.values.asNameMap()[json['type']];
    final text = json['text'] ?? '';
    final imageId = json['imageId'];
    final caption = json['caption'] ?? '';
    final level = json['level'] ?? 0;
    final indent = json['indent'] ?? 0;
    final rawMarks = json['marks'] ?? const [];
    if (id is! String || id.trim().isEmpty || type == null) {
      throw const FormatException('Invalid note block identity.');
    }
    if (text is! String ||
        caption is! String ||
        level is! int ||
        indent is! int) {
      throw const FormatException('Invalid note block content.');
    }
    if (imageId != null && imageId is! String) {
      throw const FormatException('Invalid note image block reference.');
    }
    if (type == NoteBlockType.image &&
        (imageId is! String || imageId.trim().isEmpty)) {
      throw const FormatException('Image blocks require an image reference.');
    }
    if (rawMarks is! List || rawMarks.any((mark) => mark is! Map)) {
      throw const FormatException('Invalid note block marks.');
    }
    final marks = rawMarks
        .map(
          (mark) =>
              NoteTextMark.fromJson(Map<String, dynamic>.from(mark as Map)),
        )
        .toList();
    if (marks.any((mark) => mark.end > text.length)) {
      throw const FormatException('Note text mark is outside block text.');
    }
    return NoteBlock(
      id: id,
      type: type,
      text: text,
      imageId: imageId as String?,
      caption: caption,
      level: level,
      indent: indent,
      marks: List.unmodifiable(marks),
    );
  }
}

class NoteDocument {
  const NoteDocument(this.blocks);

  static const int contentVersion = 2;

  final List<NoteBlock> blocks;

  factory NoteDocument.fromLegacy({
    required String content,
    required List<NoteImage> images,
  }) {
    final blocks = <NoteBlock>[];
    if (content.isNotEmpty) {
      blocks.add(
        NoteBlock(
          id: 'legacy-text-0',
          type: NoteBlockType.paragraph,
          text: content,
        ),
      );
    }
    for (final image in images) {
      blocks.add(
        NoteBlock(
          id: 'legacy-image-${image.id}',
          type: NoteBlockType.image,
          imageId: image.id,
        ),
      );
    }
    return NoteDocument(List.unmodifiable(blocks));
  }

  String toTextShadow() {
    return blocks
        .where((block) => block.type != NoteBlockType.image)
        .map(_blockText)
        .join('\n');
  }

  static String _blockText(NoteBlock block) {
    return switch (block.type) {
      NoteBlockType.heading =>
        '${List.filled(block.level.clamp(1, 3), '#').join()} ${block.text}',
      NoteBlockType.bulletList =>
        '${List.filled(block.indent, '  ').join()}- ${block.text}',
      NoteBlockType.numberList =>
        '${List.filled(block.indent, '  ').join()}1. ${block.text}',
      NoteBlockType.quote => '> ${block.text}',
      NoteBlockType.code => '```\n${block.text}\n```',
      NoteBlockType.divider => '---',
      NoteBlockType.paragraph => block.text,
      NoteBlockType.image => '',
    };
  }
}
