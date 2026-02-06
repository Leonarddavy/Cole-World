// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/app.dart';

void main() {
  testWidgets('loads J. Cole vault shell', (WidgetTester tester) async {
    await tester.pumpWidget(const JColeVaultApp());

    expect(find.text('J. Cole Vault'), findsOneWidget);
    expect(find.text('Quick Catalog Highlights'), findsOneWidget);
  });
}
