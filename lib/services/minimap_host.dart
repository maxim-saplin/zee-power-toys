import 'dart:ui' show Rect;

/// Navigation-sidecar port (YNavi minimap).
/// Commands flow in (enable/bounds/params); trip guidance events flow out.
abstract class MinimapHost {
  /// Enables/disables the minimap surface. Returns the native gate result
  /// when known (e.g. `"applied:true"`, `"unavailable"` when YNavi is absent
  /// or the host failed to start, `"no-minimap"` before the HUD engine
  /// exists) — surfaced verbatim in `ext.zee.readViewModel`'s `minimap.native`
  /// field. Native (Android) is the sole source of the availability gate: a
  /// Dart-side `enable(true)` alone can never make content appear when YNavi
  /// is absent (Block "kill the rainbow placeholder").
  Future<String?> enable(bool on);
  /// Show/hide the native minimap TextureView without stopping the YNavi bind
  /// (0057 onlyWhileGuidance). [enable](false) still tears the host down.
  Future<void> setSurfaceVisible(bool visible);
  Future<void> setBounds(Rect r);
  Future<void> setParams(Map<String, Object?> p);
  Stream<GuidanceEvent> get guidance;

  /// Live navigation session truth from YNavi (`navigationStarted` /
  /// `navigationEnded`). Used by 0057 `onlyWhileGuidance` gating — not inferred
  /// from trip/GuidanceEvent traffic alone.
  Stream<bool> get navigationActive;

  /// Returns true when a compatible YNavi mod is installed and detectable.
  ///
  /// Detection: PackageManager presence of ru.yandex.yandexnavi plus
  /// NavigationCarAppService declaration (Step 1+2 from ynavi-bind-and-mod.md §7).
  /// On T2 Android the native side does the check; on T1 the fake returns
  /// a configurable value (default false) for UI-state testing.
  Future<bool> isYnaviAvailable();
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

  /// Serialized for the DHU→HUD relay (0055 FAIL fix).
  Map<String, Object?> toJson() => <String, Object?>{
        if (turnIcon != null) 'turnIcon': turnIcon,
        if (distanceM != null) 'distanceM': distanceM,
        if (roadName != null) 'roadName': roadName,
        if (etaMin != null) 'etaMin': etaMin,
      };

  factory GuidanceEvent.fromJson(Map<String, Object?> json) => GuidanceEvent(
        turnIcon: json['turnIcon'] as String?,
        distanceM: (json['distanceM'] as num?)?.toInt(),
        roadName: json['roadName'] as String?,
        etaMin: (json['etaMin'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is GuidanceEvent &&
      other.turnIcon == turnIcon &&
      other.distanceM == distanceM &&
      other.roadName == roadName &&
      other.etaMin == etaMin;

  @override
  int get hashCode => Object.hash(turnIcon, distanceM, roadName, etaMin);
}
