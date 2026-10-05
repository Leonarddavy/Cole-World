import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/collection_models.dart';
import '../models/lyrics.dart';
import '../services/music_video.dart';
import '../services/online_lyrics.dart';
import '../widgets/graffiti_scaffold.dart';
import '../widgets/music_video_player.dart';

enum _LyricsMenuAction { import, remove, findVideo, removeVideo }

/// What the lyrics page needs to play a song's music video in sync.
///
/// The video comes from YouTube and plays with its own sound (YouTube's
/// rules forbid muting it under other audio or drawing over the player), so
/// the song pauses while a video is open and picks up from the matching
/// moment when the video closes.
class MusicVideoSupport {
  const MusicVideoSupport({
    required this.linkFor,
    required this.saveLink,
    required this.ensureConsent,
    required this.canSearch,
    required this.search,
    required this.openExternal,
    required this.pauseSong,
    required this.resumeSong,
    required this.songPosition,
    required this.songPlayingStream,
    this.playerFactory = createYoutubeMusicVideoPlayer,
    this.embeddedPlayerAvailable,
  });

  final MusicVideoLink? Function(Track track) linkFor;
  final Future<void> Function(Track track, MusicVideoLink? link) saveLink;

  /// Asks once before the first video; resolves to whether to go ahead.
  final Future<bool> Function() ensureConsent;

  /// Whether automatic search is set up (a YouTube API key is saved).
  final bool Function() canSearch;
  final Future<List<MusicVideoCandidate>> Function(Track track) search;
  final Future<bool> Function(Uri uri) openExternal;

  /// Pauses the song; resolves to whether it was playing.
  final Future<bool> Function() pauseSong;

  /// Continues the song from [position], playing if [play].
  final Future<void> Function(Duration position, {required bool play})
  resumeSong;
  final Duration Function() songPosition;

  /// Whether the song is playing, to notice it being started from elsewhere
  /// (lock screen, headphones) while a video is open.
  final Stream<bool> songPlayingStream;
  final MusicVideoPlayerFactory playerFactory;

  /// Overrides platform detection (for tests).
  final bool? embeddedPlayerAvailable;

  bool get embedded => embeddedPlayerAvailable ?? embeddedVideoSupported;
}

/// Full-screen lyrics for whatever is playing. Synced lyrics highlight and
/// follow the current line; tapping a line seeks to it. Optionally shows the
/// song's music video, with the lyrics following the video.
class LyricsPage extends StatefulWidget {
  const LyricsPage({
    super.key,
    required this.currentTrackListenable,
    required this.positionStream,
    required this.initialPosition,
    required this.onSeek,
    required this.loadLyrics,
    required this.onImportLyrics,
    required this.onRemoveLyrics,
    required this.onlineLyricsListenable,
    required this.onEnableOnlineLyrics,
    this.musicVideos,
  });

  final ValueListenable<Track?> currentTrackListenable;
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Future<void> Function(Duration position) onSeek;
  final Future<Lyrics?> Function(Track track) loadLyrics;

  /// Lets the user pick a lyrics file; returns the new lyrics if imported.
  final Future<Lyrics?> Function(Track track) onImportLyrics;
  final Future<void> Function(Track track) onRemoveLyrics;
  final ValueListenable<bool> onlineLyricsListenable;

  /// Asks to turn on online lookups; resolves to whether they are now on.
  final Future<bool> Function() onEnableOnlineLyrics;

  /// Music video support; the video button is hidden without it.
  final MusicVideoSupport? musicVideos;

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  /// One tap on the sync buttons moves the lyrics by this much.
  static const Duration _syncStep = Duration(milliseconds: 500);

  Track? _track;
  Future<Lyrics?>? _lyricsFuture;

  /// What the lyrics follow: the song, or the video while one is open.
  final StreamController<Duration> _lyricsPositions =
      StreamController.broadcast(sync: true);
  StreamSubscription<Duration>? _songPositionSub;
  StreamSubscription<bool>? _songPlayingSub;
  AppLifecycleListener? _lifecycle;
  late Duration _songPosition = widget.initialPosition;

  MusicVideoPlayer? _video;
  MusicVideoLink? _videoLink;
  Track? _videoTrack;
  StreamSubscription<Duration>? _videoPositionSub;
  StreamSubscription<MusicVideoStatus>? _videoStatusSub;
  bool _openingVideo = false;

  /// Set at the start of dispose, when the page must no longer rebuild.
  bool _disposing = false;

  /// Keeps the lyrics (and their scroll position) alive when the video panel
  /// appears or disappears around them.
  final GlobalKey _lyricsKey = GlobalKey();

  bool get _videoOpen => _video != null;

  @override
  void initState() {
    super.initState();
    widget.currentTrackListenable.addListener(_onTrackChanged);
    _onTrackChanged();
    _songPositionSub = widget.positionStream.listen((position) {
      _songPosition = position;
      if (!_videoOpen && !_lyricsPositions.isClosed) {
        _lyricsPositions.add(position);
      }
    });
    final videos = widget.musicVideos;
    if (videos != null) {
      _songPlayingSub = videos.songPlayingStream.listen((playing) {
        // Never play the song and the video at the same time.
        if (playing && _videoOpen && !_openingVideo) {
          unawaited(_closeVideo(resumeSong: false));
        }
      });
      // YouTube doesn't allow background playback, and music shouldn't stop
      // when the screen goes off: hand back to the song.
      _lifecycle = AppLifecycleListener(
        onHide: _handOffToSong,
        onPause: _handOffToSong,
      );
    }
  }

  @override
  void dispose() {
    _disposing = true;
    widget.currentTrackListenable.removeListener(_onTrackChanged);
    _songPositionSub?.cancel();
    _songPlayingSub?.cancel();
    _lifecycle?.dispose();
    if (_videoOpen) {
      // Leaving the screen: the song continues where the video was.
      unawaited(_closeVideo(resumeSong: true));
    }
    _lyricsPositions.close();
    super.dispose();
  }

  void _onTrackChanged() {
    final track = widget.currentTrackListenable.value;
    if (track?.id == _track?.id && _lyricsFuture != null) {
      return;
    }
    if (_videoOpen && _videoTrack?.id != track?.id) {
      // Another song is loaded now (e.g. skipped from the lock screen).
      unawaited(_closeVideo(resumeSong: false));
    }
    setState(() {
      _track = track;
      _lyricsFuture = track == null ? null : widget.loadLyrics(track);
    });
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import() async {
    final track = _track;
    if (track == null) {
      return;
    }
    final imported = await widget.onImportLyrics(track);
    if (!mounted || imported == null || _track?.id != track.id) {
      return;
    }
    setState(() {
      _lyricsFuture = Future.value(imported);
    });
  }

  Future<void> _searchOnline() async {
    final track = _track;
    if (track == null || !await widget.onEnableOnlineLyrics()) {
      return;
    }
    if (!mounted || _track?.id != track.id) {
      return;
    }
    setState(() {
      _lyricsFuture = widget.loadLyrics(track);
    });
  }

  Future<void> _remove() async {
    final track = _track;
    if (track == null) {
      return;
    }
    await widget.onRemoveLyrics(track);
    if (!mounted || _track?.id != track.id) {
      return;
    }
    setState(() {
      _lyricsFuture = widget.loadLyrics(track);
    });
  }

  // --- music video ---------------------------------------------------------

  void _handOffToSong() {
    if (_videoOpen) {
      unawaited(_closeVideo(resumeSong: true));
    }
  }

  Future<void> _toggleVideo() async {
    if (_videoOpen) {
      await _closeVideo(resumeSong: true);
      return;
    }
    final videos = widget.musicVideos;
    final track = _track;
    if (videos == null || track == null || _openingVideo) {
      return;
    }
    if (!await videos.ensureConsent() || !mounted || _track?.id != track.id) {
      return;
    }
    final link = videos.linkFor(track) ?? await _chooseVideo(track);
    if (link == null || !mounted || _track?.id != track.id) {
      return;
    }
    await _openVideo(track, link);
  }

  Future<void> _findDifferentVideo() async {
    final videos = widget.musicVideos;
    final track = _track;
    if (videos == null || track == null) {
      return;
    }
    if (!await videos.ensureConsent() || !mounted) {
      return;
    }
    if (_videoOpen) {
      await _closeVideo(resumeSong: true);
    }
    final link = await _chooseVideo(track);
    if (link != null && mounted && _track?.id == track.id) {
      await _openVideo(track, link);
    }
  }

  Future<void> _removeVideo() async {
    final videos = widget.musicVideos;
    final track = _track;
    if (videos == null || track == null) {
      return;
    }
    if (_videoOpen) {
      await _closeVideo(resumeSong: true);
    }
    await videos.saveLink(track, null);
    _showSnack('Music video removed for this song.');
    if (mounted) {
      setState(() {});
    }
  }

  Future<MusicVideoLink?> _chooseVideo(Track track) async {
    final videos = widget.musicVideos!;
    final link = await showModalBottomSheet<MusicVideoLink>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _FindVideoSheet(
        track: track,
        canSearch: videos.canSearch(),
        search: () => videos.search(track),
        openExternal: videos.openExternal,
      ),
    );
    if (link != null) {
      await videos.saveLink(track, link);
    }
    return link;
  }

  Future<void> _openVideo(Track track, MusicVideoLink link) async {
    final videos = widget.musicVideos!;
    if (!videos.embedded) {
      // No embedded player on this platform: watch it on YouTube instead.
      if (!await videos.openExternal(link.watchUri)) {
        _showSnack("Couldn't open YouTube.");
      }
      return;
    }
    _openingVideo = true;
    try {
      final songPosition = videos.songPosition();
      final wasPlaying = await videos.pauseSong();
      if (!mounted || _track?.id != track.id) {
        if (wasPlaying) {
          await videos.resumeSong(songPosition, play: true);
        }
        return;
      }
      final player = videos.playerFactory(
        videoId: link.videoId,
        start: link.videoTimeFor(songPosition),
        autoPlay: wasPlaying,
      );
      _videoPositionSub = player.positions.listen((position) {
        final current = _videoLink;
        if (current != null && !_lyricsPositions.isClosed) {
          _lyricsPositions.add(current.songTimeFor(position));
        }
      });
      _videoStatusSub = player.statuses.listen(_onVideoStatus);
      setState(() {
        _video = player;
        _videoLink = link;
        _videoTrack = track;
      });
    } finally {
      _openingVideo = false;
    }
  }

  void _onVideoStatus(MusicVideoStatus status) {
    switch (status) {
      case MusicVideoStatus.ended:
        unawaited(_closeVideo(resumeSong: true));
      case MusicVideoStatus.failed:
        unawaited(_closeVideo(resumeSong: true));
        _showSnack(
          "This video can't play inside the app. Pick another from the ⋮ menu.",
        );
      case MusicVideoStatus.loading ||
          MusicVideoStatus.playing ||
          MusicVideoStatus.paused:
        if (mounted) {
          setState(() {});
        }
    }
  }

  Future<void> _closeVideo({required bool resumeSong}) async {
    final player = _video;
    final link = _videoLink;
    final videos = widget.musicVideos;
    if (player == null || link == null || videos == null) {
      return;
    }
    final videoPosition = player.position;
    final keepPlaying =
        player.status == MusicVideoStatus.playing ||
        player.status == MusicVideoStatus.ended;
    _video = null;
    _videoLink = null;
    _videoTrack = null;
    // Not awaited: nothing depends on the cancel finishing.
    unawaited(_videoPositionSub?.cancel());
    unawaited(_videoStatusSub?.cancel());
    _videoPositionSub = null;
    _videoStatusSub = null;
    if (mounted && !_disposing) {
      setState(() {});
    }
    final songPosition = link.songTimeFor(videoPosition);
    if (!_lyricsPositions.isClosed) {
      _lyricsPositions.add(resumeSong ? songPosition : _songPosition);
    }
    unawaited(player.dispose());
    if (resumeSong) {
      await videos.resumeSong(songPosition, play: keepPlaying);
    }
  }

  void _setSyncOffset(Duration offset) {
    final link = _videoLink;
    final track = _videoTrack;
    final player = _video;
    if (link == null || track == null || player == null) {
      return;
    }
    final next = link.copyWith(offset: offset);
    setState(() => _videoLink = next);
    unawaited(widget.musicVideos!.saveLink(track, next));
    if (!_lyricsPositions.isClosed) {
      _lyricsPositions.add(next.songTimeFor(player.position));
    }
  }

  /// "This line is being sung right now": lines the lyrics up with the video.
  void _syncToLine(LyricLine line) {
    final player = _video;
    final time = line.time;
    if (player == null || time == null) {
      return;
    }
    HapticFeedback.mediumImpact();
    _setSyncOffset(player.position - time);
    _showSnack('Synced: the lyrics now follow this video.');
  }

  Future<void> _seekLyricsTo(Duration songTime) async {
    final player = _video;
    final link = _videoLink;
    if (player != null && link != null) {
      await player.seekTo(link.videoTimeFor(songTime));
      if (!_lyricsPositions.isClosed) {
        _lyricsPositions.add(songTime);
      }
      return;
    }
    await widget.onSeek(songTime);
  }

  Duration get _currentLyricsPosition {
    final player = _video;
    final link = _videoLink;
    return player != null && link != null
        ? link.songTimeFor(player.position)
        : _songPosition;
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = _track;
    final videos = widget.musicVideos;
    final hasLink = track != null && videos?.linkFor(track) != null;

    return GraffitiScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track?.title ?? 'Lyrics',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (track != null)
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          if (videos != null && track != null)
            IconButton(
              tooltip: _videoOpen
                  ? 'Close music video'
                  : videos.embedded
                  ? 'Watch the music video'
                  : 'Watch the music video on YouTube',
              color: _videoOpen ? theme.colorScheme.primary : null,
              onPressed: _toggleVideo,
              icon: Icon(
                _videoOpen ? Icons.smart_display : Icons.smart_display_outlined,
              ),
            ),
          if (track != null)
            PopupMenuButton<_LyricsMenuAction>(
              tooltip: 'Lyrics options',
              onSelected: (action) {
                switch (action) {
                  case _LyricsMenuAction.import:
                    _import();
                  case _LyricsMenuAction.remove:
                    _remove();
                  case _LyricsMenuAction.findVideo:
                    _findDifferentVideo();
                  case _LyricsMenuAction.removeVideo:
                    _removeVideo();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _LyricsMenuAction.import,
                  child: Text('Import lyrics file…'),
                ),
                const PopupMenuItem(
                  value: _LyricsMenuAction.remove,
                  child: Text('Remove imported lyrics'),
                ),
                if (videos != null) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _LyricsMenuAction.findVideo,
                    child: Text(
                      hasLink ? 'Change music video…' : 'Find music video…',
                    ),
                  ),
                  if (hasLink)
                    const PopupMenuItem(
                      value: _LyricsMenuAction.removeVideo,
                      child: Text('Remove music video'),
                    ),
                ],
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = KeyedSubtree(
              key: _lyricsKey,
              child: track == null
                  ? const Center(child: Text('Nothing is playing.'))
                  : _buildLyrics(context, track),
            );
            final player = _video;
            final link = _videoLink;
            if (player == null || link == null) {
              return content;
            }
            // Phones: the video sits on top, full width (YouTube needs at
            // least 200×200). Wide screens: lyrics and video side by side.
            final wide = constraints.maxWidth >= 840;
            final panel = _VideoPanel(
              player: player,
              link: link,
              width: wide ? 480 : constraints.maxWidth,
              onEarlier: () => _setSyncOffset(link.offset - _syncStep),
              onLater: () => _setSyncOffset(link.offset + _syncStep),
              onReset: () => _setSyncOffset(Duration.zero),
              onClose: () => _closeVideo(resumeSong: true),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: content),
                  SizedBox(
                    width: 480,
                    child: SingleChildScrollView(child: panel),
                  ),
                ],
              );
            }
            return Column(
              children: [
                panel,
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLyrics(BuildContext context, Track track) {
    final theme = Theme.of(context);
    return FutureBuilder<Lyrics?>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final lyrics = snapshot.data;
        if (lyrics == null) {
          return ValueListenableBuilder<bool>(
            valueListenable: widget.onlineLyricsListenable,
            builder: (context, onlineEnabled, _) => _NoLyrics(
              onImport: _import,
              onlineEnabled: onlineEnabled,
              onSearchOnline: _searchOnline,
            ),
          );
        }
        final view = lyrics.isSynced
            ? _SyncedLyricsView(
                key: ValueKey('synced_${track.id}'),
                lyrics: lyrics,
                positionStream: _lyricsPositions.stream,
                initialPosition: _currentLyricsPosition,
                onSeek: _seekLyricsTo,
                onLongPressLine: _videoOpen ? _syncToLine : null,
              )
            : _PlainLyricsView(
                key: ValueKey('plain_${track.id}'),
                lyrics: lyrics,
              );
        if (lyrics.source != lrclibSourceName) {
          return view;
        }
        return Column(
          children: [
            Expanded(child: view),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                'Lyrics provided by LRCLIB (lrclib.net)',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

String _formatOffset(Duration offset) {
  if (offset == Duration.zero) {
    return '0 s';
  }
  final seconds = offset.inMilliseconds / 1000;
  final sign = seconds > 0 ? '+' : '−';
  return '$sign${seconds.abs().toStringAsFixed(1)} s';
}

/// The video, with the controls for lining the lyrics up with it. Nothing
/// is drawn over the player itself.
class _VideoPanel extends StatelessWidget {
  const _VideoPanel({
    required this.player,
    required this.link,
    required this.width,
    required this.onEarlier,
    required this.onLater,
    required this.onReset,
    required this.onClose,
  });

  final MusicVideoPlayer player;
  final MusicVideoLink link;
  final double width;
  final VoidCallback onEarlier;
  final VoidCallback onLater;
  final VoidCallback onReset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = max(200.0, width * 9 / 16);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: Colors.black,
            child: player.buildView(context, aspectRatio: width / height),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Show lyrics earlier',
                onPressed: onEarlier,
                icon: const Icon(Icons.fast_rewind_rounded),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Lyrics timing ${_formatOffset(link.offset)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        if (link.offset != Duration.zero)
                          TextButton(
                            onPressed: onReset,
                            child: const Text('Reset'),
                          ),
                      ],
                    ),
                    Text(
                      'Long-press a line as you hear it to sync',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Show lyrics later',
                onPressed: onLater,
                icon: const Icon(Icons.fast_forward_rounded),
              ),
              IconButton(
                tooltip: 'Close music video',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Picks a video: YouTube search results (with an API key), a pasted link,
/// or YouTube's own search in the browser.
class _FindVideoSheet extends StatefulWidget {
  const _FindVideoSheet({
    required this.track,
    required this.canSearch,
    required this.search,
    required this.openExternal,
  });

  final Track track;
  final bool canSearch;
  final Future<List<MusicVideoCandidate>> Function() search;
  final Future<bool> Function(Uri uri) openExternal;

  @override
  State<_FindVideoSheet> createState() => _FindVideoSheetState();
}

class _FindVideoSheetState extends State<_FindVideoSheet> {
  late final Future<List<MusicVideoCandidate>>? _results = widget.canSearch
      ? widget.search()
      : null;
  final TextEditingController _linkController = TextEditingController();
  String? _linkError;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _useLink() {
    final videoId = parseYouTubeVideoId(_linkController.text);
    if (videoId == null) {
      setState(() => _linkError = "That doesn't look like a YouTube link.");
      return;
    }
    Navigator.pop(context, MusicVideoLink(videoId: videoId));
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted || text.isEmpty) {
      return;
    }
    setState(() {
      _linkController.text = text;
      _linkError = null;
    });
    if (parseYouTubeVideoId(text) != null) {
      _useLink(); // one tap when a link was already copied
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = widget.track;
    final results = _results;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Text('Music video', style: theme.textTheme.titleLarge),
          Text(
            '${track.title} · ${track.artist}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (results == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: const Text('Find videos automatically'),
              subtitle: const Text(
                'Add a free YouTube API key in Settings → Music videos. '
                'Until then, paste a link below.',
              ),
            )
          else
            FutureBuilder<List<MusicVideoCandidate>>(
              future: results,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        LinearProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Searching YouTube…'),
                      ],
                    ),
                  );
                }
                final error = snapshot.error;
                if (error != null) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.error_outline),
                    title: Text(
                      error is MusicVideoSearchException
                          ? error.message
                          : 'YouTube search failed.',
                    ),
                  );
                }
                final candidates = snapshot.data ?? const [];
                if (candidates.isEmpty) {
                  return const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.search_off),
                    title: Text(
                      'No playable videos found. Paste a link below.',
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final (index, candidate) in candidates.take(6).indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 96,
                            height: 54,
                            child: candidate.thumbnailUrl == null
                                ? const ColoredBox(color: Colors.black26)
                                : Image.network(
                                    candidate.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const ColoredBox(color: Colors.black26),
                                  ),
                          ),
                        ),
                        title: Text(
                          candidate.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          index == 0
                              ? '${candidate.channel} · Best match'
                              : candidate.channel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, candidate.toLink()),
                      ),
                  ],
                );
              },
            ),
          const Divider(height: 24),
          Text('Paste a YouTube link', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _linkController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://youtu.be/…',
              errorText: _linkError,
              suffixIcon: IconButton(
                tooltip: 'Paste',
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.content_paste),
              ),
            ),
            onChanged: (_) {
              if (_linkError != null) {
                setState(() => _linkError = null);
              }
            },
            onSubmitted: (_) => _useLink(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: () => widget.openExternal(
                    youtubeSearchUri(title: track.title, artist: track.artist),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Search on YouTube'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _useLink, child: const Text('Use link')),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoLyrics extends StatelessWidget {
  const _NoLyrics({
    required this.onImport,
    required this.onlineEnabled,
    required this.onSearchOnline,
  });

  final VoidCallback onImport;
  final bool onlineEnabled;
  final VoidCallback onSearchOnline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lyrics_outlined, size: 56),
            const SizedBox(height: 14),
            Text(
              'No lyrics for this song yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Import an .lrc file to get lyrics that follow along with the '
              'music. Tip: keep song.lrc next to song.mp3 when you import '
              'songs, and the lyrics come along automatically.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Import lyrics file'),
            ),
            const SizedBox(height: 10),
            if (onlineEnabled)
              Text(
                'Nothing found on LRCLIB either.',
                style: theme.textTheme.bodySmall,
              )
            else
              OutlinedButton.icon(
                onPressed: onSearchOnline,
                icon: const Icon(Icons.travel_explore),
                label: const Text('Find lyrics online'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlainLyricsView extends StatelessWidget {
  const _PlainLyricsView({super.key, required this.lyrics});

  final Lyrics lyrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      children: [
        Text(
          'These lyrics aren\'t time-synced.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final line in lyrics.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              line.text,
              style: theme.textTheme.titleLarge?.copyWith(height: 1.3),
            ),
          ),
      ],
    );
  }
}

class _SyncedLyricsView extends StatefulWidget {
  const _SyncedLyricsView({
    super.key,
    required this.lyrics,
    required this.positionStream,
    required this.initialPosition,
    required this.onSeek,
    this.onLongPressLine,
  });

  final Lyrics lyrics;
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Future<void> Function(Duration position) onSeek;

  /// While a video is open: "this line is being sung now", to sync.
  final ValueChanged<LyricLine>? onLongPressLine;

  @override
  State<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<_SyncedLyricsView> {
  /// After the listener scrolls by hand, leave them there for this long.
  static const Duration _manualScrollHold = Duration(seconds: 4);

  late final List<GlobalKey> _lineKeys = [
    for (var i = 0; i < widget.lyrics.lines.length; i++) GlobalKey(),
  ];
  StreamSubscription<Duration>? _positionSub;
  late int _currentIndex = widget.lyrics.indexAt(widget.initialPosition);
  DateTime? _manualScrollUntil;

  @override
  void initState() {
    super.initState();
    _positionSub = widget.positionStream.listen((position) {
      final index = widget.lyrics.indexAt(position);
      if (index != _currentIndex && mounted) {
        setState(() {
          _currentIndex = index;
        });
        _scrollToCurrent();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToCurrent(animate: false),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _scrollToCurrent({bool animate = true}) {
    final hold = _manualScrollUntil;
    if (hold != null && DateTime.now().isBefore(hold)) {
      return;
    }
    final index = _currentIndex < 0 ? 0 : _currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lineContext = _lineKeys[index].currentContext;
      if (lineContext == null || !lineContext.mounted) {
        return;
      }
      Scrollable.ensureVisible(
        lineContext,
        alignment: 0.35,
        duration: animate ? const Duration(milliseconds: 380) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final baseStyle = theme.textTheme.headlineSmall?.copyWith(
      height: 1.25,
      fontWeight: FontWeight.w700,
    );
    final onLongPressLine = widget.onLongPressLine;

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        _manualScrollUntil = DateTime.now().add(_manualScrollHold);
        return false;
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, line) in widget.lyrics.lines.indexed)
              InkWell(
                key: _lineKeys[i],
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  _manualScrollUntil = null;
                  widget.onSeek(line.time!);
                },
                onLongPress: onLongPressLine == null
                    ? null
                    : () => onLongPressLine(line),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    style: (baseStyle ?? const TextStyle()).copyWith(
                      color: i == _currentIndex
                          ? accent
                          : i < _currentIndex
                          ? Colors.white60
                          : Colors.white38,
                    ),
                    child: Text(line.isBreak ? '♪' : line.text),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
