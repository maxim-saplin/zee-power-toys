import 'dart:convert';

import 'minimap_viewport.dart' show hudPresetSizeFraction;

// ---------------------------------------------------------------------------
// MinimapLooks
// ---------------------------------------------------------------------------

/// Native colour-filter parameters applied to the YNavi minimap render.
///
/// Mirrors a hand-picked subset of MainActivity.kt's `MinimapParams` — the
/// native holder behind `setMinimapParam` — chosen for being the only three
/// knobs that (a) have a genuinely visible, honestly-nameable effect and (b)
/// are worth a permanent UI slot (PRINCIPLES.md #1, "every option must earn
/// its place"). The rest of `MinimapParams` (`saturation`, native `brightness`,
/// `invert`, `huePass`, `hueAngle`, `bufScale`, `dpiScale`) stays reachable
/// only via `ext.zee.minimap key=... value=...` — still runtime-drivable
/// (#3), just not surfaced as a permanent control (#1). In particular
/// `huePass` is intentionally left at its native default of 0.0 (pure
/// monochrome tint) — see `MainActivity.kt`'s `MinimapParams` doc: hue
/// passthrough was tried and rejected (floods on map content sharing the
/// pass hue), so [colorPreset] is the sole colour control and `hueAngle` is
/// moot at huePass=0.
///
/// Defaults are the values measured good on the real HUD (MainActivity.kt's
/// `MinimapParams` defaults / "THE FIX" history comment): white tint (phase0 HudSettings COLOR_PRESETS[0]),
/// contrast=3.0, threshold=150 — chosen so an untouched install gets the
/// good look without opening this screen.
class MinimapLooks {
  const MinimapLooks({
    this.colorPreset = 'white',
    this.contrast = 3.0,
    this.threshold = 150.0,
  });

  /// Native `preset` param token: 'green-yellow' | 'white' | 'amber' | 'cyan'.
  /// Forwarded verbatim to `setParams` — `MainActivity.kt`'s
  /// `presetIndexFromName()` accepts these exact string tokens directly, so
  /// no local index mapping is needed on the Dart side.
  final String colorPreset;

  /// Forwarded as the native `contrast` param.
  final double contrast;

  /// Forwarded as the native `threshold` param. Named "Brightness" in the UI
  /// because that is the user-visible effect: a HIGHER threshold crushes MORE
  /// of the source image to black (a darker background, more "crushed"), not
  /// a literal brightness multiplier — see `_applyMinimapConfig`/the settings
  /// screen for the honest label.
  final double threshold;

  MinimapLooks copyWith({
    String? colorPreset,
    double? contrast,
    double? threshold,
  }) => MinimapLooks(
    colorPreset: colorPreset ?? this.colorPreset,
    contrast: contrast ?? this.contrast,
    threshold: threshold ?? this.threshold,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'colorPreset': colorPreset,
    'contrast': contrast,
    'threshold': threshold,
  };

  factory MinimapLooks.fromJson(Map<String, Object?> json) => MinimapLooks(
    colorPreset: json['colorPreset'] as String? ?? 'white',
    contrast: (json['contrast'] as num?)?.toDouble() ?? 3.0,
    threshold: (json['threshold'] as num?)?.toDouble() ?? 150.0,
  );

  /// Wire-format params map for [MinimapHost.setParams] — the exact keys
  /// `setMinimapParam` reads natively (`preset`/`contrast`/`threshold`).
  Map<String, Object?> toParams() => <String, Object?>{
    'preset': colorPreset,
    'contrast': contrast,
    'threshold': threshold,
  };

  @override
  bool operator ==(Object other) =>
      other is MinimapLooks &&
      other.colorPreset == colorPreset &&
      other.contrast == contrast &&
      other.threshold == threshold;

  @override
  int get hashCode => Object.hash(colorPreset, contrast, threshold);
}

// ---------------------------------------------------------------------------
// MinimapConfig
// ---------------------------------------------------------------------------

/// HUD minimap (YNavi) configuration.
///
/// Defaults: enabled=false (safe until mod detected), preset='balanced',
/// advanced=false, looks=[MinimapLooks] defaults.
///
/// There used to be a `themeFollow` field ('auto'|'dark'|'light') driving a
/// System/Dark/Light radio group here. It was deleted outright, not merely
/// left unwired: it persisted a preference nothing native could honestly
/// apply. The only physically meaningful destination would be the
/// `Configuration.UI_MODE_NIGHT_*` value handed to YNavi, and Block 0021
/// deliberately pins that to night — a day map through an emissive projector
/// is a bright wash on black glass, precisely the defect 0021 fixed (see
/// CONTEXT.md's HUD glossary entry: "black pixels emit no light... never
/// light-on-dark UI"). A "light" HUD theme contradicts that rule outright,
/// and the DHU app itself is intentionally `ThemeMode.dark` — so 'light' had
/// nowhere true to go, 'dark' was already the permanent reality, and 'auto'
/// just meant "maybe silently give you the broken one". After the Look
/// section (colorPreset/contrast/threshold, see [MinimapLooks]) the honest
/// colour control is the colour preset — so this control was removed rather
/// than kept as another knob that lies.
class MinimapConfig {
  const MinimapConfig({
    this.enabled = false,
    this.preset = 'balanced',
    this.advanced = false,
    this.sizeFraction,
    this.looks = const MinimapLooks(),
  });

  /// Whether the minimap is enabled. Only meaningful when YNavi mod is present.
  final bool enabled;

  /// Preset name: 'compact', 'balanced', or 'large'.
  final String preset;

  /// When true, show the manual Size slider instead of the preset selector.
  final bool advanced;

  /// Manual override of the minimap square's size fraction (side = safeH ×
  /// sizeFraction), clamped to [0.1, 1.0]; null = derive from [preset] via
  /// [hudPresetSizeFraction]. [hudPresetSizeFraction] (in minimap_viewport.dart,
  /// next to the rest of the viewport geometry) is the single source of truth
  /// for preset→fraction — this class used to keep its own duplicate
  /// `presetFractions` map with different numbers than the one actually used
  /// to compute the rendered viewport, which is exactly the kind of drift
  /// this Block exists to remove. See [resolvedSizeFraction].
  final double? sizeFraction;

  /// Native colour-filter parameters (Look section: colour preset,
  /// brightness, contrast). See [MinimapLooks].
  final MinimapLooks looks;

  /// Resolved size fraction actually used to compute the rendered viewport
  /// (see `computeMinimapViewport` in minimap_viewport.dart, called from
  /// `_applyMinimapConfig` in main.dart).
  ///
  /// When [sizeFraction] is set (preset shortcuts write it too), that value
  /// wins — clamped to [0.1, 1.0]. Otherwise [hudPresetSizeFraction]([preset]).
  /// (Previously gated on [advanced], which made the Size slider a no-op after
  /// we removed the Advanced ExpansionTile.)
  double get resolvedSizeFraction {
    if (sizeFraction != null) {
      return sizeFraction!.clamp(0.1, 1.0);
    }
    return hudPresetSizeFraction(preset);
  }

  MinimapConfig copyWith({
    bool? enabled,
    String? preset,
    bool? advanced,
    Object? sizeFraction = _unset,
    MinimapLooks? looks,
  }) => MinimapConfig(
    enabled: enabled ?? this.enabled,
    preset: preset ?? this.preset,
    advanced: advanced ?? this.advanced,
    sizeFraction: identical(sizeFraction, _unset)
        ? this.sizeFraction
        : sizeFraction as double?,
    looks: looks ?? this.looks,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'preset': preset,
    'advanced': advanced,
    if (sizeFraction != null) 'sizeFraction': sizeFraction,
    'looks': looks.toJson(),
  };

  factory MinimapConfig.fromJson(Map<String, Object?> json) => MinimapConfig(
    enabled: json['enabled'] as bool? ?? false,
    preset: json['preset'] as String? ?? 'balanced',
    advanced: json['advanced'] as bool? ?? false,
    sizeFraction: (json['sizeFraction'] as num?)?.toDouble(),
    // Unknown/removed keys (widthFrac, heightFrac, themeFollow from older
    // persisted configs) are simply never read here — fromJson tolerates
    // extra keys in the map by construction, so old installs keep loading.
    looks: json['looks'] is Map<String, Object?>
        ? MinimapLooks.fromJson(json['looks']! as Map<String, Object?>)
        : const MinimapLooks(),
  );

  @override
  bool operator ==(Object other) =>
      other is MinimapConfig &&
      other.enabled == enabled &&
      other.preset == preset &&
      other.advanced == advanced &&
      other.sizeFraction == sizeFraction &&
      other.looks == looks;

  @override
  int get hashCode =>
      Object.hash(enabled, preset, advanced, sizeFraction, looks);
}

/// What parts of the battery mark to show (icon pack vs percentage label).
///
/// `both`     — pack + percentage (default).
/// `iconOnly` — pack only (no separate % label below; [BatteryStyle.pctInside]
///              still paints % inside the pack).
/// `textOnly` — percentage label only (no pack icon).
enum BatteryContentMode { both, iconOnly, textOnly }

/// Visual look of the battery pack icon.
///
/// `outline`   — Steam-Deck outline + continuous fill + nub (default / current).
/// `filled`    — segmented bars (4–5 blocks) inside the pack outline.
/// `pctInside` — continuous fill with percentage text painted inside the pack
///               (suppresses the separate % below when content includes icon).
enum BatteryStyle { outline, filled, pctInside }

/// Battery widget appearance config.
///
/// Defaults: everything shown (showBattery/showTemp/showChargingStats = true),
/// contentMode = both, style = outline, sizeScale = 1.0.  The charging stats
/// panel is show-while-charging — it appears automatically when the car
/// reports charging and is hidden otherwise (app policy per ADR 0003);
/// showChargingStats merely lets the user suppress the panel entirely if they
/// prefer.
class BatteryConfig {
  const BatteryConfig({
    this.showBattery = true,
    this.showTemp = true,
    this.showChargingStats = true,
    this.sizeScale = 1.0,
    this.contentMode = BatteryContentMode.both,
    this.style = BatteryStyle.outline,
  });

  /// Whether to render the battery indicator at all.
  final bool showBattery;

  /// Whether to show the battery temperature readout next to the icon.
  final bool showTemp;

  /// Whether to show the charging-stats panel (kW prominent, V/A secondary)
  /// while the car reports charging=true.  When false the panel is always
  /// hidden; when true it auto-shows/hides with the charging flag.
  final bool showChargingStats;

  /// Multiplier applied to the base widget size (1.0 = default).
  final double sizeScale;

  /// Icon vs text content mode (pack / percentage / both).
  final BatteryContentMode contentMode;

  /// Pack visual style (outline / filled segments / % inside).
  final BatteryStyle style;

  BatteryConfig copyWith({
    bool? showBattery,
    bool? showTemp,
    bool? showChargingStats,
    double? sizeScale,
    BatteryContentMode? contentMode,
    BatteryStyle? style,
  }) => BatteryConfig(
    showBattery: showBattery ?? this.showBattery,
    showTemp: showTemp ?? this.showTemp,
    showChargingStats: showChargingStats ?? this.showChargingStats,
    sizeScale: sizeScale ?? this.sizeScale,
    contentMode: contentMode ?? this.contentMode,
    style: style ?? this.style,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'showBattery': showBattery,
    'showTemp': showTemp,
    'showChargingStats': showChargingStats,
    'sizeScale': sizeScale,
    'contentMode': contentMode.name,
    'style': style.name,
  };

  factory BatteryConfig.fromJson(Map<String, Object?> json) {
    final modeName = json['contentMode'] as String?;
    final contentMode = modeName != null
        ? BatteryContentMode.values.firstWhere(
            (e) => e.name == modeName,
            orElse: () => BatteryContentMode.both,
          )
        : BatteryContentMode.both;
    final styleName = json['style'] as String?;
    final style = styleName != null
        ? BatteryStyle.values.firstWhere(
            (e) => e.name == styleName,
            orElse: () => BatteryStyle.outline,
          )
        : BatteryStyle.outline;
    return BatteryConfig(
      showBattery: json['showBattery'] as bool? ?? true,
      showTemp: json['showTemp'] as bool? ?? true,
      showChargingStats: json['showChargingStats'] as bool? ?? true,
      sizeScale: (json['sizeScale'] as num?)?.toDouble() ?? 1.0,
      contentMode: contentMode,
      style: style,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BatteryConfig &&
      other.showBattery == showBattery &&
      other.showTemp == showTemp &&
      other.showChargingStats == showChargingStats &&
      other.sizeScale == sizeScale &&
      other.contentMode == contentMode &&
      other.style == style;

  @override
  int get hashCode => Object.hash(
    showBattery,
    showTemp,
    showChargingStats,
    sizeScale,
    contentMode,
    style,
  );
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
    this.horizBiasFrac = 0.0,
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

  /// Horizontal bias as a fraction of slot width (−0.25…0.25). Positive shifts
  /// both marks toward the right (left pad grows, right pad shrinks).
  final double horizBiasFrac;

  BlinkerConfig copyWith({
    BlinkerShape? shape,
    double? sizeScale,
    double? sidePadFrac,
    double? vertFrac,
    double? horizBiasFrac,
  }) => BlinkerConfig(
    shape: shape ?? this.shape,
    sizeScale: sizeScale ?? this.sizeScale,
    sidePadFrac: sidePadFrac ?? this.sidePadFrac,
    vertFrac: vertFrac ?? this.vertFrac,
    horizBiasFrac: horizBiasFrac ?? this.horizBiasFrac,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'shape': shape.name,
    'sizeScale': sizeScale,
    'sidePadFrac': sidePadFrac,
    'vertFrac': vertFrac,
    'horizBiasFrac': horizBiasFrac,
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
      horizBiasFrac: (json['horizBiasFrac'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BlinkerConfig &&
      other.shape == shape &&
      other.sizeScale == sizeScale &&
      other.sidePadFrac == sidePadFrac &&
      other.vertFrac == vertFrac &&
      other.horizBiasFrac == horizBiasFrac;

  @override
  int get hashCode =>
      Object.hash(shape, sizeScale, sidePadFrac, vertFrac, horizBiasFrac);
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

  /// Phase-0 dp-constant defaults computed for 1024×576 @ 213 dpi (Zeekr S2 nominal;
  /// matches the real HUD display on both T2 emulator and T3 car).
  /// These are overwritten at runtime by dhuMain from the actual reported metrics.
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
    this.autoUsbPeripheral = false,
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

  /// Whether the DHU should re-apply USB peripheral mode on every boot
  /// (the "auto" USB mode — Block 0016 / UsbMode.auto).
  ///
  /// **Top-level key, not nested** — this must match exactly what the native
  /// pre-Flutter boot shim reads: `ConfigShim.readAutoUsbPeripheral` /
  /// `boot/ConfigShim.kt:41-47` does `json.optBoolean("autoUsbPeripheral", ...)`
  /// directly on the root `flutter.zee.config` JSON object, not on a nested
  /// object. Before this field existed, `AppConfig` never wrote this key at
  /// all, so `BootReceiver`'s re-apply on boot always read the `optBoolean`
  /// default (`false`) — "auto" looked selectable in the UI but never
  /// persisted anything a boot could read back (Task 2).
  final bool autoUsbPeripheral;

  AppConfig copyWith({
    bool? hudEnabled,
    HudSafeArea? safeArea,
    BlinkerConfig? blinker,
    BatteryConfig? battery,
    MinimapConfig? minimap,
    // Use a sentinel to distinguish "set to null" from "leave unchanged".
    Object? locale = _unset,
    bool? autoUsbPeripheral,
  }) => AppConfig(
    hudEnabled: hudEnabled ?? this.hudEnabled,
    safeArea: safeArea ?? this.safeArea,
    blinker: blinker ?? this.blinker,
    battery: battery ?? this.battery,
    minimap: minimap ?? this.minimap,
    locale: identical(locale, _unset) ? this.locale : locale as String?,
    autoUsbPeripheral: autoUsbPeripheral ?? this.autoUsbPeripheral,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'hudEnabled': hudEnabled,
    'safeArea': safeArea.toJson(),
    'blinker': blinker.toJson(),
    'battery': battery.toJson(),
    'minimap': minimap.toJson(),
    if (locale != null) 'locale': locale,
    'autoUsbPeripheral': autoUsbPeripheral,
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
    autoUsbPeripheral: json['autoUsbPeripheral'] as bool? ?? false,
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
      other.locale == locale &&
      other.autoUsbPeripheral == autoUsbPeripheral;

  @override
  int get hashCode => Object.hash(
    hudEnabled,
    safeArea,
    blinker,
    battery,
    minimap,
    locale,
    autoUsbPeripheral,
  );
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
