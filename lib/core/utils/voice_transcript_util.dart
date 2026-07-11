class VoiceTranscriptEdit {
  const VoiceTranscriptEdit({required this.text, required this.cursorOffset});

  final String text;
  final int cursorOffset;
}

abstract final class VoiceTranscriptUtil {
  static VoiceTranscriptEdit insert({
    required String source,
    required int offset,
    required String transcript,
  }) {
    final words = transcript.trim();
    final insertionOffset = offset.clamp(0, source.length);
    if (words.isEmpty) {
      return VoiceTranscriptEdit(text: source, cursorOffset: insertionOffset);
    }

    final before = source.substring(0, insertionOffset);
    final after = source.substring(insertionOffset);
    final leading = before.isEmpty || RegExp(r'\s$').hasMatch(before)
        ? ''
        : '\n';
    final trailing = after.isEmpty || RegExp(r'^\s').hasMatch(after)
        ? ''
        : '\n';
    final insertion = '$leading$words$trailing';
    return VoiceTranscriptEdit(
      text: source.replaceRange(insertionOffset, insertionOffset, insertion),
      cursorOffset: insertionOffset + insertion.length,
    );
  }
}
