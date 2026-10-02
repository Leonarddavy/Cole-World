import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/collection_models.dart';
import '../models/lyrics.dart';
import '../services/online_lyrics.dart';
import '../widgets/graffiti_scaffold.dart';

enum _LyricsMenuAction { import, remove }

/// Full-screen lyrics for whatever is playing. Synced lyrics highlight and
/// follow the current line; tapping a line seeks to it.
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

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  Track? _track;
  Future<Lyrics?>? _lyricsFuture;

  @override
  void initState() {
    super.initState();
    widget.currentTrackListenable.addListener(_onTrackChanged);
    _onTrackChanged();
  }

  @override
  void dispose() {
    widget.currentTrackListenable.removeListener(_onTrackChanged);
    super.dispose();
  }

  void _onTrackChanged() {
    final track = widget.currentTrackListenable.value;
    if (track?.id == _track?.id && _lyricsFuture != null) {
      return;
    }
    setState(() {
      _track = track;
      _lyricsFuture = track == null ? null : widget.loadLyrics(track);
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = _track;

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
          if (track != null)
            PopupMenuButton<_LyricsMenuAction>(
              tooltip: 'Lyrics options',
              onSelected: (action) {
                switch (action) {
                  case _LyricsMenuAction.import:
                    _import();
                  case _LyricsMenuAction.remove:
                    _remove();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _LyricsMenuAction.import,
                  child: Text('Import lyrics file…'),
                ),
                PopupMenuItem(
                  value: _LyricsMenuAction.remove,
                  child: Text('Remove imported lyrics'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: track == null
            ? const Center(child: Text('Nothing is playing.'))
            : FutureBuilder<Lyrics?>(
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
                          positionStream: widget.positionStream,
                          initialPosition: widget.initialPosition,
                          onSeek: widget.onSeek,
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
              ),
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
      child: Padding(
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
  });

  final Lyrics lyrics;
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Future<void> Function(Duration position) onSeek;

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
