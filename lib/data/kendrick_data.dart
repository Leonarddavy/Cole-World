import '../models/collection_models.dart';
import '../models/story_content.dart';

/// Kendrick Lamar's starter library. Songs have no audio until the user adds
/// their own files. Ids are prefixed so they never collide with other
/// artists' songs.
List<CollectionEntry> kendrickSeedEntries() {
  return const [
    CollectionEntry(
      id: 'kdot_album_gkmc',
      type: CollectionType.album,
      title: 'good kid, m.A.A.d city',
      history:
          'His 2012 major-label debut, told like a short film about one long '
          'day in Compton.',
      featuredArtists: ['Jay Rock', 'Drake', 'Dr. Dre', 'MC Eiht', 'Anna Wise'],
      tracks: [
        Track(
          id: 'kdot_track_moneytrees',
          title: 'Money Trees',
          artist: 'Kendrick Lamar ft. Jay Rock',
          filePath: '',
        ),
        Track(
          id: 'kdot_track_swimmingpools',
          title: 'Swimming Pools (Drank)',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'kdot_album_tpab',
      type: CollectionType.album,
      title: 'To Pimp a Butterfly',
      history:
          'A 2015 album steeped in jazz, funk and spoken word about fame, race '
          'and self-love. "Alright" became an anthem far beyond music.',
      featuredArtists: [
        'George Clinton',
        'Thundercat',
        'Snoop Dogg',
        'Bilal',
        'Rapsody',
      ],
      tracks: [
        Track(
          id: 'kdot_track_alright',
          title: 'Alright',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
        Track(
          id: 'kdot_track_kingkunta',
          title: 'King Kunta',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'kdot_album_damn',
      type: CollectionType.album,
      title: 'DAMN.',
      history:
          'His 2017 album won the 2018 Pulitzer Prize for Music, the first '
          'awarded to a work outside classical music and jazz.',
      featuredArtists: ['Rihanna', 'U2', 'Zacari'],
      tracks: [
        Track(
          id: 'kdot_track_humble',
          title: 'HUMBLE.',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
        Track(
          id: 'kdot_track_dna',
          title: 'DNA.',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'kdot_album_mrmorale',
      type: CollectionType.album,
      title: 'Mr. Morale & the Big Steppers',
      history:
          'A 2022 double album about therapy, family and generational trauma, '
          'and his final release with Top Dawg Entertainment.',
      featuredArtists: [
        'Sampha',
        'Summer Walker',
        'Ghostface Killah',
        'Baby Keem',
        'Kodak Black',
      ],
      tracks: [
        Track(
          id: 'kdot_track_n95',
          title: 'N95',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
        Track(
          id: 'kdot_track_countmeout',
          title: 'Count Me Out',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'kdot_album_gnx',
      type: CollectionType.album,
      title: 'GNX',
      history:
          'A surprise November 2024 release rooted in West Coast sound, with '
          '"squabble up" and the SZA duet "luther".',
      featuredArtists: ['SZA', 'Roddy Ricch'],
      tracks: [
        Track(
          id: 'kdot_track_squabbleup',
          title: 'squabble up',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
        Track(
          id: 'kdot_track_luther',
          title: 'luther',
          artist: 'Kendrick Lamar & SZA',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'kdot_single_notlikeus',
      type: CollectionType.single,
      title: 'Not Like Us',
      history:
          'The West Coast anthem from his 2024 battle with Drake. It topped the '
          'Hot 100 and won Record and Song of the Year at the 2025 Grammys.',
      featuredArtists: [],
      tracks: [
        Track(
          id: 'kdot_track_notlikeus',
          title: 'Not Like Us',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'kdot_single_heartpart5',
      type: CollectionType.single,
      title: 'The Heart Part 5',
      history:
          'The 2022 single that opened the Mr. Morale era, known for its '
          'deepfake-driven video.',
      featuredArtists: [],
      tracks: [
        Track(
          id: 'kdot_track_heartpart5',
          title: 'The Heart Part 5',
          artist: 'Kendrick Lamar',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'kdot_feature_likethat',
      type: CollectionType.feature,
      title: 'Like That',
      history:
          'Future and Metro Boomin\'s 2024 No. 1, whose Kendrick verse set off '
          'his public battle with Drake.',
      featuredArtists: ['Future', 'Metro Boomin'],
      tracks: [
        Track(
          id: 'kdot_track_likethat',
          title: 'Like That',
          artist: 'Future, Metro Boomin & Kendrick Lamar',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'kdot_feature_badblood',
      type: CollectionType.feature,
      title: 'Bad Blood (Remix)',
      history:
          'Taylor Swift\'s 2015 single remixed with Kendrick verses; its video '
          'won Video of the Year at the MTV VMAs.',
      featuredArtists: ['Taylor Swift'],
      tracks: [
        Track(
          id: 'kdot_track_badblood',
          title: 'Bad Blood',
          artist: 'Taylor Swift ft. Kendrick Lamar',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'kdot_playlist_compton',
      type: CollectionType.playlist,
      title: 'Compton to the World',
      history: 'A custom playlist for tracing Kendrick from Section.80 to GNX.',
      featuredArtists: [],
      tracks: [],
    ),
  ];
}

const StoryContent kendrickStory = StoryContent(
  heroTitle: 'Kendrick Lamar Timeline + Discography',
  heroSummary:
      'From K.Dot mixtapes in Compton to a Pulitzer Prize and the Super Bowl '
      'stage: the path of one of rap\'s most decorated writers.',
  heroImageSource: 'assets/groove2.jpg',
  timelineImageSource: 'assets/KEKE6.jpg',
  sections: [
    StorySection(
      indexLabel: '1',
      title: 'Compton Roots + K.Dot (2003-2010)',
      summary:
          'Kendrick Lamar Duckworth grew up in Compton, California, and first '
          'recorded as K.Dot while still a teenager.',
      points: [
        '2005: Signed to Top Dawg Entertainment (TDE).',
        'Formed the Black Hippy crew with Jay Rock, Ab-Soul and ScHoolboy Q.',
        '2009: Kendrick Lamar EP, the first release under his own name.',
        '2010: Overly Dedicated (mixtape).',
      ],
      imageSource: 'assets/groove.jpg',
    ),
    StorySection(
      indexLabel: '2',
      title: 'Section.80 to good kid (2011-2012)',
      summary:
          'An independent debut, then a Dr. Dre co-sign and a major-label '
          'classic.',
      points: [
        'July 2, 2011: Section.80, released independently through TDE.',
        '2012: Signed to Aftermath and Interscope alongside TDE.',
        'Oct 22, 2012: good kid, m.A.A.d city.',
      ],
      imageSource: 'assets/KEKE2.jpg',
    ),
    StorySection(
      indexLabel: '3',
      title: 'Butterfly + DAMN. (2015-2018)',
      summary: 'Two albums that turned acclaim into history.',
      points: [
        'Mar 15, 2015: To Pimp a Butterfly.',
        '2016: untitled unmastered., a set of Butterfly-era recordings.',
        'Apr 14, 2017: DAMN.; "HUMBLE." became his first No. 1 as lead artist.',
        '2018: DAMN. won the Pulitzer Prize for Music.',
        '2018: Curated Black Panther: The Album, with "All the Stars" and SZA.',
      ],
      imageSource: 'assets/KEKE3.jpg',
    ),
    StorySection(
      indexLabel: '4',
      title: 'pgLang + Mr. Morale (2020-2022)',
      summary: 'New independence and his most personal record.',
      points: [
        '2020: Co-founded the creative company pgLang with Dave Free.',
        'May 13, 2022: Mr. Morale & the Big Steppers, his last album with TDE.',
        '2023: Mr. Morale won the Grammy for Best Rap Album.',
      ],
      imageSource: 'assets/KEKE5.jpg',
    ),
    StorySection(
      indexLabel: '5',
      title: 'The Battle, GNX + Super Bowl (2024-2025)',
      summary:
          'A rap battle with Drake, a surprise album and the biggest stage in '
          'music.',
      points: [
        'Mar 2024: His verse on "Like That" sparked a battle with Drake.',
        'May 4, 2024: "Not Like Us", which topped the Hot 100.',
        'Nov 22, 2024: GNX, a surprise release.',
        'Feb 2, 2025: "Not Like Us" won five Grammys, including Record and '
            'Song of the Year.',
        'Feb 9, 2025: Headlined the Super Bowl LIX halftime show in New '
            'Orleans.',
      ],
      imageSource: 'assets/KEKE6.jpg',
    ),
  ],
  timelineEvents: [
    StoryEvent(
      year: '2009',
      title: 'Kendrick Lamar EP',
      note: 'First release under his own name',
    ),
    StoryEvent(year: '2010', title: 'Overly Dedicated', note: 'Mixtape'),
    StoryEvent(
      year: '2011',
      title: 'Section.80',
      note: 'Independent debut album',
    ),
    StoryEvent(
      year: '2012',
      title: 'good kid, m.A.A.d city',
      note: 'Major-label debut',
    ),
    StoryEvent(
      year: '2015',
      title: 'To Pimp a Butterfly',
      note: 'Released Mar 15, 2015',
    ),
    StoryEvent(
      year: '2016',
      title: 'untitled unmastered.',
      note: 'Butterfly-era recordings',
    ),
    StoryEvent(year: '2017', title: 'DAMN.', note: 'Released Apr 14, 2017'),
    StoryEvent(
      year: '2018',
      title: 'Pulitzer Prize for Music',
      note: 'Awarded for DAMN.',
    ),
    StoryEvent(
      year: '2018',
      title: 'Black Panther: The Album',
      note: 'Curated soundtrack',
    ),
    StoryEvent(
      year: '2022',
      title: 'Mr. Morale & the Big Steppers',
      note: 'Final TDE album',
    ),
    StoryEvent(year: '2024', title: 'Not Like Us', note: 'Hot 100 No. 1'),
    StoryEvent(year: '2024', title: 'GNX', note: 'Surprise release, Nov 22'),
    StoryEvent(
      year: '2025',
      title: 'Super Bowl LIX halftime show',
      note: 'New Orleans, Feb 9',
    ),
  ],
);
