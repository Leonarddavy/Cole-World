import '../models/collection_models.dart';
import '../models/story_content.dart';
import '../theme/app_theme.dart';
import 'drake_data.dart';
import 'kendrick_data.dart';
import 'seed_data.dart';

/// The artists the app can be switched to. Each has its own "vault": its
/// own library, story, theme, likes and listening history.
enum ArtistProfile { jcole, kendrick, drake }

/// One card in the intro's "Quick Catalog Highlights".
class CatalogHighlight {
  const CatalogHighlight({
    required this.tag,
    required this.title,
    required this.detail,
  });

  final String tag;
  final String title;
  final String detail;
}

/// Everything that makes the app about one artist.
class ArtistEdition {
  const ArtistEdition({
    required this.profile,
    required this.name,
    required this.labelLine,
    required this.theme,
    required this.backdropAssets,
    required this.highlights,
    required this.seedEntries,
    required this.story,
  });

  final ArtistProfile profile;

  /// "Kendrick Lamar".
  final String name;

  /// A short line about the artist's home base, e.g. "pgLang · TDE".
  final String labelLine;

  /// The edition's default look; users can still customise it.
  final AppThemeSettings theme;
  final List<String> backdropAssets;
  final List<CatalogHighlight> highlights;

  /// The starter library (songs without audio until files are added).
  final List<CollectionEntry> Function() seedEntries;
  final StoryContent story;

  /// Names the edition's own library file / storage key.
  String get storageKey => profile.name;

  /// "KL" for Kendrick Lamar; shown on the edition's swatch.
  String get initials => name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase())
      .take(2)
      .join();
}

const List<CatalogHighlight> jColeHighlights = [
  CatalogHighlight(
    tag: 'Grammy Era',
    title: 'Best Rap Song Winner',
    detail:
        'Recognized at the Grammy Awards for songwriting and lyrical precision.',
  ),
  CatalogHighlight(
    tag: '2014',
    title: 'Forest Hills Milestone',
    detail:
        '2014 Forest Hills Drive became one of modern rap\'s most defining '
        'albums.',
  ),
  CatalogHighlight(
    tag: 'Dreamville',
    title: 'Label Architect',
    detail:
        'Built Dreamville into a respected roster and collaborative movement.',
  ),
  CatalogHighlight(
    tag: 'Feature Run',
    title: 'Elite Guest Verses',
    detail:
        'Delivered standout verses across the 2020s with technical consistency.',
  ),
];

const List<CatalogHighlight> _kendrickHighlights = [
  CatalogHighlight(
    tag: 'Pulitzer',
    title: 'A First for Rap',
    detail:
        'DAMN. won the 2018 Pulitzer Prize for Music, the first for a work '
        'outside classical music and jazz.',
  ),
  CatalogHighlight(
    tag: '2015',
    title: 'To Pimp a Butterfly',
    detail:
        'A jazz- and funk-soaked landmark; "Alright" became an anthem far '
        'beyond music.',
  ),
  CatalogHighlight(
    tag: 'Compton',
    title: 'good kid, m.A.A.d city',
    detail:
        'A major-label debut told like a film about one day in his hometown.',
  ),
  CatalogHighlight(
    tag: '2025',
    title: 'Super Bowl LIX',
    detail:
        'Headlined the halftime show after "Not Like Us" swept the Grammys.',
  ),
];

const List<CatalogHighlight> _drakeHighlights = [
  CatalogHighlight(
    tag: 'OVO',
    title: 'Label Builder',
    detail: 'Co-founded OVO Sound with Noah "40" Shebib and Oliver El-Khatib.',
  ),
  CatalogHighlight(
    tag: '2011',
    title: 'Take Care',
    detail: 'His moody second album won the Grammy for Best Rap Album.',
  ),
  CatalogHighlight(
    tag: 'Charts',
    title: 'Three No. 1s, One Album',
    detail:
        'Scorpion produced "God\'s Plan", "Nice for What" and "In My '
        'Feelings", all Hot 100 No. 1s.',
  ),
  CatalogHighlight(
    tag: 'The 6ix',
    title: 'Toronto, Worldwide',
    detail: 'Turned his hometown into a global brand, from Views to OVO Fest.',
  ),
];

/// Street-art photos that suit any edition (the J. Cole posters don't).
const List<String> _streetArtAssets = [
  'assets/groove.jpg',
  'assets/groove2.jpg',
  'assets/KEKE2.jpg',
  'assets/KEKE3.jpg',
  'assets/KEKE5.jpg',
  'assets/KEKE6.jpg',
];

final Map<ArtistProfile, ArtistEdition> _editions = {
  ArtistProfile.jcole: ArtistEdition(
    profile: ArtistProfile.jcole,
    name: 'J. Cole',
    labelLine: 'Dreamville',
    theme: const AppThemeSettings(),
    backdropAssets: const [
      'assets/groove.jpg',
      'assets/groove2.jpg',
      'assets/jcole2.jpg',
      'assets/jcole3.jpg',
      'assets/KEKE2.jpg',
      'assets/KEKE3.jpg',
      'assets/KEKE5.jpg',
      'assets/KEKE6.jpg',
    ],
    highlights: jColeHighlights,
    seedEntries: seedEntries,
    story: StoryContent.defaults(),
  ),
  ArtistProfile.kendrick: ArtistEdition(
    profile: ArtistProfile.kendrick,
    name: 'Kendrick Lamar',
    labelLine: 'pgLang · TDE',
    // Stark black, bone white and stop-sign red; bold condensed type.
    theme: const AppThemeSettings(
      primaryColorValue: 0xFFE5383B,
      secondaryColorValue: 0xFFF1E9DA,
      backgroundColorValue: 0xFF0E0E10,
      displayFontKey: 'oswald',
    ),
    backdropAssets: _streetArtAssets,
    highlights: _kendrickHighlights,
    seedEntries: kendrickSeedEntries,
    story: kendrickStory,
  ),
  ArtistProfile.drake: ArtistEdition(
    profile: ArtistProfile.drake,
    name: 'Drake',
    labelLine: 'OVO Sound',
    // Toronto night blue with OVO gold; sleek condensed type.
    theme: const AppThemeSettings(
      primaryColorValue: 0xFF8EC9FF,
      secondaryColorValue: 0xFFD4AF37,
      backgroundColorValue: 0xFF0B1220,
      displayFontKey: 'teko',
    ),
    backdropAssets: _streetArtAssets,
    highlights: _drakeHighlights,
    seedEntries: drakeSeedEntries,
    story: drakeStory,
  ),
};

ArtistEdition artistEdition(ArtistProfile profile) => _editions[profile]!;

// --- per-artist saved data ----------------------------------------------------

/// Saved settings that belong to one artist's vault (the rest are global).
const List<String> vaultPrefKeys = [
  'themeSettings',
  'storyContent',
  'customBackdropSources',
  'likedTrackIds',
  'playCounts',
  'recentPlays',
  'lastSession',
  'queue',
  'musicVideos',
];

ArtistProfile activeArtistIn(Map<String, dynamic> prefs) =>
    ArtistProfile.values.firstWhere(
      (profile) => profile.name == prefs['activeArtist'],
      orElse: () => ArtistProfile.jcole,
    );

/// Every artist's saved vault data. Before editions existed, J. Cole's data
/// sat at the top level of the settings; that becomes his vault.
Map<String, Map<String, dynamic>> vaultsIn(Map<String, dynamic> prefs) {
  final vaults = <String, Map<String, dynamic>>{};
  final raw = prefs['vaults'];
  if (raw is Map) {
    for (final item in raw.entries) {
      if (item.value is Map) {
        vaults[item.key.toString()] = Map<String, dynamic>.from(
          item.value as Map,
        );
      }
    }
  }
  if (!vaults.containsKey(ArtistProfile.jcole.name)) {
    final legacy = {
      for (final key in vaultPrefKeys)
        if (prefs.containsKey(key)) key: prefs[key],
    };
    if (legacy.isNotEmpty) {
      vaults[ArtistProfile.jcole.name] = legacy;
    }
  }
  return vaults;
}

/// The look for [profile]: its saved theme if customised, else the
/// edition's own. The card shape is a global choice and overrides both.
AppThemeSettings themeForVault(
  ArtistProfile profile,
  Map<String, dynamic>? vault, {
  String? cardShapeKey,
}) {
  final saved = vault?['themeSettings'];
  final base = saved is Map
      ? AppThemeSettings.fromJson(saved)
      : artistEdition(profile).theme;
  return cardShapeKey == null
      ? base
      : base.copyWith(cardShapeKey: cardShapeKey);
}
