// Basic Flutter widget test for Daily Notes app

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_notes/main.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DailyNotesApp());

    // Verify that the app builds without crashing
    expect(find.text('Daily Notes'), findsOneWidget);
  });
}
