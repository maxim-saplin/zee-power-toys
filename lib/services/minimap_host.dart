import 'dart:ui' show Rect;

/// Navigation-sidecar port (YNavi minimap).
/// Commands flow in (enable/bounds/params); trip guidance events flow out.
abstract class MinimapHost {
  Future<void> enable(bool on);
  Future<void> setBounds(Rect r);
  Future<void> setParams(Map<String, Object?> p);
  Stream<GuidanceEvent> get guidance;
}

/// A single turn/distance guidance event from the minimap sidecar.
class GuidanceEvent {
  const GuidanceEvent({
    this.turnIcon,
    this.distanceM,
    this.roadName,
    this.etaMin,
  });

  final String? turnIcon;
  final int? distanceM;
  final String? roadName;
  final int? etaMin;
}
