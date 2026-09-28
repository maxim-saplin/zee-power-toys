import 'dart:async';

/// Immutable now-playing snapshot for HUD media chrome (0123 / 0125).
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

  /// Relay / inject decode. Returns null when [j] is a clear envelope or
  /// lacks both artist and title.
  static MediaNowPlaying? fromJson(Map<String, Object?> j) {
    if (j['clear'] == true) return null;
    final artist = (j['artist'] as String?)?.trim() ?? '';
    final title = (j['title'] as String?)?.trim() ?? '';
    if (artist.isEmpty && title.isEmpty) return null;
    final progress =
        ((j['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final playing = j['isPlaying'] as bool? ?? true;
    return MediaNowPlaying(
      artist: artist,
      title: title,
      progress: progress,
      isPlaying: playing,
    );
  }

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

/// Port for now-playing metadata.
///
/// Production (Android DHU): [NativeMediaNowPlaying] bound to
/// MediaSessionManager (0125). HUD isolate: Fake sink fed by DHU→HUD relay.
/// [FakeMediaNowPlaying] + `ext.zee.inject kind=media` remain **debug
/// fallback** only (dens320 without a real player / T1 desktop).
abstract class MediaNowPlayingSource {
  MediaNowPlaying? get current;
  Stream<MediaNowPlaying?> get changes;

  /// Push / clear a session (debug inject + HUD relay sink).
  void setNowPlaying(MediaNowPlaying? value);

  /// FL/QA provenance: `mediasession` | `inject` | `fake`.
  String get debugSourceKind => 'fake';
}

/// In-memory source — T1 desktop, HUD relay sink, and dens320 inject fallback.
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

  @override
  String get debugSourceKind => 'fake';

  void dispose() {
    _ctrl.close();
  }
}
