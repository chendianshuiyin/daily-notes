import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../domain/repositories/repositories.dart';
import '../models/models.dart';
import 'shared_preferences_note_repository.dart';

class HiveNoteRepository implements NoteRepository {
  HiveNoteRepository({
    Future<Box<dynamic>> Function()? openBox,
    NoteRepository? legacyRepository,
  }) : _openBox = openBox ?? _openDefaultBox,
       _legacyRepository =
           legacyRepository ?? const SharedPreferencesNoteRepository();

  static const String boxName = 'daily_notes.notes';
  static const String _migrationKey = 'meta:shared_preferences_migrated';
  static const String _noteKeyPrefix = 'note:';

  final Future<Box<dynamic>> Function() _openBox;
  final NoteRepository _legacyRepository;
  Box<dynamic>? _box;

  static Future<Box<dynamic>> _openDefaultBox() async {
    await Hive.initFlutter();
    return Hive.openBox<dynamic>(boxName);
  }

  Future<Box<dynamic>> _getBox() async {
    final box = _box ??= await _openBox();
    await _migrateLegacyNotes(box);
    return box;
  }

  Future<void> _migrateLegacyNotes(Box<dynamic> box) async {
    if (box.get(_migrationKey) == true) {
      return;
    }

    final legacyNotes = await _legacyRepository.getNotes();
    if (legacyNotes.isNotEmpty) {
      await box.putAll({
        for (final note in legacyNotes) _noteKey(note.id): _encodeNote(note),
      });
    }
    await box.put(_migrationKey, true);
  }

  @override
  Future<List<Note>> getNotes() async {
    final box = await _getBox();
    final notes = <Note>[];

    for (final entry in box.toMap().entries) {
      if (entry.key case final String key when key.startsWith(_noteKeyPrefix)) {
        notes.add(_decodeNote(entry.value));
      }
    }

    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final box = await _getBox();
    final value = box.get(_noteKey(id));
    return value == null ? null : _decodeNote(value);
  }

  @override
  Future<void> upsertNote(Note note) async {
    final box = await _getBox();
    await box.put(_noteKey(note.id), _encodeNote(note));
  }

  @override
  Future<void> deleteNote(String id) async {
    final box = await _getBox();
    await box.delete(_noteKey(id));
  }

  @override
  Future<void> archiveNote(String id, {required bool isArchived}) async {
    final box = await _getBox();
    final key = _noteKey(id);
    final value = box.get(key);
    if (value == null) {
      return;
    }

    final note = _decodeNote(
      value,
    ).copyWith(isArchived: isArchived, updatedAt: DateTime.now());
    await box.put(key, _encodeNote(note));
  }

  @override
  Future<void> mergeNotes(List<Note> notes) async {
    final box = await _getBox();
    await box.putAll({
      for (final note in notes) _noteKey(note.id): _encodeNote(note),
    });
  }

  static String _noteKey(String id) => '$_noteKeyPrefix$id';

  static String _encodeNote(Note note) => jsonEncode(note.toJson());

  static Note _decodeNote(Object? value) {
    if (value is! String) {
      throw const FormatException('Stored note is not valid JSON text.');
    }
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Stored note is not a JSON object.');
    }
    return Note.fromJson(Map<String, dynamic>.from(decoded));
  }
}
