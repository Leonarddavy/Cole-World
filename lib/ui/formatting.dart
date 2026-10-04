import '../models/collection_models.dart';

/// "4:07" / "1:02:09".
String formatTrackDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}

/// "48 min" / "1 hr 5 min".
String formatTotalLength(Duration total) {
  final minutes = (total.inSeconds / 60).round();
  if (minutes < 60) {
    return '$minutes min';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}

/// The total playing time, or null unless every song's length is known
/// (a partial total would understate it).
Duration? totalDuration(List<Track> tracks) {
  if (tracks.isEmpty || tracks.any((track) => track.duration == null)) {
    return null;
  }
  return tracks.fold<Duration>(
    Duration.zero,
    (sum, track) => sum + track.duration!,
  );
}

/// "1 song" / "12 songs".
String songCount(int count) => '$count ${count == 1 ? 'song' : 'songs'}';
