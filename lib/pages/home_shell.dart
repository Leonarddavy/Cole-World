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
import '../models/playback_models.dart';
import '../models/story_content.dart';
import '../services/app_prefs.dart';
import '../services/library_storage.dart';
import '../theme/app_theme.dart';
import '../ui/collection_type_ui.dart';
import '../utils/local_fs.dart';
import '../utils/object_url.dart';
import '../widgets/graffiti_backdrop.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/graffiti_scaffold.dart';
import '../widgets/mini_player_bar.dart';
import 'artist_history_page.dart';
import 'collection_detail_page.dart';
import 'library_page.dart';
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
  final Random _random = Random();
  final Set<String> _ownedObjectUrls = {};
  final ValueNotifier<Track?> _currentTrackListenable = ValueNotifier(null);
  final ValueNotifier<String?> _pendingTrackIdListenable = ValueNotifier(null);
  final ValueNotifier<List<Track>> _queueListenable = ValueNotifier(const []);
  final ValueNotifier<bool> _shuffleEnabledListenable = ValueNotifier(false);
  final ValueNotifier<RepeatMode> _repeatModeListenable = ValueNotifier(
    RepeatMode.off,
  );
  final ValueNotifier<Duration> _positionListenable = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration> _durationListenable = ValueNotifier(
    Duration.zero,
  );

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
  RepeatMode _repeatMode = RepeatMode.off;
  String? _shuffleQueueEntryId;
  List<String> _shuffleQueue = [];
  List<_RecentPlayPointer> _recentPlays = const [];
  ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;
  late AppThemeSettings _themeSettings;
  bool _isEditMode = false;
  List<String> _customBackdropSources = const [];
  StoryContent _storyContent = StoryContent.defaults();

  @override
  void initState() {
    super.initState();
    _themeSettings = widget.initialThemeSettings;
    GraffitiBackdrop.setCustomSources(_customBackdropSources);
    unawaited(_initAudioSession());
    unawaited(_hydrateLibrary());
    unawaited(_hydratePrefs());
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) {
        return;
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
    return _entries.where((entry) => entry.type == type).toList();
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

  Future<void> _hydratePrefs() async {
    final prefs = await _prefs.load();
    if (!mounted) {
      return;
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
    setState(() {
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
    final success = await _prefs.save({
      'showStoryTab': _showStoryTab,
      'showLaunchTab': _showLaunchTab,
      'editMode': _isEditMode,
      'customBackdropSources': _customBackdropSources,
      'themeSettings': _themeSettings.toJson(),
      'storyContent': _storyContent.toJson(),
      'recentPlays': _recentPlays.map((item) => item.toJson()).toList(),
    });
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
      } else {
        final entryId = _currentEntryId;
        if (entryId != null) {
          final entry = _entryById(entryId);
          if (entry != null) {
            _ensureShuffleQueue(entry);
          }
        }
      }
      _refreshQueueForCurrentEntry();
    });
    if (changed) {
      unawaited(_rebuildCurrentAudioSourcePreservingTrack());
    }
  }

  void _cycleRepeatMode() {
    setState(() {
      final nextIndex =
          (RepeatMode.values.indexOf(_repeatMode) + 1) %
          RepeatMode.values.length;
      _repeatMode = RepeatMode.values[nextIndex];
      _repeatModeListenable.value = _repeatMode;
    });
    unawaited(_applyPlayerLoopMode());
  }

  LoopMode _loopModeForRepeatMode(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return LoopMode.off;
      case RepeatMode.all:
        return LoopMode.all;
      case RepeatMode.one:
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
    final changed =
        _themeSettings.primaryColorValue != normalized.primaryColorValue ||
        _themeSettings.secondaryColorValue != normalized.secondaryColorValue ||
        _themeSettings.backgroundColorValue !=
            normalized.backgroundColorValue ||
        _themeSettings.displayFontKey != normalized.displayFontKey ||
        _themeSettings.bodyFontKey != normalized.bodyFontKey;
    if (!changed) {
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

  Future<String?> _backgroundImageLibraryDirPath() async {
    if (kIsWeb) {
      return null;
    }
    return ensureAppSubdirectory('background_images');
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

    if (sourcePath.isEmpty) {
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

    final backgroundDir = await _backgroundImageLibraryDirPath();
    if (backgroundDir == null) {
      return sourceFilePath;
    }
    if (path.isWithin(backgroundDir, sourceFilePath)) {
      return sourceFilePath;
    }

    final extension = path.extension(sourceFilePath);
    final targetPath = path.join(
      backgroundDir,
      '${_newId()}${extension.isEmpty ? '.jpg' : extension}',
    );
    try {
      final copied = await copyLocalFileToPath(
        sourcePath: sourceFilePath,
        targetPath: targetPath,
      );
      return copied ?? sourceFilePath;
    } catch (error, stackTrace) {
      _logError('persistBackdropImageFile', error, stackTrace);
      return null;
    }
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
    final entry = _currentEntryId == null ? null : _entryById(_currentEntryId!);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NowPlayingPage(
          title: title,
          entry: entry,
          currentTrackListenable: _currentTrackListenable,
          playerStateStream: _audioPlayer.playerStateStream,
          positionStream: _audioPlayer.positionStream,
          durationStream: _audioPlayer.durationStream,
          onPlayTrack: _playTrackFromEntry,
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
      try {
        await _audioPlayer.stop();
      } catch (error, stackTrace) {
        _logError('deleteTrackFromEntry.stop', error, stackTrace);
      }
      setState(() {
        _currentTrack = null;
        _currentEntryId = null;
        _currentTrackListenable.value = null;
        _isPlaying = false;
      });
      _resetPlaybackProgress();
      _pendingTrackIdListenable.value = null;
    }

    _releaseTrackResources(track);

    final updated = entry.copyWith(
      tracks: entry.tracks.where((t) => t.id != track.id).toList(),
    );
    _replaceEntry(updated);
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
      try {
        await _audioPlayer.stop();
      } catch (error, stackTrace) {
        _logError('deleteCollection.stop', error, stackTrace);
      }
      setState(() {
        _currentTrack = null;
        _currentEntryId = null;
        _currentTrackListenable.value = null;
        _isPlaying = false;
      });
      _resetPlaybackProgress();
      _pendingTrackIdListenable.value = null;
    }

    for (final t in removedTracks) {
      _releaseTrackResources(t);
    }

    setState(() {
      _entries = _entries.where((e) => e.id != entry.id).toList();
    });
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

  Uri? _notificationArtUriForEntry(CollectionEntry? entry) {
    if (entry == null || kIsWeb) {
      return null;
    }
    final thumbnailPath = entry.thumbnailPath?.trim();
    if (thumbnailPath == null || thumbnailPath.isEmpty) {
      return null;
    }
    if (!localFileExistsSync(thumbnailPath)) {
      return null;
    }
    return Uri.file(thumbnailPath);
  }

  MediaItem _mediaItemForTrack(Track track, {CollectionEntry? entry}) {
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: entry?.title ?? entry?.type.label,
      artUri: _notificationArtUriForEntry(entry),
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

  List<AudioSource> _buildAudioSourcesForQueue(
    List<Track> queue, {
    required CollectionEntry entry,
  }) {
    return [
      for (final item in queue) _buildAudioSourceForTrack(item, entry: entry),
    ];
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
      final baseName = file.name.isNotEmpty ? file.name : filePath;
      final title = path
          .basenameWithoutExtension(baseName)
          .replaceAll('_', ' ');
      tracks.add(
        Track(
          id: _newId(),
          title: title.isEmpty ? 'Untitled Track' : title,
          artist: artist,
          filePath: filePath,
        ),
      );
    }
    return tracks;
  }

  void _replaceEntry(CollectionEntry updated) {
    setState(() {
      _entries = _entries
          .map((entry) => entry.id == updated.id ? updated : entry)
          .toList();
    });
    if (_currentEntryId == updated.id) {
      _refreshQueueForEntry(updated);
      unawaited(_rebuildCurrentAudioSourcePreservingTrack());
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

  void _refreshQueueForEntry(CollectionEntry entry) {
    _queueListenable.value = _queueForEntry(entry);
  }

  void _refreshQueueForCurrentEntry() {
    final entryId = _currentEntryId;
    if (entryId == null) {
      _queueListenable.value = const [];
      return;
    }
    final entry = _entryById(entryId);
    if (entry == null) {
      _queueListenable.value = const [];
      return;
    }
    _refreshQueueForEntry(entry);
  }

  void _syncCurrentTrackFromQueueIndex(int? index) {
    if (!mounted || index == null || index < 0) {
      return;
    }
    final queue = _queueListenable.value;
    if (index >= queue.length) {
      return;
    }

    final nextTrack = queue[index];
    if (_currentTrack?.id == nextTrack.id) {
      return;
    }

    setState(() {
      _currentTrack = nextTrack;
      _currentTrackListenable.value = nextTrack;
    });
    _pendingTrackIdListenable.value = null;
    final entryId = _currentEntryId;
    if (entryId != null) {
      _rememberRecentlyPlayed(entryId: entryId, trackId: nextTrack.id);
    }
  }

  Future<void> _rebuildCurrentAudioSourcePreservingTrack() async {
    final entryId = _currentEntryId;
    final current = _currentTrack;
    if (entryId == null || current == null) {
      return;
    }
    final entry = _entryById(entryId);
    if (entry == null || entry.tracks.isEmpty) {
      return;
    }

    final queue = _queueForEntry(entry);
    if (queue.isEmpty) {
      return;
    }
    _queueListenable.value = queue;
    final targetIndex = queue.indexWhere((track) => track.id == current.id);
    if (targetIndex < 0) {
      return;
    }

    final sources = _buildAudioSourcesForQueue(queue, entry: entry);
    final resumePosition = _position;
    final resumePlayback = _isPlaying;
    try {
      await _audioPlayer.setAudioSources(
        sources,
        initialIndex: targetIndex,
        initialPosition: resumePosition,
      );
      await _applyPlayerLoopMode();
      if (resumePlayback) {
        await _audioSession?.setActive(true);
        await _audioPlayer.play();
      }
    } catch (error, stackTrace) {
      _logError('rebuildCurrentAudioSource', error, stackTrace);
    }
  }

  Future<void> _playTrack(Track track, {String? entryId}) async {
    final rawPath = track.filePath.trim();
    if (rawPath.isEmpty) {
      _showMessage('Track file not found. Upload a local file for this song.');
      return;
    }

    final uri = _audioUriFromPath(rawPath);
    if (!kIsWeb) {
      if (uri == null && !localFileExistsSync(rawPath)) {
        _showMessage(
          'Track file not found. Upload a local file for this song.',
        );
        return;
      }
      if (uri?.scheme == 'file' && !localFileUriExistsSync(uri!)) {
        _showMessage(
          'Track file not found. Upload a local file for this song.',
        );
        return;
      }
    }

    final nextEntryId = entryId ?? _currentEntryId;
    try {
      if (_currentTrack?.id == track.id && _currentEntryId == nextEntryId) {
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
      final entry = nextEntryId == null ? null : _entryById(nextEntryId);
      await _audioSession?.setActive(true);
      if (entry != null && entry.tracks.isNotEmpty) {
        final queue = _queueForEntry(entry);
        final effectiveQueue = queue.isEmpty ? [track] : queue;
        _queueListenable.value = effectiveQueue;
        final currentIndex = effectiveQueue.indexWhere(
          (item) => item.id == track.id,
        );
        final sources = _buildAudioSourcesForQueue(
          effectiveQueue,
          entry: entry,
        );
        await _audioPlayer.setAudioSources(
          sources,
          initialIndex: currentIndex < 0 ? 0 : currentIndex,
          initialPosition: Duration.zero,
        );
      } else {
        _queueListenable.value = [track];
        await _audioPlayer.setAudioSource(
          _buildAudioSourceForTrack(track, entry: entry),
        );
      }
      await _applyPlayerLoopMode();
      await _audioPlayer.play();
      if (nextEntryId != null) {
        _rememberRecentlyPlayed(entryId: nextEntryId, trackId: track.id);
      }
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
    final queue = _queueListenable.value;
    if (queue.isEmpty) {
      return;
    }
    final currentIndex =
        _audioPlayer.currentIndex ??
        queue.indexWhere((track) => track.id == _currentTrack?.id);
    if (currentIndex < 0) {
      return;
    }
    if (currentIndex < queue.length - 1) {
      await _audioPlayer.seek(Duration.zero, index: currentIndex + 1);
      return;
    }
    if (_repeatMode == RepeatMode.all) {
      await _audioPlayer.seek(Duration.zero, index: 0);
    }
  }

  Future<void> _playPreviousInEntry() async {
    final queue = _queueListenable.value;
    if (queue.isEmpty) {
      return;
    }
    if (_position > const Duration(seconds: 3)) {
      await _seekTo(Duration.zero);
      return;
    }
    final currentIndex =
        _audioPlayer.currentIndex ??
        queue.indexWhere((track) => track.id == _currentTrack?.id);
    if (currentIndex < 0) {
      return;
    }
    if (currentIndex > 0) {
      await _audioPlayer.seek(Duration.zero, index: currentIndex - 1);
      return;
    }
    if (_repeatMode == RepeatMode.all) {
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

    final current = _entryById(entryId);
    if (current == null) {
      return null;
    }

    final updated = current.copyWith(
      thumbnailPath: thumbPath,
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

    final updated = current.copyWith(tracks: [...current.tracks, ...tracks]);
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
    if (!mounted) {
      return;
    }

    final fromSingles = type == CollectionType.playlist
        ? _singleTracksByIds(draft.selectedSingleTrackIds)
        : const <Track>[];
    final effectiveTracks = [...fromSingles, ...tracks];

    final created = CollectionEntry(
      id: _newId(),
      type: type,
      title: draft.title,
      history: draft.history,
      featuredArtists: draft.featuredArtists,
      tracks: effectiveTracks,
      thumbnailPath: draft.thumbnailPath,
      thumbnailDataBase64: draft.thumbnailDataBase64,
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
          currentEntryId: _currentEntryId,
          onShowTrackDetails: _showTrackDetailsFromEntry,
          onReorderTracks: _reorderEntryTracks,
          onDeleteTrack: _deleteTrackFromEntry,
          onMenuAction: _runMenuActionFromDetail,
          resolveEntry: _entryById,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _runMenuActionFromDetail(
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

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs();
    final maxIndex = tabs.length - 1;
    final effectiveIndex = _tabIndex.clamp(0, maxIndex);
    final currentTab = tabs[effectiveIndex];
    final page = switch (currentTab) {
      _HomeTab.albums => LibraryPage(
        key: const ValueKey('albums'),
        tabType: CollectionType.album,
        entries: _ofType(CollectionType.album),
        recentTracks: _recentTracksForType(CollectionType.album),
        onOpen: _openDetail,
        onPlayRecentTrack: _playTrackFromEntry,
        onCreateCollection: () => _createCollection(CollectionType.album),
        onUploadToCollection: () =>
            _uploadSongsToTypeCollection(CollectionType.album),
        onPlayAll: () => _playFromType(CollectionType.album, shuffle: false),
        onShufflePlay: () => _playFromType(CollectionType.album, shuffle: true),
        onMenuAction: _runMenuAction,
      ),
      _HomeTab.singles => LibraryPage(
        key: const ValueKey('singles'),
        tabType: CollectionType.single,
        entries: _ofType(CollectionType.single),
        recentTracks: _recentTracksForType(CollectionType.single),
        onOpen: _openDetail,
        onPlayRecentTrack: _playTrackFromEntry,
        onCreateCollection: () => _createCollection(CollectionType.single),
        onUploadToCollection: () =>
            _uploadSongsToTypeCollection(CollectionType.single),
        onPlayAll: () => _playFromType(CollectionType.single, shuffle: false),
        onShufflePlay: () =>
            _playFromType(CollectionType.single, shuffle: true),
        onMenuAction: _runMenuAction,
      ),
      _HomeTab.features => LibraryPage(
        key: const ValueKey('features'),
        tabType: CollectionType.feature,
        entries: _ofType(CollectionType.feature),
        recentTracks: _recentTracksForType(CollectionType.feature),
        onOpen: _openDetail,
        onPlayRecentTrack: _playTrackFromEntry,
        onCreateCollection: () => _createCollection(CollectionType.feature),
        onUploadToCollection: () =>
            _uploadSongsToTypeCollection(CollectionType.feature),
        onPlayAll: () => _playFromType(CollectionType.feature, shuffle: false),
        onShufflePlay: () =>
            _playFromType(CollectionType.feature, shuffle: true),
        onMenuAction: _runMenuAction,
      ),
      _HomeTab.playlist => LibraryPage(
        key: const ValueKey('playlists'),
        tabType: CollectionType.playlist,
        entries: _ofType(CollectionType.playlist),
        recentTracks: _recentTracksForType(CollectionType.playlist),
        onOpen: _openDetail,
        onPlayRecentTrack: _playTrackFromEntry,
        onCreateCollection: () => _createCollection(CollectionType.playlist),
        onUploadToCollection: () =>
            _uploadSongsToTypeCollection(CollectionType.playlist),
        onPlayAll: () => _playFromType(CollectionType.playlist, shuffle: false),
        onShufflePlay: () =>
            _playFromType(CollectionType.playlist, shuffle: true),
        onMenuAction: _runMenuAction,
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
  });

  final List<CollectionEntry> entries;
  final List<RecentTrackShortcut> recentTracks;
  final Future<void> Function(CollectionEntry entry) onOpenCollection;
  final Future<void> Function(Track track, CollectionEntry entry) onPlayTrack;

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
              trailing: const Icon(Icons.play_arrow),
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
              trailing: const Icon(Icons.play_arrow),
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
    for (final draft in _sectionDrafts) {
      draft.dispose();
    }
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
