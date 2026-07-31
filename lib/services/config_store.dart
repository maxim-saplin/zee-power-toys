import 'dart:convert';

// ---------------------------------------------------------------------------
// MinimapConfig
// ---------------------------------------------------------------------------

/// HUD minimap (YNavi) configuration.
///
/// Defaults: enabled=false (safe until mod detected), preset='balanced',
/// advanced=false, themeFollow='auto'.
///
/// themeFollow ∈ {'auto', 'dark', 'light'}:
///   - 'auto'  → HUD palette follows MediaQuery.platformBrightness
///   - 'dark'  → always dark palette
///   - 'light' → always light palette
class MinimapConfig {
  const MinimapConfig({
    this.enabled = false,
    this.preset = 'balanced',
    this.advanced = false,
    this.widthFrac,
    this.heightFrac,
    this.themeFollow = 'auto',
  });

  /// Whether the minimap is enabled. Only meaningful when YNavi mod is present.
  final bool enabled;

  /// Preset name: 'compact', 'balanced', or 'large'.
  final String preset;

  /// When true, show manual dimension sliders instead of the preset selector.
  final bool advanced;

  /// Manual width as fraction of HUD safe area width (0..1); null = use preset.
  final double? widthFrac;

  /// Manual height as fraction of HUD safe area height (0..1); null = use preset.
  final double? heightFrac;

  /// Theme-follow mode: 'auto' | 'dark' | 'light'.
  final String themeFollow;

  MinimapConfig copyWith({
    bool? enabled,
    String? preset,
    bool? advanced,
    Object? widthFrac = _unset,
    Object? heightFrac = _unset,
    String? themeFollow,
  }) => MinimapConfig(
    enabled: enabled ?? this.enabled,
    preset: preset ?? this.preset,
    advanced: advanced ?? this.advanced,
    widthFrac:
        identical(widthFrac, _unset) ? this.widthFrac : widthFrac as double?,
    heightFrac:
        identical(heightFrac, _unset)
            ? this.heightFrac
            : heightFrac as double?,
    themeFollow: themeFollow ?? this.themeFollow,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'preset': preset,
    'advanced': advanced,
    if (widthFrac != null) 'widthFrac': widthFrac,
    if (heightFrac != null) 'heightFrac': heightFrac,
    'themeFollow': themeFollow,
  };

  factory MinimapConfig.fromJson(Map<String, Object?> json) => MinimapConfig(
    enabled: json['enabled'] as bool? ?? false,
    preset: json['preset'] as String? ?? 'balanced',
    advanced: json['advanced'] as bool? ?? false,
    widthFrac: (json['widthFrac'] as num?)?.toDouble(),
    heightFrac: (json['heightFrac'] as num?)?.toDouble(),
    themeFollow: json['themeFollow'] as String? ?? 'auto',
  );

  @override
  bool operator ==(Object other) =>
      other is MinimapConfig &&
      other.enabled == enabled &&
      other.preset == preset &&
      other.advanced == advanced &&
      other.widthFrac == widthFrac &&
      other.heightFrac == heightFrac &&
      other.themeFollow == themeFollow;

  @override
  int get hashCode =>
      Object.hash(enabled, preset, advanced, widthFrac, heightFrac, themeFollow);

  // ---------------------------------------------------------------------------
  // Preset geometry
  // ---------------------------------------------------------------------------

  /// Preset name → (widthFrac, heightFrac) of HUD Safe Area.
  ///
  /// These fractions are the default geometry for each preset. They are applied
  /// by the MinimapHost wiring in main.dart whenever the config changes and the
  /// preset (not advanced) mode is active.
  static const Map<String, (double, double)> presetFractions = {
    'compact':  (0.35, 0.60),
    'balanced': (0.50, 0.80),
    'large':    (0.70, 1.00),
  };

  /// Resolved safe-area fractions for the current config.
  ///
  /// In advanced mode (when [advanced] is true AND [widthFrac]/[heightFrac] are
  /// set), returns those manual values clamped to [0.1, 1.0].
  /// In preset mode, returns [presetFractions] for [preset] (fallback: balanced).
  (double, double) get resolvedFracs {
    if (advanced && widthFrac != null && heightFrac != null) {
      return (widthFrac!.clamp(0.1, 1.0), heightFrac!.clamp(0.1, 1.0));
    }
    return presetFractions[preset] ?? presetFractions['balanced']!;
  }
}

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
/// `dots`   — a single small amber circle per side (default; reads like a real
///            dashboard turn indicator, not a billboard).
/// `arrows` — chevron turn-arrows ported from phase0 ic_blinker_left/right SVG.
/// `smiley` — a yellow smiley face (new, per REQUIREMENTS "yellow smileys").
enum BlinkerShape { dots, arrows, smiley }

/// Blinker appearance config.
///
/// The mark is sized as a small fixed-ish indicator (see [BlinkerWidget]); the
/// fields here govern its scale and placement within the BLINKER slot.
///
/// `sizeScale` multiplies the small base diameter (1.0 = the calibrated neat
/// indicator size).
///
/// `sidePadFrac` is the inward padding from the left/right Safe Area edge, as a
/// fraction of Safe Area width.  A small value keeps the mark near the outer
/// edge with a comfortable margin.
///
/// `vertFrac` is the vertical centre of the blinker mark as a fraction of the
/// blinker slot height (0 = top, 1 = bottom).  0.50 centres it vertically.
class BlinkerConfig {
  const BlinkerConfig({
    this.shape = BlinkerShape.dots,
    this.sizeScale = 1.0,
    this.sidePadFrac = 0.04,
    this.vertFrac = 0.50,
  });

  final BlinkerShape shape;

  /// Multiplier applied to the small base blinker diameter (1.0 = the
  /// calibrated neat indicator size).
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
      sidePadFrac: (json['sidePadFrac'] as num?)?.toDouble() ?? 0.04,
      vertFrac: (json['vertFrac'] as num?)?.toDouble() ?? 0.50,
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
/// The fraction defaults below are derived from phase-0 dp constants
/// (616×175 dp @ +5/+6 offset — see `lib/services/minimap_viewport.dart`)
/// converted for the Zeekr S2 nominal display (1024×576 @ 213 dpi):
///   density=1.33125; safeW≈820 px, safeH≈233 px
///   → left=109/1024≈0.1064, top=180/576≈0.3125,
///     right=929/1024≈0.9072, bottom=413/576≈0.7170
///
/// At runtime, when the actual HUD display metrics are known (after `onHudReady`),
/// `dhuMain` recomputes and updates these fractions from the same dp constants ×
/// real density so the Flutter HUD overlay (battery, blinker) is positioned
/// correctly on any display size.  The fallback defaults keep T1 desktop
/// preview reasonable before the real metrics arrive.
class HudSafeArea {
  const HudSafeArea({
    this.left = _defaultLeft,
    this.top = _defaultTop,
    this.right = _defaultRight,
    this.bottom = _defaultBottom,
  });

  /// Phase-0 dp-constant defaults computed for 1024×576 @ 213 dpi (Zeekr S2 nominal).
  /// On T2 (1280×720) and T3 (real car) these are overwritten at runtime by dhuMain.
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
    this.hudEnabled = true,
    this.safeArea = const HudSafeArea(),
    this.blinker = const BlinkerConfig(),
    this.battery = const BatteryConfig(),
    this.minimap = const MinimapConfig(),
    this.locale,
  });

  /// Whether the HUD engine should be spawned at all.
  ///
  /// The native boot shim (ConfigShim.kt) reads this flag from the
  /// `flutter.zee.config` SharedPreferences key before any Flutter isolate
  /// starts (ADR 0003). Default true — key absent or parse failure → HUD on.
  final bool hudEnabled;

  /// Safe Area rectangle for the HUD's backing display.
  final HudSafeArea safeArea;

  /// Blinker appearance (shape, size, position).
  final BlinkerConfig blinker;

  /// Battery widget appearance (show/hide elements, size).
  final BatteryConfig battery;

  /// YNavi minimap configuration (enable, preset, theme-follow, advanced dims).
  final MinimapConfig minimap;

  /// UI language override: null = follow system locale; 'en' or 'ru' = explicit
  /// override.  Stored as a plain string so the JSON round-trip is trivial and
  /// future locale codes need no schema change.
  final String? locale;

  AppConfig copyWith({
    bool? hudEnabled,
    HudSafeArea? safeArea,
    BlinkerConfig? blinker,
    BatteryConfig? battery,
    MinimapConfig? minimap,
    // Use a sentinel to distinguish "set to null" from "leave unchanged".
    Object? locale = _unset,
  }) => AppConfig(
    hudEnabled: hudEnabled ?? this.hudEnabled,
    safeArea: safeArea ?? this.safeArea,
    blinker: blinker ?? this.blinker,
    battery: battery ?? this.battery,
    minimap: minimap ?? this.minimap,
    locale: identical(locale, _unset) ? this.locale : locale as String?,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'hudEnabled': hudEnabled,
    'safeArea': safeArea.toJson(),
    'blinker': blinker.toJson(),
    'battery': battery.toJson(),
    'minimap': minimap.toJson(),
    if (locale != null) 'locale': locale,
  };

  factory AppConfig.fromJson(Map<String, Object?> json) => AppConfig(
    hudEnabled: json['hudEnabled'] as bool? ?? true,
    safeArea: json['safeArea'] is Map<String, Object?>
        ? HudSafeArea.fromJson(json['safeArea']! as Map<String, Object?>)
        : const HudSafeArea(),
    blinker: json['blinker'] is Map<String, Object?>
        ? BlinkerConfig.fromJson(json['blinker']! as Map<String, Object?>)
        : const BlinkerConfig(),
    battery: json['battery'] is Map<String, Object?>
        ? BatteryConfig.fromJson(json['battery']! as Map<String, Object?>)
        : const BatteryConfig(),
    minimap: json['minimap'] is Map<String, Object?>
        ? MinimapConfig.fromJson(json['minimap']! as Map<String, Object?>)
        : const MinimapConfig(),
    locale: json['locale'] as String?,
  );

  /// Convenience: round-trip through JSON string (used by SharedPrefsConfigStore).
  factory AppConfig.fromJsonString(String s) =>
      AppConfig.fromJson(jsonDecode(s) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      other is AppConfig &&
      other.hudEnabled == hudEnabled &&
      other.safeArea == safeArea &&
      other.blinker == blinker &&
      other.battery == battery &&
      other.minimap == minimap &&
      other.locale == locale;

  @override
  int get hashCode =>
      Object.hash(hudEnabled, safeArea, blinker, battery, minimap, locale);
}

// Sentinel used by copyWith to distinguish "pass null" from "omit".
const Object _unset = Object();

/// Port for config persistence. Each isolate owns its own instance.
abstract class ConfigStore {
  AppConfig get value;
  Stream<AppConfig> get changes;
  Future<void> load();
  Future<void> setConfig(AppConfig next);
}
