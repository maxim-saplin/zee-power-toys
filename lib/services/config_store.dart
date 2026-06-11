import 'dart:convert';

/// Battery widget appearance config.
///
/// Defaults: everything shown (showBattery/showTemp/showChargingStats = true),
/// sizeScale = 1.0.  The charging stats panel is show-while-charging — it
/// appears automatically when the car reports charging and is hidden otherwise
/// (app policy per ADR 0003); showChargingStats merely lets the user suppress
/// the panel entirely if they prefer.
class BatteryConfig {
  const BatteryConfig({
    this.showBattery = true,
    this.showTemp = true,
    this.showChargingStats = true,
    this.sizeScale = 1.0,
  });

  /// Whether to render the battery icon and percentage at all.
  final bool showBattery;

  /// Whether to show the battery temperature readout next to the icon.
  final bool showTemp;

  /// Whether to show the charging-stats panel (kW prominent, V/A secondary)
  /// while the car reports charging=true.  When false the panel is always
  /// hidden; when true it auto-shows/hides with the charging flag.
  final bool showChargingStats;

  /// Multiplier applied to the base widget size (1.0 = default).
  final double sizeScale;

  BatteryConfig copyWith({
    bool? showBattery,
    bool? showTemp,
    bool? showChargingStats,
    double? sizeScale,
  }) => BatteryConfig(
    showBattery: showBattery ?? this.showBattery,
    showTemp: showTemp ?? this.showTemp,
    showChargingStats: showChargingStats ?? this.showChargingStats,
    sizeScale: sizeScale ?? this.sizeScale,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'showBattery': showBattery,
    'showTemp': showTemp,
    'showChargingStats': showChargingStats,
    'sizeScale': sizeScale,
  };

  factory BatteryConfig.fromJson(Map<String, Object?> json) => BatteryConfig(
    showBattery: json['showBattery'] as bool? ?? true,
    showTemp: json['showTemp'] as bool? ?? true,
    showChargingStats: json['showChargingStats'] as bool? ?? true,
    sizeScale: (json['sizeScale'] as num?)?.toDouble() ?? 1.0,
  );

  @override
  bool operator ==(Object other) =>
      other is BatteryConfig &&
      other.showBattery == showBattery &&
      other.showTemp == showTemp &&
      other.showChargingStats == showChargingStats &&
      other.sizeScale == sizeScale;

  @override
  int get hashCode =>
      Object.hash(showBattery, showTemp, showChargingStats, sizeScale);
}

/// Shape of the blinker indicator rendered in the HUD BLINKER slot.
///
/// `dots`   — phase0 amber dot cluster (default; faithful to BlinkerOverlayView).
/// `arrows` — chevron turn-arrows ported from phase0 ic_blinker_left/right SVG.
/// `smiley` — a yellow smiley face (new, per REQUIREMENTS "yellow smileys").
enum BlinkerShape { dots, arrows, smiley }

/// Blinker appearance config.  All fields are fractions of the Safe Area unless
/// otherwise noted so they stay correct at any HUD resolution.
///
/// Phase-0 grounding (BlinkerOverlayView):
///   dot size = 12dp, left X offset -282dp, right X offset +292dp,
///   Y offset -60.5dp from Safe Area centre.  The dot pair sits in the upper
///   portion of the display, well clear of the Guidance slot.
///
/// `sidePadFrac` is the inward padding from the left/right Safe Area edge, as a
/// fraction of Safe Area width.  Derived from phase0: the HUD Safe Area was
/// ~820dp wide; the dots sat ~282/820 ≈ 0.34 in from the nearest edge.
/// We round to 0.02 so the dot lands near the outer edge and matches phase0.
///
/// `vertFrac` is the vertical centre of the blinker mark as a fraction of the
/// blinker slot height (0 = top, 1 = bottom).  0.40 places it in the upper
/// portion, matching -60.5dp Y offset from centre in phase0.
class BlinkerConfig {
  const BlinkerConfig({
    this.shape = BlinkerShape.dots,
    this.sizeScale = 1.0,
    this.sidePadFrac = 0.02,
    this.vertFrac = 0.40,
  });

  final BlinkerShape shape;

  /// Multiplier applied to the base blinker size (1.0 = phase0 size).
  final double sizeScale;

  /// Inward padding from the left/right edge of the Safe Area, as fraction of
  /// Safe Area width.  Kept small so the mark stays near the outer edge.
  final double sidePadFrac;

  /// Vertical position of the blinker mark centre as fraction of the BLINKER
  /// slot height (0 = top, 1 = bottom).
  final double vertFrac;

  BlinkerConfig copyWith({
    BlinkerShape? shape,
    double? sizeScale,
    double? sidePadFrac,
    double? vertFrac,
  }) => BlinkerConfig(
    shape: shape ?? this.shape,
    sizeScale: sizeScale ?? this.sizeScale,
    sidePadFrac: sidePadFrac ?? this.sidePadFrac,
    vertFrac: vertFrac ?? this.vertFrac,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'shape': shape.name,
    'sizeScale': sizeScale,
    'sidePadFrac': sidePadFrac,
    'vertFrac': vertFrac,
  };

  factory BlinkerConfig.fromJson(Map<String, Object?> json) {
    final shapeName = json['shape'] as String?;
    final shape = shapeName != null
        ? BlinkerShape.values.firstWhere(
            (e) => e.name == shapeName,
            orElse: () => BlinkerShape.dots,
          )
        : BlinkerShape.dots;
    return BlinkerConfig(
      shape: shape,
      sizeScale: (json['sizeScale'] as num?)?.toDouble() ?? 1.0,
      sidePadFrac: (json['sidePadFrac'] as num?)?.toDouble() ?? 0.02,
      vertFrac: (json['vertFrac'] as num?)?.toDouble() ?? 0.40,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BlinkerConfig &&
      other.shape == shape &&
      other.sizeScale == sizeScale &&
      other.sidePadFrac == sidePadFrac &&
      other.vertFrac == vertFrac;

  @override
  int get hashCode => Object.hash(shape, sizeScale, sidePadFrac, vertFrac);
}

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
  const AppConfig({
    this.hudBoxOn = false,
    this.safeArea = const HudSafeArea(),
    this.blinker = const BlinkerConfig(),
    this.battery = const BatteryConfig(),
  });

  final bool hudBoxOn;

  /// Safe Area rectangle for the HUD's backing display.
  final HudSafeArea safeArea;

  /// Blinker appearance (shape, size, position).
  final BlinkerConfig blinker;

  /// Battery widget appearance (show/hide elements, size).
  final BatteryConfig battery;

  AppConfig copyWith({
    bool? hudBoxOn,
    HudSafeArea? safeArea,
    BlinkerConfig? blinker,
    BatteryConfig? battery,
  }) => AppConfig(
    hudBoxOn: hudBoxOn ?? this.hudBoxOn,
    safeArea: safeArea ?? this.safeArea,
    blinker: blinker ?? this.blinker,
    battery: battery ?? this.battery,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'hudBoxOn': hudBoxOn,
    'safeArea': safeArea.toJson(),
    'blinker': blinker.toJson(),
    'battery': battery.toJson(),
  };

  factory AppConfig.fromJson(Map<String, Object?> json) => AppConfig(
    hudBoxOn: json['hudBoxOn'] as bool? ?? false,
    safeArea: json['safeArea'] is Map<String, Object?>
        ? HudSafeArea.fromJson(json['safeArea']! as Map<String, Object?>)
        : const HudSafeArea(),
    blinker: json['blinker'] is Map<String, Object?>
        ? BlinkerConfig.fromJson(json['blinker']! as Map<String, Object?>)
        : const BlinkerConfig(),
    battery: json['battery'] is Map<String, Object?>
        ? BatteryConfig.fromJson(json['battery']! as Map<String, Object?>)
        : const BatteryConfig(),
  );

  /// Convenience: round-trip through JSON string (used by SharedPrefsConfigStore).
  factory AppConfig.fromJsonString(String s) =>
      AppConfig.fromJson(jsonDecode(s) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      other is AppConfig &&
      other.hudBoxOn == hudBoxOn &&
      other.safeArea == safeArea &&
      other.blinker == blinker &&
      other.battery == battery;

  @override
  int get hashCode => Object.hash(hudBoxOn, safeArea, blinker, battery);
}

/// Port for config persistence. Each isolate owns its own instance.
abstract class ConfigStore {
  AppConfig get value;
  Stream<AppConfig> get changes;
  Future<void> load();
  Future<void> setConfig(AppConfig next);
}
