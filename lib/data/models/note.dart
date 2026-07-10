import 'note_image.dart';

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.images = const [],
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final List<NoteImage> images;

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

  List<String> get tags {
    final matches = RegExp(
      r'#[^\s#，。,.!?！？；;：:]+',
    ).allMatches('$title $content');
    return matches.map((match) => match.group(0)!).toSet().toList();
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    List<NoteImage>? images,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      images: images ?? this.images,
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
}
