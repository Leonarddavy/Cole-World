import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';

import '../data/seed_data.dart';
import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
import '../models/playback_models.dart';
import '../services/app_prefs.dart';
import '../services/library_storage.dart';
import '../ui/collection_type_ui.dart';
import '../utils/object_url.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/graffiti_scaffold.dart';
import '../widgets/mini_player_bar.dart';
import 'artist_history_page.dart';
import 'collection_detail_page.dart';
import 'library_page.dart';
import 'now_playing_page.dart';
import 'splash_catalog_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum _HomeTab { albums, singles, playlist, story, launch }

class _HomeShellState extends State<HomeShell> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AppPrefs _prefs = const AppPrefs();
  final LibraryStorage _libraryStorage = const LibraryStorage();
  final Random _random = Random();
  final Set<String> _ownedObjectUrls = {};
  final ValueNotifier<Track?> _currentTrackListenable = ValueNotifier(null);
  final ValueNotifier<String?> _pendingTrackIdListenable = ValueNotifier(null);
  final ValueNotifier<List<Track>> _queueListenable =
      ValueNotifier(const []);
  final ValueNotifier<bool> _shuffleEnabledListenable =
      ValueNotifier(false);
  final ValueNotifier<RepeatMode> _repeatModeListenable =
      ValueNotifier(RepeatMode.off);

  AudioSession? _audioSession;
  StreamSubscription<AudioInterruptionEvent>? _audioInterruptionSub;
  StreamSubscription<void>? _becomingNoisySub;
  bool _resumeAfterInterruption = false;

  late List<CollectionEntry> _entries = seedEntries();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  int _tabIndex = 0;
  int _previousTabIndex = 0;
  bool _showStoryTab = true;
  bool _showLaunchTab = true;
  Track? _currentTrack;
  String? _currentEntryId;
  bool _isPlaying = false;
  bool _isAutoAdvancing = false;
  bool _miniPlayerExpanded = true;
  bool _shuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  String? _shuffleQueueEntryId;
  List<String> _shuffleQueue = [];
  ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
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
      if (processing == ProcessingState.completed) {
        unawaited(_handleAutoAdvanceIfNeeded());
      }
    });
    _positionSub = _audioPlayer.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
      });
    });
    _durationSub = _audioPlayer.durationStream.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });
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
    _audioInterruptionSub?.cancel();
    _becomingNoisySub?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
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

  String _newId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(99999)}';
  }

  Future<Directory> _audioLibraryDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory(path.join(directory.path, 'audio_library'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  Future<void> _hydrateLibrary() async {
    final loaded = await _libraryStorage.load();
    if (!mounted) {
      return;
    }
    if (loaded == null || loaded.isEmpty) {
      await _libraryStorage.save(_entries);
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
    setState(() {
      _showStoryTab = showStory is bool ? showStory : true;
      _showLaunchTab = showLaunch is bool ? showLaunch : true;
      _clampTabIndex();
    });
  }

  Future<void> _persistLibrary() async {
    await _libraryStorage.save(_entries);
  }

  Future<void> _persistPrefs() async {
    await _prefs.save({
      'showStoryTab': _showStoryTab,
      'showLaunchTab': _showLaunchTab,
    });
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
  }

  void _cycleRepeatMode() {
    setState(() {
      final nextIndex = (RepeatMode.values.indexOf(_repeatMode) + 1) %
          RepeatMode.values.length;
      _repeatMode = RepeatMode.values[nextIndex];
      _repeatModeListenable.value = _repeatMode;
    });
  }

  void _toggleMiniPlayerSize() {
    setState(() {
      _miniPlayerExpanded = !_miniPlayerExpanded;
    });
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

  Future<void> _showTrackDetails(
    Track track, {
    CollectionEntry? entry,
  }) async {
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
                  SelectableText(
                    filePath,
                    maxLines: 2,
                  ),
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
    final entry =
        _currentEntryId == null ? null : _entryById(_currentEntryId!);
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

  Future<void> _playTrackFromEntry(
    Track track,
    CollectionEntry entry,
  ) async {
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

    final audioDir = await _audioLibraryDir();
    final onDiskPath = uri == null ? trimmed : File.fromUri(uri).path;
    if (!path.isWithin(audioDir.path, onDiskPath)) {
      return;
    }

    final stillUsed = _entries.any(
      (entry) => entry.tracks.any((t) => t.filePath.trim() == trimmed),
    );
    if (stillUsed) {
      return;
    }

    try {
      final file = File(onDiskPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
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
      } catch (_) {}
      setState(() {
        _currentTrack = null;
        _currentEntryId = null;
        _currentTrackListenable.value = null;
        _isPlaying = false;
        _position = Duration.zero;
      });
      _pendingTrackIdListenable.value = null;
    }

    _releaseTrackResources(track);

    final updated = entry.copyWith(
      tracks: entry.tracks.where((t) => t.id != track.id).toList(),
    );
    _replaceEntry(updated);
    unawaited(_persistLibrary());
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
      } catch (_) {}
      setState(() {
        _currentTrack = null;
        _currentEntryId = null;
        _currentTrackListenable.value = null;
        _isPlaying = false;
        _position = Duration.zero;
      });
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

    final sourceFile = uri == null ? File(sourcePath) : File.fromUri(uri);
    if (!await sourceFile.exists()) {
      return sourcePath;
    }

    final audioDir = await _audioLibraryDir();
    if (path.isWithin(audioDir.path, sourceFile.path)) {
      return sourceFile.path;
    }

    final extension = path.extension(sourceFile.path);
    final targetPath =
        path.join(audioDir.path, '${_newId()}${extension.isEmpty ? '' : extension}');
    try {
      final copied = await sourceFile.copy(targetPath);
      return copied.path;
    } catch (_) {
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
    }
    unawaited(_persistLibrary());
  }

  Future<void> _handleAutoAdvanceIfNeeded() async {
    if (!mounted || _isAutoAdvancing) {
      return;
    }
    final entryId = _currentEntryId;
    final current = _currentTrack;
    if (entryId == null || current == null) {
      return;
    }

    final entry = _entryById(entryId);
    if (entry == null) {
      return;
    }
    if (entry.type != CollectionType.album &&
        entry.type != CollectionType.playlist) {
      return;
    }
    if (entry.tracks.isEmpty) {
      return;
    }

    _isAutoAdvancing = true;
    try {
      if (_repeatMode == RepeatMode.one) {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        return;
      }

      Track? next;
      if (_shuffleEnabled) {
        _ensureShuffleQueue(entry);
        final idx = _shuffleQueue.indexOf(current.id);
        if (idx >= 0 && idx < _shuffleQueue.length - 1) {
          next = _trackById(entry, _shuffleQueue[idx + 1]);
        } else if (_repeatMode == RepeatMode.all &&
            _shuffleQueue.isNotEmpty) {
          next = _trackById(entry, _shuffleQueue.first);
        }
      } else {
        final index =
            entry.tracks.indexWhere((track) => track.id == current.id);
        if (index >= 0 && index < entry.tracks.length - 1) {
          next = entry.tracks[index + 1];
        } else if (_repeatMode == RepeatMode.all) {
          next = entry.tracks.first;
        }
      }

      if (next != null) {
        await _playTrack(next, entryId: entry.id);
      }
    } finally {
      _isAutoAdvancing = false;
    }
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
        isSameEntry && isSameLength && _shuffleQueue.toSet().containsAll(trackIdSet);
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

  Future<void> _playTrack(Track track, {String? entryId}) async {
    final rawPath = track.filePath.trim();
    if (rawPath.isEmpty) {
      _showMessage('Track file not found. Upload a local file for this song.');
      return;
    }

    final uri = _audioUriFromPath(rawPath);
    if (!kIsWeb) {
      if (uri == null && !File(rawPath).existsSync()) {
        _showMessage('Track file not found. Upload a local file for this song.');
        return;
      }
      if (uri?.scheme == 'file' && !File.fromUri(uri!).existsSync()) {
        _showMessage('Track file not found. Upload a local file for this song.');
        return;
      }
    }

    try {
      if (_currentTrack?.id == track.id) {
        if (!_isPlaying) {
          await _audioPlayer.play();
        }
        return;
      }

      final nextEntryId = entryId ?? _currentEntryId;

      // Immediate feedback: show the mini-player context and a loading state.
      setState(() {
        _currentTrack = track;
        _currentEntryId = nextEntryId;
        _currentTrackListenable.value = track;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
      _pendingTrackIdListenable.value = track.id;
      if (nextEntryId != null) {
        final entry = _entryById(nextEntryId);
        if (entry != null) {
          _refreshQueueForEntry(entry);
        }
      }

      final entry = nextEntryId == null ? null : _entryById(nextEntryId);
      final mediaItem = MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: entry?.title ?? entry?.type.label,
      );
      final sourceUri = uri ?? Uri.file(rawPath);
      await _audioSession?.setActive(true);
      await _audioPlayer.setAudioSource(
        AudioSource.uri(sourceUri, tag: mediaItem),
      );
      await _audioPlayer.play();
      if (!mounted) {
        return;
      }
      setState(() {
        _position = Duration.zero;
      });
    } catch (_) {
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
    } catch (_) {}
  }

  Future<void> _playNextInEntry() async {
    final entryId = _currentEntryId;
    final current = _currentTrack;
    if (entryId == null || current == null) {
      return;
    }
    final entry = _entryById(entryId);
    if (entry == null || entry.tracks.length < 2) {
      return;
    }
    if (_shuffleEnabled) {
      _ensureShuffleQueue(entry);
      final idx = _shuffleQueue.indexOf(current.id);
      if (idx >= 0 && idx < _shuffleQueue.length - 1) {
        final next = _trackById(entry, _shuffleQueue[idx + 1]);
        if (next != null) {
          await _playTrack(next, entryId: entry.id);
        }
        return;
      }
      if (_repeatMode == RepeatMode.all && _shuffleQueue.isNotEmpty) {
        final next = _trackById(entry, _shuffleQueue.first);
        if (next != null) {
          await _playTrack(next, entryId: entry.id);
        }
      }
      return;
    }

    final index = entry.tracks.indexWhere((track) => track.id == current.id);
    if (index < 0) {
      return;
    }
    if (index < entry.tracks.length - 1) {
      await _playTrack(entry.tracks[index + 1], entryId: entry.id);
      return;
    }
    if (_repeatMode == RepeatMode.all) {
      await _playTrack(entry.tracks.first, entryId: entry.id);
    }
  }

  Future<void> _playPreviousInEntry() async {
    final entryId = _currentEntryId;
    final current = _currentTrack;
    if (entryId == null || current == null) {
      return;
    }
    if (_position > const Duration(seconds: 3)) {
      await _seekTo(Duration.zero);
      return;
    }
    final entry = _entryById(entryId);
    if (entry == null || entry.tracks.isEmpty) {
      return;
    }
    if (_shuffleEnabled) {
      _ensureShuffleQueue(entry);
      final idx = _shuffleQueue.indexOf(current.id);
      if (idx > 0) {
        final prev = _trackById(entry, _shuffleQueue[idx - 1]);
        if (prev != null) {
          await _playTrack(prev, entryId: entry.id);
        }
        return;
      }
      if (_repeatMode == RepeatMode.all && _shuffleQueue.isNotEmpty) {
        final prev = _trackById(entry, _shuffleQueue.last);
        if (prev != null) {
          await _playTrack(prev, entryId: entry.id);
        }
        return;
      }
      await _seekTo(Duration.zero);
      return;
    }

    final index = entry.tracks.indexWhere((track) => track.id == current.id);
    if (index > 0) {
      await _playTrack(entry.tracks[index - 1], entryId: entry.id);
      return;
    }
    if (_repeatMode == RepeatMode.all) {
      await _playTrack(entry.tracks.last, entryId: entry.id);
      return;
    }
    await _seekTo(Duration.zero);
  }

  Future<void> _seekBySeconds(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    if (_duration == Duration.zero) {
      await _seekTo(target < Duration.zero ? Duration.zero : target);
      return;
    }
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    await _seekTo(clamped);
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
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selected = result.files.first;
    final thumbPath = selected.path;
    final thumbData = selected.bytes == null || selected.bytes!.isEmpty
        ? null
        : base64Encode(selected.bytes!);
    if (thumbPath == null && thumbData == null) {
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

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final tracks = await _tracksFromFiles(result.files, artist: 'J. Cole');
    if (tracks.isEmpty) {
      _showMessage('No valid audio files selected.');
      return null;
    }

    final updated = current.copyWith(tracks: [...current.tracks, ...tracks]);
    _replaceEntry(updated);
    _showMessage('${tracks.length} song(s) added to ${updated.title}.');
    return updated;
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
    final draft = await showDialog<_NewCollectionDraft>(
      context: context,
      builder: (context) {
        return _CreateCollectionDialog(type: type);
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

    final effectiveTracks = tracks.isEmpty && type == CollectionType.playlist
        ? _allSingleTracks()
        : tracks;

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
    if (tracks.isEmpty && type == CollectionType.playlist) {
      _showMessage('${created.title} created from singles.');
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
          onOpen: _openDetail,
          onCreateCollection: () => _createCollection(CollectionType.album),
          onUploadToCollection: () =>
              _uploadSongsToTypeCollection(CollectionType.album),
          onMenuAction: _runMenuAction,
        ),
      _HomeTab.singles => LibraryPage(
          key: const ValueKey('singles'),
          tabType: CollectionType.single,
          entries: _ofType(CollectionType.single),
          onOpen: _openDetail,
          onCreateCollection: () => _createCollection(CollectionType.single),
          onUploadToCollection: () =>
              _uploadSongsToTypeCollection(CollectionType.single),
          onMenuAction: _runMenuAction,
        ),
      _HomeTab.playlist => LibraryPage(
          key: const ValueKey('playlists'),
          tabType: CollectionType.playlist,
          entries: _ofType(CollectionType.playlist),
          onOpen: _openDetail,
          onCreateCollection: () => _createCollection(CollectionType.playlist),
          onUploadToCollection: () =>
              _uploadSongsToTypeCollection(CollectionType.playlist),
          onMenuAction: _runMenuAction,
        ),
      _HomeTab.story => const ArtistHistoryPage(key: ValueKey('story')),
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                letterSpacing: 1.2,
              ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'App options',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
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
                      isBuffering: _processingState == ProcessingState.buffering,
                      duration: _duration,
                      position: _position,
                      onToggle: _togglePlayback,
                      onOpenNowPlaying: _openNowPlaying,
                      isExpanded: _miniPlayerExpanded,
                      onToggleSize: _toggleMiniPlayerSize,
                      onSeek: _seekTo,
                      onSkipBack: () => _seekBySeconds(-10),
                      onSkipForward: () => _seekBySeconds(10),
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

class _NewCollectionDraft {
  const _NewCollectionDraft({
    required this.title,
    required this.history,
    required this.featuredArtists,
    required this.selectedSongs,
    this.thumbnailPath,
    this.thumbnailDataBase64,
  });

  final String title;
  final String history;
  final List<String> featuredArtists;
  final List<PlatformFile> selectedSongs;
  final String? thumbnailPath;
  final String? thumbnailDataBase64;
}

class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog({required this.type});

  final CollectionType type;

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
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final selected = result.files.first;
    setState(() {
      _thumbnailPath = selected.path;
      _thumbnailDataBase64 =
          selected.bytes == null || selected.bytes!.isEmpty
              ? null
              : base64Encode(selected.bytes!);
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
