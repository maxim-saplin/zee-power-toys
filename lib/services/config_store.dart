import 'dart:convert';

import 'minimap_viewport.dart' show hudPresetSizeFraction;
import 'speedcam.dart' show SpeedcamPresenceMode;


/// jsonDecode nests are [Map<String, dynamic>], which fail `is Map<String, Object?>`.
Map<String, Object?>? _asStringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}


// ---------------------------------------------------------------------------
// MinimapLooks
// ---------------------------------------------------------------------------

class MinimapLooks {
  const MinimapLooks({
    this.colorPreset = 'default',
    this.contrast = 3.0,
    this.threshold = 150.0,
    this.brightness = -20,
    this.huePass = 1.0,
    this.hueAngle = 290,
  });

  /// UI / persisted look token:
  /// - `default` — phase0 White bundle (tint white + huePass 1 / hueAngle 290)
  /// - `white` — mono white tint (huePass 0)
  /// - `green-yellow` | `amber` | `cyan` — phase0 COLOR_PRESETS with hue pass
  final String colorPreset;

  final double contrast;

  /// Filter threshold (UI label "Brightness" — higher crushes more to black).
  final double threshold;

  /// Native filter brightness offset (phase0 White uses -20).
  final int brightness;

  /// 0 = mono tint; 1 = phase0 hue passthrough (keeps YNavi yellow cursor/roads).
  final double huePass;

  /// Hue passthrough angle (phase0 White = 290).
  final int hueAngle;

  /// Named look bundles matching phase0 HudSettings.COLOR_PRESETS (+ mono White).
  factory MinimapLooks.bundle(String name) {
    switch (name) {
      case 'default':
        // phase0 COLOR_PRESETS[0] White
        return const MinimapLooks(
          colorPreset: 'default',
          contrast: 3.0,
          threshold: 150,
          brightness: -20,
          huePass: 1.0,
          hueAngle: 290,
        );
      case 'white':
        // Mono white — useful as an option; not phase0 parity.
        return const MinimapLooks(
          colorPreset: 'white',
          contrast: 3.0,
          threshold: 150,
          brightness: -20,
          huePass: 0.0,
          hueAngle: 290,
        );
      case 'green-yellow':
        return const MinimapLooks(
          colorPreset: 'green-yellow',
          contrast: 3.0,
          threshold: 150,
          brightness: -20,
          huePass: 1.0,
          hueAngle: 120,
        );
      case 'cyan':
        return const MinimapLooks(
          colorPreset: 'cyan',
          contrast: 3.0,
          threshold: 150,
          brightness: -20,
          huePass: 1.0,
          hueAngle: 180,
        );
      case 'amber':
        return const MinimapLooks(
          colorPreset: 'amber',
          contrast: 3.0,
          threshold: 150,
          brightness: -20,
          huePass: 1.0,
          hueAngle: 60,
        );
      default:
        return MinimapLooks.bundle('default');
    }
  }

  /// Native ColorMatrix tint token (never `default` — maps to white).
  String get nativePreset =>
      colorPreset == 'default' ? 'white' : colorPreset;

  MinimapLooks copyWith({
    String? colorPreset,
    double? contrast,
    double? threshold,
    int? brightness,
    double? huePass,
    int? hueAngle,
  }) => MinimapLooks(
    colorPreset: colorPreset ?? this.colorPreset,
    contrast: contrast ?? this.contrast,
    threshold: threshold ?? this.threshold,
    brightness: brightness ?? this.brightness,
    huePass: huePass ?? this.huePass,
    hueAngle: hueAngle ?? this.hueAngle,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'colorPreset': colorPreset,
    'contrast': contrast,
    'threshold': threshold,
    'brightness': brightness,
    'huePass': huePass,
    'hueAngle': hueAngle,
  };

  factory MinimapLooks.fromJson(Map<String, Object?> json) {
    final name = json['colorPreset'] as String? ?? 'default';
    // Old installs that only stored tint+contrast+threshold: if they claimed
    // white without huePass, treat as mono white; missing keys → phase0 default.
    if (!json.containsKey('huePass') && !json.containsKey('hueAngle')) {
      if (name == 'white') return MinimapLooks.bundle('white');
      if (name == 'default' || name == 'green-yellow' || name == 'cyan' || name == 'amber') {
        return MinimapLooks.bundle(name);
      }
    }
    return MinimapLooks(
      colorPreset: name,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 3.0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 150.0,
      brightness: (json['brightness'] as num?)?.toInt() ?? -20,
      huePass: (json['huePass'] as num?)?.toDouble() ?? 1.0,
      hueAngle: (json['hueAngle'] as num?)?.toInt() ?? 290,
    );
  }

  Map<String, Object?> toParams() => <String, Object?>{
    'preset': nativePreset,
    'contrast': contrast,
    'threshold': threshold,
    'brightness': brightness,
    'huePass': huePass,
    'hueAngle': hueAngle,
  };

  @override
  bool operator ==(Object other) =>
      other is MinimapLooks &&
      other.colorPreset == colorPreset &&
      other.contrast == contrast &&
      other.threshold == threshold &&
      other.brightness == brightness &&
      other.huePass == huePass &&
      other.hueAngle == hueAngle;

  @override
  int get hashCode =>
      Object.hash(colorPreset, contrast, threshold, brightness, huePass, hueAngle);
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
/// light-on-dark UI"). A "light" *HUD* theme contradicts that rule outright
/// (DHU theme via [AppConfig.themeMode]: auto/dark/light; HUD stays dark).
/// 'auto' just meant "maybe silently give you the broken one". After the Look
/// section (colorPreset/contrast/threshold, see [MinimapLooks]) the honest
/// colour control is the colour preset — so this control was removed rather
/// than kept as another knob that lies.
class MinimapConfig {
  const MinimapConfig({
    this.enabled = false,
    this.onlyWhileGuidance = false,
    this.guidanceOverlay = true,
    this.etaBar = true,
    this.overlayScale = 0.5,
    this.preset = 'balanced',
    this.advanced = false,
    this.sizeFraction,
    this.contentScale = 0.5,
    this.looks = const MinimapLooks(),
  });

  /// Whether the minimap is enabled. Only meaningful when YNavi mod is present.
  final bool enabled;

  /// When true, show the minimap surface only while YNavi reports an active
  /// navigation session (0057). Default false = always show when [enabled].
  final bool onlyWhileGuidance;

  /// 0055 / Zee HUD 2: show turn-by-turn top bar on native GuidanceOverlayView
  /// (arrow + distance + road). Default true.
  final bool guidanceOverlay;

  /// 0055 / Zee HUD 2: show bottom ETA bar (remain dist + time + arrival).
  /// Default true.
  final bool etaBar;

  /// Zee HUD 2 overlayScale (0.25–1.0). Independent of [contentScale]/ shrinks
  /// guidance bars to fit the square viewport. Default 0.5.
  final double overlayScale;

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

  /// Phase0 `minimapScale`: map content density inside the square (0.3–1.0).
  /// Lower = more map area in the same viewport (buffer = viewport / scale).
  /// Default 0.5 matches phase0 HudSettings. Forwarded as native `bufScale`
  /// (= 1 / contentScale) with a cold YNavi rebind on change.
  final double contentScale;

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
    bool? onlyWhileGuidance,
    bool? guidanceOverlay,
    bool? etaBar,
    double? overlayScale,
    String? preset,
    bool? advanced,
    Object? sizeFraction = _unset,
    double? contentScale,
    MinimapLooks? looks,
  }) => MinimapConfig(
    enabled: enabled ?? this.enabled,
    onlyWhileGuidance: onlyWhileGuidance ?? this.onlyWhileGuidance,
    guidanceOverlay: guidanceOverlay ?? this.guidanceOverlay,
    etaBar: etaBar ?? this.etaBar,
    overlayScale: overlayScale ?? this.overlayScale,
    preset: preset ?? this.preset,
    advanced: advanced ?? this.advanced,
    sizeFraction: identical(sizeFraction, _unset)
        ? this.sizeFraction
        : sizeFraction as double?,
    contentScale: contentScale ?? this.contentScale,
    looks: looks ?? this.looks,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'onlyWhileGuidance': onlyWhileGuidance,
    'guidanceOverlay': guidanceOverlay,
    'etaBar': etaBar,
    'overlayScale': overlayScale,
    'preset': preset,
    'advanced': advanced,
    if (sizeFraction != null) 'sizeFraction': sizeFraction,
    'contentScale': contentScale,
    'looks': looks.toJson(),
  };

  factory MinimapConfig.fromJson(Map<String, Object?> json) => MinimapConfig(
    enabled: json['enabled'] as bool? ?? false,
    onlyWhileGuidance: json['onlyWhileGuidance'] as bool? ?? false,
    guidanceOverlay: json['guidanceOverlay'] as bool? ?? true,
    etaBar: json['etaBar'] as bool? ?? true,
    overlayScale: ((json['overlayScale'] as num?)?.toDouble() ?? 0.5).clamp(0.25, 1.0),
    preset: json['preset'] as String? ?? 'balanced',
    advanced: json['advanced'] as bool? ?? false,
    sizeFraction: (json['sizeFraction'] as num?)?.toDouble(),
    contentScale: (json['contentScale'] as num?)?.toDouble() ?? 0.5,
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
      other.onlyWhileGuidance == onlyWhileGuidance &&
      other.guidanceOverlay == guidanceOverlay &&
      other.etaBar == etaBar &&
      other.overlayScale == overlayScale &&
      other.preset == preset &&
      other.advanced == advanced &&
      other.sizeFraction == sizeFraction &&
      other.contentScale == contentScale &&
      other.looks == looks;

  @override
  int get hashCode =>
      Object.hash(enabled, onlyWhileGuidance, guidanceOverlay, etaBar,
          overlayScale, preset, advanced, sizeFraction, contentScale, looks);
}


/// Effective minimap surface visibility (0057).
///
/// [navActive] is YNavi navigation-session truth (`navigationActive` stream).
bool minimapSurfaceWanted(MinimapConfig mm, {required bool navActive}) =>
    mm.enabled && (!mm.onlyWhileGuidance || navActive);

/// What parts of the battery mark to show (icon pack vs percentage label).
///
/// Kept as the low-level rendering axes; product UI picks a [BatteryLook]
/// which maps onto these (0056 PDM names).
///
/// `both`     — pack + percentage.
/// `iconOnly` — pack only (no separate % label below; [BatteryStyle.pctInside]
///              still paints % inside the pack).
/// `textOnly` — percentage label only (no pack icon).
enum BatteryContentMode { both, iconOnly, textOnly }

/// Visual look of the battery pack icon (low-level).
///
/// `outline`   — squarish bold outline + continuous fill + nub (default).
/// `filled`    — segmented bars (4–5 blocks) inside the pack outline.
/// `pctInside` — continuous fill with percentage text painted inside the pack
///               ([BatteryLook.batteryText] / 0062 dual-color clip).
enum BatteryStyle { outline, filled, pctInside }

/// Product battery looks (0056 PDM names).
///
/// 1. [battery]     — "Battery" — filled pack (icon only, continuous fill)
/// 2. [batteryText] — "Battery + text" — pack with % inside (0062 dual-color)
/// 3. [batteryBars] — "Battery with bars" — segmented
/// 4. [justText]    — "Just text" — % only
enum BatteryLook { battery, batteryText, batteryBars, justText }

/// Map a [BatteryLook] onto contentMode + style.
({BatteryContentMode contentMode, BatteryStyle style}) batteryLookParts(
  BatteryLook look,
) =>
    switch (look) {
      BatteryLook.battery => (
          contentMode: BatteryContentMode.iconOnly,
          style: BatteryStyle.outline,
        ),
      BatteryLook.batteryText => (
          contentMode: BatteryContentMode.both,
          // 0062: % lives inside the pack (dual-color clip), not below.
          style: BatteryStyle.pctInside,
        ),
      BatteryLook.batteryBars => (
          contentMode: BatteryContentMode.iconOnly,
          style: BatteryStyle.filled,
        ),
      BatteryLook.justText => (
          contentMode: BatteryContentMode.textOnly,
          style: BatteryStyle.outline,
        ),
    };

/// Derive [BatteryLook] from legacy contentMode + style (prefs migration).
BatteryLook batteryLookFromParts(
  BatteryContentMode contentMode,
  BatteryStyle style,
) {
  if (contentMode == BatteryContentMode.textOnly) {
    return BatteryLook.justText;
  }
  if (style == BatteryStyle.filled) {
    return BatteryLook.batteryBars;
  }
  if (contentMode == BatteryContentMode.iconOnly) {
    return BatteryLook.battery;
  }
  // both + outline/pctInside → Battery + text
  return BatteryLook.batteryText;
}

/// Named placement for the battery cluster (icon + % + temp + charging kW).
///
/// Fine adjust (`vertFrac` / `sidePadFrac` / `horizBiasFrac`) rides on top of
/// the preset's side. Selecting a preset in the DHU resets the fine knobs to
/// that preset's defaults (see `batteryPlacementDefaults`).
///
/// `rightTop` is today's hard-coded top-right look and the config default.
enum BatteryPlacement {
  /// Left Safe-Area edge, top (mirror of [rightTop]).
  left,

  /// Right Safe-Area edge, mid-upper (below [rightTop]).
  right,

  /// Right Safe-Area edge, top — default / prior hard-coded placement.
  rightTop,
}

/// Default fine-adjust knobs for a named [BatteryPlacement] preset.
///
/// Kept next to the enum so ConfigStore and `battery_geometry` share one
/// source of truth (no hud/ → services cycle).
({double vertFrac, double sidePadFrac}) batteryPlacementDefaults(
  BatteryPlacement placement,
) =>
    switch (placement) {
      BatteryPlacement.left => (vertFrac: 0.010, sidePadFrac: 0.04),
      BatteryPlacement.right => (vertFrac: 0.35, sidePadFrac: 0.04),
      BatteryPlacement.rightTop => (vertFrac: 0.010, sidePadFrac: 0.04),
    };

/// Battery widget appearance + placement config.
///
/// Defaults: everything shown (showBattery/showTemp/showChargingStats = true),
/// look = batteryText (PDM "Battery + text", % inside pack), sizeScale = 1.0, placement =
/// rightTop with vertFrac/sidePadFrac matching today's hard-coded top-right
/// slot. The charging stats panel is show-while-charging — it appears
/// automatically when the car reports charging and is hidden otherwise (app
/// policy per ADR 0003); showChargingStats merely lets the user suppress the
/// panel entirely if they prefer.
class BatteryConfig {
  const BatteryConfig({
    this.showBattery = true,
    this.showTemp = true,
    this.showChargingStats = true,
    this.sizeScale = 1.0,
    this.look = BatteryLook.batteryText,
    this.contentMode = BatteryContentMode.both,
    this.style = BatteryStyle.pctInside,
    this.placement = BatteryPlacement.rightTop,
    this.vertFrac = 0.010,
    this.sidePadFrac = 0.04,
    this.horizBiasFrac = 0.0,
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

  /// Product look (0056 PDM). Source of truth for contentMode + style when
  /// set via [withLook] / [copyWith] `look:`.
  final BatteryLook look;

  /// Icon vs text content mode (pack / percentage / both). Kept in sync with
  /// [look] by [withLook]; still writable for Feedback Loop / legacy prefs.
  final BatteryContentMode contentMode;

  /// Pack visual style (outline / filled segments / % inside). Kept in sync
  /// with [look] by [withLook].
  final BatteryStyle style;

  /// Named side/corner preset. Fine adjust fields below override the preset's
  /// default fractions without changing the active side.
  final BatteryPlacement placement;

  /// Top edge of the battery slot as a fraction of Safe Area height (0 = top).
  final double vertFrac;

  /// Inward padding from the active edge as a fraction of Safe Area width.
  final double sidePadFrac;

  /// Horizontal bias as a fraction of Safe Area width (−0.25…0.25). Positive
  /// shifts the cluster toward the right (same convention as blinker).
  final double horizBiasFrac;

  BatteryConfig copyWith({
    bool? showBattery,
    bool? showTemp,
    bool? showChargingStats,
    double? sizeScale,
    BatteryLook? look,
    BatteryContentMode? contentMode,
    BatteryStyle? style,
    BatteryPlacement? placement,
    double? vertFrac,
    double? sidePadFrac,
    double? horizBiasFrac,
  }) {
    // Prefer explicit look; else if contentMode/style change without look,
    // re-derive look so product picker stays coherent.
    final BatteryLook nextLook;
    final BatteryContentMode nextMode;
    final BatteryStyle nextStyle;
    if (look != null) {
      nextLook = look;
      final parts = batteryLookParts(look);
      nextMode = parts.contentMode;
      nextStyle = parts.style;
    } else if (contentMode != null || style != null) {
      nextMode = contentMode ?? this.contentMode;
      nextStyle = style ?? this.style;
      nextLook = batteryLookFromParts(nextMode, nextStyle);
    } else {
      nextLook = this.look;
      nextMode = this.contentMode;
      nextStyle = this.style;
    }
    return BatteryConfig(
      showBattery: showBattery ?? this.showBattery,
      showTemp: showTemp ?? this.showTemp,
      showChargingStats: showChargingStats ?? this.showChargingStats,
      sizeScale: sizeScale ?? this.sizeScale,
      look: nextLook,
      contentMode: nextMode,
      style: nextStyle,
      placement: placement ?? this.placement,
      vertFrac: vertFrac ?? this.vertFrac,
      sidePadFrac: sidePadFrac ?? this.sidePadFrac,
      horizBiasFrac: horizBiasFrac ?? this.horizBiasFrac,
    );
  }

  /// Apply a named product [look] (0056 PDM) and sync contentMode + style.
  BatteryConfig withLook(BatteryLook look) => copyWith(look: look);

  /// Apply a named [placement] and reset fine-adjust knobs to that preset's
  /// defaults (left / right / rightTop).
  BatteryConfig withPlacement(BatteryPlacement placement) {
    final defaults = batteryPlacementDefaults(placement);
    return copyWith(
      placement: placement,
      vertFrac: defaults.vertFrac,
      sidePadFrac: defaults.sidePadFrac,
      horizBiasFrac: 0.0,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'showBattery': showBattery,
    'showTemp': showTemp,
    'showChargingStats': showChargingStats,
    'sizeScale': sizeScale,
    'look': look.name,
    'contentMode': contentMode.name,
    'style': style.name,
    'placement': placement.name,
    'vertFrac': vertFrac,
    'sidePadFrac': sidePadFrac,
    'horizBiasFrac': horizBiasFrac,
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
            orElse: () => BatteryStyle.pctInside,
          )
        : BatteryStyle.pctInside;
    final lookName = json['look'] as String?;
    final hasLook = lookName != null;
    final look = hasLook
        ? BatteryLook.values.firstWhere(
            (e) => e.name == lookName,
            orElse: () => batteryLookFromParts(contentMode, style),
          )
        : batteryLookFromParts(contentMode, style);
    // look key present → parts follow look (product source of truth).
    // Legacy prefs without look → keep contentMode/style (e.g. pctInside).
    final parts = batteryLookParts(look);
    final resolvedMode = hasLook ? parts.contentMode : contentMode;
    final resolvedStyle = hasLook ? parts.style : style;
    final placementName = json['placement'] as String?;
    final placement = placementName != null
        ? BatteryPlacement.values.firstWhere(
            (e) => e.name == placementName,
            orElse: () => BatteryPlacement.rightTop,
          )
        : BatteryPlacement.rightTop;
    return BatteryConfig(
      showBattery: json['showBattery'] as bool? ?? true,
      showTemp: json['showTemp'] as bool? ?? true,
      showChargingStats: json['showChargingStats'] as bool? ?? true,
      sizeScale: (json['sizeScale'] as num?)?.toDouble() ?? 1.0,
      look: look,
      contentMode: resolvedMode,
      style: resolvedStyle,
      placement: placement,
      vertFrac: (json['vertFrac'] as num?)?.toDouble() ?? 0.010,
      sidePadFrac: (json['sidePadFrac'] as num?)?.toDouble() ?? 0.04,
      horizBiasFrac: (json['horizBiasFrac'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BatteryConfig &&
      other.showBattery == showBattery &&
      other.showTemp == showTemp &&
      other.showChargingStats == showChargingStats &&
      other.sizeScale == sizeScale &&
      other.look == look &&
      other.contentMode == contentMode &&
      other.style == style &&
      other.placement == placement &&
      other.vertFrac == vertFrac &&
      other.sidePadFrac == sidePadFrac &&
      other.horizBiasFrac == horizBiasFrac;

  @override
  int get hashCode => Object.hash(
    showBattery,
    showTemp,
    showChargingStats,
    sizeScale,
    look,
    contentMode,
    style,
    placement,
    vertFrac,
    sidePadFrac,
    horizBiasFrac,
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


/// Speedcam HUD/DHU radar appearance (0034).
/// When to re-fetch the OSM pack from Overpass (0037).
enum SpeedcamRadarLook {
  /// Clean HUD-first: distance + bearing, no CRT cosplay.
  defaultLook,
  /// Motion-tracker CRT wedge + range ping (fun mode).
  alien,
}

enum SpeedcamRefreshPolicy {
  /// Only when the user taps Update.
  manualOnly,

  /// Auto-refresh if pack is missing or older than [SpeedcamConfig.staleAfterDays].
  ifStale,
}

class SpeedcamConfig {
  const SpeedcamConfig({
    this.hudMode = SpeedcamPresenceMode.any,
    this.soundMode = SpeedcamPresenceMode.dangerous,
    this.dhuRangeM = 2000,
    this.soundVolume = 0.85,
    this.radarLook = SpeedcamRadarLook.defaultLook,
    this.refreshPolicy = SpeedcamRefreshPolicy.manualOnly,
    this.staleAfterDays = 7,
    this.dhuSystemOverlay = false,
    this.ynaviEnrichEnabled = false,
    this.ynaviCollectEnabled = true,
    this.ynaviAlertEnabled = true,
    this.ynaviPointTtlDays = 7,
  });

  /// HUD radar/presence mode (default [SpeedcamPresenceMode.any]).
  final SpeedcamPresenceMode hudMode;

  /// Alert sound mode (default [SpeedcamPresenceMode.dangerous]).
  final SpeedcamPresenceMode soundMode;

  /// Alert presence + DHU radar radius in metres (prefs → approachRadiusM).
  final double dhuRangeM;

  /// Alert sound volume 0.0 (mute) … 1.0. Applied to sting + Alien ping.
  final double soundVolume;

  /// Visual language: Default (HUD-clean) vs Alien (motion-tracker CRT).
  final SpeedcamRadarLook radarLook;

  /// Harvest / cache refresh policy.
  final SpeedcamRefreshPolicy refreshPolicy;

  /// Age in days after which [SpeedcamRefreshPolicy.ifStale] refetches.
  final int staleAfterDays;

  /// 0065: always-on-top Speedcam plate on the DHU (SYSTEM_ALERT_WINDOW).
  final bool dhuSystemOverlay;

  /// 0071: ingest YNavi SPEEDCAM_DATA (ghost+route). Default OFF until user opts in.
  final bool ynaviEnrichEnabled;

  /// 0074: when enrich ON, collect into store. Default ON.
  final bool ynaviCollectEnabled;

  /// 0074: when enrich ON, alert/HUD treat YNavi-sourced cams. Default ON.
  final bool ynaviAlertEnabled;

  /// 0073: TTL days for YNavi overlay points (not OSM pack). Default 7.
  final int ynaviPointTtlDays;

  /// Legacy: HUD paint not Off (0060 migration / dumpState).
  bool get hudRadarEnabled => hudMode != SpeedcamPresenceMode.off;

  /// Legacy: sound not Off (0060 migration / dumpState).
  bool get soundEnabled => soundMode != SpeedcamPresenceMode.off;

  SpeedcamConfig copyWith({
    SpeedcamPresenceMode? hudMode,
    SpeedcamPresenceMode? soundMode,
    double? dhuRangeM,
    double? soundVolume,
    SpeedcamRadarLook? radarLook,
    SpeedcamRefreshPolicy? refreshPolicy,
    int? staleAfterDays,
    bool? dhuSystemOverlay,
    bool? ynaviEnrichEnabled,
    bool? ynaviCollectEnabled,
    bool? ynaviAlertEnabled,
    int? ynaviPointTtlDays,
    // Legacy bool shims — prefer [hudMode] / [soundMode].
    bool? hudRadarEnabled,
    bool? soundEnabled,
  }) {
    var nextHud = hudMode ?? this.hudMode;
    var nextSound = soundMode ?? this.soundMode;
    if (hudMode == null && hudRadarEnabled != null) {
      nextHud = hudRadarEnabled
          ? SpeedcamPresenceMode.any
          : SpeedcamPresenceMode.off;
    }
    if (soundMode == null && soundEnabled != null) {
      nextSound = soundEnabled
          ? SpeedcamPresenceMode.dangerous
          : SpeedcamPresenceMode.off;
    }
    return SpeedcamConfig(
      hudMode: nextHud,
      soundMode: nextSound,
      dhuRangeM: dhuRangeM ?? this.dhuRangeM,
      soundVolume: soundVolume ?? this.soundVolume,
      radarLook: radarLook ?? this.radarLook,
      refreshPolicy: refreshPolicy ?? this.refreshPolicy,
      staleAfterDays: staleAfterDays ?? this.staleAfterDays,
      dhuSystemOverlay: dhuSystemOverlay ?? this.dhuSystemOverlay,
      ynaviEnrichEnabled: ynaviEnrichEnabled ?? this.ynaviEnrichEnabled,
      ynaviCollectEnabled: ynaviCollectEnabled ?? this.ynaviCollectEnabled,
      ynaviAlertEnabled: ynaviAlertEnabled ?? this.ynaviAlertEnabled,
      ynaviPointTtlDays: ynaviPointTtlDays ?? this.ynaviPointTtlDays,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'hudMode': hudMode.name,
        'soundMode': soundMode.name,
        // Legacy mirrors for older readers / dumpState.
        'hudRadarEnabled': hudRadarEnabled,
        'dhuRangeM': dhuRangeM,
        'soundEnabled': soundEnabled,
        'soundVolume': soundVolume,
        'radarLook': radarLook.name,
        'refreshPolicy': refreshPolicy.name,
        'staleAfterDays': staleAfterDays,
        'dhuSystemOverlay': dhuSystemOverlay,
        'ynaviEnrichEnabled': ynaviEnrichEnabled,
        'ynaviCollectEnabled': ynaviCollectEnabled,
        'ynaviAlertEnabled': ynaviAlertEnabled,
        'ynaviPointTtlDays': ynaviPointTtlDays,
      };

  factory SpeedcamConfig.fromJson(Map<String, Object?> json) {
    final policyName = json['refreshPolicy'] as String?;
    final policy = SpeedcamRefreshPolicy.values.firstWhere(
      (e) => e.name == policyName,
      orElse: () => SpeedcamRefreshPolicy.manualOnly,
    );
    final lookName = json['radarLook'] as String?;
    final look = SpeedcamRadarLook.values.firstWhere(
      (e) => e.name == lookName || (lookName == 'default' && e == SpeedcamRadarLook.defaultLook),
      orElse: () => SpeedcamRadarLook.defaultLook,
    );
    final vol = (json['soundVolume'] as num?)?.toDouble() ?? 0.85;
    return SpeedcamConfig(
      hudMode: _presenceModeFromJson(
        json['hudMode'],
        legacyBool: json['hudRadarEnabled'] as bool?,
        legacyTrue: SpeedcamPresenceMode.any,
        defaultMode: SpeedcamPresenceMode.any,
      ),
      soundMode: _presenceModeFromJson(
        json['soundMode'],
        legacyBool: json['soundEnabled'] as bool?,
        legacyTrue: SpeedcamPresenceMode.dangerous,
        defaultMode: SpeedcamPresenceMode.dangerous,
      ),
      dhuRangeM: (json['dhuRangeM'] as num?)?.toDouble() ?? 2000,
      soundVolume: vol.clamp(0.0, 1.0),
      radarLook: look,
      refreshPolicy: policy,
      staleAfterDays: (json['staleAfterDays'] as num?)?.toInt() ?? 7,
      dhuSystemOverlay: json['dhuSystemOverlay'] as bool? ?? false,
      ynaviEnrichEnabled: json['ynaviEnrichEnabled'] as bool? ?? false,
      ynaviCollectEnabled: json['ynaviCollectEnabled'] as bool? ?? true,
      ynaviAlertEnabled: json['ynaviAlertEnabled'] as bool? ?? true,
      ynaviPointTtlDays: (json['ynaviPointTtlDays'] as num?)?.toInt() ?? 7,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SpeedcamConfig &&
      other.hudMode == hudMode &&
      other.soundMode == soundMode &&
      other.dhuRangeM == dhuRangeM &&
      other.soundVolume == soundVolume &&
      other.radarLook == radarLook &&
      other.refreshPolicy == refreshPolicy &&
      other.staleAfterDays == staleAfterDays &&
      other.dhuSystemOverlay == dhuSystemOverlay &&
      other.ynaviEnrichEnabled == ynaviEnrichEnabled &&
      other.ynaviCollectEnabled == ynaviCollectEnabled &&
      other.ynaviAlertEnabled == ynaviAlertEnabled &&
      other.ynaviPointTtlDays == ynaviPointTtlDays;

  @override
  int get hashCode => Object.hash(
        hudMode,
        soundMode,
        dhuRangeM,
        soundVolume,
        radarLook,
        refreshPolicy,
        staleAfterDays,
        dhuSystemOverlay,
        ynaviEnrichEnabled,
        ynaviCollectEnabled,
        ynaviAlertEnabled,
        ynaviPointTtlDays,
      );
}

SpeedcamPresenceMode _presenceModeFromJson(
  Object? raw, {
  required bool? legacyBool,
  required SpeedcamPresenceMode legacyTrue,
  required SpeedcamPresenceMode defaultMode,
}) {
  if (raw is String) {
    for (final m in SpeedcamPresenceMode.values) {
      if (m.name == raw) return m;
    }
  }
  if (legacyBool == false) return SpeedcamPresenceMode.off;
  if (legacyBool == true) return legacyTrue;
  return defaultMode;
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
    this.speedcam = const SpeedcamConfig(),
    this.locale,
    this.themeMode = 'auto',
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

  /// Speedcam radar (HUD enable + DHU zoom range).
  final SpeedcamConfig speedcam;

  /// UI language override: null = follow system locale; 'en' or 'ru' = explicit
  /// override.  Stored as a plain string so the JSON round-trip is trivial and
  /// future locale codes need no schema change.
  final String? locale;

  /// DHU MaterialApp theme: `'auto'` (default, follow system), `'dark'`, or `'light'`.
  ///
  /// Persisted for cold-boot restore. **HUD isolate ignores this** — [HudApp]
  /// stays emissive-black / ThemeMode.dark (CONTEXT.md).
  final String themeMode;

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
    SpeedcamConfig? speedcam,
    // Use a sentinel to distinguish "set to null" from "leave unchanged".
    Object? locale = _unset,
    String? themeMode,
    bool? autoUsbPeripheral,
  }) => AppConfig(
    hudEnabled: hudEnabled ?? this.hudEnabled,
    safeArea: safeArea ?? this.safeArea,
    blinker: blinker ?? this.blinker,
    battery: battery ?? this.battery,
    minimap: minimap ?? this.minimap,
    speedcam: speedcam ?? this.speedcam,
    locale: identical(locale, _unset) ? this.locale : locale as String?,
    themeMode: themeMode ?? this.themeMode,
    autoUsbPeripheral: autoUsbPeripheral ?? this.autoUsbPeripheral,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'hudEnabled': hudEnabled,
    'safeArea': safeArea.toJson(),
    'blinker': blinker.toJson(),
    'battery': battery.toJson(),
    'minimap': minimap.toJson(),
    'speedcam': speedcam.toJson(),
    if (locale != null) 'locale': locale,
    'themeMode': themeMode,
    'autoUsbPeripheral': autoUsbPeripheral,
  };

  factory AppConfig.fromJson(Map<String, Object?> json) {
    final safeArea = _asStringKeyedMap(json['safeArea']);
    final blinker = _asStringKeyedMap(json['blinker']);
    final battery = _asStringKeyedMap(json['battery']);
    final minimap = _asStringKeyedMap(json['minimap']);
    final speedcam = _asStringKeyedMap(json['speedcam']);
    return AppConfig(
      hudEnabled: json['hudEnabled'] as bool? ?? true,
      safeArea: safeArea != null
          ? HudSafeArea.fromJson(safeArea)
          : const HudSafeArea(),
      blinker: blinker != null
          ? BlinkerConfig.fromJson(blinker)
          : const BlinkerConfig(),
      battery: battery != null
          ? BatteryConfig.fromJson(battery)
          : const BatteryConfig(),
      minimap: minimap != null
          ? MinimapConfig.fromJson(minimap)
          : const MinimapConfig(),
      speedcam: speedcam != null
          ? SpeedcamConfig.fromJson(speedcam)
          : const SpeedcamConfig(),
      locale: json['locale'] as String?,
      themeMode: _themeModeFromJson(json['themeMode']),
      autoUsbPeripheral: json['autoUsbPeripheral'] as bool? ?? false,
    );
  }

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
      other.speedcam == speedcam &&
      other.locale == locale &&
      other.themeMode == themeMode &&
      other.autoUsbPeripheral == autoUsbPeripheral;

  @override
  int get hashCode => Object.hash(
    hudEnabled,
    safeArea,
    blinker,
    battery,
    minimap,
    speedcam,
    locale,
    themeMode,
    autoUsbPeripheral,
  );
}

// Sentinel used by copyWith to distinguish "pass null" from "omit".
const Object _unset = Object();


String _themeModeFromJson(Object? raw) {
  // 'auto' = follow system (default). 'system' accepted as alias.
  if (raw == 'light' || raw == 'dark' || raw == 'auto') return raw as String;
  if (raw == 'system') return 'auto';
  return 'auto';
}


/// Port for config persistence. Each isolate owns its own instance.
abstract class ConfigStore {
  AppConfig get value;
  Stream<AppConfig> get changes;
  Future<void> load();
  Future<void> setConfig(AppConfig next);
}
