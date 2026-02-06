import '../models/collection_models.dart';

List<CollectionEntry> seedEntries() {
  return const [
    CollectionEntry(
      id: 'album_2014fhd',
      type: CollectionType.album,
      title: '2014 Forest Hills Drive',
      history:
          'Released in 2014, this autobiographical album captures his upbringing and helped define a new era of introspective mainstream rap.',
      featuredArtists: ['No official guest verses'],
      tracks: [
        Track(
          id: 'track_03ad',
          title: 'No Role Modelz',
          artist: 'J. Cole',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'album_bornsinner',
      type: CollectionType.album,
      title: 'Born Sinner',
      history:
          'A 2013 release that expanded his sonic range and sharpened his storytelling across fame, morality, and pressure.',
      featuredArtists: ['Miguel', 'Kendrick Lamar', 'James Fauntleroy'],
      tracks: [
        Track(
          id: 'track_bs1',
          title: 'Power Trip',
          artist: 'J. Cole ft. Miguel',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'album_offseason',
      type: CollectionType.album,
      title: 'The Off-Season',
      history:
          'In 2021, Cole leaned into technical precision and high-level competition energy while staying reflective.',
      featuredArtists: ['21 Savage', 'Lil Baby', 'Morray'],
      tracks: [
        Track(
          id: 'track_os1',
          title: 'm y . l i f e',
          artist: 'J. Cole ft. 21 Savage & Morray',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'single_middlechild',
      type: CollectionType.single,
      title: 'Middle Child',
      history:
          'A pivotal stand-alone single that framed Cole as a bridge between rap generations.',
      featuredArtists: [],
      tracks: [
        Track(
          id: 'track_mid1',
          title: 'Middle Child',
          artist: 'J. Cole',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'single_snow',
      type: CollectionType.single,
      title: 'Snow On Tha Bluff',
      history:
          'A reflective release that sparked broad conversation around activism, responsibility, and discourse.',
      featuredArtists: [],
      tracks: [
        Track(
          id: 'track_snow1',
          title: 'Snow On Tha Bluff',
          artist: 'J. Cole',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'feature_alot',
      type: CollectionType.feature,
      title: 'a lot',
      history:
          'Feature verse with 21 Savage that highlighted Cole\'s sharp narrative voice and chemistry on collaborative records.',
      featuredArtists: ['21 Savage'],
      tracks: [
        Track(
          id: 'track_alot1',
          title: 'a lot',
          artist: '21 Savage ft. J. Cole',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'feature_caddy',
      type: CollectionType.feature,
      title: 'Johnny P\'s Caddy',
      history:
          'A high-impact feature with Benny the Butcher that reinforced Cole\'s elite technical and lyrical status.',
      featuredArtists: ['Benny the Butcher'],
      tracks: [
        Track(
          id: 'track_caddy1',
          title: 'Johnny P\'s Caddy',
          artist: 'Benny the Butcher ft. J. Cole',
          filePath: '',
        ),
      ],
    ),
    CollectionEntry(
      id: 'playlist_era',
      type: CollectionType.playlist,
      title: 'Cole Evolution Playlist',
      history:
          'A custom timeline playlist format to map J. Cole\'s growth from early hunger to polished veteran execution.',
      featuredArtists: ['Various collaborators'],
      tracks: [],
    ),
  ];
}
