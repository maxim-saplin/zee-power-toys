import 'dart:async';

/// Immutable now-playing snapshot for HUD media chrome (0123).
///
/// [progress] is 0.0…1.0 (bar only — no elapsed/remaining times in chrome).
/// Null / inactive → BatteryWidget hides media chrome.
class MediaNowPlaying {
  const MediaNowPlaying({
    required this.artist,
    required this.title,
    required this.progress,
    this.isPlaying = true,
  });

  final String artist;
  final String title;

  /// 0.0…1.0 playback fraction.
  final double progress;
  final bool isPlaying;

  String get artistSongLabel {
    final a = artist.trim();
    final t = title.trim();
    if (a.isEmpty && t.isEmpty) return '';
    if (a.isEmpty) return t;
    if (t.isEmpty) return a;
    return '$a — $t';
  }

  MediaNowPlaying copyWith({
    String? artist,
    String? title,
    double? progress,
    bool? isPlaying,
  }) =>
      MediaNowPlaying(
        artist: artist ?? this.artist,
        title: title ?? this.title,
        progress: progress ?? this.progress,
        isPlaying: isPlaying ?? this.isPlaying,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'artist': artist,
        'title': title,
        'progress': progress,
        'isPlaying': isPlaying,
      };

  @override
  bool operator ==(Object other) =>
      other is MediaNowPlaying &&
      other.artist == artist &&
      other.title == title &&
      other.progress == progress &&
      other.isPlaying == isPlaying;

  @override
  int get hashCode => Object.hash(artist, title, progress, isPlaying);
}

/// Port for now-playing metadata. T1 uses [FakeMediaNowPlaying]; native
/// MediaSession bind is soft/deferred (0123 FAIL-open).
abstract class MediaNowPlayingSource {
  MediaNowPlaying? get current;
  Stream<MediaNowPlaying?> get changes;

  /// Push / clear a session (T1 inject + future native bridge).
  void setNowPlaying(MediaNowPlaying? value);
}

/// In-memory source for T1 concepts + dens320 inject until MediaSession
/// binding is proven on car/DHU.
class FakeMediaNowPlaying implements MediaNowPlayingSource {
  FakeMediaNowPlaying([MediaNowPlaying? seed])
      : _current = seed,
        _ctrl = StreamController<MediaNowPlaying?>.broadcast();

  MediaNowPlaying? _current;
  final StreamController<MediaNowPlaying?> _ctrl;

  @override
  MediaNowPlaying? get current => _current;

  @override
  Stream<MediaNowPlaying?> get changes => _ctrl.stream;

  @override
  void setNowPlaying(MediaNowPlaying? value) {
    _current = value;
    _ctrl.add(value);
  }

  void dispose() {
    _ctrl.close();
  }
}
