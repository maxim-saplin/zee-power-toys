import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../media_now_playing.dart';

/// Native MediaSession → [MediaNowPlayingSource] for Android DHU.
///
/// Channels (registered on the DHU engine only):
///   MethodChannel  `zee/media`         — start() / snapshot()
///   EventChannel   `zee/media/events`  — streamed now-playing maps
///
/// HUD isolate does **not** use this adapter; it receives relayed snapshots
/// via [pushMediaToHud] / Fake sink (ADR 0003), same pattern as CarSignals.
///
/// [setNowPlaying] remains the **debug inject** path (`ext.zee.inject
/// kind=media`) — last writer wins until the next native tick / clear.
class NativeMediaNowPlaying implements MediaNowPlayingSource {
  static const _methodCh = MethodChannel('zee/media');
  static const _eventCh = EventChannel('zee/media/events');

  NativeMediaNowPlaying() {
    _sub = _eventCh.receiveBroadcastStream().listen(
      onNativeEvent,
      onError: (Object err) =>
          debugPrint('NativeMediaNowPlaying: event error: $err'),
    );
    _methodCh.invokeMapMethod<String, Object?>('start').then((raw) {
      if (raw != null) onNativeEvent(raw);
    }).catchError((Object err) {
      debugPrint('NativeMediaNowPlaying: start failed: $err');
    });
  }

  MediaNowPlaying? _current;
  final StreamController<MediaNowPlaying?> _ctrl =
      StreamController<MediaNowPlaying?>.broadcast();
  StreamSubscription<dynamic>? _sub;

  /// Last native/inject provenance for readViewModel / QA.
  String sourceKind = 'mediasession';

  @override
  String get debugSourceKind => sourceKind;

  @override
  MediaNowPlaying? get current => _current;

  @override
  Stream<MediaNowPlaying?> get changes => _ctrl.stream;

  @override
  void setNowPlaying(MediaNowPlaying? value) {
    sourceKind = value == null ? 'mediasession' : 'inject';
    _apply(value);
  }

  /// Decode a native EventChannel map. Visible for unit tests.
  @visibleForTesting
  void onNativeEvent(dynamic raw) {
    if (raw is! Map) {
      _apply(null);
      return;
    }
    final m = Map<String, Object?>.from(raw);
    sourceKind = (m['source'] as String?) ?? 'mediasession';
    final active = m['active'] == true;
    if (!active) {
      _apply(null);
      return;
    }
    final artist = (m['artist'] as String?)?.trim() ?? '';
    final title = (m['title'] as String?)?.trim() ?? '';
    if (artist.isEmpty && title.isEmpty) {
      _apply(null);
      return;
    }
    final progress = _asDouble(m['progress'])?.clamp(0.0, 1.0) ?? 0.0;
    final playing = m['isPlaying'] == true;
    _apply(
      MediaNowPlaying(
        artist: artist,
        title: title,
        progress: progress,
        isPlaying: playing,
      ),
    );
  }

  void _apply(MediaNowPlaying? value) {
    if (_current == value) return;
    _current = value;
    if (!_ctrl.isClosed) _ctrl.add(value);
  }

  double? _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return null;
  }

  void dispose() {
    _sub?.cancel();
    _ctrl.close();
  }
}
