import '../models/collection_models.dart';
import '../models/story_content.dart';

/// Drake's starter library. Songs have no audio until the user adds their
/// own files. Ids are prefixed so they never collide with other artists'.
List<CollectionEntry> drakeSeedEntries() {
  return const [
    CollectionEntry(
      id: 'drake_album_takecare',
      type: CollectionType.album,
      title: 'Take Care',
      history:
          'His moody, R&B-leaning 2011 second album, which won the Grammy for '
          'Best Rap Album.',
      featuredArtists: [
        'Rihanna',
        'The Weeknd',
        'Kendrick Lamar',
        'Lil Wayne',
        'Nicki Minaj',
        'Rick Ross',
        'André 3000',
      ],
      tracks: [
        Track(
          id: 'drake_track_marvinsroom',
          title: 'Marvins Room',
          artist: 'Drake',
          filePath: '',
        ),
        Track(
          id: 'drake_track_headlines',
          title: 'Headlines',
          artist: 'Drake',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'drake_album_nwts',
      type: CollectionType.album,
      title: 'Nothing Was the Same',
      history:
          'A 2013 album built around Noah "40" Shebib\'s minimal production, '
          'home to "Started from the Bottom".',
      featuredArtists: [
        'Majid Jordan',
        'Jay-Z',
        '2 Chainz',
        'Jhené Aiko',
        'Sampha',
      ],
      tracks: [
        Track(
          id: 'drake_track_startedfromthebottom',
          title: 'Started from the Bottom',
          artist: 'Drake',
          filePath: '',
        ),
        Track(
          id: 'drake_track_holdon',
          title: 'Hold On, We\'re Going Home',
          artist: 'Drake ft. Majid Jordan',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'drake_album_views',
      type: CollectionType.album,
      title: 'Views',
      history:
          'A Toronto-centred 2016 album whose single "One Dance" became one of '
          'the most-streamed songs of its time.',
      featuredArtists: ['Wizkid', 'Kyla', 'Rihanna', 'Future', 'PartyNextDoor'],
      tracks: [
        Track(
          id: 'drake_track_onedance',
          title: 'One Dance',
          artist: 'Drake ft. Wizkid & Kyla',
          filePath: '',
        ),
        Track(
          id: 'drake_track_controlla',
          title: 'Controlla',
          artist: 'Drake',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'drake_album_scorpion',
      type: CollectionType.album,
      title: 'Scorpion',
      history:
          'A 2018 double album split between rap and R&B sides, with three Hot '
          '100 No. 1 singles: "God\'s Plan", "Nice for What" and "In My '
          'Feelings".',
      featuredArtists: ['Jay-Z', 'Ty Dolla \$ign', 'Michael Jackson'],
      tracks: [
        Track(
          id: 'drake_track_godsplan',
          title: 'God\'s Plan',
          artist: 'Drake',
          filePath: '',
        ),
        Track(
          id: 'drake_track_niceforwhat',
          title: 'Nice for What',
          artist: 'Drake',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'drake_album_clb',
      type: CollectionType.album,
      title: 'Certified Lover Boy',
      history:
          'His 2021 album, led by "Way 2 Sexy" with Future and Young Thug.',
      featuredArtists: [
        'Future',
        'Young Thug',
        'Lil Baby',
        'Travis Scott',
        'Kid Cudi',
        'Jay-Z',
      ],
      tracks: [
        Track(
          id: 'drake_track_way2sexy',
          title: 'Way 2 Sexy',
          artist: 'Drake ft. Future & Young Thug',
          filePath: '',
        ),
        Track(
          id: 'drake_track_fairtrade',
          title: 'Fair Trade',
          artist: 'Drake ft. Travis Scott',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'drake_single_hotlinebling',
      type: CollectionType.single,
      title: 'Hotline Bling',
      history:
          'A 2015 single whose dance-meme video became a pop-culture moment; it '
          'won two Grammys.',
      featuredArtists: [],
      tracks: [
        Track(
          id: 'drake_track_hotlinebling',
          title: 'Hotline Bling',
          artist: 'Drake',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'drake_single_bestiever',
      type: CollectionType.single,
      title: 'Best I Ever Had',
      history:
          'The So Far Gone breakout that took a free mixtape song to No. 2 on '
          'the Hot 100.',
      featuredArtists: [],
      tracks: [
        Track(
          id: 'drake_track_bestieverhad',
          title: 'Best I Ever Had',
          artist: 'Drake',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'drake_feature_work',
      type: CollectionType.feature,
      title: 'Work',
      history: 'Rihanna\'s 2016 dancehall-tinged No. 1 from ANTI, with Drake.',
      featuredArtists: ['Rihanna'],
      tracks: [
        Track(
          id: 'drake_track_work',
          title: 'Work',
          artist: 'Rihanna ft. Drake',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'drake_feature_noguidance',
      type: CollectionType.feature,
      title: 'No Guidance',
      history: 'Chris Brown\'s 2019 R&B hit with Drake.',
      featuredArtists: ['Chris Brown'],
      tracks: [
        Track(
          id: 'drake_track_noguidance',
          title: 'No Guidance',
          artist: 'Chris Brown ft. Drake',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'drake_playlist_6ix',
      type: CollectionType.playlist,
      title: 'The 6ix Playlist',
      history: 'A custom playlist for mapping Drake from So Far Gone to OVO.',
      featuredArtists: [],
      tracks: [],
    ),
  ];
}

const StoryContent drakeStory = StoryContent(
  heroTitle: 'Drake Timeline + Discography',
  heroSummary:
      'From a Toronto TV set to OVO and the top of the charts: mixtapes, '
      'albums and records built on blending rap and R&B.',
  heroImageSource: 'assets/KEKE5.jpg',
  timelineImageSource: 'assets/groove2.jpg',
  sections: [
    StorySection(
      indexLabel: '1',
      title: 'Degrassi + Toronto Beginnings (2001-2008)',
      summary:
          'Aubrey Drake Graham grew up in Toronto and was known as Jimmy Brooks '
          'on Degrassi: The Next Generation before music took over.',
      points: [
        '2006: Room for Improvement (mixtape).',
        '2007: Comeback Season (mixtape).',
        'Shaped his sound with producer Noah "40" Shebib.',
      ],
      imageSource: 'assets/KEKE2.jpg',
    ),
    StorySection(
      indexLabel: '2',
      title: 'So Far Gone + Young Money (2009-2010)',
      summary: 'A free mixtape turned breakout.',
      points: [
        'Feb 2009: So Far Gone (mixtape), with "Best I Ever Had".',
        '2009: Signed to Lil Wayne\'s Young Money.',
        'June 15, 2010: Thank Me Later, his debut album.',
      ],
      imageSource: 'assets/groove.jpg',
    ),
    StorySection(
      indexLabel: '3',
      title: 'Take Care to Views (2011-2016)',
      summary: 'The run that made him pop\'s center of gravity.',
      points: [
        'Nov 15, 2011: Take Care; it won the Grammy for Best Rap Album.',
        '2012: Co-founded OVO Sound with 40 and Oliver El-Khatib.',
        'Sept 24, 2013: Nothing Was the Same.',
        'Feb 2015: If You\'re Reading This It\'s Too Late, a surprise release.',
        'Apr 29, 2016: Views, with "One Dance" and "Hotline Bling".',
      ],
      imageSource: 'assets/KEKE3.jpg',
    ),
    StorySection(
      indexLabel: '4',
      title: 'Scorpion + Streaming Era (2017-2021)',
      summary: 'Chart dominance in the streaming age.',
      points: [
        'Mar 2017: More Life, billed as a playlist.',
        'June 29, 2018: Scorpion, with three Hot 100 No. 1 singles.',
        'Sept 3, 2021: Certified Lover Boy.',
      ],
      imageSource: 'assets/KEKE6.jpg',
    ),
    StorySection(
      indexLabel: '5',
      title: 'New Sounds + Collaborations (2022-2025)',
      summary: 'Dance music, duets and a very public rivalry.',
      points: [
        'June 17, 2022: Honestly, Nevermind, a house-influenced album.',
        'Nov 4, 2022: Her Loss, with 21 Savage.',
        'Oct 6, 2023: For All the Dogs.',
        '2024: Traded diss tracks with Kendrick Lamar.',
        'Feb 14, 2025: \$ome \$exy \$ongs 4 U, with PartyNextDoor.',
      ],
      imageSource: 'assets/groove2.jpg',
    ),
  ],
  timelineEvents: [
    StoryEvent(year: '2006', title: 'Room for Improvement', note: 'Mixtape'),
    StoryEvent(year: '2009', title: 'So Far Gone', note: 'Breakout mixtape'),
    StoryEvent(year: '2010', title: 'Thank Me Later', note: 'Debut album'),
    StoryEvent(
      year: '2011',
      title: 'Take Care',
      note: 'Grammy for Best Rap Album',
    ),
    StoryEvent(year: '2012', title: 'OVO Sound', note: 'Label co-founded'),
    StoryEvent(
      year: '2013',
      title: 'Nothing Was the Same',
      note: 'Third album',
    ),
    StoryEvent(
      year: '2015',
      title: 'If You\'re Reading This It\'s Too Late',
      note: 'Surprise release',
    ),
    StoryEvent(year: '2016', title: 'Views', note: 'Released Apr 29, 2016'),
    StoryEvent(year: '2018', title: 'Scorpion', note: 'Double album'),
    StoryEvent(
      year: '2021',
      title: 'Certified Lover Boy',
      note: 'Released Sept 3, 2021',
    ),
    StoryEvent(
      year: '2022',
      title: 'Honestly, Nevermind',
      note: 'House-influenced album',
    ),
    StoryEvent(year: '2022', title: 'Her Loss', note: 'With 21 Savage'),
    StoryEvent(
      year: '2023',
      title: 'For All the Dogs',
      note: 'Released Oct 6, 2023',
    ),
    StoryEvent(
      year: '2025',
      title: '\$ome \$exy \$ongs 4 U',
      note: 'With PartyNextDoor',
    ),
  ],
);
