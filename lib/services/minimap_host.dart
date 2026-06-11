import 'dart:ui' show Rect;

/// Navigation-sidecar port (YNavi minimap).
/// Commands flow in (enable/bounds/params); trip guidance events flow out.
abstract class MinimapHost {
  Future<void> enable(bool on);
  Future<void> setBounds(Rect r);
  Future<void> setParams(Map<String, Object?> p);
  Stream<GuidanceEvent> get guidance;

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
}
