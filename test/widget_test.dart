import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/app.dart';
import 'package:jcole_player/services/app_prefs.dart';

/// In-memory settings, so tests choose first launch vs. returning listener.
class _FakePrefs extends AppPrefs {
  const _FakePrefs(this.values);

  final Map<String, dynamic> values;

  @override
  Future<Map<String, dynamic>> load() async => values;

  @override
  Future<bool> save(Map<String, dynamic> prefs) async => true;
}

void main() {
  testWidgets('first launch shows the intro', (WidgetTester tester) async {
    await tester.pumpWidget(const JColeVaultApp(prefs: _FakePrefs({})));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('II.VI'), findsOneWidget);
    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('Quick Catalog Highlights'), findsOneWidget);
  });

  testWidgets('returning listeners skip the intro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const JColeVaultApp(prefs: _FakePrefs({'introSeen': true})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Quick Catalog Highlights'), findsNothing);
  });

  testWidgets('people updating from an older version skip the intro', (
    WidgetTester tester,
  ) async {
    // Saved settings from before the "intro seen" flag existed.
    await tester.pumpWidget(
      const JColeVaultApp(prefs: _FakePrefs({'editMode': false})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Quick Catalog Highlights'), findsNothing);
  });
}
