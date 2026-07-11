import '../models/models.dart';

class TagSuggestion {
  const TagSuggestion({
    required this.tag,
    required this.reason,
    required this.score,
  });

  final String tag;
  final String reason;
  final int score;
}

/// Provides private, deterministic organization suggestions without networking.
class LocalAiOrganizer {
  const LocalAiOrganizer();

  List<TagSuggestion> suggestTags({
    required String title,
    required String content,
    required Iterable<Note> notes,
    String? currentNoteId,
    int limit = 3,
  }) {
    final source = '$title\n$content'.trim();
    if (source.isEmpty || limit <= 0) {
      return const [];
    }
    final currentTags = Note.extractTags(
      source,
    ).map((tag) => tag.toLowerCase()).toSet();
    final sourceTerms = _terms(source);
    final scores = <String, int>{};
    final labels = <String, String>{};
    final relatedCounts = <String, int>{};
    final directMatches = <String>{};

    for (final note in notes) {
      if (note.id == currentNoteId || note.isArchived || note.tags.isEmpty) {
        continue;
      }
      final overlap = sourceTerms
          .intersection(_terms('${note.title}\n${note.content}'))
          .length;
      for (final tag in note.tags) {
        final key = tag.toLowerCase();
        if (currentTags.contains(key)) {
          continue;
        }
        labels.putIfAbsent(key, () => tag);
        final tagName = tag.substring(1).replaceAll('/', ' ');
        final isDirectMatch = _containsMeaningful(source, tagName);
        if (overlap == 0 && !isDirectMatch) {
          continue;
        }
        scores.update(
          key,
          (score) => score + overlap * 3 + (isDirectMatch ? 8 : 0),
          ifAbsent: () => overlap * 3 + (isDirectMatch ? 8 : 0),
        );
        if (overlap > 0) {
          relatedCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
        }
        if (isDirectMatch) {
          directMatches.add(key);
        }
      }
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) {
        final scoreOrder = b.value.compareTo(a.value);
        return scoreOrder != 0
            ? scoreOrder
            : labels[a.key]!.compareTo(labels[b.key]!);
      });
    return List.unmodifiable(
      ranked.take(limit).map((entry) {
        final relatedCount = relatedCounts[entry.key] ?? 0;
        final reason = directMatches.contains(entry.key)
            ? '正文提到了这个主题'
            : '与 $relatedCount 条相关笔记共同出现';
        return TagSuggestion(
          tag: labels[entry.key]!,
          reason: reason,
          score: entry.value,
        );
      }),
    );
  }

  bool _containsMeaningful(String source, String value) {
    final normalizedSource = source.toLowerCase();
    return value
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((part) => part.length >= 2)
        .any(normalizedSource.contains);
  }

  Set<String> _terms(String source) {
    final terms = <String>{};
    for (final match in RegExp(
      r'[A-Za-z0-9]+|[\u4e00-\u9fff]+',
    ).allMatches(source.toLowerCase())) {
      final value = match.group(0)!;
      if (RegExp(r'^[\u4e00-\u9fff]+$').hasMatch(value)) {
        if (value.length == 1) {
          terms.add(value);
        } else {
          for (var index = 0; index < value.length - 1; index++) {
            terms.add(value.substring(index, index + 2));
          }
        }
      } else if (value.length >= 2) {
        terms.add(value);
      }
    }
    return terms;
  }
}
