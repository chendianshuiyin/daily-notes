import 'package:flutter/foundation.dart';

import '../../core/utils/utils.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/services.dart';
import '../../domain/repositories/repositories.dart';

class NoteProvider extends ChangeNotifier {
  NoteProvider({NoteRepository? repository})
    : _repository = repository ?? HiveNoteRepository();

  final NoteRepository _repository;
  final NoteBackupService _backupService = const NoteBackupService();

  List<Note> _notes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Note> get notes => List.unmodifiable(_notes);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  List<Note> get activeNotes {
    return _notes.where((note) => !note.isArchived).toList();
  }

  List<Note> get archivedNotes {
    return _notes.where((note) => note.isArchived).toList();
  }

  List<Note> get todayNotes {
    final today = DateTime.now();
    return activeNotes
        .where((note) => DateUtil.isSameDay(note.createdAt, today))
        .toList();
  }

  Map<DateTime, int> get activityByDay {
    final activity = <DateTime, int>{};
    for (final note in _notes) {
      final day = DateTime(
        note.createdAt.year,
        note.createdAt.month,
        note.createdAt.day,
      );
      activity.update(day, (count) => count + 1, ifAbsent: () => 1);
    }
    return Map.unmodifiable(activity);
  }

  int get currentStreak {
    final activeDays = activityByDay.keys.toSet();
    if (activeDays.isEmpty) {
      return 0;
    }

    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!activeDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<Note> notesForDay(DateTime day) {
    return _notes
        .where((note) => DateUtil.isSameDay(note.createdAt, day))
        .toList();
  }

  Future<void> loadNotes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notes = await _repository.getNotes();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Note? noteById(String id) {
    for (final note in _notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  Future<Note?> ensureNoteById(String id) async {
    return noteById(id) ?? _repository.getNoteById(id);
  }

  List<Note> searchNotes(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return notes;
    }

    return notes.where((note) {
      return note.title.toLowerCase().contains(normalized) ||
          note.content.toLowerCase().contains(normalized) ||
          note.tags.any((tag) => tag.toLowerCase().contains(normalized));
    }).toList();
  }

  Future<Note> saveNote({
    String? id,
    required String title,
    required String content,
    List<NoteImage>? images,
    List<String>? tags,
  }) async {
    final now = DateTime.now();
    final existing = id == null ? null : await ensureNoteById(id);
    final note = Note(
      id: existing?.id ?? GuidUtil.generate(),
      title: title.trim(),
      content: content.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isArchived: existing?.isArchived ?? false,
      images: images ?? existing?.images ?? const [],
      tags: tags ?? existing?.tags ?? const [],
    );

    await _repository.upsertNote(note);
    await loadNotes();
    return note;
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    await loadNotes();
  }

  Future<void> archiveNote(String id, {required bool isArchived}) async {
    await _repository.archiveNote(id, isArchived: isArchived);
    await loadNotes();
  }

  String createBackup() {
    return _backupService.encode(_notes);
  }

  NoteBackup inspectBackup(String source) {
    return _backupService.decode(source);
  }

  Future<void> restoreBackup(NoteBackup backup) async {
    await _repository.mergeNotes(backup.notes);
    await loadNotes();
  }
}
