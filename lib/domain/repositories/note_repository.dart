import '../../data/models/models.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotes();

  Future<Note?> getNoteById(String id);

  Future<void> upsertNote(Note note);

  Future<void> deleteNote(String id);

  Future<void> archiveNote(String id, {required bool isArchived});
}
