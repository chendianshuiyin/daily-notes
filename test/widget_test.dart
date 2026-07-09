import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_notes/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyNotesApp());
    await tester.pumpAndSettle();

    expect(find.text('Daily Notes'), findsOneWidget);
  });

  testWidgets('Creates and lists a note', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyNotesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('noteTitleField')),
      '可用性测试笔记',
    );
    await tester.enterText(
      find.byKey(const ValueKey('noteContentField')),
      '这是一条可以保存并显示在首页的笔记。',
    );
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(find.text('可用性测试笔记'), findsWidgets);
    expect(find.textContaining('可以保存并显示'), findsWidgets);
  });
}
