import 'package:flutter_test/flutter_test.dart';

import 'package:manga_tracker/main.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const MangaTrackerApp());
    await tester.pumpAndSettle();

    // Verify the app contains expected text
    expect(find.text('Koleksi Komik'), findsOneWidget);
  });
}
