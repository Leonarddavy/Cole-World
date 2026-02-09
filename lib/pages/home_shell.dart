import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/seed_data.dart';
import '../models/collection_models.dart';
import '../models/entry_menu_action.dart';
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AppPrefs _prefs = const AppPrefs();
  final LibraryStorage _libraryStorage = const LibraryStorage();
  final Random _random = Random();
  final Set<String> _ownedObjectUrls = {};

  late List<CollectionEntry> _entries = seedEntries();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  int _tabIndex = 0;
  int _previousTabIndex = 0;
  bool _showStoryTab = true;
  Track? _currentTrack;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_hydrateLibrary());
    unawaited(_hydratePrefs());
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = state.playing;
      });
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
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<CollectionEntry> _ofType(CollectionType type) {
    return _entries.where((entry) => entry.type == type).toList();
  }

  CollectionEntry? _entryById(String id) {
    for (final entry in _entries) {
      if (entry.id == id) {
        return entry;
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
    setState(() {
      _showStoryTab = showStory is bool ? showStory : true;
      if (!_showStoryTab && _tabIndex >= 3) {
        _tabIndex = 0;
        _previousTabIndex = 0;
      }
    });
  }

  Future<void> _persistLibrary() async {
    await _libraryStorage.save(_entries);
  }

  Future<void> _persistPrefs() async {
    await _prefs.save({'showStoryTab': _showStoryTab});
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
        _isPlaying = false;
        _position = Duration.zero;
      });
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
        _isPlaying = false;
        _position = Duration.zero;
      });
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
      if (_tabIndex >= 3) {
        _tabIndex = 0;
        _previousTabIndex = 0;
      }
    });
    unawaited(_persistPrefs());
  }

  Future<void> _restoreStoryTab() async {
    if (_showStoryTab) {
      return;
    }
    setState(() {
      _showStoryTab = true;
    });
    unawaited(_persistPrefs());
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
    unawaited(_persistLibrary());
  }

  Future<void> _playTrack(Track track) async {
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
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
        return;
      }

      if (uri != null) {
        await _audioPlayer.setAudioSource(AudioSource.uri(uri));
      } else {
        await _audioPlayer.setFilePath(rawPath);
      }
      await _audioPlayer.play();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentTrack = track;
        _position = Duration.zero;
      });
    } catch (_) {
      _showMessage('Unable to play this track.');
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
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
    final titleController = TextEditingController();
    final historyController = TextEditingController();
    final featuredController = TextEditingController();

    String? thumbnailPath;
    String? thumbnailDataBase64;
    String? thumbnailLabel;
    List<PlatformFile> selectedSongs = [];

    try {
      final created = await showDialog<CollectionEntry>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('New ${type.label}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Enter collection name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: historyController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Brief history',
                          hintText: 'Context about release and era',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: featuredController,
                        decoration: const InputDecoration(
                          labelText: 'Featured artists (comma separated)',
                          hintText: 'e.g. 21 Savage, Lil Baby',
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.image_outlined),
                        label: Text(thumbnailLabel ?? 'Select Thumbnail'),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                            withData: true,
                          );
                          if (result == null || result.files.isEmpty) {
                            return;
                          }
                          final selected = result.files.first;
                          setDialogState(() {
                            thumbnailPath = selected.path;
                            thumbnailDataBase64 =
                                selected.bytes == null ||
                                    selected.bytes!.isEmpty
                                ? null
                                : base64Encode(selected.bytes!);
                            thumbnailLabel = selected.path == null
                                ? selected.name
                                : path.basename(selected.path!);
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.music_note),
                        label: Text(
                          selectedSongs.isEmpty
                              ? 'Upload Songs'
                              : '${selectedSongs.length} song(s) selected',
                        ),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.audio,
                            allowMultiple: true,
                            withData: kIsWeb,
                          );
                          if (result == null || result.files.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            selectedSongs = result.files;
                          });
                        },
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
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        return;
                      }
                      final featured = featuredController.text
                          .split(',')
                          .map((name) => name.trim())
                          .where((name) => name.isNotEmpty)
                          .toList();
                      final tracks = await _tracksFromFiles(
                        selectedSongs,
                        artist: 'J. Cole',
                      );
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.pop(
                        context,
                        CollectionEntry(
                          id: _newId(),
                          type: type,
                          title: title,
                          history: historyController.text.trim(),
                          featuredArtists: featured,
                          tracks: tracks,
                          thumbnailPath: thumbnailPath,
                          thumbnailDataBase64: thumbnailDataBase64,
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || created == null) {
        return;
      }

      setState(() {
        _entries = [..._entries, created];
      });
      unawaited(_persistLibrary());
      _showMessage('${created.title} added.');
    } finally {
      titleController.dispose();
      historyController.dispose();
      featuredController.dispose();
    }
  }

  Future<void> _openDetail(CollectionEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionDetailPage(
          entry: entry,
          currentTrackId: _currentTrack?.id,
          isPlaying: _isPlaying,
          onPlayTrack: _playTrack,
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
    final maxIndex = _showStoryTab ? 3 : 2;
    final clamped = index.clamp(0, maxIndex).toInt();
    if (clamped == _tabIndex) {
      return;
    }
    setState(() {
      _previousTabIndex = _tabIndex;
      _tabIndex = clamped;
    });
  }

  String get _title {
    switch (_tabIndex) {
      case 0:
        return 'Albums';
      case 1:
        return 'Singles';
      case 2:
        return 'Playlist';
      case 3:
        return _showStoryTab ? 'Story' : 'J. Cole Vault';
      default:
        return 'J. Cole Vault';
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIndex = (!_showStoryTab && _tabIndex >= 3) ? 0 : _tabIndex;
    final page = switch (effectiveIndex) {
      0 => LibraryPage(
        key: const ValueKey('albums'),
        tabType: CollectionType.album,
        entries: _ofType(CollectionType.album),
        onOpen: _openDetail,
        onCreateCollection: () => _createCollection(CollectionType.album),
        onUploadToCollection: () =>
            _uploadSongsToTypeCollection(CollectionType.album),
        onMenuAction: _runMenuAction,
      ),
      1 => LibraryPage(
        key: const ValueKey('singles'),
        tabType: CollectionType.single,
        entries: _ofType(CollectionType.single),
        onOpen: _openDetail,
        onCreateCollection: () => _createCollection(CollectionType.single),
        onUploadToCollection: () =>
            _uploadSongsToTypeCollection(CollectionType.single),
        onMenuAction: _runMenuAction,
      ),
      2 => LibraryPage(
        key: const ValueKey('playlists'),
        tabType: CollectionType.playlist,
        entries: _ofType(CollectionType.playlist),
        onOpen: _openDetail,
        onCreateCollection: () => _createCollection(CollectionType.playlist),
        onUploadToCollection: () =>
            _uploadSongsToTypeCollection(CollectionType.playlist),
        onMenuAction: _runMenuAction,
      ),
      _ => const ArtistHistoryPage(key: ValueKey('story')),
    };

    final slideFromRight = _tabIndex > _previousTabIndex;
    final offsetStart = slideFromRight
        ? const Offset(0.2, 0)
        : const Offset(-0.2, 0);

    return GraffitiScaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          _title,
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
            if (_currentTrack != null)
              MiniPlayerBar(
                track: _currentTrack!,
                isPlaying: _isPlaying,
                duration: _duration,
                position: _position,
                onToggle: () => _playTrack(_currentTrack!),
                onSeek: _seekTo,
                onSkipBack: () => _seekBySeconds(-10),
                onSkipForward: () => _seekBySeconds(10),
              ),
            FloatingNavBar(
              selectedIndex: _tabIndex,
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
