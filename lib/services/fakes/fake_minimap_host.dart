import 'dart:async';
import 'dart:ui' show Rect;

import '../minimap_host.dart';

/// T1 fake for [MinimapHost].
/// Records commands; can emit a canned GuidanceEvent via [emitGuidance].
///
/// [ynaviAvailable] defaults to false (emulator/T1 state: no mod installed).
/// Flip it to true in a test or via the debug set-config flag to exercise
/// the "YNavi present" UI state on the enable toggle.
class FakeMinimapHost implements MinimapHost {
  FakeMinimapHost({bool ynaviAvailable = false})
      : _ctrl = StreamController<GuidanceEvent>.broadcast(),
        _navCtrl = StreamController<bool>.broadcast(),
        _ynaviAvailable = ynaviAvailable; // ignore: prefer_initializing_formals

  final StreamController<GuidanceEvent> _ctrl;
  final StreamController<bool> _navCtrl;
  bool _ynaviAvailable;

  bool? lastEnabled;
  bool? lastSurfaceVisible;
  Rect? lastBounds;
  Map<String, Object?>? lastParams;

  /// Flip at runtime (e.g. from a debug ext.zee.setConfig flag) to test the
  /// "YNavi available" UI state on T1.
  // ignore: avoid_setters_without_getters
  set ynaviAvailable(bool v) => _ynaviAvailable = v;

  @override
  Future<String?> enable(bool on) async {
    lastEnabled = on;
    if (!on) return 'applied:false';
    return _ynaviAvailable ? 'applied:true' : 'unavailable';
  }

  @override
  Future<void> setSurfaceVisible(bool visible) async {
    lastSurfaceVisible = visible;
  }

  @override
  Future<void> setBounds(Rect r) async => lastBounds = r;

  @override
  Future<void> setParams(Map<String, Object?> p) async => lastParams = p;

  @override
  Stream<GuidanceEvent> get guidance => _ctrl.stream;

  @override
  Stream<bool> get navigationActive => _navCtrl.stream;

  @override
  Future<bool> isYnaviAvailable() async => _ynaviAvailable;

  void emitGuidance(GuidanceEvent e) => _ctrl.add(e);

  void emitNavigationActive(bool active) => _navCtrl.add(active);

  void dispose() {
    _ctrl.close();
    _navCtrl.close();
  }
}
