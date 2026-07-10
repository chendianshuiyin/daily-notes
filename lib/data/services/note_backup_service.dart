import 'dart:convert';

import '../models/models.dart';

class NoteBackup {
  const NoteBackup({required this.exportedAt, required this.notes});

  final DateTime exportedAt;
  final List<Note> notes;
}

class NoteBackupService {
  const NoteBackupService();

  static const String format = 'daily_notes_backup';
  static const int version = 1;

  String encode(Iterable<Note> notes, {DateTime? exportedAt}) {
    return jsonEncode({
      'format': format,
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'notes': notes.map((note) => note.toJson()).toList(),
    });
  }

  NoteBackup decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('剪贴板内容不是有效的 Daily Notes 备份。');
    }

    if (decoded is! Map) {
      throw const FormatException('备份根节点格式不正确。');
    }

    final root = Map<String, dynamic>.from(decoded);
    if (root['format'] != format || root['version'] != version) {
      throw const FormatException('备份格式或版本不受支持。');
    }

    final exportedAt = _readDate(root['exportedAt'], 'exportedAt');
    final rawNotes = root['notes'];
    if (rawNotes is! List) {
      throw const FormatException('备份中缺少笔记列表。');
    }

    final notes = <Note>[];
    final ids = <String>{};
    for (var index = 0; index < rawNotes.length; index++) {
      final note = _readNote(rawNotes[index], index);
      if (!ids.add(note.id)) {
        throw FormatException('备份中包含重复的笔记 ID：${note.id}。');
      }
      notes.add(note);
    }

    return NoteBackup(exportedAt: exportedAt, notes: List.unmodifiable(notes));
  }

  Note _readNote(Object? value, int index) {
    if (value is! Map) {
      throw FormatException('第 ${index + 1} 条笔记格式不正确。');
    }

    final map = Map<String, dynamic>.from(value);
    final id = map['id'];
    final title = map['title'];
    final content = map['content'];
    final isArchived = map['isArchived'];

    if (id is! String || id.trim().isEmpty) {
      throw FormatException('第 ${index + 1} 条笔记缺少有效 ID。');
    }
    if (title is! String || content is! String) {
      throw FormatException('第 ${index + 1} 条笔记的文本字段无效。');
    }
    if (isArchived is! bool) {
      throw FormatException('第 ${index + 1} 条笔记的归档状态无效。');
    }

    return Note(
      id: id,
      title: title,
      content: content,
      createdAt: _readDate(map['createdAt'], 'createdAt', index: index),
      updatedAt: _readDate(map['updatedAt'], 'updatedAt', index: index),
      isArchived: isArchived,
    );
  }

  DateTime _readDate(Object? value, String fieldName, {int? index}) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) {
      final prefix = index == null ? '备份' : '第 ${index + 1} 条笔记';
      throw FormatException('$prefix 的 $fieldName 时间无效。');
    }
    return parsed;
  }
}
