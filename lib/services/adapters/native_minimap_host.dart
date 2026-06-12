import 'dart:async';

import 'package:flutter/services.dart';

import '../minimap_host.dart';

/// Android adapter for [MinimapHost] over the native `zee/minimap` MethodChannel
/// and the `zee/minimap/guidance` EventChannel.
///
/// Registered on Android in dhuMain (Block 0009, ADR 0001 exception).
/// The DHU Dart isolate drives the native MinimapView (TextureView under-layer)
/// on the HUD Presentation via this channel.
///
/// setMinimap / setMinimapBounds / setMinimapParam are idempotent on the native
/// side (NOOP-log when already in the requested state).
///
/// The [guidance] stream is fed from the `zee/minimap/guidance` EventChannel.
/// Each event is a `Map<String, dynamic>` with keys:
///   turnIcon   : String? — maneuver type code (e.g. "8" = TURN\_NORMAL\_RIGHT)
///   distanceM  : int?   — metres to next maneuver
///   roadName   : String? — next road / cue text
///   etaMin     : int?   — minutes to destination
class NativeMinimapHost implements MinimapHost {
  static const MethodChannel _ch = MethodChannel('zee/minimap');
  static const EventChannel _guidanceCh = EventChannel('zee/minimap/guidance');

  late final Stream<GuidanceEvent> _guidanceStream;

  NativeMinimapHost() {
    _guidanceStream = _guidanceCh
        .receiveBroadcastStream()
        .map((dynamic raw) {
          final m = (raw as Map?)?.cast<String, dynamic>() ?? {};
          return GuidanceEvent(
            turnIcon: m['turnIcon'] as String?,
            distanceM: m['distanceM'] as int?,
            roadName: m['roadName'] as String?,
            etaMin: m['etaMin'] as int?,
          );
        })
        .asBroadcastStream();
  }

  @override
  Future<void> enable(bool on) async {
    await _ch.invokeMethod<Object?>('setMinimap', {'enabled': on});
  }

  @override
  Future<void> setBounds(Rect r) async {
    await _ch.invokeMethod<Object?>('setMinimapBounds', {
      'x': r.left.toInt(),
      'y': r.top.toInt(),
      'w': r.width.toInt(),
      'h': r.height.toInt(),
    });
  }

  @override
  Future<void> setParams(Map<String, Object?> p) async {
    for (final entry in p.entries) {
      await _ch.invokeMethod<Object?>(
        'setMinimapParam',
        {'key': entry.key, 'value': entry.value},
      );
    }
  }

  @override
  Stream<GuidanceEvent> get guidance => _guidanceStream;

  /// Delegates to the native PackageManager check over zee/minimap.
  /// Returns false on any channel error (safe default: toggle stays disabled).
  @override
  Future<bool> isYnaviAvailable() async {
    try {
      final result = await _ch.invokeMethod<bool>('isYnaviAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
