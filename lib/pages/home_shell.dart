import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as path;
import 'package:audio_session/audio_session.dart';

import '../data/seed_data.dart';
import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
import '../models/lyrics.dart';
import '../models/playback_models.dart';
import '../models/story_content.dart';
import '../services/app_prefs.dart';
import '../services/library_storage.dart';
import '../services/lyrics_store.dart';
import '../services/online_lyrics.dart';
import '../services/play_queue.dart';
import '../services/smart_playlists.dart';
import '../theme/app_theme.dart';
import '../ui/collection_type_ui.dart';
import '../utils/audio_tags.dart';
import '../utils/local_fs.dart';
import '../utils/object_url.dart';
import '../widgets/graffiti_backdrop.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/graffiti_scaffold.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/track_queue_menu_button.dart';
import 'artist_history_page.dart';
import 'collection_detail_page.dart';
import 'library_page.dart';
import 'lyrics_page.dart';
import 'now_playing_page.dart';
import 'splash_catalog_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.onThemeSettingsChanged,
    required this.initialThemeSettings,
  });

  final ValueChanged<AppThemeSettings> onThemeSettingsChanged;
  final AppThemeSettings initialThemeSettings;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum _HomeTab { albums, singles, features, playlist, story, launch }

enum _SongImportSource { files, folder }

class _HomeShellState extends State<HomeShell> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AppPrefs _prefs = const AppPrefs();
  final LibraryStorage _libraryStorage = const LibraryStorage();
  final LyricsStore _lyricsStore = const LyricsStore();

  /// Lyrics already looked up this session (null = none found).
  final Map<String, Lyrics?> _lyricsCache = {};
  final LrclibClient _lrclib = LrclibClient();

  /// Opt-in: look songs up on LRCLIB when no local lyrics exist.
  final ValueNotifier<bool> _onlineLyricsListenable = ValueNotifier(false);
  final Random _random = Random();
  final Set<String> _ownedObjectUrls = {};
  final ValueNotifier<Track?> _currentTrackListenable = ValueNotifier(null);
  final ValueNotifier<String?> _pendingTrackIdListenable = ValueNotifier(null);
  final ValueNotifier<PlayQueueView> _queueListenable = ValueNotifier(
    PlayQueueView.empty,
  );

  /// Every change to the player's playlist runs through this chain so the
  /// queue mirror and the player can never be updated out of order.
  Future<void> _queueOpChain = Future.value();

  /// The queue saved by the previous launch, consumed by session restore.
  Object? _savedQueueJson;
  final ValueNotifier<bool> _shuffleEnabledListenable = ValueNotifier(false);
  final ValueNotifier<PlaybackRepeatMode> _repeatModeListenable = ValueNotifier(
    PlaybackRepeatMode.off,
  );
  final ValueNotifier<Duration> _positionListenable = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration> _durationListenable = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Set<String>> _likedIdsListenable = ValueNotifier(
    const {},
  );
  final ValueNotifier<SleepTimerState?> _sleepTimerListenable = ValueNotifier(
    null,
  );

  /// Newest like first.
  List<String> _likedTrackIds = const [];
  Map<String, int> _playCounts = const {};
  Timer? _sleepTimer;

  AudioSession? _audioSession;
  StreamSubscription<AudioInterruptionEvent>? _audioInterruptionSub;
  StreamSubscription<void>? _becomingNoisySub;
  bool _resumeAfterInterruption = false;

  late List<CollectionEntry> _entries = seedEntries();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<int?>? _currentIndexSub;

  int _tabIndex = 0;
  int _previousTabIndex = 0;
  bool _showStoryTab = true;
  bool _showLaunchTab = true;
  Track? _currentTrack;
  String? _currentEntryId;
  bool _isPlaying = false;
  bool _miniPlayerExpanded = true;
  bool _shuffleEnabled = false;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;
  String? _shuffleQueueEntryId;
  List<String> _shuffleQueue = [];
  List<_RecentPlayPointer> _recentPlays = const [];
  ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;
  late AppThemeSettings _themeSettings;
  bool _isEditMode = false;
  List<String> _customBackdropSources = const [];
  StoryContent _storyContent = StoryContent.defaults();

  /// Saving before the stored prefs are loaded would overwrite them with
  /// defaults, so persistence is held off until hydration completes.
  bool _prefsHydrated = false;
  Future<bool> _prefsWriteChain = Future.value(true);
  Duration _lastSavedPosition = Duration.zero;
  late final AppLifecycleListener _lifecycleListener;

  static const Duration _sessionSaveInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _themeSettings = widget.initialThemeSettings;
    GraffitiBackdrop.setCustomSources(_customBackdropSources);
    unawaited(_initAudioSession());
    unawaited(_hydrateAndRestoreSession());
    _lifecycleListener = AppLifecycleListener(
      onHide: _saveSessionNow,
      onPause: _saveSessionNow,
    );
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (_isPlaying && !state.playing) {
        _saveSessionNow();
      }
      final processing = state.processingState;
      setState(() {
        _isPlaying = state.playing;
        _processingState = processing;
        if (processing == ProcessingState.ready ||
            processing == ProcessingState.completed ||
            processing == ProcessingState.idle) {
          _pendingTrackIdListenable.value = null;
        }
      });
    });
    _positionSub = _audioPlayer.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      _setPlaybackPosition(position);
      if (_isPlaying &&
          (position - _lastSavedPosition).abs() >= _sessionSaveInterval) {
        _saveSessionNow();
      }
      _checkSleepAtEndOfTrack(position);
    });
    _durationSub = _audioPlayer.durationStream.listen((duration) {
      if (!mounted) {
        return;
      }
      _setPlaybackDuration(duration ?? Duration.zero);
    });
    _currentIndexSub = _audioPlayer.currentIndexStream.listen(
      _syncCurrentTrackFromQueueIndex,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _sleepTimer?.cancel();
    _likedIdsListenable.dispose();
    _sleepTimerListenable.dispose();
    _onlineLyricsListenable.dispose();
    for (final url in _ownedObjectUrls) {
      revokeObjectUrl(url);
    }
    _currentTrackListenable.dispose();
    _pendingTrackIdListenable.dispose();
    _queueListenable.dispose();
    _shuffleEnabledListenable.dispose();
    _repeatModeListenable.dispose();
    _positionListenable.dispose();
    _durationListenable.dispose();
    _audioInterruptionSub?.cancel();
    _becomingNoisySub?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _currentIndexSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<CollectionEntry> _ofType(CollectionType type) {
    final stored = _entries.where((entry) => entry.type == type).toList();
    if (type != CollectionType.playlist) {
      return stored;
    }
    // Smart playlists lead the Playlist tab once they have something in them.
    final smart = [
      for (final id in const [likedSongsEntryId, onRepeatEntryId])
        _smartEntry(id),
    ].whereType<CollectionEntry>().where((entry) => entry.tracks.isNotEmpty);
    return [...smart, ...stored];
  }

  CollectionEntry? _smartEntry(String id) {
    return buildSmartEntry(
      id,
      entries: _entries,
      likedTrackIds: _likedTrackIds,
      playCounts: _playCounts,
    );
  }

  bool _isLiked(Track track) => _likedIdsListenable.value.contains(track.id);

  void _toggleLike(Track track) {
    final wasLiked = _isLiked(track);
    final next = [..._likedTrackIds]..remove(track.id);
    if (!wasLiked) {
      next.insert(0, track.id);
    }
    setState(() {
      _likedTrackIds = next;
    });
    _likedIdsListenable.value = next.toSet();
    unawaited(_persistPrefs(notifyOnFailure: false));
    _showMessage(
      wasLiked ? 'Removed from Liked Songs.' : 'Added to Liked Songs.',
    );
  }

  void _setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (duration == null) {
      _sleepTimerListenable.value = null;
      _showMessage('Sleep timer off.');
      return;
    }
    _sleepTimer = Timer(duration, _onSleepTimerFired);
    _sleepTimerListenable.value = SleepTimerState.at(
      DateTime.now().add(duration),
    );
    _showMessage('Music will stop in ${duration.inMinutes} min.');
  }

  void _setSleepAtEndOfTrack() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerListenable.value = const SleepTimerState.endOfTrack();
    _showMessage('Music will stop at the end of this song.');
  }

  void _onSleepTimerFired() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerListenable.value = null;
    unawaited(_audioPlayer.pause());
  }

  /// Position updates arrive at most ~200ms apart while playing, so a 350ms
  /// window reliably catches the end of the song before the next one starts.
  void _checkSleepAtEndOfTrack(Duration position) {
    if (_sleepTimerListenable.value?.endOfTrack != true || !_isPlaying) {
      return;
    }
    final duration = _durationListenable.value;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 350)) {
      _onSleepTimerFired();
    }
  }

  List<Track> _allSingleTracks() {
    final tracks = <Track>[];
    for (final entry in _entries) {
      if (entry.type != CollectionType.single) {
        continue;
      }
      tracks.addAll(entry.tracks);
    }
    return tracks;
  }

  List<Track> _singleTracksByIds(List<String> ids) {
    if (ids.isEmpty) {
      return const [];
    }
    final selected = <Track>[];
    final wanted = ids.toSet();
    for (final entry in _entries) {
      if (entry.type != CollectionType.single) {
        continue;
      }
      for (final track in entry.tracks) {
        if (wanted.remove(track.id)) {
          selected.add(track);
        }
      }
      if (wanted.isEmpty) {
        break;
      }
    }
    return selected;
  }

  CollectionEntry? _entryById(String id) {
    if (CollectionEntry.isSmartId(id)) {
      return _smartEntry(id);
    }
    for (final entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  Track? _trackById(CollectionEntry entry, String trackId) {
    for (final track in entry.tracks) {
      if (track.id == trackId) {
        return track;
      }
    }
    return null;
  }

  List<RecentTrackShortcut> _recentTracksForType(CollectionType type) {
    final tracks = <RecentTrackShortcut>[];
    for (final pointer in _recentPlays) {
      final entry = _entryById(pointer.entryId);
      if (entry == null || entry.type != type) {
        continue;
      }
      final track = _trackById(entry, pointer.trackId);
      if (track == null) {
        continue;
      }
      tracks.add(RecentTrackShortcut(entry: entry, track: track));
      if (tracks.length >= 10) {
        break;
      }
    }
    return tracks;
  }

  void _rememberRecentlyPlayed({
    required String entryId,
    required String trackId,
  }) {
    if (!mounted) {
      return;
    }
    final next = [..._recentPlays]
      ..removeWhere(
        (item) => item.entryId == entryId && item.trackId == trackId,
      )
      ..insert(0, _RecentPlayPointer(entryId: entryId, trackId: trackId));
    const maxItems = 40;
    if (next.length > maxItems) {
      next.removeRange(maxItems, next.length);
    }
    setState(() {
      _recentPlays = next;
      _playCounts = {..._playCounts, trackId: (_playCounts[trackId] ?? 0) + 1};
    });
    unawaited(_persistPrefs(notifyOnFailure: false));
  }

  String _newId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(99999)}';
  }

  void _logError(String contextLabel, Object error, StackTrace stackTrace) {
    debugPrint('[$contextLabel] $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  void _setPlaybackPosition(Duration value) {
    _position = value;
    _positionListenable.value = value;
  }

  void _setPlaybackDuration(Duration value) {
    _durationListenable.value = value;
  }

  void _resetPlaybackProgress() {
    _setPlaybackPosition(Duration.zero);
    _setPlaybackDuration(Duration.zero);
  }

  Future<String?> _audioLibraryDirPath() async {
    if (kIsWeb) {
      return null;
    }
    return ensureAppSubdirectory('audio_library');
  }

  Future<void> _hydrateLibrary() async {
    final loaded = await _libraryStorage.load();
    if (!mounted) {
      return;
    }
    if (loaded == null || loaded.isEmpty) {
      final seeded = await _libraryStorage.save(_entries);
      if (!seeded) {
        debugPrint('[hydrateLibrary] Could not initialize the library cache.');
      }
      return;
    }
    setState(() {
      _entries = loaded;
    });
  }

  Future<void> _hydrateAndRestoreSession() async {
    // Load both in parallel; the session can only be resolved once the
    // library it points into is available.
    final sessionFuture = _hydratePrefs();
    await _hydrateLibrary();
    final session = await sessionFuture;
    if (!mounted) {
      return;
    }
    await _restoreLastSession(session);
  }

  /// Loads the track from the previous launch, paused at its saved position.
  Future<void> _restoreLastSession(_LastSession? session) async {
    // Skip if the user already started something while we were loading.
    if (session == null || _currentTrack != null) {
      return;
    }
    final playable = {
      for (final track in tracksById(_entries).values)
        if (_isTrackFileAvailable(track)) track.id: track,
    };
    final savedQueue = queueFromJson(
      _savedQueueJson,
      resolveTrack: (id) => playable[id],
    );
    _savedQueueJson = null;

    final PlayQueueView Function(PlayQueueView) compose;
    final Track track;
    final String entryId;
    final savedCurrent = savedQueue?.current;
    if (savedCurrent != null && savedCurrent.track.id == session.trackId) {
      // Bring back the exact queue, including songs the user lined up.
      track = savedCurrent.track;
      entryId = savedCurrent.entryId;
      compose = (_) => savedQueue!;
    } else {
      final entry = _entryById(session.entryId);
      final found = entry == null ? null : _trackById(entry, session.trackId);
      if (entry == null || found == null || playable[found.id] == null) {
        return;
      }
      track = found;
      entryId = entry.id;
      compose = (previous) => startQueue(
        previous,
        startTrack: found,
        context: _queueForEntry(entry),
        contextEntryId: entry.id,
      );
    }

    setState(() {
      _currentTrack = track;
      _currentEntryId = entryId;
      _currentTrackListenable.value = track;
    });
    _setPlaybackPosition(session.position);
    _lastSavedPosition = session.position;
    try {
      await _loadQueue(compose, position: session.position, autoplay: false);
    } catch (error, stackTrace) {
      _logError('restoreLastSession', error, stackTrace);
      await _stopAndClearCurrentTrack();
    }
  }

  void _saveSessionNow() {
    _lastSavedPosition = _position;
    unawaited(_persistPrefs(notifyOnFailure: false));
  }

  /// Returns the session saved by the previous launch, if any.
  Future<_LastSession?> _hydratePrefs() async {
    final prefs = await _prefs.load();
    if (!mounted) {
      return null;
    }
    final showStory = prefs['showStoryTab'];
    final showLaunch = prefs['showLaunchTab'];
    final editMode = prefs['editMode'];
    final customBackdropSources = _parseStringList(
      prefs['customBackdropSources'],
    );
    final themeSettings = _normalizedThemeSettings(
      AppThemeSettings.fromJson(prefs['themeSettings']),
    );
    final storyContent = StoryContent.fromJson(prefs['storyContent']);
    final recentPlays = _parseRecentPlays(prefs['recentPlays']);
    final lastSession = _LastSession.fromJson(prefs['lastSession']);
    _savedQueueJson = prefs['queue'];
    final likedTrackIds = _parseStringList(prefs['likedTrackIds']);
    final rawCounts = prefs['playCounts'];
    final playCounts = <String, int>{
      if (rawCounts is Map)
        for (final item in rawCounts.entries)
          if (item.value is num && (item.value as num) > 0)
            item.key.toString(): (item.value as num).toInt(),
    };
    final shuffle = prefs['shuffleEnabled'];
    final repeatMode = PlaybackRepeatMode.values.firstWhere(
      (mode) => mode.name == prefs['repeatMode'],
      orElse: () => PlaybackRepeatMode.off,
    );
    _likedIdsListenable.value = likedTrackIds.toSet();
    _onlineLyricsListenable.value = prefs['onlineLyrics'] == true;
    setState(() {
      _likedTrackIds = likedTrackIds;
      _playCounts = playCounts;
      _shuffleEnabled = shuffle is bool ? shuffle : false;
      _shuffleEnabledListenable.value = _shuffleEnabled;
      _repeatMode = repeatMode;
      _repeatModeListenable.value = repeatMode;
      _showStoryTab = showStory is bool ? showStory : true;
      _showLaunchTab = showLaunch is bool ? showLaunch : true;
      _isEditMode = editMode is bool ? editMode : false;
      _customBackdropSources = customBackdropSources;
      _themeSettings = themeSettings;
      _storyContent = storyContent;
      _recentPlays = recentPlays;
      _clampTabIndex();
    });
    GraffitiBackdrop.setCustomSources(customBackdropSources);
    widget.onThemeSettingsChanged(themeSettings);
    _prefsHydrated = true;
    return lastSession;
  }

  List<_RecentPlayPointer> _parseRecentPlays(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final parsed = <_RecentPlayPointer>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final pointer = _RecentPlayPointer.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (pointer != null) {
        parsed.add(pointer);
      }
    }
    return parsed;
  }

  List<String> _parseStringList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  AppThemeSettings _normalizedThemeSettings(AppThemeSettings settings) {
    final validDisplay = AppTheme.displayFontChoices.any(
      (item) => item.key == settings.displayFontKey,
    );
    final validBody = AppTheme.bodyFontChoices.any(
      (item) => item.key == settings.bodyFontKey,
    );
    const defaults = AppThemeSettings();
    return settings.copyWith(
      displayFontKey: validDisplay
          ? settings.displayFontKey
          : defaults.displayFontKey,
      bodyFontKey: validBody ? settings.bodyFontKey : defaults.bodyFontKey,
    );
  }

  Future<void> _persistLibrary() async {
    final success = await _libraryStorage.save(_entries);
    if (!success) {
      _showMessage('Could not save library changes.');
    }
  }

  Future<void> _persistPrefs({bool notifyOnFailure = true}) async {
    if (!_prefsHydrated) {
      return;
    }
    final entryId = _currentEntryId;
    final track = _currentTrack;
    final snapshot = <String, dynamic>{
      'lastSession': entryId == null || track == null
          ? null
          : _LastSession(
              entryId: entryId,
              trackId: track.id,
              position: _position,
            ).toJson(),
      'shuffleEnabled': _shuffleEnabled,
      'repeatMode': _repeatMode.name,
      'queue': _queueListenable.value.current == null
          ? null
          : queueToJson(_queueListenable.value),
      'likedTrackIds': _likedTrackIds,
      'onlineLyrics': _onlineLyricsListenable.value,
      'playCounts': _playCounts,
      'showStoryTab': _showStoryTab,
      'showLaunchTab': _showLaunchTab,
      'editMode': _isEditMode,
      'customBackdropSources': _customBackdropSources,
      'themeSettings': _themeSettings.toJson(),
      'storyContent': _storyContent.toJson(),
      'recentPlays': _recentPlays.map((item) => item.toJson()).toList(),
    };
    // Serialize writes so an older snapshot can never land after a newer one.
    final write = _prefsWriteChain.then((_) => _prefs.save(snapshot));
    _prefsWriteChain = write.catchError((Object _) => false);
    final success = await write;
    if (!success && notifyOnFailure) {
      _showMessage('Could not save app preferences.');
    }
  }

  Future<void> _initAudioSession() async {
    if (kIsWeb) {
      return;
    }
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _audioSession = session;
    _audioInterruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.pause) {
          _resumeAfterInterruption = _isPlaying;
          unawaited(_audioPlayer.pause());
        }
        return;
      }
      if (_resumeAfterInterruption) {
        _resumeAfterInterruption = false;
        unawaited(_audioSession?.setActive(true));
        unawaited(_audioPlayer.play());
      }
      _resumeAfterInterruption = false;
    });
    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
      _resumeAfterInterruption = false;
      unawaited(_audioPlayer.pause());
    });
  }

  void _setShuffleEnabled(bool enabled) {
    final changed = _shuffleEnabled != enabled;
    setState(() {
      _shuffleEnabled = enabled;
      _shuffleEnabledListenable.value = enabled;
      if (!enabled) {
        _shuffleQueueEntryId = null;
        _shuffleQueue = [];
      }
    });
    if (changed) {
      unawaited(_rebuildQueueFromContext());
      _saveSessionNow();
    }
  }

  void _cycleRepeatMode() {
    setState(() {
      final nextIndex =
          (PlaybackRepeatMode.values.indexOf(_repeatMode) + 1) %
          PlaybackRepeatMode.values.length;
      _repeatMode = PlaybackRepeatMode.values[nextIndex];
      _repeatModeListenable.value = _repeatMode;
    });
    unawaited(_applyPlayerLoopMode());
    _saveSessionNow();
  }

  LoopMode _loopModeForRepeatMode(PlaybackRepeatMode mode) {
    switch (mode) {
      case PlaybackRepeatMode.off:
        return LoopMode.off;
      case PlaybackRepeatMode.all:
        return LoopMode.all;
      case PlaybackRepeatMode.one:
        return LoopMode.one;
    }
  }

  Future<void> _applyPlayerLoopMode() async {
    try {
      await _audioPlayer.setLoopMode(_loopModeForRepeatMode(_repeatMode));
    } catch (error, stackTrace) {
      _logError('applyPlayerLoopMode', error, stackTrace);
    }
  }

  void _toggleMiniPlayerSize() {
    setState(() {
      _miniPlayerExpanded = !_miniPlayerExpanded;
    });
  }

  void _setEditMode(bool enabled) {
    if (_isEditMode == enabled) {
      return;
    }
    setState(() {
      _isEditMode = enabled;
    });
    unawaited(_persistPrefs());
  }

  void _applyThemeSettings(AppThemeSettings next, {bool persist = true}) {
    final normalized = _normalizedThemeSettings(next);
    if (_themeSettings == normalized) {
      return;
    }
    setState(() {
      _themeSettings = normalized;
    });
    widget.onThemeSettingsChanged(normalized);
    if (persist) {
      unawaited(_persistPrefs());
    }
  }

  Future<void> _openThemeEditor() async {
    if (!_isEditMode) {
      _showMessage('Enter Edit Mode to customize fonts and colors.');
      return;
    }
    final next = await showDialog<AppThemeSettings>(
      context: context,
      builder: (context) {
        return _ThemeEditorDialog(initialSettings: _themeSettings);
      },
    );
    if (!mounted || next == null) {
      return;
    }
    _applyThemeSettings(next);
    _showMessage('Appearance updated.');
  }

  String _imageMimeTypeForFileName(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.svg':
        return 'image/svg+xml';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<String?> _persistBackdropImageFile(PlatformFile file) async {
    final sourcePath = file.path?.trim() ?? '';
    if (kIsWeb) {
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        final mimeType = _imageMimeTypeForFileName(file.name);
        return 'data:$mimeType;base64,${base64Encode(file.bytes!)}';
      }
      return sourcePath.isEmpty ? null : sourcePath;
    }

    return _copyImageIntoAppDirectory(sourcePath, 'background_images');
  }

  /// Copies a picked image into an app-owned directory so it survives the
  /// picker's cache being cleared. Returns null if the source is unreadable.
  Future<String?> _copyImageIntoAppDirectory(
    String sourcePath,
    String directoryName,
  ) async {
    if (kIsWeb || sourcePath.isEmpty) {
      return null;
    }
    final uri = _audioUriFromPath(sourcePath);
    if (uri != null && uri.scheme != 'file') {
      return sourcePath;
    }
    final sourceFilePath = uri == null ? sourcePath : localFilePathFromUri(uri);
    if (!await localFileExists(sourceFilePath)) {
      return null;
    }

    final targetDir = await ensureAppSubdirectory(directoryName);
    if (targetDir == null || path.isWithin(targetDir, sourceFilePath)) {
      return sourceFilePath;
    }

    final extension = path.extension(sourceFilePath);
    final targetPath = path.join(
      targetDir,
      '${_newId()}${extension.isEmpty ? '.jpg' : extension}',
    );
    try {
      final copied = await copyLocalFileToPath(
        sourcePath: sourceFilePath,
        targetPath: targetPath,
      );
      return copied ?? sourceFilePath;
    } catch (error, stackTrace) {
      _logError('copyImageIntoAppDirectory', error, stackTrace);
      return null;
    }
  }

  Future<String?> _persistThumbnailPath(String? rawPath) async {
    final trimmed = rawPath?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return await _copyImageIntoAppDirectory(trimmed, 'thumbnails') ?? trimmed;
  }

  Future<void> _uploadBackdropImages() async {
    if (!_isEditMode) {
      _showMessage('Enter Edit Mode before uploading background images.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final sources = <String>[];
    for (final file in result.files) {
      final persisted = await _persistBackdropImageFile(file);
      if (persisted != null && persisted.isNotEmpty) {
        sources.add(persisted);
      }
    }
    if (sources.isEmpty) {
      _showMessage('No valid images selected.');
      return;
    }

    final next = [..._customBackdropSources];
    for (final source in sources) {
      if (!next.contains(source)) {
        next.add(source);
      }
    }

    setState(() {
      _customBackdropSources = next;
    });
    GraffitiBackdrop.setCustomSources(next);
    unawaited(_persistPrefs());
    _showMessage('${sources.length} background image(s) added.');
  }

  void _resetBackdropImages() {
    if (!_isEditMode) {
      _showMessage('Enter Edit Mode before editing backgrounds.');
      return;
    }
    setState(() {
      _customBackdropSources = const [];
    });
    GraffitiBackdrop.setCustomSources(const []);
    unawaited(_persistPrefs());
    _showMessage('Background images reset to default.');
  }

  Future<void> _openStoryEditor() async {
    if (!_isEditMode) {
      _showMessage('Enter Edit Mode before editing Story.');
      return;
    }
    final next = await showDialog<StoryContent>(
      context: context,
      builder: (context) {
        return _StoryEditorDialog(initialContent: _storyContent);
      },
    );
    if (!mounted || next == null) {
      return;
    }
    setState(() {
      _storyContent = next;
    });
    unawaited(_persistPrefs());
    _showMessage('Story updated.');
  }

  Future<bool> _confirmDelete({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _showTrackDetails(Track track, {CollectionEntry? entry}) async {
    if (!mounted) {
      return;
    }
    final textTheme = Theme.of(context).textTheme;
    final filePath = track.filePath.trim();
    final collectionLabel = entry == null
        ? 'Unknown'
        : '${entry.title} (${entry.type.label})';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge,
                          ),
                          Text(
                            track.artist.isEmpty ? 'Unknown' : track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Collection', style: textTheme.labelLarge),
                Text(collectionLabel),
                if (filePath.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('File', style: textTheme.labelLarge),
                  SelectableText(filePath, maxLines: 2),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNowPlaying({String title = 'Now Playing'}) async {
    final track = _currentTrack;
    if (track == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NowPlayingPage(
          title: title,
          resolveEntry: _entryById,
          currentTrackListenable: _currentTrackListenable,
          playerStateStream: _audioPlayer.playerStateStream,
          positionStream: _audioPlayer.positionStream,
          durationStream: _audioPlayer.durationStream,
          onJumpToQueueItem: _jumpToQueueItem,
          onRemoveFromQueue: _removeQueueItem,
          onMoveQueueItem: _moveQueueItem,
          onOpenLyrics: _openLyrics,
          onSeek: _seekTo,
          onTogglePlayback: _togglePlayback,
          onSkipNext: _playNextInEntry,
          onSkipPrevious: _playPreviousInEntry,
          onToggleShuffle: () => _setShuffleEnabled(!_shuffleEnabled),
          onCycleRepeat: _cycleRepeatMode,
          queueListenable: _queueListenable,
          shuffleEnabledListenable: _shuffleEnabledListenable,
          repeatModeListenable: _repeatModeListenable,
          onShowTrackDetails: _showTrackDetailsFromEntry,
          likedTrackIdsListenable: _likedIdsListenable,
          onToggleLike: _toggleLike,
          sleepTimerListenable: _sleepTimerListenable,
          onSetSleepTimer: _setSleepTimer,
          onSleepAtEndOfTrack: _setSleepAtEndOfTrack,
        ),
      ),
    );
  }

  Future<void> _openQueuedNowPlaying() async {
    await _openNowPlaying(title: 'Queued');
  }

  List<RecentTrackShortcut> _allRecentTrackShortcuts() {
    final tracks = <RecentTrackShortcut>[];
    for (final pointer in _recentPlays) {
      final entry = _entryById(pointer.entryId);
      if (entry == null) {
        continue;
      }
      final track = _trackById(entry, pointer.trackId);
      if (track == null) {
        continue;
      }
      tracks.add(RecentTrackShortcut(entry: entry, track: track));
      if (tracks.length >= 12) {
        break;
      }
    }
    return tracks;
  }

  Future<void> _openLibrarySearch() async {
    if (!mounted) {
      return;
    }
    await showSearch<void>(
      context: context,
      delegate: _LibrarySearchDelegate(
        entries: _entries,
        recentTracks: _allRecentTrackShortcuts(),
        onOpenCollection: _openDetail,
        onPlayTrack: _playTrackFromEntry,
        onPlayNext: _playTrackNext,
        onAddToQueue: _addTrackToQueue,
      ),
    );
  }

  Future<void> _playFromType(
    CollectionType type, {
    required bool shuffle,
  }) async {
    final candidates = _entries
        .where((entry) => entry.type == type && entry.tracks.isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      _showMessage(
        'No songs in ${type.label.toLowerCase()} yet. Upload tracks first.',
      );
      return;
    }

    final entry = shuffle
        ? candidates[_random.nextInt(candidates.length)]
        : candidates.first;
    final track = shuffle
        ? entry.tracks[_random.nextInt(entry.tracks.length)]
        : entry.tracks.first;
    await _playTrackFromEntry(track, entry);
  }

  Future<void> _playTrackFromEntry(Track track, CollectionEntry entry) async {
    await _playTrack(track, entryId: entry.id);
  }

  Future<void> _toggleOrPlayTrackFromEntry(
    Track track,
    CollectionEntry entry,
  ) async {
    if (_currentTrack?.id == track.id) {
      await _togglePlayback();
      return;
    }
    await _playTrack(track, entryId: entry.id);
  }

  Future<void> _showTrackDetailsFromEntry(
    Track track,
    CollectionEntry entry,
  ) async {
    await _showTrackDetails(track, entry: entry);
  }

  void _releaseTrackResources(Track track) {
    final raw = track.filePath.trim();
    if (raw.startsWith('blob:') && _ownedObjectUrls.remove(raw)) {
      revokeObjectUrl(raw);
    }
  }

  Future<void> _deleteManagedAudioIfUnused(String filePath) async {
    if (kIsWeb) {
      return;
    }
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final uri = _audioUriFromPath(trimmed);
    if (uri != null && uri.scheme != 'file') {
      return;
    }

    final audioDirPath = await _audioLibraryDirPath();
    if (audioDirPath == null) {
      return;
    }
    final onDiskPath = uri == null ? trimmed : localFilePathFromUri(uri);
    if (!path.isWithin(audioDirPath, onDiskPath)) {
      return;
    }

    final stillUsed = _entries.any(
      (entry) => entry.tracks.any((t) => t.filePath.trim() == trimmed),
    );
    if (stillUsed) {
      return;
    }

    try {
      await deleteLocalFile(onDiskPath);
    } catch (error, stackTrace) {
      _logError('deleteManagedAudioIfUnused', error, stackTrace);
    }
  }

  Future<void> _stopAndClearCurrentTrack() async {
    try {
      await _audioPlayer.stop();
    } catch (error, stackTrace) {
      _logError('stopAndClearCurrentTrack', error, stackTrace);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _currentTrack = null;
      _currentEntryId = null;
      _currentTrackListenable.value = null;
      _isPlaying = false;
    });
    _queueListenable.value = PlayQueueView.empty;
    _resetPlaybackProgress();
    _pendingTrackIdListenable.value = null;
    _saveSessionNow();
  }

  Future<void> _deleteTrackFromEntry(String entryId, Track track) async {
    final entry = _entryById(entryId);
    if (entry == null) {
      return;
    }

    final ok = await _confirmDelete(
      title: 'Delete Song',
      body: 'Remove "${track.title}" from "${entry.title}"?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) {
      return;
    }

    if (_currentTrack?.id == track.id) {
      await _stopAndClearCurrentTrack();
    }

    _releaseTrackResources(track);

    final updated = entry.copyWith(
      tracks: entry.tracks.where((t) => t.id != track.id).toList(),
    );
    _replaceEntry(updated);
    _pruneQueueOfDeletedTracks();
    _forgetLyricsOfDeletedTracks([track]);
    unawaited(_deleteManagedAudioIfUnused(track.filePath));
    _showMessage('Song deleted.');
  }

  Future<void> _deleteCollection(CollectionEntry entry) async {
    final ok = await _confirmDelete(
      title: 'Delete ${entry.type.label}',
      body: 'Delete "${entry.title}" from your library?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) {
      return;
    }

    final removedTracks = entry.tracks;
    if (removedTracks.any((t) => t.id == _currentTrack?.id)) {
      await _stopAndClearCurrentTrack();
    }

    for (final t in removedTracks) {
      _releaseTrackResources(t);
    }

    setState(() {
      _entries = _entries.where((e) => e.id != entry.id).toList();
    });
    _pruneQueueOfDeletedTracks();
    _forgetLyricsOfDeletedTracks(removedTracks);
    unawaited(_persistLibrary());
    for (final t in removedTracks) {
      unawaited(_deleteManagedAudioIfUnused(t.filePath));
    }
    _showMessage('${entry.type.label} deleted.');
  }

  Future<void> _deleteStoryTab() async {
    if (!_showStoryTab) {
      return;
    }
    final ok = await _confirmDelete(
      title: 'Remove Story Tab',
      body: 'This hides the Story tab. You can restore it later.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() {
      _showStoryTab = false;
      _clampTabIndex();
    });
    unawaited(_persistPrefs());
  }

  Future<void> _restoreStoryTab() async {
    if (_showStoryTab) {
      return;
    }
    setState(() {
      _showStoryTab = true;
      _clampTabIndex();
    });
    unawaited(_persistPrefs());
  }

  Future<void> _deleteLaunchTab() async {
    if (!_showLaunchTab) {
      return;
    }
    final ok = await _confirmDelete(
      title: 'Remove Launch Tab',
      body: 'This hides the Launch tab. You can restore it later.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() {
      _showLaunchTab = false;
      _clampTabIndex();
    });
    unawaited(_persistPrefs());
  }

  Future<void> _restoreLaunchTab() async {
    if (_showLaunchTab) {
      return;
    }
    setState(() {
      _showLaunchTab = true;
      _clampTabIndex();
    });
    unawaited(_persistPrefs());
  }

  List<_HomeTab> _visibleTabs() {
    final tabs = <_HomeTab>[
      _HomeTab.albums,
      _HomeTab.singles,
      _HomeTab.features,
      _HomeTab.playlist,
    ];
    if (_showStoryTab) {
      tabs.add(_HomeTab.story);
    }
    if (_showLaunchTab) {
      tabs.add(_HomeTab.launch);
    }
    return tabs;
  }

  void _clampTabIndex() {
    final tabs = _visibleTabs();
    final maxIndex = tabs.isEmpty ? 0 : tabs.length - 1;
    if (_tabIndex > maxIndex) {
      _tabIndex = maxIndex;
      _previousTabIndex = _tabIndex;
    }
  }

  String _titleForTab(_HomeTab tab) {
    switch (tab) {
      case _HomeTab.albums:
        return 'Albums';
      case _HomeTab.singles:
        return 'Singles';
      case _HomeTab.features:
        return 'Features';
      case _HomeTab.playlist:
        return 'Playlist';
      case _HomeTab.story:
        return 'Story';
      case _HomeTab.launch:
        return 'Launch';
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _looksLikeAudioUri(String value) {
    return value.startsWith('content://') ||
        value.startsWith('file://') ||
        value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('blob:') ||
        value.startsWith('data:');
  }

  Uri? _audioUriFromPath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty || !_looksLikeAudioUri(trimmed)) {
      return null;
    }
    return Uri.tryParse(trimmed);
  }

  Uri? _notificationArtUri(Track track, CollectionEntry? entry) {
    if (kIsWeb) {
      return null;
    }
    for (final candidate in [track.artworkPath, entry?.thumbnailPath]) {
      final trimmed = candidate?.trim() ?? '';
      if (trimmed.isNotEmpty && localFileExistsSync(trimmed)) {
        return Uri.file(trimmed);
      }
    }
    return null;
  }

  MediaItem _mediaItemForTrack(Track track, {CollectionEntry? entry}) {
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: entry?.title ?? entry?.type.label,
      artUri: _notificationArtUri(track, entry),
    );
  }

  AudioSource _buildAudioSourceForTrack(Track track, {CollectionEntry? entry}) {
    final rawPath = track.filePath.trim();
    final sourceUri = _audioUriFromPath(rawPath) ?? Uri.file(rawPath);
    return AudioSource.uri(
      sourceUri,
      tag: _mediaItemForTrack(track, entry: entry),
    );
  }

  Future<String?> _persistAudioFile(PlatformFile file) async {
    final sourcePath = file.path?.trim() ?? '';
    if (sourcePath.isEmpty) {
      if (kIsWeb && file.bytes != null && file.bytes!.isNotEmpty) {
        final url = createObjectUrlFromBytes(file.bytes!);
        if (url != null && url.isNotEmpty) {
          _ownedObjectUrls.add(url);
          return url;
        }
      }
      return null;
    }
    if (kIsWeb) {
      return sourcePath;
    }

    final uri = _audioUriFromPath(sourcePath);
    if (uri != null && uri.scheme != 'file') {
      return sourcePath;
    }

    final sourceFilePath = uri == null ? sourcePath : localFilePathFromUri(uri);
    if (!await localFileExists(sourceFilePath)) {
      return sourcePath;
    }

    final audioDirPath = await _audioLibraryDirPath();
    if (audioDirPath == null) {
      return sourcePath;
    }
    if (path.isWithin(audioDirPath, sourceFilePath)) {
      return sourceFilePath;
    }

    final extension = path.extension(sourceFilePath);
    final targetPath = path.join(
      audioDirPath,
      '${_newId()}${extension.isEmpty ? '' : extension}',
    );
    try {
      final copiedPath = await copyLocalFileToPath(
        sourcePath: sourceFilePath,
        targetPath: targetPath,
      );
      return copiedPath ?? sourcePath;
    } catch (error, stackTrace) {
      _logError('persistAudioFile', error, stackTrace);
      return sourcePath;
    }
  }

  Future<List<Track>> _tracksFromFiles(
    List<PlatformFile> files, {
    required String artist,
  }) async {
    final tracks = <Track>[];
    for (final file in files) {
      final filePath = await _persistAudioFile(file);
      if (filePath == null || filePath.isEmpty) {
        continue;
      }
      final tags = await _readTagsForStoredFile(filePath);
      final baseName = file.name.isNotEmpty ? file.name : filePath;
      final fileTitle = path
          .basenameWithoutExtension(baseName)
          .replaceAll('_', ' ')
          .trim();
      final trackId = _newId();
      await _importSidecarLyrics(file, trackId);
      tracks.add(
        Track(
          id: trackId,
          title:
              tags?.title ?? (fileTitle.isEmpty ? 'Untitled Track' : fileTitle),
          artist: tags?.artist ?? artist,
          filePath: filePath,
          artworkPath: await _storeTrackArtwork(tags),
        ),
      );
    }
    return tracks;
  }

  /// The on-disk path behind a stored track path, or null for web and
  /// non-file URIs (content://, http://, blob:).
  String? _localPathForStored(String storedPath) {
    final trimmed = storedPath.trim();
    if (kIsWeb || trimmed.isEmpty) {
      return null;
    }
    final uri = _audioUriFromPath(trimmed);
    if (uri != null && uri.scheme != 'file') {
      return null;
    }
    return uri == null ? trimmed : localFilePathFromUri(uri);
  }

  Future<AudioTags?> _readTagsForStoredFile(String storedPath) async {
    final localPath = _localPathForStored(storedPath);
    return localPath == null ? null : readAudioTags(localPath);
  }

  /// Imported songs are copied under new names, so a `song.lrc` next to the
  /// original would be lost; keep it with the track instead.
  Future<void> _importSidecarLyrics(PlatformFile file, String trackId) async {
    final sourcePath = file.path;
    final localSource = sourcePath == null
        ? null
        : _localPathForStored(sourcePath);
    if (localSource == null) {
      return;
    }
    final sidecar = await readSidecarLyrics(localSource);
    if (Lyrics.tryParse(sidecar) != null) {
      await _lyricsStore.write(trackId, sidecar!);
    }
  }

  /// Imported lyrics first, then a `.lrc` beside the file, then lyrics
  /// embedded in the file's tags.
  Future<Lyrics?> _loadLyrics(Track track) async {
    if (_lyricsCache.containsKey(track.id)) {
      return _lyricsCache[track.id];
    }
    var lyrics = Lyrics.tryParse(await _lyricsStore.read(track.id));
    final localPath = _localPathForStored(track.filePath);
    if (lyrics == null && localPath != null) {
      lyrics = Lyrics.tryParse(await readSidecarLyrics(localPath));
      lyrics ??= Lyrics.tryParse((await readAudioTags(localPath))?.lyrics);
    }
    if (lyrics == null && _onlineLyricsListenable.value) {
      try {
        lyrics = await _fetchOnlineLyrics(track);
      } on LrclibUnavailableException {
        // Don't remember "no lyrics": LRCLIB may be back next time.
        _showMessage("Couldn't reach LRCLIB. Try again in a moment.");
        return null;
      }
    }
    _lyricsCache[track.id] = lyrics;
    return lyrics;
  }

  /// Looks the song up on LRCLIB and saves what it finds, so it works
  /// offline from then on.
  Future<Lyrics?> _fetchOnlineLyrics(Track track) async {
    final duration = _currentTrack?.id == track.id
        ? _durationListenable.value
        : null;
    final text = await _lrclib.fetch(
      title: track.title,
      artist: track.artist,
      duration: duration,
    );
    final lyrics = Lyrics.tryParse(text);
    if (lyrics != null) {
      unawaited(_lyricsStore.write(track.id, text!));
    }
    return lyrics;
  }

  /// Asks before turning on online lookups, since song titles and artists
  /// leave the device. Returns whether online lyrics are now on.
  Future<bool> _enableOnlineLyrics() async {
    if (_onlineLyricsListenable.value) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find lyrics online?'),
        content: const Text(
          'When a song has no lyrics on this device, II.VI will look it up on '
          'LRCLIB (lrclib.net), a free, community-run lyrics database.\n\n'
          'Only the song\'s title, artist and length are sent. Lyrics that are '
          'found are saved on this device. You can turn this off any time '
          'from the menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return false;
    }
    _setOnlineLyrics(true);
    return true;
  }

  void _setOnlineLyrics(bool enabled) {
    if (_onlineLyricsListenable.value == enabled) {
      return;
    }
    _onlineLyricsListenable.value = enabled;
    if (enabled) {
      // Songs that had no lyrics earlier deserve another look.
      _lyricsCache.removeWhere((_, lyrics) => lyrics == null);
    }
    setState(() {});
    unawaited(_persistPrefs(notifyOnFailure: false));
    _showMessage(enabled ? 'Online lyrics on.' : 'Online lyrics off.');
  }

  Future<Lyrics?> _importLyricsFor(Track track) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['lrc', 'txt'],
      withData: true,
    );
    final bytes = result?.files.firstOrNull?.bytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final lyrics = Lyrics.tryParse(text);
    if (lyrics == null) {
      _showMessage('That file has no lyrics in it.');
      return null;
    }
    if (!await _lyricsStore.write(track.id, text)) {
      _showMessage('Could not save these lyrics.');
      return null;
    }
    _lyricsCache[track.id] = lyrics;
    _showMessage(
      lyrics.isSynced
          ? 'Synced lyrics added.'
          : 'Lyrics added (not time-synced).',
    );
    return lyrics;
  }

  Future<void> _removeLyricsFor(Track track) async {
    await _lyricsStore.delete(track.id);
    _lyricsCache.remove(track.id);
    _showMessage('Imported lyrics removed.');
  }

  /// Deletes stored lyrics for tracks that no longer exist anywhere.
  void _forgetLyricsOfDeletedTracks(Iterable<Track> removed) {
    final alive = tracksById(_entries);
    for (final track in removed) {
      if (!alive.containsKey(track.id)) {
        _lyricsCache.remove(track.id);
        unawaited(_lyricsStore.delete(track.id));
      }
    }
  }

  Future<void> _openLyrics() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LyricsPage(
          currentTrackListenable: _currentTrackListenable,
          positionStream: _audioPlayer.positionStream,
          initialPosition: _position,
          onSeek: _seekTo,
          loadLyrics: _loadLyrics,
          onImportLyrics: _importLyricsFor,
          onRemoveLyrics: _removeLyricsFor,
          onlineLyricsListenable: _onlineLyricsListenable,
          onEnableOnlineLyrics: _enableOnlineLyrics,
        ),
      ),
    );
  }

  /// Saves embedded cover art under a content-derived name, so every track
  /// from the same album shares one file instead of writing a copy each.
  Future<String?> _storeTrackArtwork(AudioTags? tags) async {
    if (kIsWeb || tags == null || !tags.hasCover) {
      return null;
    }
    final bytes = tags.coverBytes!;
    try {
      final artworkDir = await ensureAppSubdirectory('track_artwork');
      if (artworkDir == null) {
        return null;
      }
      final hash = Object.hashAll(bytes).toUnsigned(32).toRadixString(16);
      final fileName = 'art_${bytes.length}_$hash${tags.coverExtension}';
      return await writeLocalFileBytesIfAbsent(
        targetPath: path.join(artworkDir, fileName),
        bytes: bytes,
      );
    } catch (error, stackTrace) {
      _logError('storeTrackArtwork', error, stackTrace);
      return null;
    }
  }

  bool _isRescanning = false;

  /// Re-reads tags for every stored song so tracks imported before tag
  /// support get proper titles, artists and cover art.
  Future<void> _rescanSongInfo() async {
    if (_isRescanning) {
      return;
    }
    _isRescanning = true;
    _showMessage('Scanning your songs…');
    try {
      final updates = <String, Track>{};
      for (final track in tracksById(_entries).values) {
        if (track.filePath.trim().isEmpty) {
          continue;
        }
        final tags = await _readTagsForStoredFile(track.filePath);
        if (tags == null) {
          continue;
        }
        final updated = track.copyWith(
          title: tags.title,
          artist: tags.artist,
          artworkPath: await _storeTrackArtwork(tags),
        );
        if (!updated.hasSameInfoAs(track)) {
          updates[track.id] = updated;
        }
      }
      if (!mounted) {
        return;
      }
      if (updates.isEmpty) {
        _showMessage('All song info is already up to date.');
        return;
      }

      // Apply to the library as it is now, not as it was when the scan
      // started, so edits made during the scan are kept.
      final merged = [
        for (final entry in _entries)
          if (!entry.tracks.any((track) => updates.containsKey(track.id)))
            entry
          else
            _withFallbackThumbnail(
              entry.copyWith(
                tracks: [
                  for (final track in entry.tracks) updates[track.id] ?? track,
                ],
              ),
              entry.tracks.map((track) => updates[track.id] ?? track).toList(),
            ),
      ];
      final current = _currentTrack;
      final updatedCurrent = current == null ? null : updates[current.id];
      setState(() {
        _entries = merged;
        if (updatedCurrent != null) {
          _currentTrack = updatedCurrent;
          _currentTrackListenable.value = updatedCurrent;
        }
      });
      final view = _queueListenable.value;
      _queueListenable.value = view.copyWith(
        items: [
          for (final item in view.items)
            updates[item.track.id] == null
                ? item
                : item.withTrack(updates[item.track.id]!),
        ],
      );
      unawaited(_persistLibrary());
      _showMessage('Updated info for ${updates.length} song(s).');
    } finally {
      _isRescanning = false;
    }
  }

  /// Uses the first imported track's cover when the collection has none.
  CollectionEntry _withFallbackThumbnail(
    CollectionEntry entry,
    List<Track> tracks,
  ) {
    final hasThumbnail =
        (entry.thumbnailPath?.isNotEmpty ?? false) ||
        (entry.thumbnailDataBase64?.isNotEmpty ?? false);
    if (hasThumbnail) {
      return entry;
    }
    for (final track in tracks) {
      final artwork = track.artworkPath;
      if (artwork != null && artwork.isNotEmpty) {
        return entry.withThumbnail(thumbnailPath: artwork);
      }
    }
    return entry;
  }

  void _replaceEntry(CollectionEntry updated) {
    setState(() {
      _entries = _entries
          .map((entry) => entry.id == updated.id ? updated : entry)
          .toList();
    });
    if (_queueListenable.value.contextEntryId == updated.id) {
      unawaited(_rebuildQueueFromContext());
    }
    unawaited(_persistLibrary());
  }

  void _ensureShuffleQueue(CollectionEntry entry) {
    if (!_shuffleEnabled) {
      return;
    }
    final trackIds = entry.tracks.map((track) => track.id).toList();
    final trackIdSet = trackIds.toSet();
    final isSameEntry = _shuffleQueueEntryId == entry.id;
    final isSameLength = _shuffleQueue.length == trackIds.length;
    final matches =
        isSameEntry &&
        isSameLength &&
        _shuffleQueue.toSet().containsAll(trackIdSet);
    if (matches) {
      return;
    }
    _shuffleQueueEntryId = entry.id;
    _shuffleQueue = [...trackIds]..shuffle(_random);
  }

  List<Track> _queueForEntry(CollectionEntry entry) {
    if (!_shuffleEnabled) {
      return entry.tracks;
    }
    _ensureShuffleQueue(entry);
    final queue = <Track>[];
    for (final id in _shuffleQueue) {
      final track = _trackById(entry, id);
      if (track != null) {
        queue.add(track);
      }
    }
    return queue;
  }

  void _syncCurrentTrackFromQueueIndex(int? index) {
    if (!mounted || index == null || index < 0) {
      return;
    }
    final view = _queueListenable.value;
    if (index >= view.items.length) {
      return;
    }
    if (view.currentIndex != index) {
      _queueListenable.value = view.copyWith(currentIndex: index);
      // Like Spotify, a queued song leaves the queue once playback moves past
      // it, so repeat-all doesn't play it again.
      final played = {
        for (var i = 0; i < index; i++)
          if (view.items[i].userQueued) view.items[i].uid,
      };
      if (played.isNotEmpty) {
        unawaited(_removeFromQueueWhere((item) => played.contains(item.uid)));
      }
    }

    final item = view.items[index];
    if (_currentTrack?.id == item.track.id && _currentEntryId == item.entryId) {
      return;
    }
    setState(() {
      _currentEntryId = item.entryId;
      _currentTrack = item.track;
      _currentTrackListenable.value = item.track;
    });
    _pendingTrackIdListenable.value = null;
    _rememberRecentlyPlayed(entryId: item.entryId, trackId: item.track.id);
  }

  Future<T> _runQueueOp<T>(Future<T> Function() op) {
    final result = _queueOpChain.then((_) => op());
    _queueOpChain = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// Replaces the whole playlist. [compose] receives the queue as it is when
  /// the operation runs, not when it was requested.
  Future<void> _loadQueue(
    PlayQueueView Function(PlayQueueView current) compose, {
    Duration position = Duration.zero,
    required bool autoplay,
  }) {
    return _runQueueOp(() async {
      final view = compose(_queueListenable.value);
      if (view.current == null) {
        return;
      }
      _queueListenable.value = view;
      await _audioPlayer.setAudioSources(
        [
          for (final item in view.items)
            _buildAudioSourceForTrack(
              item.track,
              entry: _entryById(item.entryId),
            ),
        ],
        initialIndex: view.currentIndex,
        initialPosition: position,
      );
      await _applyPlayerLoopMode();
      if (autoplay) {
        await _audioSession?.setActive(true);
        await _audioPlayer.play();
      }
    });
  }

  /// Re-reads the collection being played (after shuffle is toggled or its
  /// songs change) while keeping the current song and the user's queue.
  Future<void> _rebuildQueueFromContext() async {
    final contextId = _queueListenable.value.contextEntryId;
    if (contextId == null || _queueListenable.value.current == null) {
      return;
    }
    final resumePosition = _position;
    final resumePlayback = _isPlaying;
    try {
      await _loadQueue(
        (current) {
          final contextEntry = _entryById(contextId);
          return recomposeQueue(
            current,
            context: contextEntry == null
                ? const []
                : _queueForEntry(contextEntry),
            contextEntryId: contextId,
          );
        },
        position: resumePosition,
        autoplay: resumePlayback,
      );
    } catch (error, stackTrace) {
      _logError('rebuildQueueFromContext', error, stackTrace);
    }
  }

  /// "Play next" / "Add to queue". Starts playback if nothing is loaded.
  Future<void> _enqueueTrack(
    Track track,
    CollectionEntry entry, {
    required bool playNext,
  }) async {
    if (_queueListenable.value.current == null) {
      await _playTrack(track, entryId: entry.id);
      return;
    }
    if (!_isTrackFileAvailable(track)) {
      _showMessage('Track file not found. Upload a local file for this song.');
      return;
    }
    final item = QueueItem(track: track, entryId: entry.id, userQueued: true);
    try {
      await _runQueueOp(() async {
        final view = _queueListenable.value;
        final index = playNext
            ? playNextInsertIndex(view)
            : addToQueueInsertIndex(view);
        // Update the mirror first so index events from the player resolve
        // against the new layout.
        _queueListenable.value = view.copyWith(
          items: [...view.items]..insert(index, item),
        );
        try {
          await _audioPlayer.insertAudioSource(
            index,
            _buildAudioSourceForTrack(track, entry: entry),
          );
        } catch (_) {
          final latest = _queueListenable.value;
          _queueListenable.value = latest.copyWith(
            items: [
              for (final other in latest.items)
                if (other.uid != item.uid) other,
            ],
          );
          rethrow;
        }
      });
      _saveSessionNow();
      _showMessage(
        playNext
            ? 'Playing next: ${track.title}'
            : 'Added to queue: ${track.title}',
      );
    } catch (error, stackTrace) {
      _logError('enqueueTrack', error, stackTrace);
      _showMessage('Could not add this song to the queue.');
    }
  }

  Future<void> _playTrackNext(Track track, CollectionEntry entry) =>
      _enqueueTrack(track, entry, playNext: true);

  Future<void> _addTrackToQueue(Track track, CollectionEntry entry) =>
      _enqueueTrack(track, entry, playNext: false);

  /// Removes items other than the one playing that match [test].
  Future<void> _removeFromQueueWhere(bool Function(QueueItem item) test) {
    return _runQueueOp(() async {
      final view = _queueListenable.value;
      final doomed = [
        for (var i = view.items.length - 1; i >= 0; i--)
          if (i != view.currentIndex && test(view.items[i])) i,
      ];
      if (doomed.isEmpty) {
        return;
      }
      final items = [...view.items];
      var currentIndex = view.currentIndex;
      for (final index in doomed) {
        items.removeAt(index);
        if (index < currentIndex) {
          currentIndex--;
        }
      }
      _queueListenable.value = view.copyWith(
        items: items,
        currentIndex: currentIndex,
      );
      try {
        for (final index in doomed) {
          await _audioPlayer.removeAudioSourceAt(index);
        }
      } catch (error, stackTrace) {
        _logError('removeFromQueue', error, stackTrace);
      }
    });
  }

  void _removeQueueItem(String uid) {
    unawaited(
      _removeFromQueueWhere(
        (item) => item.uid == uid,
      ).then((_) => _saveSessionNow()),
    );
  }

  /// Drag-to-reorder in Now Playing. [offset] is the target position among
  /// the upcoming songs (0 = straight after the current song).
  void _moveQueueItem(String uid, int offset) {
    unawaited(
      _runQueueOp(() async {
        final view = _queueListenable.value;
        final from = view.indexOfUid(uid);
        final to = view.currentIndex + 1 + offset;
        final next = moveQueueItem(view, from, to);
        if (identical(next, view)) {
          return;
        }
        _queueListenable.value = next;
        if (from == to) {
          return;
        }
        try {
          await _audioPlayer.moveAudioSource(from, to);
        } catch (error, stackTrace) {
          _logError('moveQueueItem', error, stackTrace);
        }
      }).then((_) => _saveSessionNow()),
    );
  }

  /// Drops queued copies of songs that no longer exist in the library.
  void _pruneQueueOfDeletedTracks() {
    // Resolved when the operation runs, after any queued rebuild.
    Set<String>? alive;
    unawaited(
      _removeFromQueueWhere(
        (item) => !(alive ??= tracksById(
          _entries,
        ).keys.toSet()).contains(item.track.id),
      ),
    );
  }

  Future<void> _jumpToQueueItem(String uid) async {
    final index = _queueListenable.value.indexOfUid(uid);
    if (index < 0) {
      return;
    }
    try {
      await _audioPlayer.seek(Duration.zero, index: index);
      if (!_isPlaying) {
        await _audioSession?.setActive(true);
        await _audioPlayer.play();
      }
    } catch (error, stackTrace) {
      _logError('jumpToQueueItem', error, stackTrace);
    }
  }

  bool _isTrackFileAvailable(Track track) {
    final rawPath = track.filePath.trim();
    if (rawPath.isEmpty) {
      return false;
    }
    if (kIsWeb) {
      return true;
    }
    final uri = _audioUriFromPath(rawPath);
    if (uri == null) {
      return localFileExistsSync(rawPath);
    }
    if (uri.scheme == 'file') {
      return localFileUriExistsSync(uri);
    }
    return true;
  }

  Future<void> _playTrack(Track track, {String? entryId}) async {
    if (!_isTrackFileAvailable(track)) {
      _showMessage('Track file not found. Upload a local file for this song.');
      return;
    }

    final nextEntryId = entryId ?? _currentEntryId ?? '';
    try {
      if (_currentTrack?.id == track.id &&
          _queueListenable.value.contextEntryId == nextEntryId) {
        if (!_isPlaying) {
          await _audioSession?.setActive(true);
          await _audioPlayer.play();
        }
        return;
      }

      // Immediate feedback: show the mini-player context and a loading state.
      setState(() {
        _currentTrack = track;
        _currentEntryId = nextEntryId;
        _currentTrackListenable.value = track;
      });
      _resetPlaybackProgress();
      _pendingTrackIdListenable.value = track.id;
      final entry = _entryById(nextEntryId);
      final context = entry == null || entry.tracks.isEmpty
          ? [track]
          : _queueForEntry(entry);
      await _loadQueue(
        (previous) => startQueue(
          previous,
          startTrack: track,
          context: context,
          contextEntryId: nextEntryId,
        ),
        autoplay: true,
      );
      _rememberRecentlyPlayed(entryId: nextEntryId, trackId: track.id);
      if (!mounted) {
        return;
      }
      _setPlaybackPosition(Duration.zero);
    } catch (error, stackTrace) {
      _logError('playTrack', error, stackTrace);
      _pendingTrackIdListenable.value = null;
      _showMessage('Unable to play this track.');
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> _togglePlayback() async {
    if (_currentTrack == null) {
      return;
    }
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioSession?.setActive(true);
        await _audioPlayer.play();
      }
    } catch (error, stackTrace) {
      _logError('togglePlayback', error, stackTrace);
      _showMessage('Playback control failed.');
    }
  }

  Future<void> _playNextInEntry() async {
    final queue = _queueListenable.value.items;
    if (queue.isEmpty) {
      return;
    }
    final currentIndex =
        _audioPlayer.currentIndex ?? _queueListenable.value.currentIndex;
    if (currentIndex < 0) {
      return;
    }
    if (currentIndex < queue.length - 1) {
      await _audioPlayer.seek(Duration.zero, index: currentIndex + 1);
      return;
    }
    if (_repeatMode == PlaybackRepeatMode.all) {
      await _audioPlayer.seek(Duration.zero, index: 0);
    }
  }

  Future<void> _playPreviousInEntry() async {
    final queue = _queueListenable.value.items;
    if (queue.isEmpty) {
      return;
    }
    if (_position > const Duration(seconds: 3)) {
      await _seekTo(Duration.zero);
      return;
    }
    final currentIndex =
        _audioPlayer.currentIndex ?? _queueListenable.value.currentIndex;
    if (currentIndex < 0) {
      return;
    }
    if (currentIndex > 0) {
      await _audioPlayer.seek(Duration.zero, index: currentIndex - 1);
      return;
    }
    if (_repeatMode == PlaybackRepeatMode.all) {
      await _audioPlayer.seek(Duration.zero, index: queue.length - 1);
      return;
    }
    await _seekTo(Duration.zero);
  }

  Future<void> _reorderEntryTracks(
    String entryId,
    int oldIndex,
    int newIndex,
  ) async {
    final entry = _entryById(entryId);
    if (entry == null || entry.tracks.length < 2) {
      return;
    }

    final tracks = [...entry.tracks];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final moved = tracks.removeAt(oldIndex);
    final target = newIndex.clamp(0, tracks.length).toInt();
    tracks.insert(target, moved);
    _replaceEntry(entry.copyWith(tracks: tracks));
  }

  Future<CollectionEntry?> _pickAndSetThumbnail(String entryId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selected = result.files.first;
    final thumbPath = selected.path?.trim();
    final shouldStoreBase64 = kIsWeb || thumbPath == null || thumbPath.isEmpty;
    final thumbData =
        shouldStoreBase64 &&
            selected.bytes != null &&
            selected.bytes!.isNotEmpty
        ? base64Encode(selected.bytes!)
        : null;
    if ((thumbPath == null || thumbPath.isEmpty) && thumbData == null) {
      _showMessage('Could not read selected image.');
      return null;
    }

    final storedThumbPath = thumbData == null
        ? await _persistThumbnailPath(thumbPath)
        : null;
    final current = _entryById(entryId);
    if (current == null) {
      return null;
    }

    final updated = current.withThumbnail(
      thumbnailPath: storedThumbPath,
      thumbnailDataBase64: thumbData,
    );
    _replaceEntry(updated);
    _showMessage('Thumbnail updated for ${updated.title}.');
    return updated;
  }

  Future<CollectionEntry?> _uploadSongsToEntry(String entryId) async {
    final current = _entryById(entryId);
    if (current == null) {
      return null;
    }

    final files = await _pickAudioPlatformFiles();
    if (files.isEmpty) {
      return null;
    }

    final tracks = await _tracksFromFiles(files, artist: 'J. Cole');
    if (tracks.isEmpty) {
      _showMessage('No valid audio files selected.');
      return null;
    }

    final updated = _withFallbackThumbnail(
      current.copyWith(tracks: [...current.tracks, ...tracks]),
      tracks,
    );
    _replaceEntry(updated);
    _showMessage('${tracks.length} song(s) added to ${updated.title}.');
    return updated;
  }

  Future<_SongImportSource?> _pickSongImportSource() async {
    if (kIsWeb) {
      return _SongImportSource.files;
    }
    return showModalBottomSheet<_SongImportSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Import Songs'),
                subtitle: Text('Choose files or a folder'),
              ),
              ListTile(
                leading: const Icon(Icons.audio_file_outlined),
                title: const Text('Pick Audio Files'),
                onTap: () => Navigator.pop(context, _SongImportSource.files),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Pick Folder'),
                subtitle: const Text(
                  'Detects songs recursively and supports bulk selection',
                ),
                onTap: () => Navigator.pop(context, _SongImportSource.folder),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<PlatformFile>> _pickAudioPlatformFiles() async {
    final source = await _pickSongImportSource();
    if (source == null) {
      return const [];
    }

    if (source == _SongImportSource.files) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        withData: kIsWeb,
      );
      return result?.files ?? const [];
    }

    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Music Folder',
      );
      if (directoryPath == null || directoryPath.trim().isEmpty) {
        return const [];
      }
      final normalizedDirectoryPath = _normalizeDirectoryPathForListing(
        directoryPath,
      );
      if (normalizedDirectoryPath == null) {
        return const [];
      }
      final filePaths = await listAudioFilesRecursively(
        normalizedDirectoryPath,
      );
      if (filePaths.isEmpty) {
        _showMessage('No supported audio files found in selected folder.');
        return const [];
      }
      if (!mounted) {
        return const [];
      }
      final selectedPaths = await _showFolderAudioBulkPicker(
        context: context,
        rootDirectory: normalizedDirectoryPath,
        filePaths: filePaths,
        title: 'Select Songs To Upload',
      );
      if (selectedPaths == null || selectedPaths.isEmpty) {
        if (selectedPaths != null) {
          _showMessage('No songs selected.');
        }
        return const [];
      }
      return _platformFilesFromPaths(selectedPaths);
    } catch (error, stackTrace) {
      _logError('pickAudioPlatformFiles', error, stackTrace);
      _showMessage('Could not import folder audio files.');
      return const [];
    }
  }

  Future<void> _uploadSongsToTypeCollection(CollectionType type) async {
    final candidates = _entries.where((entry) => entry.type == type).toList();
    if (candidates.isEmpty) {
      _showMessage('Add a ${type.label.toLowerCase()} before uploading songs.');
      return;
    }

    if (candidates.length == 1) {
      await _uploadSongsToEntry(candidates.first.id);
      return;
    }

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              ListTile(
                title: Text('Upload Songs To ${type.label}'),
                subtitle: const Text('Pick one collection'),
              ),
              for (final entry in candidates)
                ListTile(
                  leading: Icon(type.icon),
                  title: Text(entry.title),
                  onTap: () => Navigator.pop(context, entry.id),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || selectedId == null) {
      return;
    }
    await _uploadSongsToEntry(selectedId);
  }

  Future<void> _createCollection(CollectionType type) async {
    final availableSingleTracks = type == CollectionType.playlist
        ? _allSingleTracks()
        : const <Track>[];
    final draft = await showDialog<_NewCollectionDraft>(
      context: context,
      builder: (context) {
        return _CreateCollectionDialog(
          type: type,
          availableSingleTracks: availableSingleTracks,
        );
      },
    );

    if (!mounted || draft == null) {
      return;
    }

    final tracks = await _tracksFromFiles(
      draft.selectedSongs,
      artist: 'J. Cole',
    );
    final thumbnailPath = draft.thumbnailDataBase64 == null
        ? await _persistThumbnailPath(draft.thumbnailPath)
        : null;
    if (!mounted) {
      return;
    }

    final fromSingles = type == CollectionType.playlist
        ? _singleTracksByIds(draft.selectedSingleTrackIds)
        : const <Track>[];
    final effectiveTracks = [...fromSingles, ...tracks];

    final created = _withFallbackThumbnail(
      CollectionEntry(
        id: _newId(),
        type: type,
        title: draft.title,
        history: draft.history,
        featuredArtists: draft.featuredArtists,
        tracks: effectiveTracks,
        thumbnailPath: thumbnailPath,
        thumbnailDataBase64: draft.thumbnailDataBase64,
      ),
      effectiveTracks,
    );

    setState(() {
      _entries = [..._entries, created];
    });
    unawaited(_persistLibrary());
    if (type == CollectionType.playlist && fromSingles.isNotEmpty) {
      _showMessage(
        '${created.title} added with ${fromSingles.length} single(s).',
      );
    } else {
      _showMessage('${created.title} added.');
    }
  }

  Future<void> _openDetail(CollectionEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionDetailPage(
          entry: entry,
          currentTrackListenable: _currentTrackListenable,
          playerStateStream: _audioPlayer.playerStateStream,
          pendingTrackIdListenable: _pendingTrackIdListenable,
          onPlayTrack: _playTrackFromEntry,
          onToggleTrack: _toggleOrPlayTrackFromEntry,
          onOpenNowPlaying: _openNowPlaying,
          onOpenQueuedNowPlaying: _openQueuedNowPlaying,
          queueListenable: _queueListenable,
          onJumpToQueueItem: _jumpToQueueItem,
          onPlayNext: _playTrackNext,
          onAddToQueue: _addTrackToQueue,
          onShowTrackDetails: _showTrackDetailsFromEntry,
          onReorderTracks: _reorderEntryTracks,
          onDeleteTrack: _deleteTrackFromEntry,
          onMenuAction: _runMenuAction,
          resolveEntry: _entryById,
          likedTrackIdsListenable: _likedIdsListenable,
          onToggleLike: _toggleLike,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _runMenuAction(
    CollectionEntry entry,
    EntryMenuAction action,
  ) async {
    switch (action) {
      case EntryMenuAction.open:
        await _openDetail(entry);
        break;
      case EntryMenuAction.editThumbnail:
        await _pickAndSetThumbnail(entry.id);
        break;
      case EntryMenuAction.uploadSongs:
        await _uploadSongsToEntry(entry.id);
        break;
      case EntryMenuAction.deleteCollection:
        await _deleteCollection(entry);
        break;
    }
  }

  void _onTabSelected(int index) {
    final maxIndex = _visibleTabs().length - 1;
    final clamped = index.clamp(0, maxIndex).toInt();
    if (clamped == _tabIndex) {
      return;
    }
    setState(() {
      _previousTabIndex = _tabIndex;
      _tabIndex = clamped;
    });
  }

  Widget _buildLibraryPage(CollectionType type, String keyName) {
    return LibraryPage(
      key: ValueKey(keyName),
      tabType: type,
      entries: _ofType(type),
      recentTracks: _recentTracksForType(type),
      onOpen: _openDetail,
      onPlayRecentTrack: _playTrackFromEntry,
      onPlayNext: _playTrackNext,
      onAddToQueue: _addTrackToQueue,
      onCreateCollection: () => _createCollection(type),
      onUploadToCollection: () => _uploadSongsToTypeCollection(type),
      onPlayAll: () => _playFromType(type, shuffle: false),
      onShufflePlay: () => _playFromType(type, shuffle: true),
      onMenuAction: _runMenuAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs();
    final maxIndex = tabs.length - 1;
    final effectiveIndex = _tabIndex.clamp(0, maxIndex);
    final currentTab = tabs[effectiveIndex];
    final page = switch (currentTab) {
      _HomeTab.albums => _buildLibraryPage(CollectionType.album, 'albums'),
      _HomeTab.singles => _buildLibraryPage(CollectionType.single, 'singles'),
      _HomeTab.features => _buildLibraryPage(
        CollectionType.feature,
        'features',
      ),
      _HomeTab.playlist => _buildLibraryPage(
        CollectionType.playlist,
        'playlists',
      ),
      _HomeTab.story => ArtistHistoryPage(
        key: const ValueKey('story'),
        content: _storyContent,
        isEditMode: _isEditMode,
        onEditStory: _openStoryEditor,
      ),
      _HomeTab.launch => SplashCatalogPage(
        key: const ValueKey('launch'),
        autoAdvance: false,
        tagLabel: 'Launch Screen',
        secondaryCtaLabel: 'Back',
        primaryCtaLabel: 'Back To Vault',
        onFinished: () => _onTabSelected(0),
      ),
    };

    final previousIndex = _previousTabIndex.clamp(0, maxIndex);
    final slideFromRight = effectiveIndex > previousIndex;
    final offsetStart = slideFromRight
        ? const Offset(0.2, 0)
        : const Offset(-0.2, 0);

    return GraffitiScaffold(
      appBar: AppBar(
        centerTitle: false,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: Image.asset(
            'assets/logo26.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        title: Text(
          _titleForTab(currentTab),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(letterSpacing: 1.2),
        ),
        actions: [
          if (_isEditMode)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(
                child: Chip(
                  avatar: Icon(Icons.edit, size: 16),
                  label: Text('Edit Mode'),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Search library',
            icon: const Icon(Icons.search),
            onPressed: _openLibrarySearch,
          ),
          PopupMenuButton<String>(
            tooltip: 'App options',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'enter_edit':
                  _setEditMode(true);
                  _showMessage('Edit mode enabled.');
                  break;
                case 'exit_edit':
                  _setEditMode(false);
                  _showMessage('Edit mode disabled.');
                  break;
                case 'theme_editor':
                  await _openThemeEditor();
                  break;
                case 'upload_backgrounds':
                  await _uploadBackdropImages();
                  break;
                case 'reset_backgrounds':
                  _resetBackdropImages();
                  break;
                case 'edit_story':
                  await _openStoryEditor();
                  break;
                case 'remove_story':
                  await _deleteStoryTab();
                  break;
                case 'restore_story':
                  await _restoreStoryTab();
                  break;
                case 'remove_launch':
                  await _deleteLaunchTab();
                  break;
                case 'restore_launch':
                  await _restoreLaunchTab();
                  break;
                case 'rescan_songs':
                  await _rescanSongInfo();
                  break;
                case 'online_lyrics':
                  if (_onlineLyricsListenable.value) {
                    _setOnlineLyrics(false);
                  } else {
                    await _enableOnlineLyrics();
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              if (_isEditMode)
                const PopupMenuItem(
                  value: 'exit_edit',
                  child: Text('Exit Edit Mode'),
                )
              else
                const PopupMenuItem(
                  value: 'enter_edit',
                  child: Text('Enter Edit Mode'),
                ),
              if (_isEditMode) const PopupMenuDivider(),
              if (_isEditMode)
                const PopupMenuItem(
                  value: 'theme_editor',
                  child: Text('Edit Fonts & Colors'),
                ),
              if (_isEditMode)
                const PopupMenuItem(
                  value: 'upload_backgrounds',
                  child: Text('Upload Background Images'),
                ),
              if (_isEditMode)
                PopupMenuItem(
                  value: 'reset_backgrounds',
                  child: Text(
                    _customBackdropSources.isEmpty
                        ? 'Use Default Backgrounds'
                        : 'Reset Backgrounds To Default',
                  ),
                ),
              if (_isEditMode && currentTab == _HomeTab.story)
                const PopupMenuItem(
                  value: 'edit_story',
                  child: Text('Edit Story Content'),
                ),
              const PopupMenuDivider(),
              if (!kIsWeb)
                const PopupMenuItem(
                  value: 'rescan_songs',
                  child: Text('Rescan Song Info'),
                ),
              CheckedPopupMenuItem(
                value: 'online_lyrics',
                checked: _onlineLyricsListenable.value,
                child: const Text('Find Lyrics Online'),
              ),
              if (_showStoryTab)
                const PopupMenuItem(
                  value: 'remove_story',
                  child: Text('Remove Story Tab'),
                )
              else
                const PopupMenuItem(
                  value: 'restore_story',
                  child: Text('Restore Story Tab'),
                ),
              if (_showLaunchTab)
                const PopupMenuItem(
                  value: 'remove_launch',
                  child: Text('Remove Launch Tab'),
                )
              else
                const PopupMenuItem(
                  value: 'restore_launch',
                  child: Text('Restore Launch Tab'),
                ),
            ],
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: offsetStart,
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: page,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _currentTrack == null
                  ? const SizedBox.shrink(key: ValueKey('mini_empty'))
                  : MiniPlayerBar(
                      key: const ValueKey('mini_player'),
                      track: _currentTrack!,
                      entry: _currentEntryId == null
                          ? null
                          : _entryById(_currentEntryId!),
                      isPlaying: _isPlaying,
                      isLoading: _processingState == ProcessingState.loading,
                      isBuffering:
                          _processingState == ProcessingState.buffering,
                      durationListenable: _durationListenable,
                      positionListenable: _positionListenable,
                      onToggle: _togglePlayback,
                      onOpenNowPlaying: _openNowPlaying,
                      isExpanded: _miniPlayerExpanded,
                      onToggleSize: _toggleMiniPlayerSize,
                      onSeek: _seekTo,
                      onPrevious: _playPreviousInEntry,
                      onNext: _playNextInEntry,
                      onToggleShuffle: () =>
                          _setShuffleEnabled(!_shuffleEnabled),
                      shuffleEnabled: _shuffleEnabled,
                      isLiked: _isLiked(_currentTrack!),
                      onToggleLike: () => _toggleLike(_currentTrack!),
                    ),
            ),
            FloatingNavBar(
              selectedIndex: effectiveIndex,
              onSelected: _onTabSelected,
              items: [
                const NavItem(
                  label: 'Albums',
                  icon: Icons.library_books_outlined,
                  selectedIcon: Icons.library_books,
                ),
                const NavItem(
                  label: 'Singles',
                  icon: Icons.music_note_outlined,
                  selectedIcon: Icons.music_note,
                ),
                const NavItem(
                  label: 'Features',
                  icon: Icons.mic_external_on_outlined,
                  selectedIcon: Icons.mic_external_on,
                ),
                const NavItem(
                  label: 'Playlist',
                  icon: Icons.playlist_play_outlined,
                  selectedIcon: Icons.playlist_play,
                ),
                if (_showStoryTab)
                  const NavItem(
                    label: 'Story',
                    icon: Icons.history_edu_outlined,
                    selectedIcon: Icons.history_edu,
                  ),
                if (_showLaunchTab)
                  const NavItem(
                    label: 'Launch',
                    icon: Icons.rocket_launch_outlined,
                    selectedIcon: Icons.rocket_launch,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPlayPointer {
  const _RecentPlayPointer({required this.entryId, required this.trackId});

  final String entryId;
  final String trackId;

  Map<String, dynamic> toJson() {
    return {'entryId': entryId, 'trackId': trackId};
  }

  static _RecentPlayPointer? fromJson(Map<String, dynamic> json) {
    final entryId = (json['entryId'] ?? '').toString().trim();
    final trackId = (json['trackId'] ?? '').toString().trim();
    if (entryId.isEmpty || trackId.isEmpty) {
      return null;
    }
    return _RecentPlayPointer(entryId: entryId, trackId: trackId);
  }
}

class _LastSession {
  const _LastSession({
    required this.entryId,
    required this.trackId,
    required this.position,
  });

  final String entryId;
  final String trackId;
  final Duration position;

  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'trackId': trackId,
      'positionMs': position.inMilliseconds,
    };
  }

  static _LastSession? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final entryId = (raw['entryId'] ?? '').toString().trim();
    final trackId = (raw['trackId'] ?? '').toString().trim();
    if (entryId.isEmpty || trackId.isEmpty) {
      return null;
    }
    final positionMs = raw['positionMs'];
    return _LastSession(
      entryId: entryId,
      trackId: trackId,
      position: Duration(
        milliseconds: positionMs is num && positionMs > 0
            ? positionMs.toInt()
            : 0,
      ),
    );
  }
}

class _TrackSearchHit {
  const _TrackSearchHit({required this.entry, required this.track});

  final CollectionEntry entry;
  final Track track;
}

class _LibrarySearchDelegate extends SearchDelegate<void> {
  _LibrarySearchDelegate({
    required this.entries,
    required this.recentTracks,
    required this.onOpenCollection,
    required this.onPlayTrack,
    required this.onPlayNext,
    required this.onAddToQueue,
  });

  final List<CollectionEntry> entries;
  final List<RecentTrackShortcut> recentTracks;
  final Future<void> Function(CollectionEntry entry) onOpenCollection;
  final Future<void> Function(Track track, CollectionEntry entry) onPlayTrack;
  final Future<void> Function(Track track, CollectionEntry entry) onPlayNext;
  final Future<void> Function(Track track, CollectionEntry entry) onAddToQueue;

  Widget _queueMenu(Track track, CollectionEntry entry) {
    return TrackQueueMenuButton(
      onPlayNext: () => onPlayNext(track, entry),
      onAddToQueue: () => onAddToQueue(track, entry),
    );
  }

  @override
  String get searchFieldLabel => 'Search songs, artists, collections';

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) {
      return null;
    }
    return [
      IconButton(
        tooltip: 'Clear',
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchBody(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchBody(context);
  }

  List<CollectionEntry> _matchingCollections(String rawQuery) {
    if (rawQuery.isEmpty) {
      return const [];
    }
    return entries
        .where((entry) {
          final haystack = [
            entry.title,
            entry.history,
            entry.type.label,
            ...entry.featuredArtists,
          ].join(' ').toLowerCase();
          return haystack.contains(rawQuery);
        })
        .take(20)
        .toList();
  }

  List<_TrackSearchHit> _matchingTracks(String rawQuery) {
    if (rawQuery.isEmpty) {
      return const [];
    }
    final hits = <_TrackSearchHit>[];
    for (final entry in entries) {
      for (final track in entry.tracks) {
        final haystack = [
          track.title,
          track.artist,
          entry.title,
          entry.type.label,
        ].join(' ').toLowerCase();
        if (haystack.contains(rawQuery)) {
          hits.add(_TrackSearchHit(entry: entry, track: track));
        }
      }
    }
    return hits.take(30).toList();
  }

  Future<void> _openCollectionResult(
    BuildContext context,
    CollectionEntry entry,
  ) async {
    close(context, null);
    await onOpenCollection(entry);
  }

  Future<void> _playTrackResult(
    BuildContext context,
    Track track,
    CollectionEntry entry,
  ) async {
    close(context, null);
    await onPlayTrack(track, entry);
  }

  Widget _buildSearchBody(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final collections = _matchingCollections(normalizedQuery);
    final tracks = _matchingTracks(normalizedQuery);
    final hasQuery = normalizedQuery.isNotEmpty;

    if (!hasQuery && recentTracks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        children: const [
          ListTile(
            leading: Icon(Icons.search),
            title: Text('Search your vault'),
            subtitle: Text('Try a track title, artist name, or collection.'),
          ),
        ],
      );
    }

    if (hasQuery && collections.isEmpty && tracks.isEmpty) {
      return const Center(child: Text('No matches found.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        if (!hasQuery && recentTracks.isNotEmpty) ...[
          Text('Recent Plays', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in recentTracks)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(item.track.title),
              subtitle: Text('${item.entry.title} • ${item.entry.type.label}'),
              trailing: _queueMenu(item.track, item.entry),
              onTap: () => _playTrackResult(context, item.track, item.entry),
            ),
        ],
        if (hasQuery && tracks.isNotEmpty) ...[
          Text('Songs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final hit in tracks)
            ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(hit.track.title),
              subtitle: Text('${hit.track.artist} • ${hit.entry.title}'),
              trailing: _queueMenu(hit.track, hit.entry),
              onTap: () => _playTrackResult(context, hit.track, hit.entry),
            ),
          const SizedBox(height: 8),
        ],
        if (hasQuery && collections.isNotEmpty) ...[
          Text('Collections', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in collections)
            ListTile(
              leading: Icon(entry.type.icon),
              title: Text(entry.title),
              subtitle: Text(
                '${entry.type.label} • ${entry.tracks.length} song(s)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openCollectionResult(context, entry),
            ),
        ],
      ],
    );
  }
}

List<PlatformFile> _platformFilesFromPaths(List<String> paths) {
  final files = <PlatformFile>[];
  for (final rawPath in paths) {
    final filePath = rawPath.trim();
    if (filePath.isEmpty) {
      continue;
    }
    files.add(
      PlatformFile(name: path.basename(filePath), size: 0, path: filePath),
    );
  }
  return files;
}

String? _normalizeDirectoryPathForListing(String rawDirectoryPath) {
  final trimmed = rawDirectoryPath.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.scheme == 'file') {
    return localFilePathFromUri(uri);
  }
  return trimmed;
}

Future<List<String>?> _showFolderAudioBulkPicker({
  required BuildContext context,
  required String rootDirectory,
  required List<String> filePaths,
  required String title,
}) async {
  if (filePaths.isEmpty) {
    return const [];
  }

  final selected = List<bool>.filled(filePaths.length, true);
  var selectedCount = selected.length;
  final relativePaths = [
    for (final filePath in filePaths)
      path.relative(filePath, from: rootDirectory),
  ];

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.86,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${filePaths.length} detected • $selectedCount selected',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              for (int i = 0; i < selected.length; i++) {
                                selected[i] = true;
                              }
                              selectedCount = selected.length;
                            });
                          },
                          child: const Text('Select All'),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              for (int i = 0; i < selected.length; i++) {
                                selected[i] = false;
                              }
                              selectedCount = 0;
                            });
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filePaths.length,
                      itemBuilder: (context, index) {
                        final isChecked = selected[index];
                        final fullPath = filePaths[index];
                        final relative = relativePaths[index];
                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(
                            path.basename(fullPath),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            relative,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          onChanged: (value) {
                            final next = value ?? false;
                            if (next == selected[index]) {
                              return;
                            }
                            setModalState(() {
                              selected[index] = next;
                              if (next) {
                                selectedCount += 1;
                              } else {
                                selectedCount -= 1;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: selectedCount == 0
                              ? null
                              : () {
                                  final picked = <String>[];
                                  for (int i = 0; i < filePaths.length; i++) {
                                    if (selected[i]) {
                                      picked.add(filePaths[i]);
                                    }
                                  }
                                  Navigator.pop(context, picked);
                                },
                          icon: const Icon(Icons.library_add),
                          label: Text('Add $selectedCount'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _NewCollectionDraft {
  const _NewCollectionDraft({
    required this.title,
    required this.history,
    required this.featuredArtists,
    required this.selectedSongs,
    required this.selectedSingleTrackIds,
    this.thumbnailPath,
    this.thumbnailDataBase64,
  });

  final String title;
  final String history;
  final List<String> featuredArtists;
  final List<PlatformFile> selectedSongs;
  final List<String> selectedSingleTrackIds;
  final String? thumbnailPath;
  final String? thumbnailDataBase64;
}

class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog({
    required this.type,
    required this.availableSingleTracks,
  });

  final CollectionType type;
  final List<Track> availableSingleTracks;

  @override
  State<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<_CreateCollectionDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();
  final TextEditingController _featuredController = TextEditingController();

  String? _thumbnailPath;
  String? _thumbnailDataBase64;
  String? _thumbnailLabel;
  List<PlatformFile> _selectedSongs = [];
  Set<String> _selectedSingleTrackIds = <String>{};

  @override
  void dispose() {
    _titleController.dispose();
    _historyController.dispose();
    _featuredController.dispose();
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final selected = result.files.first;
    setState(() {
      _thumbnailPath = selected.path?.trim();
      final shouldStoreBase64 =
          kIsWeb || _thumbnailPath == null || _thumbnailPath!.isEmpty;
      _thumbnailDataBase64 =
          shouldStoreBase64 &&
              selected.bytes != null &&
              selected.bytes!.isNotEmpty
          ? base64Encode(selected.bytes!)
          : null;
      _thumbnailLabel = selected.path == null
          ? selected.name
          : path.basename(selected.path!);
    });
  }

  Future<void> _pickSongs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    setState(() {
      _selectedSongs = result.files;
    });
  }

  Future<void> _pickSongsFromFolder() async {
    if (kIsWeb) {
      _showDialogMessage('Folder upload is not supported on web.');
      return;
    }
    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Music Folder',
      );
      if (!mounted || directoryPath == null || directoryPath.trim().isEmpty) {
        return;
      }
      final normalizedDirectoryPath = _normalizeDirectoryPathForListing(
        directoryPath,
      );
      if (normalizedDirectoryPath == null) {
        return;
      }
      final paths = await listAudioFilesRecursively(normalizedDirectoryPath);
      if (!mounted) {
        return;
      }
      if (paths.isEmpty) {
        _showDialogMessage(
          'No supported audio files found in selected folder.',
        );
        return;
      }
      final selectedPaths = await _showFolderAudioBulkPicker(
        context: context,
        rootDirectory: normalizedDirectoryPath,
        filePaths: paths,
        title: 'Select Songs To Add',
      );
      if (!mounted) {
        return;
      }
      if (selectedPaths == null || selectedPaths.isEmpty) {
        if (selectedPaths != null) {
          _showDialogMessage('No songs selected.');
        }
        return;
      }
      setState(() {
        _selectedSongs = _platformFilesFromPaths(selectedPaths);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showDialogMessage('Could not import songs from folder.');
    }
  }

  void _showDialogMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickTracksFromSingles() async {
    final sourceTracks = widget.availableSingleTracks;
    if (sourceTracks.isEmpty) {
      return;
    }

    final selected = Set<String>.from(_selectedSingleTrackIds);
    final chosen = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.85,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Add Singles To Playlist',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(selected.clear);
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sourceTracks.length,
                        itemBuilder: (context, index) {
                          final track = sourceTracks[index];
                          final selectedNow = selected.contains(track.id);
                          return CheckboxListTile(
                            value: selectedNow,
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track.artist.isEmpty
                                  ? 'Unknown artist'
                                  : track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  selected.add(track.id);
                                } else {
                                  selected.remove(track.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, selected),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || chosen == null) {
      return;
    }
    setState(() {
      _selectedSingleTrackIds = chosen;
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    final featured = _featuredController.text
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    Navigator.pop(
      context,
      _NewCollectionDraft(
        title: title,
        history: _historyController.text.trim(),
        featuredArtists: featured,
        selectedSongs: _selectedSongs,
        selectedSingleTrackIds: _selectedSingleTrackIds.toList(),
        thumbnailPath: _thumbnailPath,
        thumbnailDataBase64: _thumbnailDataBase64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New ${widget.type.label}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter collection name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _historyController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Brief history',
                hintText: 'Context about release and era',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _featuredController,
              decoration: const InputDecoration(
                labelText: 'Featured artists (comma separated)',
                hintText: 'e.g. 21 Savage, Lil Baby',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.image_outlined),
              label: Text(_thumbnailLabel ?? 'Select Thumbnail'),
              onPressed: _pickThumbnail,
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.music_note),
              label: Text(
                _selectedSongs.isEmpty
                    ? 'Upload Songs'
                    : '${_selectedSongs.length} song(s) selected',
              ),
              onPressed: _pickSongs,
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Upload Folder'),
                onPressed: _pickSongsFromFolder,
              ),
            ],
            if (widget.type == CollectionType.playlist) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.library_music),
                label: Text(
                  _selectedSingleTrackIds.isEmpty
                      ? 'Add From Existing Singles'
                      : '${_selectedSingleTrackIds.length} single(s) added',
                ),
                onPressed: widget.availableSingleTracks.isEmpty
                    ? null
                    : _pickTracksFromSingles,
              ),
              if (widget.availableSingleTracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No singles available yet. Add songs in Singles first.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _ThemeEditorDialog extends StatefulWidget {
  const _ThemeEditorDialog({required this.initialSettings});

  final AppThemeSettings initialSettings;

  @override
  State<_ThemeEditorDialog> createState() => _ThemeEditorDialogState();
}

class _ThemeEditorDialogState extends State<_ThemeEditorDialog> {
  static const List<_ColorOption> _accentColors = [
    _ColorOption(label: 'Gold', value: 0xFFFFB547),
    _ColorOption(label: 'Sky', value: 0xFF5CC8FF),
    _ColorOption(label: 'Mint', value: 0xFF2EE6D6),
    _ColorOption(label: 'Rose', value: 0xFFFF6B6B),
    _ColorOption(label: 'Lime', value: 0xFFB4FF5C),
    _ColorOption(label: 'Purple', value: 0xFFB084FF),
  ];

  static const List<_ColorOption> _backgroundColors = [
    _ColorOption(label: 'Black', value: 0xFF0C0B0A),
    _ColorOption(label: 'Slate', value: 0xFF101720),
    _ColorOption(label: 'Brown', value: 0xFF15110E),
    _ColorOption(label: 'Graphite', value: 0xFF111111),
    _ColorOption(label: 'Midnight', value: 0xFF0B1220),
    _ColorOption(label: 'Olive', value: 0xFF13160F),
  ];

  late String _displayFontKey;
  late String _bodyFontKey;
  late int _primaryColorValue;
  late int _secondaryColorValue;
  late int _backgroundColorValue;

  @override
  void initState() {
    super.initState();
    _displayFontKey = widget.initialSettings.displayFontKey;
    _bodyFontKey = widget.initialSettings.bodyFontKey;
    _primaryColorValue = widget.initialSettings.primaryColorValue;
    _secondaryColorValue = widget.initialSettings.secondaryColorValue;
    _backgroundColorValue = widget.initialSettings.backgroundColorValue;
  }

  Widget _buildColorOptions({
    required String title,
    required List<_ColorOption> options,
    required int selectedValue,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                selected: selectedValue == option.value,
                label: Text(option.label),
                avatar: CircleAvatar(
                  radius: 9,
                  backgroundColor: Color(option.value),
                ),
                onSelected: (_) => onChanged(option.value),
              ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    Navigator.pop(
      context,
      AppThemeSettings(
        primaryColorValue: _primaryColorValue,
        secondaryColorValue: _secondaryColorValue,
        backgroundColorValue: _backgroundColorValue,
        displayFontKey: _displayFontKey,
        bodyFontKey: _bodyFontKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Fonts & Colors'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _displayFontKey,
                decoration: const InputDecoration(labelText: 'Display font'),
                items: [
                  for (final option in AppTheme.displayFontChoices)
                    DropdownMenuItem(
                      value: option.key,
                      child: Text(option.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _displayFontKey = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _bodyFontKey,
                decoration: const InputDecoration(labelText: 'Body font'),
                items: [
                  for (final option in AppTheme.bodyFontChoices)
                    DropdownMenuItem(
                      value: option.key,
                      child: Text(option.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _bodyFontKey = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildColorOptions(
                title: 'Primary color',
                options: _accentColors,
                selectedValue: _primaryColorValue,
                onChanged: (value) {
                  setState(() {
                    _primaryColorValue = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildColorOptions(
                title: 'Secondary color',
                options: _accentColors,
                selectedValue: _secondaryColorValue,
                onChanged: (value) {
                  setState(() {
                    _secondaryColorValue = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildColorOptions(
                title: 'Background color',
                options: _backgroundColors,
                selectedValue: _backgroundColorValue,
                onChanged: (value) {
                  setState(() {
                    _backgroundColorValue = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Apply')),
      ],
    );
  }
}

class _StoryEditorDialog extends StatefulWidget {
  const _StoryEditorDialog({required this.initialContent});

  final StoryContent initialContent;

  @override
  State<_StoryEditorDialog> createState() => _StoryEditorDialogState();
}

class _StoryEditorDialogState extends State<_StoryEditorDialog> {
  late TextEditingController _heroTitleController;
  late TextEditingController _heroSummaryController;
  late TextEditingController _timelineController;
  late List<_StorySectionDraft> _sectionDrafts;

  @override
  void initState() {
    super.initState();
    _heroTitleController = TextEditingController(
      text: widget.initialContent.heroTitle,
    );
    _heroSummaryController = TextEditingController(
      text: widget.initialContent.heroSummary,
    );
    _timelineController = TextEditingController(
      text: _encodeTimeline(widget.initialContent.timelineEvents),
    );
    _sectionDrafts = [
      for (final section in widget.initialContent.sections)
        _StorySectionDraft.fromSection(section),
    ];
  }

  @override
  void dispose() {
    _heroTitleController.dispose();
    _heroSummaryController.dispose();
    _timelineController.dispose();
    for (final draft in _sectionDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  String _encodeTimeline(List<StoryEvent> events) {
    return events
        .map((event) => '${event.year} | ${event.title} | ${event.note}')
        .join('\n');
  }

  List<StoryEvent> _parseTimeline(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    final events = <StoryEvent>[];
    for (final line in lines) {
      final parts = line.split('|').map((item) => item.trim()).toList();
      if (parts.length < 3) {
        continue;
      }
      final year = parts[0];
      final title = parts[1];
      final note = parts.sublist(2).join(' | ');
      if (year.isEmpty || title.isEmpty || note.isEmpty) {
        continue;
      }
      events.add(StoryEvent(year: year, title: title, note: note));
    }
    return events;
  }

  void _resetDefaults() {
    final defaults = StoryContent.defaults();
    // The old controllers are still attached to TextFields until the next
    // frame rebuilds with the new drafts, so dispose them after that frame.
    final staleDrafts = _sectionDrafts;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final draft in staleDrafts) {
        draft.dispose();
      }
    });
    setState(() {
      _heroTitleController.text = defaults.heroTitle;
      _heroSummaryController.text = defaults.heroSummary;
      _timelineController.text = _encodeTimeline(defaults.timelineEvents);
      _sectionDrafts = [
        for (final section in defaults.sections)
          _StorySectionDraft.fromSection(section),
      ];
    });
  }

  void _submit() {
    final heroTitle = _heroTitleController.text.trim();
    final heroSummary = _heroSummaryController.text.trim();
    if (heroTitle.isEmpty || heroSummary.isEmpty) {
      return;
    }
    final sections = <StorySection>[];
    for (final draft in _sectionDrafts) {
      final section = draft.toSection();
      if (section != null) {
        sections.add(section);
      }
    }
    if (sections.isEmpty) {
      return;
    }

    final events = _parseTimeline(_timelineController.text.trim());
    final effectiveEvents = events.isEmpty
        ? widget.initialContent.timelineEvents
        : events;

    Navigator.pop(
      context,
      widget.initialContent.copyWith(
        heroTitle: heroTitle,
        heroSummary: heroSummary,
        sections: sections,
        timelineEvents: effectiveEvents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Story'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _heroTitleController,
                decoration: const InputDecoration(labelText: 'Hero title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _heroSummaryController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Hero summary'),
              ),
              const SizedBox(height: 14),
              for (final draft in _sectionDrafts)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Section ${draft.indexLabel}'),
                  subtitle: Text(
                    draft.titleController.text.isEmpty
                        ? 'Add title'
                        : draft.titleController.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: [
                    TextField(
                      controller: draft.titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: draft.summaryController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Summary'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: draft.pointsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Bullet points (one per line)',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                'Timeline rows (format: year | title | note)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _timelineController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '2007 | The Come Up | May 4, 2007',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetDefaults,
          child: const Text('Reset Defaults'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _StorySectionDraft {
  _StorySectionDraft({
    required this.indexLabel,
    required this.imageSource,
    required this.titleController,
    required this.summaryController,
    required this.pointsController,
  });

  factory _StorySectionDraft.fromSection(StorySection section) {
    return _StorySectionDraft(
      indexLabel: section.indexLabel,
      imageSource: section.imageSource,
      titleController: TextEditingController(text: section.title),
      summaryController: TextEditingController(text: section.summary),
      pointsController: TextEditingController(text: section.points.join('\n')),
    );
  }

  final String indexLabel;
  final String imageSource;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController pointsController;

  StorySection? toSection() {
    final title = titleController.text.trim();
    final summary = summaryController.text.trim();
    if (title.isEmpty || summary.isEmpty) {
      return null;
    }
    final points = pointsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return StorySection(
      indexLabel: indexLabel,
      title: title,
      summary: summary,
      points: points,
      imageSource: imageSource,
    );
  }

  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    pointsController.dispose();
  }
}

class _ColorOption {
  const _ColorOption({required this.label, required this.value});

  final String label;
  final int value;
}
