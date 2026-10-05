import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;

enum MusicVideoStatus { loading, playing, paused, ended, failed }

/// A music video shown alongside the lyrics. An interface so the lyrics
/// page can be tested with a fake instead of the WebView-based player.
abstract class MusicVideoPlayer {
  /// Video position, reported about every 100 ms while playing.
  Stream<Duration> get positions;
  Stream<MusicVideoStatus> get statuses;
  Duration get position;
  MusicVideoStatus get status;

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);

  /// The visible player. [aspectRatio] matches the box it is given, which
  /// is never smaller than YouTube's 200×200 minimum.
  Widget buildView(BuildContext context, {required double aspectRatio});

  Future<void> dispose();
}

typedef MusicVideoPlayerFactory =
    MusicVideoPlayer Function({
      required String videoId,
      required Duration start,
      required bool autoPlay,
    });

/// Whether the embedded YouTube player works here (it needs a WebView or a
/// browser; Windows and Linux don't have one it supports).
bool get embeddedVideoSupported =>
    kIsWeb ||
    const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

MusicVideoPlayer createYoutubeMusicVideoPlayer({
  required String videoId,
  required Duration start,
  required bool autoPlay,
}) => _YoutubeMusicVideoPlayer(
  videoId: videoId,
  start: start,
  autoPlay: autoPlay,
);

/// YouTube's official IFrame player. It plays with its own sound and is
/// never covered by other widgets, per YouTube's developer policies.
class _YoutubeMusicVideoPlayer implements MusicVideoPlayer {
  _YoutubeMusicVideoPlayer({
    required String videoId,
    required Duration start,
    required bool autoPlay,
  }) : _controller = yt.YoutubePlayerController.fromVideoId(
         videoId: videoId,
         autoPlay: autoPlay,
         startSeconds: start.inMilliseconds / 1000,
         params: const yt.YoutubePlayerParams(
           showFullscreenButton: true,
           strictRelatedVideos: true,
         ),
       ) {
    _stateSub = _controller.videoStateStream.listen((state) {
      _position = state.position;
      _positions.add(state.position);
    });
    _valueSub = _controller.stream.listen((value) {
      final next = _statusFor(value);
      if (next != _status) {
        _status = next;
        _statuses.add(next);
      }
    });
  }

  final yt.YoutubePlayerController _controller;
  final StreamController<Duration> _positions = StreamController.broadcast();
  final StreamController<MusicVideoStatus> _statuses =
      StreamController.broadcast();
  StreamSubscription<yt.YoutubeVideoState>? _stateSub;
  StreamSubscription<yt.YoutubePlayerValue>? _valueSub;
  Duration _position = Duration.zero;
  MusicVideoStatus _status = MusicVideoStatus.loading;

  static MusicVideoStatus _statusFor(yt.YoutubePlayerValue value) {
    if (value.error != yt.YoutubeError.none) {
      return MusicVideoStatus.failed;
    }
    return switch (value.playerState) {
      yt.PlayerState.playing => MusicVideoStatus.playing,
      yt.PlayerState.paused || yt.PlayerState.cued => MusicVideoStatus.paused,
      yt.PlayerState.ended => MusicVideoStatus.ended,
      _ => MusicVideoStatus.loading,
    };
  }

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<MusicVideoStatus> get statuses => _statuses.stream;

  @override
  Duration get position => _position;

  @override
  MusicVideoStatus get status => _status;

  @override
  Future<void> play() => _controller.playVideo();

  @override
  Future<void> pause() => _controller.pauseVideo();

  @override
  Future<void> seekTo(Duration position) {
    _position = position;
    return _controller.seekTo(
      seconds: position.inMilliseconds / 1000,
      allowSeekAhead: true,
    );
  }

  @override
  Widget buildView(BuildContext context, {required double aspectRatio}) {
    return yt.YoutubePlayer(
      controller: _controller,
      aspectRatio: aspectRatio,
      // Vertical drags scroll the lyrics, not toggle full screen.
      enableFullScreenOnVerticalDrag: false,
    );
  }

  @override
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _valueSub?.cancel();
    await _positions.close();
    await _statuses.close();
    await _controller.close();
  }
}
