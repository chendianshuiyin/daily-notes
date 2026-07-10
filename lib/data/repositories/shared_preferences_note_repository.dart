import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/repositories.dart';
import '../models/models.dart';

class SharedPreferencesNoteRepository implements NoteRepository {
  const SharedPreferencesNoteRepository();

  static const String _notesKey = 'daily_notes.notes';

  @override
  Future<List<Note>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_notesKey);

    if (rawValue == null || rawValue.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is! List) {
      return [];
    }

    final notes = <Note>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        notes.add(Note.fromJson(item));
      } else if (item is Map) {
        notes.add(Note.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final notes = await getNotes();
    for (final note in notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  @override
  Future<void> upsertNote(Note note) async {
    final notes = await getNotes();
    final index = notes.indexWhere((item) => item.id == note.id);

    if (index == -1) {
      notes.add(note);
    } else {
      notes[index] = note;
    }

    await _saveNotes(notes);
  }

  @override
  Future<void> deleteNote(String id) async {
    final notes = await getNotes();
    notes.removeWhere((note) => note.id == id);
    await _saveNotes(notes);
  }

  @override
  Future<void> archiveNote(String id, {required bool isArchived}) async {
    final notes = await getNotes();
    final index = notes.indexWhere((note) => note.id == id);

    if (index == -1) {
      return;
    }

    notes[index] = notes[index].copyWith(
      isArchived: isArchived,
      updatedAt: DateTime.now(),
    );
    await _saveNotes(notes);
  }

  @override
  Future<void> mergeNotes(List<Note> importedNotes) async {
    final existingNotes = await getNotes();
    final notesById = <String, Note>{
      for (final note in existingNotes) note.id: note,
    };

    for (final note in importedNotes) {
      notesById[note.id] = note;
    }

    await _saveNotes(notesById.values.toList());
  }

  Future<void> _saveNotes(List<Note> notes) async {
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(notes.map((note) => note.toJson()).toList());
    final didSave = await prefs.setString(_notesKey, encoded);
    if (!didSave) {
      throw StateError('Failed to persist notes');
    }
  }
}
