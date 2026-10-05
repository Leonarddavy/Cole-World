import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/app.dart';
import 'package:jcole_player/data/artist_editions.dart';
import 'package:jcole_player/models/collection_models.dart';
import 'package:jcole_player/pages/home_page.dart';
import 'package:jcole_player/pages/splash_catalog_page.dart';
import 'package:jcole_player/services/app_prefs.dart';
import 'package:jcole_player/services/library_storage.dart';
import 'package:jcole_player/theme/app_theme.dart';
import 'package:jcole_player/widgets/artist_edition_tile.dart';

/// In-memory settings that remember every save.
class _RecordingPrefs extends AppPrefs {
  _RecordingPrefs(this.values);

  final Map<String, dynamic> values;
  final List<Map<String, dynamic>> saved = [];

  @override
  Future<Map<String, dynamic>> load() async => values;

  @override
  Future<bool> save(Map<String, dynamic> prefs) async {
    saved.add(prefs);
    return true;
  }
}

/// Every artist's library, kept in memory.
class _MemoryLibraries {
  final Map<String, List<CollectionEntry>> files = {};

  LibraryStorage call(String vault) => _MemoryLibrary(this, vault);
}

class _MemoryLibrary extends LibraryStorage {
  _MemoryLibrary(this.store, String vault) : super(vault: vault);

  final _MemoryLibraries store;

  @override
  Future<List<CollectionEntry>?> load() async => store.files[vault];

  @override
  Future<bool> save(List<CollectionEntry> entries) async {
    store.files[vault] = entries;
    return true;
  }
}

Map<String, dynamic> _vaultsOf(Map<String, dynamic> prefs) =>
    Map<String, dynamic>.from(prefs['vaults'] as Map);

Future<void> _settle(WidgetTester tester) async {
  // The shell keeps ambient animations running, so pump fixed steps rather
  // than waiting for everything to settle.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('editions', () {
    test('each artist has their own library, story and look', () {
      final editions = ArtistProfile.values.map(artistEdition).toList();
      expect(editions.map((e) => e.name), [
        'J. Cole',
        'Kendrick Lamar',
        'Drake',
      ]);
      expect(editions.map((e) => e.storageKey).toSet(), hasLength(3));
      expect(editions.map((e) => e.theme).toSet(), hasLength(3));
      expect(editions.map((e) => e.story.heroTitle).toSet(), hasLength(3));
      for (final edition in editions) {
        expect(edition.highlights, isNotEmpty, reason: edition.name);
        expect(edition.story.sections, isNotEmpty, reason: edition.name);
        expect(edition.story.timelineEvents, isNotEmpty, reason: edition.name);
        expect(edition.backdropAssets, isNotEmpty, reason: edition.name);
        expect(edition.labelLine, isNotEmpty, reason: edition.name);
        // Display fonts must be ones the app can render.
        expect(
          AppTheme.displayFontChoices.map((f) => f.key),
          contains(edition.theme.displayFontKey),
          reason: edition.name,
        );
      }
    });

    test('initials label the swatches', () {
      expect(artistEdition(ArtistProfile.jcole).initials, 'JC');
      expect(artistEdition(ArtistProfile.kendrick).initials, 'KL');
      expect(artistEdition(ArtistProfile.drake).initials, 'D');
    });

    test('starter libraries cover every kind of collection', () {
      for (final profile in ArtistProfile.values) {
        final entries = artistEdition(profile).seedEntries();
        final types = entries.map((entry) => entry.type).toSet();
        expect(types, containsAll(CollectionType.values), reason: profile.name);
      }
    });

    test('song and collection ids never collide across artists', () {
      final entryIds = <String>[];
      final trackIds = <String>[];
      for (final profile in ArtistProfile.values) {
        for (final entry in artistEdition(profile).seedEntries()) {
          entryIds.add(entry.id);
          trackIds.addAll(entry.tracks.map((track) => track.id));
        }
      }
      expect(entryIds.toSet(), hasLength(entryIds.length));
      expect(trackIds.toSet(), hasLength(trackIds.length));

      final kendrick = artistEdition(ArtistProfile.kendrick).seedEntries();
      final drake = artistEdition(ArtistProfile.drake).seedEntries();
      for (final entry in kendrick) {
        expect(entry.id, startsWith('kdot_'));
        for (final track in entry.tracks) {
          expect(track.id, startsWith('kdot_'));
        }
      }
      for (final entry in drake) {
        expect(entry.id, startsWith('drake_'));
        for (final track in entry.tracks) {
          expect(track.id, startsWith('drake_'));
        }
      }
    });
  });

  group('saved settings', () {
    test('the active artist defaults to J. Cole', () {
      expect(activeArtistIn({}), ArtistProfile.jcole);
      expect(activeArtistIn({'activeArtist': 'drake'}), ArtistProfile.drake);
      expect(activeArtistIn({'activeArtist': 'nobody'}), ArtistProfile.jcole);
      expect(activeArtistIn({'activeArtist': 3}), ArtistProfile.jcole);
    });

    test("settings from before editions become J. Cole's vault", () {
      final vaults = vaultsIn({
        'likedTrackIds': ['track_03ad'],
        'playCounts': {'track_03ad': 4},
        'themeSettings': {'primaryColorValue': 0xFF00FF00},
        // Global settings stay out of the vault.
        'tabLayout': {'order': <String>[]},
        'shuffleEnabled': true,
      });
      expect(vaults.keys, ['jcole']);
      expect(vaults['jcole'], {
        'likedTrackIds': ['track_03ad'],
        'playCounts': {'track_03ad': 4},
        'themeSettings': {'primaryColorValue': 0xFF00FF00},
      });
    });

    test('saved vaults win over leftover top-level settings', () {
      final vaults = vaultsIn({
        'likedTrackIds': ['stale'],
        'vaults': {
          'jcole': {
            'likedTrackIds': ['fresh'],
          },
          'drake': {
            'likedTrackIds': ['drake_track_work'],
          },
          'broken': 'not a vault',
        },
      });
      expect(vaults.keys, unorderedEquals(['jcole', 'drake']));
      expect(vaults['jcole']!['likedTrackIds'], ['fresh']);
    });

    test('a fresh install has no vaults yet', () {
      expect(vaultsIn({}), isEmpty);
    });

    test("an artist's look is their own until customised", () {
      final kendrick = themeForVault(ArtistProfile.kendrick, null);
      expect(kendrick, artistEdition(ArtistProfile.kendrick).theme);
      expect(kendrick.displayFontKey, 'oswald');

      final custom = themeForVault(ArtistProfile.kendrick, {
        'themeSettings': const AppThemeSettings(
          primaryColorValue: 0xFF123456,
        ).toJson(),
      });
      expect(custom.primaryColorValue, 0xFF123456);
    });

    test('the card shape is shared by every artist', () {
      final drake = themeForVault(
        ArtistProfile.drake,
        null,
        cardShapeKey: 'cut',
      );
      expect(drake.cardShapeKey, 'cut');
      expect(drake.primaryColorValue, 0xFF8EC9FF);
    });
  });

  group('widgets', () {
    testWidgets('the intro shows the chosen artist highlights', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashCatalogPage(
            onFinished: () {},
            autoAdvance: false,
            items: artistEdition(ArtistProfile.kendrick).highlights,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('A First for Rap'), findsOneWidget);
      expect(find.text('Best Rap Song Winner'), findsNothing);
    });

    testWidgets('a tile marks the current artist', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Column(
              children: [
                ArtistEditionTile(
                  edition: artistEdition(ArtistProfile.drake),
                  selected: true,
                  onTap: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Drake'), findsOneWidget);
      expect(find.text('OVO Sound'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await tester.tap(find.text('Drake'));
      expect(taps, 1);
    });
  });

  group('the app', () {
    testWidgets("opens in the saved artist's vault and look", (tester) async {
      final libraries = _MemoryLibraries();
      final prefs = _RecordingPrefs({
        'introSeen': true,
        'activeArtist': 'kendrick',
        'vaults': <String, dynamic>{},
      });
      await tester.pumpWidget(
        JColeVaultApp(prefs: prefs, libraryStorageFor: libraries.call),
      );
      await _settle(tester);

      expect(find.textContaining('Kendrick Lamar'), findsWidgets);
      final context = tester.element(find.byType(HomePage));
      expect(Theme.of(context).colorScheme.primary, const Color(0xFFE5383B));
      final home = tester.widget<HomePage>(find.byType(HomePage));
      expect(home.entries.map((e) => e.id), everyElement(startsWith('kdot_')));
    });

    testWidgets("moves pre-edition settings into J. Cole's vault", (
      tester,
    ) async {
      final libraries = _MemoryLibraries();
      final prefs = _RecordingPrefs({
        'introSeen': true,
        'themeVersion': AppThemeSettings.currentVersion,
        'themeSettings': const AppThemeSettings(
          primaryColorValue: 0xFF00AA00,
        ).toJson(),
        'likedTrackIds': ['track_03ad'],
      });
      await tester.pumpWidget(
        JColeVaultApp(prefs: prefs, libraryStorageFor: libraries.call),
      );
      await _settle(tester);

      expect(prefs.saved, isNotEmpty);
      final last = prefs.saved.last;
      expect(last['activeArtist'], 'jcole');
      expect(last.containsKey('likedTrackIds'), isFalse);
      expect(last.containsKey('themeSettings'), isFalse);
      final jcole = Map<String, dynamic>.from(_vaultsOf(last)['jcole'] as Map);
      expect(jcole['likedTrackIds'], ['track_03ad']);
      expect((jcole['themeSettings'] as Map)['primaryColorValue'], 0xFF00AA00);
    });

    testWidgets('switching keeps each artist in their own vault', (
      tester,
    ) async {
      final kendrickLook = const AppThemeSettings(
        primaryColorValue: 0xFFAA0000,
        displayFontKey: 'oswald',
      ).toJson();
      final libraries = _MemoryLibraries();
      final prefs = _RecordingPrefs({
        'introSeen': true,
        'themeVersion': AppThemeSettings.currentVersion,
        'activeArtist': 'kendrick',
        'cardShape': 'sharp',
        'vaults': {
          'kendrick': {
            'themeSettings': kendrickLook,
            'likedTrackIds': ['kdot_track_humble'],
          },
        },
      });
      await tester.pumpWidget(
        JColeVaultApp(prefs: prefs, libraryStorageFor: libraries.call),
      );
      await _settle(tester);

      await tester.tap(find.textContaining('Kendrick Lamar').first);
      await _settle(tester);
      expect(find.text('Switch artist'), findsOneWidget);
      await tester.tap(find.text('Drake'));
      await _settle(tester);

      expect(find.text('Switched to Drake.'), findsOneWidget);
      final home = tester.widget<HomePage>(find.byType(HomePage));
      expect(home.entries.map((e) => e.id), everyElement(startsWith('drake_')));
      final context = tester.element(find.byType(HomePage));
      expect(Theme.of(context).colorScheme.primary, const Color(0xFF8EC9FF));

      final last = prefs.saved.last;
      expect(last['activeArtist'], 'drake');
      // The shape picked for one artist carries over to the next.
      expect(last['cardShape'], 'sharp');
      final vaults = _vaultsOf(last);
      final kendrick = Map<String, dynamic>.from(vaults['kendrick'] as Map);
      expect(kendrick['likedTrackIds'], ['kdot_track_humble']);
      expect(
        (kendrick['themeSettings'] as Map)['primaryColorValue'],
        0xFFAA0000,
      );
      final drake = Map<String, dynamic>.from(vaults['drake'] as Map);
      expect(drake['likedTrackIds'], isEmpty);
      expect((drake['storyContent'] as Map)['heroTitle'], contains('Drake'));

      // Each artist's library lives in its own file.
      expect(
        libraries.files['kendrick']!.map((e) => e.id),
        everyElement(startsWith('kdot_')),
      );
      expect(
        libraries.files['drake']!.map((e) => e.id),
        everyElement(startsWith('drake_')),
      );
      expect(libraries.files.containsKey('jcole'), isFalse);
    });
  });
}
