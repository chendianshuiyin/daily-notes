import 'package:daily_notes/core/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'inserts a transcript at the captured cursor without replacing text',
    () {
      final edit = VoiceTranscriptUtil.insert(
        source: '前文后文',
        offset: 2,
        transcript: ' 语音内容 ',
      );

      expect(edit.text, '前文\n语音内容\n后文');
      expect(edit.cursorOffset, '前文\n语音内容\n'.length);
    },
  );

  test('reuses surrounding whitespace and clamps a stale cursor', () {
    final edit = VoiceTranscriptUtil.insert(
      source: '已有正文\n',
      offset: 999,
      transcript: '继续记录',
    );

    expect(edit.text, '已有正文\n继续记录');
    expect(edit.cursorOffset, edit.text.length);
  });

  test('keeps source unchanged for an empty transcript', () {
    final edit = VoiceTranscriptUtil.insert(
      source: '原文',
      offset: 1,
      transcript: '   ',
    );

    expect(edit.text, '原文');
    expect(edit.cursorOffset, 1);
  });
}
