import 'dart:async';

import 'package:flutter/services.dart';

import '../minimap_host.dart';

/// Android adapter for [MinimapHost] over the native `zee/minimap` MethodChannel.
///
/// Registered on Android in dhuMain (Block 0009, ADR 0001 exception).
/// The DHU Dart isolate drives the native MinimapView (TextureView under-layer)
/// on the HUD Presentation via this channel.
///
/// setMinimap / setMinimapBounds / setMinimapParam are idempotent on the native
/// side (NOOP-log when already in the requested state).
///
/// The [guidance] stream is empty for now (no YNavi bind yet — T3).
class NativeMinimapHost implements MinimapHost {
  static const MethodChannel _ch = MethodChannel('zee/minimap');

  // guidance stream is a no-op placeholder until T3 YNavi bind.
  final StreamController<GuidanceEvent> _guidanceCtrl =
      StreamController<GuidanceEvent>.broadcast();

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
  Stream<GuidanceEvent> get guidance => _guidanceCtrl.stream;

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

  void dispose() => _guidanceCtrl.close();
}
