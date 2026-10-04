import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/widgets/library_track_picker.dart';

Track _t(String id, String title) =>
    Track(id: id, title: title, artist: 'J. Cole', filePath: '/$id.mp3');

final _album = CollectionEntry(
  id: 'fhd',
  type: CollectionType.album,
  title: 'Forest Hills Drive',
  history: '',
  featuredArtists: const [],
  tracks: [_t('a1', 'Wet Dreamz'), _t('a2', 'Love Yourz')],
);

final _single = CollectionEntry(
  id: 'mc',
  type: CollectionType.single,
  title: 'Middle Child',
  history: '',
  featuredArtists: const [],
  tracks: [_t('s1', 'Middle Child')],
);

void main() {
  late List<Track>? result;

  Future<void> openPicker(
    WidgetTester tester, {
    Set<String> alreadyIncluded = const {},
    List<CollectionEntry>? sources,
  }) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showLibraryTrackPicker(
                    context,
                    sources: sources ?? [_album, _single],
                    alreadyIncluded: alreadyIncluded,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('groups songs from albums and singles', (tester) async {
    await openPicker(tester);
    expect(find.text('Forest Hills Drive · Album'), findsOneWidget);
    expect(find.text('Middle Child · Single'), findsOneWidget);
    expect(find.text('Wet Dreamz'), findsOneWidget);
    expect(find.text('Love Yourz'), findsOneWidget);
  });

  testWidgets('returns songs in the order they were ticked', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('Middle Child').last);
    await tester.tap(find.text('Wet Dreamz'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Add 2'));
    await tester.pumpAndSettle();
    expect(result!.map((t) => t.id), ['s1', 'a1']);
  });

  testWidgets('search filters songs and collections', (tester) async {
    await openPicker(tester);
    await tester.enterText(find.byType(TextField), 'love');
    await tester.pump();
    expect(find.text('Love Yourz'), findsOneWidget);
    expect(find.text('Wet Dreamz'), findsNothing);
    expect(find.text('Middle Child · Single'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No songs match your search.'), findsOneWidget);
  });

  testWidgets('select all picks a whole album and can be cleared', (
    tester,
  ) async {
    await openPicker(tester);
    await tester.tap(find.text('Select all').first);
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('0 selected'), findsOneWidget);
  });

  testWidgets('songs already in the playlist cannot be picked again', (
    tester,
  ) async {
    await openPicker(tester, alreadyIncluded: {'a1'});
    expect(find.text('Already in this playlist'), findsOneWidget);
    await tester.tap(find.text('Wet Dreamz'));
    await tester.pump();
    expect(find.text('0 selected'), findsOneWidget);

    await tester.tap(find.text('Select all').first);
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    expect(result!.map((t) => t.id), ['a2']);
  });

  testWidgets('explains an empty library and cancel returns null', (
    tester,
  ) async {
    await openPicker(tester, sources: const []);
    expect(find.textContaining('No songs in your library yet'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
