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
///
/// Native also calls `hudReady({w, h, dpi})` on this channel after [setupHud()]
/// completes.  Subscribers listen via [onHudReady] to re-apply minimap config
/// with the actual HUD display dimensions (QA1-2, QA1-4).
class NativeMinimapHost implements MinimapHost {
  static const MethodChannel _ch = MethodChannel('zee/minimap');
  static const EventChannel _guidanceCh = EventChannel('zee/minimap/guidance');

  late final Stream<GuidanceEvent> _guidanceStream;

  // Non-broadcast: buffers events so hudReady is not lost if Dart startup is
  // slower than the native 1500ms HUD_SPAWN_DELAY (QA1-2).
  final _hudReadyController = StreamController<(double, double, double)>();

  /// Fires once (or again on re-enable) with the actual HUD display
  /// (width, height, dpi) in physical pixels / dpi, reported by native after
  /// [setupHud()] completes.  The dpi is used for phase0 Safe-Area computation.
  Stream<(double, double, double)> get onHudReady => _hudReadyController.stream;

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

    // Handle native→Dart calls on zee/minimap (e.g. hudReady after setupHud).
    _ch.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'hudReady') {
      final args = call.arguments as Map?;
      final w   = (args?['w']   as num?)?.toDouble() ?? 1024.0;
      final h   = (args?['h']   as num?)?.toDouble() ??  576.0;
      final dpi = (args?['dpi'] as num?)?.toDouble() ??  213.0;
      _hudReadyController.add((w, h, dpi));
    }
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
