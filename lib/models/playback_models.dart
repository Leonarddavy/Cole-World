enum PlaybackRepeatMode { off, all, one }

/// An active sleep timer: either a wall-clock deadline or "end of track".
class SleepTimerState {
  const SleepTimerState.at(DateTime this.endsAt) : endOfTrack = false;

  const SleepTimerState.endOfTrack() : endsAt = null, endOfTrack = true;

  final DateTime? endsAt;
  final bool endOfTrack;

  /// Time left before playback stops, or null for "end of track".
  Duration? remaining([DateTime? now]) {
    final deadline = endsAt;
    if (deadline == null) {
      return null;
    }
    final left = deadline.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}
