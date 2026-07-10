import 'dart:convert';

import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = NoteBackupService();

  test('round-trips note content and metadata', () {
    final note = Note(
      id: 'note-1',
      title: '备份测试',
      content: '需要完整恢复的正文',
      createdAt: DateTime.utc(2026, 7, 9, 8),
      updatedAt: DateTime.utc(2026, 7, 10, 9),
      isArchived: true,
      images: [
        NoteImage(
          id: 'image-1',
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
          base64Data: base64Encode([1, 2, 3]),
        ),
      ],
    );
    final exportedAt = DateTime.utc(2026, 7, 10, 10);

    final encoded = service.encode([note], exportedAt: exportedAt);
    final backup = service.decode(encoded);

    expect(backup.exportedAt, exportedAt);
    expect(backup.notes, hasLength(1));
    expect(backup.notes.single.id, note.id);
    expect(backup.notes.single.title, note.title);
    expect(backup.notes.single.content, note.content);
    expect(backup.notes.single.createdAt, note.createdAt);
    expect(backup.notes.single.updatedAt, note.updatedAt);
    expect(backup.notes.single.isArchived, isTrue);
    expect(backup.notes.single.images.single.name, 'photo.jpg');
  });

  test('rejects unsupported backup formats', () {
    final encoded = jsonEncode({
      'format': 'another_app',
      'version': 1,
      'exportedAt': DateTime.utc(2026, 7, 10).toIso8601String(),
      'notes': <Object>[],
    });

    expect(() => service.decode(encoded), throwsFormatException);
  });

  test('rejects duplicate note IDs', () {
    final note = Note(
      id: 'duplicate-id',
      title: '重复',
      content: '',
      createdAt: DateTime.utc(2026, 7, 10),
      updatedAt: DateTime.utc(2026, 7, 10),
    );
    final encoded = service.encode([note, note]);

    expect(() => service.decode(encoded), throwsFormatException);
  });
}
