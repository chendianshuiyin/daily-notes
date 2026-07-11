import 'note_image.dart';
import 'note_block.dart';

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.images = const [],
    List<NoteBlock> blocks = const [],
    List<String> tags = const [],
  }) : _blocks = blocks,
       _tags = tags;

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final List<NoteImage> images;
  final List<NoteBlock> _blocks;
  final List<String> _tags;

  List<NoteBlock> get blocks {
    if (_blocks.isNotEmpty) {
      return List.unmodifiable(_blocks);
    }
    return NoteDocument.fromLegacy(content: content, images: images).blocks;
  }

  String get displayTitle {
    final value = title.trim();
    return value.isEmpty ? '未命名笔记' : value;
  }

  String get preview {
    final text = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isNotEmpty) {
      return text;
    }
    return images.isEmpty ? '' : '${images.length} 张图片';
  }

  bool get hasBody =>
      title.trim().isNotEmpty || content.trim().isNotEmpty || images.isNotEmpty;

  List<String> get tags =>
      normalizeTags([..._tags, ...extractTags('$title $content')]);

  static List<String> extractTags(String source) {
    final matches = RegExp(r'#[^\s#，。,.!?！？；;：:]+').allMatches(source);
    return matches.map((match) => match.group(0)!).toList();
  }

  static List<String> normalizeTags(Iterable<String> values) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final withoutMarker = value.trim().replaceFirst(RegExp(r'^#+'), '');
      final name = withoutMarker.replaceAll(RegExp(r'[\s#，。,.!?！？；;：:]+'), '');
      if (name.isEmpty) {
        continue;
      }
      final tag = '#$name';
      final key = tag.toLowerCase();
      if (seen.add(key)) {
        normalized.add(tag);
      }
    }
    return List.unmodifiable(normalized);
  }

  static List<String> expandTagHierarchy(Iterable<String> values) {
    final expanded = <String>[];
    final seen = <String>{};
    for (final tag in normalizeTags(values)) {
      final segments = tag.substring(1).split('/');
      for (var depth = 1; depth <= segments.length; depth++) {
        final ancestor = '#${segments.take(depth).join('/')}';
        if (seen.add(ancestor.toLowerCase())) {
          expanded.add(ancestor);
        }
      }
    }
    return List.unmodifiable(expanded);
  }

  static bool matchesTag(Iterable<String> values, String selectedTag) {
    final normalized = normalizeTags([selectedTag]);
    if (normalized.isEmpty) {
      return false;
    }
    final selected = normalized.single.toLowerCase();
    return normalizeTags(values).any((tag) {
      final candidate = tag.toLowerCase();
      return candidate == selected || candidate.startsWith('$selected/');
    });
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    List<NoteImage>? images,
    List<NoteBlock>? blocks,
    List<String>? tags,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      images: images ?? this.images,
      blocks: blocks ?? _blocks,
      tags: tags ?? _tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isArchived': isArchived,
      'images': images.map((image) => image.toJson()).toList(),
      'contentVersion': NoteDocument.contentVersion,
      'blocks': blocks.map((block) => block.toJson()).toList(),
      'tags': tags,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
      isArchived: json['isArchived'] as bool? ?? false,
      images: _readImages(json['images']),
      blocks: _readBlocks(json['blocks']),
      tags: _readTags(json['tags']),
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static List<NoteImage> _readImages(Object? value) {
    if (value is! List) {
      return const [];
    }

    final images = <NoteImage>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      try {
        images.add(NoteImage.fromJson(Map<String, dynamic>.from(item)));
      } on FormatException {
        // Keep the note readable when a single legacy attachment is damaged.
      }
    }
    return List.unmodifiable(images);
  }

  static List<String> _readTags(Object? value) {
    if (value is! List) {
      return const [];
    }
    return normalizeTags(value.whereType<String>());
  }

  static List<NoteBlock> _readBlocks(Object? value) {
    if (value is! List) {
      return const [];
    }
    final blocks = <NoteBlock>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      try {
        blocks.add(NoteBlock.fromJson(Map<String, dynamic>.from(item)));
      } on FormatException {
        return const [];
      }
    }
    return List.unmodifiable(blocks);
  }
}
