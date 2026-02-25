import 'package:flutter_test/flutter_test.dart';

import 'package:unitunes/main.dart';

void main() {
  testWidgets('App shows placeholder when no link is shared', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('UniTunes'), findsOneWidget);
    expect(find.text('Share a music link to this app to convert it.'), findsOneWidget);
  });
}
