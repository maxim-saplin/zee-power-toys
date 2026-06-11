import 'dart:convert';

/// The sub-rectangle of the HUD's backing display that is optically visible
/// through the projector optics.  All four values are logical fractions 0..1
/// relative to the backing display's width (left/right) or height (top/bottom).
///
/// Phase-0 defaults are derived from the hand-calibrated Zeekr S2 values in
/// hud-presentation-host.md: display 1024×576 @ 213 dpi, density=1.33125.
///   safeW≈820 px, safeH≈233 px, safeCenterX≈519 px, safeCenterY≈296 px
///   → left=109/1024≈0.1064, top=180/576≈0.3125,
///     right=929/1024≈0.9072, bottom=413/576≈0.7170
/// These are T3-calibrated values; T3 validation should re-confirm on the
/// physical car if optics shift between units.
class HudSafeArea {
  const HudSafeArea({
    this.left = _defaultLeft,
    this.top = _defaultTop,
    this.right = _defaultRight,
    this.bottom = _defaultBottom,
  });

  /// Phase-0 hand-calibrated defaults (Zeekr S2, 1024×576 display).
  static const double _defaultLeft = 0.1064;
  static const double _defaultTop = 0.3125;
  static const double _defaultRight = 0.9072;
  static const double _defaultBottom = 0.7170;

  /// Fraction of backing-display width from left edge.
  final double left;

  /// Fraction of backing-display height from top edge.
  final double top;

  /// Fraction of backing-display width to right edge.
  final double right;

  /// Fraction of backing-display height to bottom edge.
  final double bottom;

  HudSafeArea copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) => HudSafeArea(
    left: left ?? this.left,
    top: top ?? this.top,
    right: right ?? this.right,
    bottom: bottom ?? this.bottom,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  factory HudSafeArea.fromJson(Map<String, Object?> json) => HudSafeArea(
    left: (json['left'] as num?)?.toDouble() ?? _defaultLeft,
    top: (json['top'] as num?)?.toDouble() ?? _defaultTop,
    right: (json['right'] as num?)?.toDouble() ?? _defaultRight,
    bottom: (json['bottom'] as num?)?.toDouble() ?? _defaultBottom,
  );

  @override
  bool operator ==(Object other) =>
      other is HudSafeArea &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Minimal app configuration.
/// Plain JSON serialization so the native boot shim can read it.
class AppConfig {
  const AppConfig({this.hudBoxOn = false, this.safeArea = const HudSafeArea()});

  final bool hudBoxOn;

  /// Safe Area rectangle for the HUD's backing display.
  final HudSafeArea safeArea;

  AppConfig copyWith({bool? hudBoxOn, HudSafeArea? safeArea}) => AppConfig(
    hudBoxOn: hudBoxOn ?? this.hudBoxOn,
    safeArea: safeArea ?? this.safeArea,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'hudBoxOn': hudBoxOn,
    'safeArea': safeArea.toJson(),
  };

  factory AppConfig.fromJson(Map<String, Object?> json) => AppConfig(
    hudBoxOn: json['hudBoxOn'] as bool? ?? false,
    safeArea: json['safeArea'] is Map<String, Object?>
        ? HudSafeArea.fromJson(json['safeArea']! as Map<String, Object?>)
        : const HudSafeArea(),
  );

  /// Convenience: round-trip through JSON string (used by SharedPrefsConfigStore).
  factory AppConfig.fromJsonString(String s) =>
      AppConfig.fromJson(jsonDecode(s) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      other is AppConfig &&
      other.hudBoxOn == hudBoxOn &&
      other.safeArea == safeArea;

  @override
  int get hashCode => Object.hash(hudBoxOn, safeArea);
}

/// Port for config persistence. Each isolate owns its own instance.
abstract class ConfigStore {
  AppConfig get value;
  Stream<AppConfig> get changes;
  Future<void> load();
  Future<void> setConfig(AppConfig next);
}
