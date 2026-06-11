import 'dart:async';
import 'dart:ui' show Rect;

import '../minimap_host.dart';

/// T1 fake for [MinimapHost].
/// Records commands; can emit a canned GuidanceEvent via [emitGuidance].
class FakeMinimapHost implements MinimapHost {
  FakeMinimapHost() : _ctrl = StreamController<GuidanceEvent>.broadcast();

  final StreamController<GuidanceEvent> _ctrl;

  bool? lastEnabled;
  Rect? lastBounds;
  Map<String, Object?>? lastParams;

  @override
  Future<void> enable(bool on) async => lastEnabled = on;

  @override
  Future<void> setBounds(Rect r) async => lastBounds = r;

  @override
  Future<void> setParams(Map<String, Object?> p) async => lastParams = p;

  @override
  Stream<GuidanceEvent> get guidance => _ctrl.stream;

  void emitGuidance(GuidanceEvent e) => _ctrl.add(e);

  void dispose() => _ctrl.close();
}
