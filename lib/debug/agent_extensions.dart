import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show File, pid;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show InkResponse;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../services/car_signals.dart';
import '../services/config_store.dart';
import '../services/fakes/fake_car_signals.dart';
import '../services/install_targets.dart';
import '../services/installer.dart';
import '../services/speedcam.dart';
import '../services/fakes/fake_speedcam_service.dart';
import '../services/speedcam_pack_store.dart';
import '../services/speedcam_drive.dart';
import '../services/minimap_host.dart';
import '../services/system_config.dart';
import '../services/usb_mode.dart';

/// Register ext.zee.* VM-service extensions for [surface] (either 'dhu' or 'hud').
///
/// Both isolates register the same set so the Feedback Loop can drive and read
/// each surface independently. [shotKey] must wrap the root RepaintBoundary.
/// [carSignals] is the CarSignals instance for this isolate — may be a
/// [FakeCarSignals] (T1/HUD) or a NativeCarSignals (T2 DHU). On T2 DHU the
/// ext.zee.inject extension is disabled (native injection uses ADB broadcasts).
/// [onSetConfig] is optional (DHU can pass null; the store.changes subscription
/// already relays to HUD).
/// [minimapHost] is optional; when provided, ext.zee.minimap is registered.
/// [getBootState] is optional; when provided, ext.zee.bootState is registered
/// (DHU surface passes a callback that queries the native FGS state).
/// [installer] is optional; when provided, ext.zee.install is registered so
/// the Feedback Loop can trigger and observe install progress.
/// [systemConfig] is optional; when provided, ext.zee.setLanguage is registered
/// and readViewModel includes {systemLocale, clusterSupported} (Block 0015).
/// [usbMode] is optional; when provided, ext.zee.setUsbMode is registered
/// and readViewModel includes {usbMode, usbWritable} (Block 0016).
/// [getHudGeometry] is optional; when provided, readViewModel includes a
/// `hud` map ({displayId, w, h, dpi}) — the real HUD display geometry as
/// last reported by native's onHudReady (Block 0027). Only meaningful on the
/// DHU surface, which owns the NativeMinimapHost that receives that callback.
/// [getMinimapViewport] is optional; when provided, readViewModel includes a
/// `viewport` map ({x, y, w, h}) — the minimap ROI computed by
/// computeMinimapViewport() in lib/main.dart. The app is the source of truth
/// for this geometry so the Feedback Loop never has to reimplement it and
/// risk the two copies drifting apart (the exact failure mode that let a
/// minimap regression ship undetected — docs/issues/0009-minimap-under-layer.md:39).
void registerZeeExtensions({
  required String surface,
  required ConfigStore store,
  required GlobalKey shotKey,
  CarSignals? carSignals,
  Future<void> Function(AppConfig)? onSetConfig,
  MinimapHost? minimapHost,
  Future<Map<String, Object?>> Function()? getBootState,
  Installer? installer,
  SystemConfig? systemConfig,
  UsbModePort? usbMode,
  Map<String, Object?> Function()? getHudGeometry,
  Rect? Function()? getMinimapViewport,
  // [getMinimapNative] surfaces the last native `setMinimap` gate result
  // ("applied:true" | "unavailable" | "no-minimap") in readViewModel's
  // `minimap.native` field. [onMinimapNativeResult] lets the direct
  // `ext.zee.minimap on=...` path (below) feed that same holder so
  // readViewModel stays consistent regardless of which path enabled it.
  String? Function()? getMinimapNative,
  void Function(String?)? onMinimapNativeResult,
  SpeedcamService? speedcam,
  SpeedcamPackStore? speedcamPack,
}) {
  final SpeedcamDriveSim? speedcamDrive = speedcam != null
      ? SpeedcamDriveSim(speedcam)
      : null;
  developer.registerExtension('ext.zee.whoami', (method, params) async {
    return developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{
        'surface': surface,
        'isolate': identityHashCode(store),
        'pid': pid,
        'hudEnabled': store.value.hudEnabled,
      }),
    );
  });

  developer.registerExtension('ext.zee.dumpState', (method, params) async {
    return developer.ServiceExtensionResponse.result(
      _dumpStateJson(surface, store),
    );
  });

  // readViewModel returns the full derived view-model (ADR 0004).
  // HUD layout state (safeArea + active slots) is included so the Feedback Loop
  // can verify layout changes without a screenshot.
  developer.registerExtension('ext.zee.readViewModel', (method, params) async {
    final snap = carSignals?.snapshot;
    final sa = store.value.safeArea;
    final bl = store.value.blinker;
    final bat = store.value.battery;
    final mm = store.value.minimap;
    // ynaviAvailable is queried from the minimapHost if present; otherwise null.
    final bool? ynaviAvailable = minimapHost != null
        ? await minimapHost.isYnaviAvailable()
        : null;
    // systemLocale / clusterSupported — read from SystemConfig when provided.
    // On T1 FakeSystemConfig returns a fixed locale and false/true for clusterSupported.
    // On T2 NativeSystemConfig reads the real Android locale and probes AdaptAPI.
    final String? systemLocaleTag = systemConfig?.systemLocale.toLanguageTag();
    final bool? clusterSupported = systemConfig != null
        ? await systemConfig.clusterSupported()
        : null;
    // signalSource: 'adaptapi' | 'simulated' | 'fake' — which CarSignals
    // source is actually live (Task 1). Mirrors the native
    // CarSignalsController's own selectSource() decision; never re-derived
    // here. Null when no CarSignals was provided at all (shouldn't happen on
    // a registered surface, but the extension must never throw).
    final String? signalSource = await carSignals?.sourceKind;
    final SpeedcamPackMeta? packMeta = await speedcamPack?.current(
      SpeedcamPackIds.by,
    );
    return developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{
        'surface': surface,
        // locale: null = follow system; 'en'/'ru' = explicit override.
        'locale': store.value.locale,
        'signalSource': signalSource,
        'speedcam': speedcam?.snapshot.toJson(),
        'speedcamPack': packMeta?.toJson(),
        'speedcamConfig': <String, Object?>{
          'hudMode': store.value.speedcam.hudMode.name,
          'soundMode': store.value.speedcam.soundMode.name,
          'hudRadarEnabled': store.value.speedcam.hudRadarEnabled,
          'radarLook': store.value.speedcam.radarLook.name,
          'soundEnabled': store.value.speedcam.soundEnabled,
          'soundVolume': store.value.speedcam.soundVolume,
          'dhuRangeM': store.value.speedcam.dhuRangeM,
        },
        'speedKmh': snap?.speedKmh,
        'blinker': <String, Object?>{
          'state': snap?.blinker.name ?? BlinkerState.off.name,
          'shape': bl.shape.name,
          'sizeScale': bl.sizeScale,
        },
        'battery': <String, Object?>{
          'pct': snap?.batteryPct,
          'tempC': snap?.batteryTempC,
          'charging': snap?.charging,
          'kw': snap?.chargeKw,
          'showBattery': bat.showBattery,
          'showTemp': bat.showTemp,
          'showChargingStats': bat.showChargingStats,
          'look': bat.look.name,
          'contentMode': bat.contentMode.name,
          'style': bat.style.name,
          'placement': bat.placement.name,
          'vertFrac': bat.vertFrac,
          'sidePadFrac': bat.sidePadFrac,
          'horizBiasFrac': bat.horizBiasFrac,
        },
        'powerFlow': snap?.powerFlow.name ?? PowerFlow.unknown.name,
        // HUD layout state — safeArea fractions + which slots are active.
        // activeSlots: slots with real rendered content on the production HUD.
        // The minimap is native (a TextureView beneath the transparent Flutter
        // overlay), so it is active but is NOT visible to `ext.zee.shot` —
        // only to `feedback_loop.py shot --layer native`.
        //
        // plannedSlots is now always empty. It used to advertise
        // ['guidance', 'minimap'] — the minimap long after it had shipped, and
        // guidance for a slot that has since been removed outright (the HUD
        // shows the YNavi map; there is no separate turn-by-turn overlay in
        // scope). Kept as an empty list for wire compatibility.
        'safeArea': sa.toJson(),
        'activeSlots': <String>['blinker', 'battery', 'minimap'],
        'plannedSlots': const <String>[],
        // Minimap config + live YNavi availability for the Feedback Loop.
        'minimap': <String, Object?>{
          'enabled': mm.enabled,
          'preset': mm.preset,
          'advanced': mm.advanced,
          if (mm.sizeFraction != null) 'sizeFraction': mm.sizeFraction,
          'resolvedSizeFraction': mm.resolvedSizeFraction,
          'looks': mm.looks.toJson(),
          'ynaviAvailable': ynaviAvailable,
          // Native setMinimap gate result — see [getMinimapNative] above.
          'native': getMinimapNative != null ? getMinimapNative() : null,
        },
        // Block 0027: the app's own HUD display geometry + minimap ROI — the
        // native composite verifier (shot --layer native) crops exactly this
        // rect instead of guessing/reimplementing computeMinimapViewport().
        // Null (both keys, or the whole 'hud' map) when neither callback was
        // provided (e.g. the HUD surface, or T1 desktop before hudReady fires).
        'hud': getHudGeometry != null ? getHudGeometry() : null,
        'viewport': () {
          final r = getMinimapViewport != null ? getMinimapViewport() : null;
          if (r == null) return null;
          return <String, Object?>{
            'x': r.left,
            'y': r.top,
            'w': r.width,
            'h': r.height,
          };
        }(),
        // Install state — last/current install progress for the Feedback Loop.
        // Populated once ext.zee.install is called; null until first install.
        'install': Map<String, Object?>.from(
          _installStateHolder[surface] ?? <String, Object?>{},
        ),
        // Block 0015: system locale + cluster availability.
        // systemLocale: BCP-47 tag e.g. "en-US" or "ru-RU" (null when SystemConfig absent).
        // clusterSupported: false on emulator (no AdaptAPI), true on Zeekr car.
        'systemLocale': systemLocaleTag,
        'clusterSupported': clusterSupported,
        // Block 0016: USB mode + writability.
        // usbMode: "peripheral"|"host"|"auto" (null when UsbModePort absent).
        // usbWritable: optimistic true until a write fails off-car (no platform
        // signing) flips it false; genuinely writable on the car (T3).
        'usbMode': usbMode?.currentMode.name,
        'usbWritable': usbMode?.writable,
      }),
    );
  });

  // setConfig — supports hudEnabled, safeArea, blinker, battery.
  // safeArea param: JSON-encoded object string e.g. '{"left":0.1,"top":0.3,...}'
  // or individual edge keys: safeLeft, safeTop, safeRight, safeBottom.
  developer.registerExtension('ext.zee.setConfig', (method, params) async {
    var next = store.value;

    // hudEnabled — gates native HUD-engine spawn (boot shim reads this, ADR 0003).
    final rawHudEnabled = params['hudEnabled'];
    if (rawHudEnabled != null) {
      next = next.copyWith(hudEnabled: rawHudEnabled == 'true');
    }

    // Accept safeArea as a JSON object string.
    final rawSafeArea = params['safeArea'];
    if (rawSafeArea != null) {
      try {
        final decoded = jsonDecode(rawSafeArea) as Map<String, Object?>;
        next = next.copyWith(safeArea: HudSafeArea.fromJson(decoded));
      } catch (e) {
        return _extError('setConfig: invalid safeArea JSON: $e');
      }
    }

    // Also support individual safe-area edge keys for convenience.
    final sa = next.safeArea;
    final saLeft = double.tryParse(params['safeLeft'] ?? '');
    final saTop = double.tryParse(params['safeTop'] ?? '');
    final saRight = double.tryParse(params['safeRight'] ?? '');
    final saBottom = double.tryParse(params['safeBottom'] ?? '');
    if (saLeft != null ||
        saTop != null ||
        saRight != null ||
        saBottom != null) {
      next = next.copyWith(
        safeArea: sa.copyWith(
          left: saLeft,
          top: saTop,
          right: saRight,
          bottom: saBottom,
        ),
      );
    }

    // Blinker config: blinkerShape=dots|arrows|smiley, blinkerSize=<double>.
    final rawBlinkerShape = params['blinkerShape'];
    final rawBlinkerSize = params['blinkerSize'];
    if (rawBlinkerShape != null || rawBlinkerSize != null) {
      final bl = next.blinker;
      BlinkerShape? shape;
      if (rawBlinkerShape != null) {
        shape = BlinkerShape.values.firstWhere(
          (e) => e.name == rawBlinkerShape,
          orElse: () => bl.shape,
        );
      }
      final size = double.tryParse(rawBlinkerSize ?? '');
      next = next.copyWith(
        blinker: bl.copyWith(shape: shape, sizeScale: size),
      );
    }

    // Battery config: batteryShow=true|false, tempShow=..., chargingShow=...,
    // batterySize=<double>,
    // batteryLook=battery|batteryText|batteryBars|justText (0056 PDM),
    // batteryContentMode=both|iconOnly|textOnly + batteryStyle=outline|filled|pctInside
    // (legacy aliases; also contentMode/style),
    // batteryPlacement=left|right|rightTop, batteryVert / batterySidePad /
    // batteryHorizBias=<double>.
    final rawBatteryShow = params['batteryShow'];
    final rawTempShow = params['tempShow'];
    final rawChargingShow = params['chargingShow'];
    final rawBatterySize = params['batterySize'];
    final rawBatteryLook = params['batteryLook'] ?? params['look'];
    final rawBatteryContentMode =
        params['batteryContentMode'] ?? params['contentMode'];
    final rawBatteryStyle = params['batteryStyle'] ?? params['style'];
    final rawBatteryPlacement = params['batteryPlacement'];
    final rawBatteryVert = params['batteryVert'];
    final rawBatterySidePad = params['batterySidePad'];
    final rawBatteryHorizBias = params['batteryHorizBias'];
    if (rawBatteryShow != null ||
        rawTempShow != null ||
        rawChargingShow != null ||
        rawBatterySize != null ||
        rawBatteryLook != null ||
        rawBatteryContentMode != null ||
        rawBatteryStyle != null ||
        rawBatteryPlacement != null ||
        rawBatteryVert != null ||
        rawBatterySidePad != null ||
        rawBatteryHorizBias != null) {
      var bat = next.battery;
      BatteryLook? look;
      if (rawBatteryLook != null) {
        look = BatteryLook.values.firstWhere(
          (e) => e.name == rawBatteryLook,
          orElse: () => bat.look,
        );
      }
      BatteryContentMode? contentMode;
      if (rawBatteryContentMode != null) {
        contentMode = BatteryContentMode.values.firstWhere(
          (e) => e.name == rawBatteryContentMode,
          orElse: () => bat.contentMode,
        );
      }
      BatteryStyle? style;
      if (rawBatteryStyle != null) {
        style = BatteryStyle.values.firstWhere(
          (e) => e.name == rawBatteryStyle,
          orElse: () => bat.style,
        );
      }
      if (rawBatteryPlacement != null) {
        final placement = BatteryPlacement.values.firstWhere(
          (e) => e.name == rawBatteryPlacement,
          orElse: () => bat.placement,
        );
        bat = bat.withPlacement(placement);
      }
      if (look != null) {
        bat = bat.withLook(look);
      }
      next = next.copyWith(
        battery: bat.copyWith(
          showBattery: rawBatteryShow != null ? rawBatteryShow == 'true' : null,
          showTemp: rawTempShow != null ? rawTempShow == 'true' : null,
          showChargingStats: rawChargingShow != null
              ? rawChargingShow == 'true'
              : null,
          sizeScale: double.tryParse(rawBatterySize ?? ''),
          contentMode: look == null ? contentMode : null,
          style: look == null ? style : null,
          vertFrac: double.tryParse(rawBatteryVert ?? ''),
          sidePadFrac: double.tryParse(rawBatterySidePad ?? ''),
          horizBiasFrac: double.tryParse(rawBatteryHorizBias ?? ''),
        ),
      );
    }

    // locale: en|ru|system  (system → null, clears the override)
    final rawLocale = params['locale'];
    if (rawLocale != null) {
      next = next.copyWith(locale: rawLocale == 'system' ? null : rawLocale);
    }

    // speedcam.radarLook=alien|defaultLook (0080 T1 A/B)
    final rawRadarLook = params['radarLook'];
    if (rawRadarLook != null) {
      final look = SpeedcamRadarLook.values.firstWhere(
        (e) => e.name == rawRadarLook,
        orElse: () => next.speedcam.radarLook,
      );
      next = next.copyWith(speedcam: next.speedcam.copyWith(radarLook: look));
    }

    // 0083 QA: force DHU system Overlay without Switch UI.
    // dhuSystemOverlay=true|false — store.changes → Overlay enable + re-seed.
    final rawDhuOverlay =
        params['dhuSystemOverlay'] ??
        params['systemOverlay'] ??
        params['overlay'];
    if (rawDhuOverlay != null) {
      next = next.copyWith(
        speedcam: next.speedcam.copyWith(
          dhuSystemOverlay: rawDhuOverlay == 'true' || rawDhuOverlay == '1',
        ),
      );
    }

    // Minimap config: minimapEnabled=true|false,
    // minimapOnlyWhileGuidance=true|false (0057),
    // guidanceOverlay / etaBar (0055 Zee HUD 2),
    // minimapPreset=compact|balanced|large.
    final rawMinimapEnabled = params['minimapEnabled'];
    final rawMinimapOnlyWhileGuidance =
        params['minimapOnlyWhileGuidance'] ?? params['onlyWhileGuidance'];
    final rawGuidanceOverlay =
        params['guidanceOverlay'] ?? params['guidance_overlay'];
    final rawEtaBar = params['etaBar'] ?? params['eta_bar'];
    final rawMinimapPreset = params['minimapPreset'];
    if (rawMinimapEnabled != null ||
        rawMinimapOnlyWhileGuidance != null ||
        rawGuidanceOverlay != null ||
        rawEtaBar != null ||
        rawMinimapPreset != null) {
      final mm = next.minimap;
      next = next.copyWith(
        minimap: mm.copyWith(
          enabled: rawMinimapEnabled != null
              ? rawMinimapEnabled == 'true'
              : null,
          onlyWhileGuidance: rawMinimapOnlyWhileGuidance != null
              ? rawMinimapOnlyWhileGuidance == 'true'
              : null,
          guidanceOverlay: rawGuidanceOverlay != null
              ? rawGuidanceOverlay == 'true'
              : null,
          etaBar: rawEtaBar != null ? rawEtaBar == 'true' : null,
          preset: rawMinimapPreset,
        ),
      );
    }

    await store.setConfig(next);
    if (onSetConfig != null) await onSetConfig(next);
    return developer.ServiceExtensionResponse.result(
      _dumpStateJson(surface, store),
    );
  });

  // ext.zee.setLanguage — attempt a system or cluster language change.
  //
  // Block 0015: Feedback Loop path for language writes.
  //   scope=app     value=en|ru|system  → sets AppConfig.locale (same as setConfig locale=…)
  //   scope=system  value=en|ru         → calls SystemConfig.setSystemLanguage (T3-only)
  //   scope=cluster value=en|ru         → calls SystemConfig.setClusterLanguage (T3-only)
  //
  // Returns a JSON map with {ok, reason?, surface, scope, value}.
  // On T2 emulator scope=system|cluster returns {ok:false, reason:"unsupported-on-device"}.
  // Registered only when [systemConfig] is provided (DHU surface).
  if (systemConfig != null) {
    developer.registerExtension('ext.zee.setLanguage', (method, params) async {
      final scope = params['scope'] ?? 'app';
      final value = params['value'] ?? 'en';

      switch (scope) {
        case 'app':
          final code = value == 'system' ? null : value;
          var next = store.value;
          next = next.copyWith(locale: code);
          await store.setConfig(next);
          if (onSetConfig != null) await onSetConfig(next);
          return developer.ServiceExtensionResponse.result(
            jsonEncode(<String, Object?>{
              'surface': surface,
              'scope': scope,
              'value': value,
              'ok': true,
            }),
          );

        case 'system':
          final result = await systemConfig.setSystemLanguage(ui.Locale(value));
          return developer.ServiceExtensionResponse.result(
            jsonEncode(<String, Object?>{
              'surface': surface,
              'scope': scope,
              'value': value,
              'ok': result.ok,
              if (result.reason != null) 'reason': result.reason,
              // Always include the current system locale tag so the caller
              // can verify what the mechanism read.
              'systemLocale': systemConfig.systemLocale.toLanguageTag(),
            }),
          );

        case 'cluster':
          final result = await systemConfig.setClusterLanguage(
            ui.Locale(value),
          );
          return developer.ServiceExtensionResponse.result(
            jsonEncode(<String, Object?>{
              'surface': surface,
              'scope': scope,
              'value': value,
              'ok': result.ok,
              if (result.reason != null) 'reason': result.reason,
            }),
          );

        default:
          return _extError(
            'ext.zee.setLanguage: unknown scope "$scope"; '
            'expected app|system|cluster',
          );
      }
    });
  }

  // ext.zee.setUsbMode — set USB mode via UsbModePort (Block 0016).
  //
  // Params: value=peripheral|host|auto
  //
  // Returns {ok, reason?, usbMode, usbWritable}.
  // On T2 emulator returns {ok:false, reason:"requires-platform-signing"}.
  // T1 FakeUsbMode reflects the mode immediately (writable=true).
  // Registered only when [usbMode] is provided (DHU surface).
  if (usbMode != null) {
    developer.registerExtension('ext.zee.setUsbMode', (method, params) async {
      final rawValue = params['value'];
      final UsbMode? mode = switch (rawValue) {
        'peripheral' => UsbMode.peripheral,
        'host' => UsbMode.host,
        'auto' => UsbMode.auto,
        _ => null,
      };
      if (mode == null) {
        return _extError(
          'ext.zee.setUsbMode: unknown value "$rawValue"; '
          'expected peripheral|host|auto',
        );
      }
      // Persist the "auto" preference to ConfigStore regardless of whether
      // the native write below succeeds — same honesty split as the
      // UsbAdbScreen UI path (Task 2): the top-level autoUsbPeripheral flag
      // is what BootReceiver/ConfigShim actually read on boot, independent
      // of the privileged persist.usb.mode write this build cannot make.
      await store.setConfig(
        store.value.copyWith(autoUsbPeripheral: mode == UsbMode.auto),
      );
      final result = await usbMode.setUsbMode(mode);
      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{
          'surface': surface,
          'value': rawValue,
          'ok': result.ok,
          if (result.reason != null) 'reason': result.reason,
          'usbMode': usbMode.currentMode.name,
          'usbWritable': usbMode.writable,
          'autoUsbPeripheral': store.value.autoUsbPeripheral,
        }),
      );
    });
  }

  // inject — push a fake CarSignalEvent into the DHU isolate's FakeCarSignals.
  // Registered on DHU only: HUD CarSignals are driven exclusively via the
  // DHU→HUD relay, so injecting on HUD would bypass the relay and diverge
  // the two surfaces. Always target surface=dhu (or ADB broadcast on T2/T3).
  if (surface == 'dhu') {
    developer.registerExtension('ext.zee.inject', (method, params) async {
      final fake = carSignals is FakeCarSignals ? carSignals : null;
      if (fake == null) {
        return _extError(
          'ext.zee.inject not available on this surface '
          '(use ADB broadcast on T2: adb shell am broadcast -a com.zeepowertoys.SIMULATE)',
        );
      }
      final kind = params['kind'];
      try {
        switch (kind) {
          case 'speed':
            final kmh = int.parse(params['value'] ?? '0');
            fake.emitSpeed(kmh);
          case 'blinker':
            final state = BlinkerState.values.byName(params['value'] ?? 'off');
            fake.emitBlinker(state);
          case 'charge':
            final charging = (params['charging'] ?? 'false') == 'true';
            final kw = double.tryParse(params['kw'] ?? '');
            final volts = double.tryParse(params['volts'] ?? '');
            final amps = double.tryParse(params['amps'] ?? '');
            fake.emitCharge(
              charging: charging,
              kw: kw,
              volts: volts,
              amps: amps,
            );
          case 'battery':
            final levelPct = int.parse(params['levelPct'] ?? '0');
            final tempC = double.parse(params['tempC'] ?? '0');
            fake.emitBattery(levelPct: levelPct, tempC: tempC);
          case 'powerFlow':
            final flow = PowerFlow.values.byName(params['value'] ?? 'unknown');
            fake.emitPowerFlow(flow);
          default:
            return _extError(
              'unknown kind "$kind"; expected speed|blinker|charge|battery|powerFlow',
            );
        }
      } catch (e) {
        return _extError('inject error: $e');
      }
      return developer.ServiceExtensionResponse.result(
        jsonEncode(fake.snapshot.toJson()..['surface'] = surface),
      );
    }); // end ext.zee.inject

    // Speedcam (0030): set host pose / approach a sample cam / enable.
    // T1 Fake only until pack+native land.
    developer.registerExtension('ext.zee.speedcam', (method, params) async {
      final svc = speedcam;
      if (svc == null) {
        return developer.ServiceExtensionResponse.result(
          jsonEncode(<String, Object?>{
            'ok': false,
            'error': 'speedcam not available on this surface',
          }),
        );
      }
      final action = params['action'] ?? params['op'] ?? 'snapshot';
      try {
        switch (action) {
          case 'enable':
            await svc.setEnabled(
              params['on'] != 'false' && params['on'] != '0',
            );
          case 'disable':
            await svc.setEnabled(false);
          case 'pose':
            final lat = double.parse(params['lat'] ?? '0');
            final lon = double.parse(params['lon'] ?? '0');
            final spd = params['speedKmh'] != null
                ? double.tryParse(params['speedKmh']!)
                : null;
            final heading = params['headingDeg'] != null
                ? double.tryParse(params['headingDeg']!)
                : null;
            await svc.setHostPose(
              SpeedcamHostPose(
                lat: lat,
                lon: lon,
                speedKmh: spd,
                headingDeg: heading,
              ),
            );
          case 'approach':
          case 'demo':
            // 0089: `demo` mirrors Speedcam Settings "Demo on HUD" (pose +
            // speedKmh=50). Optional overlay=true|false also flips
            // SpeedcamConfig.dhuSystemOverlay via the same store write as
            // setConfig — one RPC for Demo+Overlay without OCR/tap thrash.
            // `approach` keeps the older name; defaults now match Demo.
            final dist = double.parse(
              params['distanceM'] ?? '$kSpeedcamDemoDistanceM',
            );
            final cams = svc.snapshot.cams.isNotEmpty
                ? svc.snapshot.cams
                : FakeSpeedcamService.kFakeBySampleCams;
            if (cams.isEmpty) {
              return developer.ServiceExtensionResponse.result(
                jsonEncode(<String, Object?>{
                  'ok': false,
                  'error': 'no cams loaded',
                }),
              );
            }
            final id = params['camId'];
            final cam = id == null
                ? pickSpeedcamDemoCam(cams)
                : cams.firstWhere((c) => c.id == id, orElse: () => cams.first);
            // 1 deg lat ≈ 111320 m — approach from south.
            // Default heading null (like HUD Demo) so facing/ahead fail-open;
            // heading=0 made Overlay hide behind cams before visible-gate fix.
            final dLat = dist / 111320.0;
            final heading = params['headingDeg'] != null
                ? double.tryParse(params['headingDeg']!)
                : null;
            // Demo button uses 50 km/h; approach used to leave speed null.
            final speed =
                double.tryParse(
                  params['speedKmh'] ?? (action == 'demo' ? '50' : ''),
                ) ??
                (action == 'demo' ? 50.0 : null);
            await svc.setHostPose(
              SpeedcamHostPose(
                lat: cam.lat - dLat,
                lon: cam.lon,
                speedKmh: speed ?? 50.0,
                headingDeg: heading,
              ),
            );
            final rawOverlay =
                params['overlay'] ??
                params['dhuSystemOverlay'] ??
                params['systemOverlay'];
            if (rawOverlay != null) {
              final on = rawOverlay == 'true' || rawOverlay == '1';
              final cfg = store.value;
              await store.setConfig(
                cfg.copyWith(
                  speedcam: cfg.speedcam.copyWith(dhuSystemOverlay: on),
                ),
              );
            }
          case 'demoStop':
          case 'clearPose':
            // demoStop aliases clearPose; optional overlay=false tears Overlay down.
            await svc.clearHostPose();
            final rawOverlayStop =
                params['overlay'] ??
                params['dhuSystemOverlay'] ??
                params['systemOverlay'];
            if (rawOverlayStop != null) {
              final on = rawOverlayStop == 'true' || rawOverlayStop == '1';
              final cfg = store.value;
              await store.setConfig(
                cfg.copyWith(
                  speedcam: cfg.speedcam.copyWith(dhuSystemOverlay: on),
                ),
              );
            }
          case 'reloadPack':
            await svc.reloadFromPack();
            break;
          case 'packStatus':
            final meta = await speedcamPack?.current(SpeedcamPackIds.by);
            return developer.ServiceExtensionResponse.result(
              jsonEncode(<String, Object?>{
                'ok': true,
                'speedcamPack': meta?.toJson(),
              }),
            );
          case 'packUpdate':
            if (speedcamPack == null) {
              return developer.ServiceExtensionResponse.result(
                jsonEncode(<String, Object?>{
                  'ok': false,
                  'error': 'speedcamPack not available',
                }),
              );
            }
            final host = speedcam?.snapshot.host;
            final meta = await speedcamPack.updatePack(
              SpeedcamPackIds.by,
              centerLat: host?.lat,
              centerLon: host?.lon,
            );
            await speedcam?.reloadFromPack();
            return developer.ServiceExtensionResponse.result(
              jsonEncode(<String, Object?>{
                'ok': true,
                'speedcamPack': meta.toJson(),
                'speedcam': speedcam?.snapshot.toJson(),
              }),
            );
          case 'packInstall':
            // Offline QA: install fixture JSON (path= or body=). File store only.
            if (speedcamPack is! FileSpeedcamPackStore) {
              return developer.ServiceExtensionResponse.result(
                jsonEncode(<String, Object?>{
                  'ok': false,
                  'error': 'packInstall requires FileSpeedcamPackStore',
                }),
              );
            }
            final path = params['path'];
            final bodyParam = params['body'];
            late final String jsonBody;
            if (path != null && path.isNotEmpty) {
              jsonBody = await File(path).readAsString();
            } else if (bodyParam != null && bodyParam.isNotEmpty) {
              jsonBody = bodyParam;
            } else {
              return developer.ServiceExtensionResponse.result(
                jsonEncode(<String, Object?>{
                  'ok': false,
                  'error': 'packInstall needs path= or body=',
                }),
              );
            }
            final installed = await speedcamPack.installFixture(
              packId: params['packId'] ?? SpeedcamPackIds.by,
              jsonBody: jsonBody,
            );
            await speedcam?.reloadFromPack();
            return developer.ServiceExtensionResponse.result(
              jsonEncode(<String, Object?>{
                'ok': true,
                'speedcamPack': installed.toJson(),
                'speedcam': speedcam?.snapshot.toJson(),
              }),
            );
          case 'drive':
            // Continuous polyline through pack cams (0036).
            if (speedcamDrive == null) {
              return developer.ServiceExtensionResponse.result(
                jsonEncode(<String, Object?>{
                  'ok': false,
                  'error': 'drive not available',
                }),
              );
            }
            await svc.reloadFromPack();
            final cams = svc.snapshot.cams;
            if (cams.length < 2) {
              return developer.ServiceExtensionResponse.result(
                jsonEncode(<String, Object?>{
                  'ok': false,
                  'error': 'need >=2 pack cams (got ${cams.length})',
                  'camCount': cams.length,
                }),
              );
            }
            final camIds = (params['cams'] ?? '')
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            List<SpeedcamPoint> selected;
            if (camIds.isEmpty) {
              selected = cams.take(2).toList();
            } else {
              selected = <SpeedcamPoint>[];
              for (final id in camIds) {
                selected.add(
                  cams.firstWhere((c) => c.id == id, orElse: () => cams.first),
                );
              }
              if (selected.length < 2) {
                selected = cams.take(2).toList();
              }
            }
            final approachM = double.tryParse(params['approachM'] ?? '') ?? 800;
            final speedKmh = double.tryParse(params['speedKmh'] ?? '') ?? 50;
            final tickMs = int.tryParse(params['tickMs'] ?? '') ?? 100;
            final pathRaw = params['path'];
            late final List<SpeedcamWaypoint> waypoints;
            if (pathRaw != null && pathRaw.isNotEmpty) {
              waypoints = pathRaw.split(';').map((pair) {
                final parts = pair.split(',');
                return SpeedcamWaypoint(
                  double.parse(parts[0].trim()),
                  double.parse(parts[1].trim()),
                );
              }).toList();
            } else {
              waypoints = pathThroughCams(selected, approachM: approachM);
            }
            final started = await speedcamDrive.start(
              waypoints: waypoints,
              speedKmh: speedKmh,
              tickMs: tickMs,
            );
            return developer.ServiceExtensionResponse.result(
              jsonEncode(<String, Object?>{
                ...started,
                'cams': selected.map((c) => c.id).toList(),
                'speedcam': svc.snapshot.toJson(),
                'drive': speedcamDrive.statusJson(),
              }),
            );
          case 'driveStop':
            speedcamDrive?.stop();
            return developer.ServiceExtensionResponse.result(
              jsonEncode(<String, Object?>{
                'ok': true,
                'drive': speedcamDrive?.statusJson(),
                'speedcam': svc.snapshot.toJson(),
              }),
            );
          case 'driveStatus':
            return developer.ServiceExtensionResponse.result(
              jsonEncode(<String, Object?>{
                'ok': true,
                'drive': speedcamDrive?.statusJson(),
                'speedcam': svc.snapshot.toJson(),
              }),
            );
          case 'snapshot':
            break;
          default:
            return developer.ServiceExtensionResponse.result(
              jsonEncode(<String, Object?>{
                'ok': false,
                'error': 'unknown action=$action',
              }),
            );
        }
        return developer.ServiceExtensionResponse.result(
          jsonEncode(<String, Object?>{
            'ok': true,
            'surface': surface,
            'speedcam': svc.snapshot.toJson(),
          }),
        );
      } catch (e) {
        return developer.ServiceExtensionResponse.result(
          jsonEncode(<String, Object?>{'ok': false, 'error': '$e'}),
        );
      }
    });
  } // end if (surface == 'dhu')

  // tapByKey — synthetic-tap a widget identified by ValueKey<String>.
  // Ported from the flutter-debug skill's nothingness AgentService pattern.
  // Three-tier fallback: descendant-callback → synthetic-pointer → ancestor-callback.
  developer.registerExtension('ext.zee.tapByKey', (method, params) async {
    final keyValue = params['key'];
    if (keyValue == null || keyValue.isEmpty) {
      return _extError('key parameter required');
    }
    final element = _findElementByKey(keyValue);
    if (element == null) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{
          'tapped': false,
          'error': 'no widget found with key "$keyValue"',
        }),
      );
    }

    // Scroll ListView/off-screen keyed widgets into view so agent keys below
    // the fold (e.g. battery-content-*) are tappable on HUD Settings.
    try {
      await Scrollable.ensureVisible(
        element,
        duration: Duration.zero,
        alignment: 0.1,
      );
    } catch (_) {
      // Not in a scrollable — fine.
    }

    // Prefer a descendant callback walk (catches GestureDetector/InkResponse
    // nested below the keyed wrapper without touching the live pointer pipeline).
    if (_invokeOnTapInSubtree(element)) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{
          'tapped': true,
          'key': keyValue,
          'mode': 'descendant-callback',
        }),
      );
    }

    // Fallback: dispatch synthetic PointerAdded/Down/Up/Removed at the
    // RenderBox centre (handles Listener, MouseRegion, Switch, etc.).
    final at = _dispatchSyntheticTap(element);
    if (at != null) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{
          'tapped': true,
          'key': keyValue,
          'x': at.dx,
          'y': at.dy,
        }),
      );
    }

    // Last resort: ancestor callback walk.
    if (_invokeOnTapAncestor(element)) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{
          'tapped': true,
          'key': keyValue,
          'mode': 'ancestor-callback',
        }),
      );
    }

    return developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{
        'tapped': false,
        'error':
            'widget with key "$keyValue" found but has no callback and no RenderBox',
      }),
    );
  });

  // Per-engine screenshot via RepaintBoundary → PNG → base64.
  // pixelRatio=1.0 keeps payloads small; this is diagnostic-only.
  developer.registerExtension('ext.zee.shot', (method, params) async {
    try {
      final ctx = shotKey.currentContext;
      if (ctx == null) {
        return developer.ServiceExtensionResponse.result(
          jsonEncode(<String, Object?>{'surface': surface, 'error': 'no ctx'}),
        );
      }
      final boundary = ctx.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{
          'surface': surface,
          'w': image.width,
          'h': image.height,
          'png_b64': base64Encode(bd!.buffer.asUint8List()),
        }),
      );
    } catch (e) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{'surface': surface, 'error': '$e'}),
      );
    }
  });

  // ext.zee.minimap — drive the native MinimapView (Block 0009).
  // Registered only when a MinimapHost is provided (DHU surface on Android).
  // Params: on=true|false (enable/disable), x/y/w/h for bounds, key/value for params.
  if (minimapHost != null) {
    developer.registerExtension('ext.zee.minimap', (method, params) async {
      try {
        final onParam = params['on'];
        String? nativeResult;
        if (onParam != null) {
          nativeResult = await minimapHost.enable(onParam == 'true');
          onMinimapNativeResult?.call(nativeResult);
        }
        final x = double.tryParse(params['x'] ?? '');
        final y = double.tryParse(params['y'] ?? '');
        final w = double.tryParse(params['w'] ?? '');
        final h = double.tryParse(params['h'] ?? '');
        if (x != null && y != null && w != null && h != null) {
          await minimapHost.setBounds(Rect.fromLTWH(x, y, w, h));
        }
        final pKey = params['key'];
        final pVal = params['value'];
        if (pKey != null && pVal != null) {
          await minimapHost.setParams({pKey: double.tryParse(pVal) ?? pVal});
        }
        return developer.ServiceExtensionResponse.result(
          jsonEncode(<String, Object?>{
            'surface': surface,
            'minimap': 'ok',
            'on': onParam,
            // `?` drops the entry when the native gate returned nothing
            // (e.g. the fake host off-car), matching the previous if-null form.
            'result': ?nativeResult,
          }),
        );
      } catch (e) {
        return _extError('ext.zee.minimap error: $e');
      }
    });
  }

  // ext.zee.install — trigger an install and observe progress.
  // Params (one of two forms):
  //   target=launcher|ynavi  → uses the kLauncherAsset / kYnaviAsset constants.
  //   repo=<owner/name> tag=<tag> asset=<filename>  → arbitrary GithubAsset.
  // Response: the last install progress event (phase + fraction).
  // On T1 FakeInstaller drives the sequence; on T2 NativeInstaller downloads real APKs.
  if (installer != null) {
    // _installStateHolder is a module-level map keyed by surface string.
    // The install listener updates the inner map in-place so the readViewModel
    // closure (registered above) sees live progress via the same reference.
    _installStateHolder[surface] = <String, Object?>{};

    developer.registerExtension('ext.zee.install', (method, params) async {
      GithubAsset? asset;

      final target = params['target'];
      if (target == 'launcher') {
        asset = kLauncherAsset;
      } else if (target == 'ynavi') {
        asset = kYnaviAsset;
      } else {
        // Arbitrary asset: repo/branch/path params (T2 real-download testing).
        final repo = params['repo'];
        final branch = params['branch'];
        final path = params['path'];
        if (repo != null && branch != null && path != null) {
          asset = GithubAsset(repo: repo, branch: branch, path: path);
        }
      }

      if (asset == null) {
        return _extError(
          'ext.zee.install: provide target=launcher|ynavi '
          'OR repo=<r> branch=<b> path=<p>',
        );
      }

      final targetLabel =
          target ?? '${params['repo']}/${params['branch']}/${params['path']}';

      // Reset and update the holder's map in-place (not reassignment) so the
      // readViewModel closure always reads through the same reference.
      final state = _installStateHolder[surface]!;
      state
        ..clear()
        ..addAll(<String, Object?>{'target': targetLabel, 'started': true});

      // Subscribe to the install stream; update state on each event.
      installer
          .install(asset)
          .listen(
            (InstallProgress p) {
              state
                ..clear()
                ..addAll(<String, Object?>{
                  'target': targetLabel,
                  'phase': p.phase.name,
                  'fraction': p.fraction,
                  if (p.message != null) 'message': p.message,
                });
            },
            onError: (Object err) {
              state
                ..clear()
                ..addAll(<String, Object?>{
                  'target': targetLabel,
                  'phase': 'failed',
                  'fraction': 0.0,
                  'message': err.toString(),
                });
            },
          );

      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{
          'surface': surface,
          'install': Map<String, Object?>.from(state),
        }),
      );
    });
  }

  // ext.zee.bootState — Feedback Loop reads FGS/boot status (Block 0010).
  // Registered on every surface; on DHU Android a [getBootState] callback
  // queries the native ZeeForegroundService state.  On other surfaces (T1,
  // HUD isolate) the response is best-effort from the config store alone.
  developer.registerExtension('ext.zee.bootState', (method, params) async {
    final Map<String, Object?> native = getBootState != null
        ? await getBootState()
        : <String, Object?>{};
    return developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{
        'surface': surface,
        'hudEnabled': store.value.hudEnabled,
        'configReadOk':
            true, // store is loaded by the time extensions are registered
        ...native,
      }),
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers — shared by whoami/dumpState/tapByKey.
// ---------------------------------------------------------------------------

String _dumpStateJson(String surface, ConfigStore store) =>
    jsonEncode(<String, Object?>{
      'surface': surface,
      'hudEnabled': store.value.hudEnabled,
      'locale': store.value.locale,
      'safeArea': store.value.safeArea.toJson(),
      'blinker': store.value.blinker.toJson(),
      'battery': store.value.battery.toJson(),
      'minimap': store.value.minimap.toJson(),
      'autoUsbPeripheral': store.value.autoUsbPeripheral,
    });

developer.ServiceExtensionResponse _extError(String message) =>
    developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      message,
    );

// ---------------------------------------------------------------------------
// Install progress holder — module-level mutable map keyed by surface.
//
// Each surface that registers ext.zee.install gets a child Map stored here.
// The install listener updates the child map in-place (clear+addAll) so that
// readViewModel reads through the same reference and sees live progress without
// needing to re-register the extension closure.
// ---------------------------------------------------------------------------

/// Live install state per surface ('dhu', 'hud').
/// Set to an empty map on first ext.zee.install registration for that surface;
/// updated in-place by the install stream listener.
final Map<String, Map<String, Object?>> _installStateHolder = {};

// ---------------------------------------------------------------------------
// Widget-tree walking utilities (ported from nothingness AgentService).
// ---------------------------------------------------------------------------

/// Depth-first pre-order walk of [root]'s subtree; stops when [visit] returns
/// true. Offers root itself first when [includeSelf] is set.
bool _walkSubtree(
  Element root,
  bool Function(Element) visit, {
  bool includeSelf = false,
}) {
  var matched = false;
  void recurse(Element el, bool offerSelf) {
    if (matched) return;
    if (offerSelf && visit(el)) {
      matched = true;
      return;
    }
    el.visitChildren((child) => recurse(child, true));
  }

  recurse(root, includeSelf);
  return matched;
}

/// Find the first [Element] whose widget has a [ValueKey<String>] equal to [key].
Element? _findElementByKey(String key) {
  final targetKey = ValueKey<String>(key);
  Element? found;
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return null;
  _walkSubtree(root, (el) {
    if (el.widget.key == targetKey) {
      found = el;
      return true;
    }
    return false;
  }, includeSelf: true);
  return found;
}

/// Return the `onTap` callback of [el]'s widget if it is a GestureDetector or
/// InkResponse, else null.
VoidCallback? _onTapOf(Element el) {
  final w = el.widget;
  if (w is GestureDetector) return w.onTap;
  if (w is InkResponse) return w.onTap;
  return null;
}

/// Invoke the first `onTap` found in [root] itself or its subtree; returns true if one fired.
/// includeSelf=true ensures keyed GestureDetectors (the matched element IS the detector)
/// are invoked directly without needing an inner descendant.
bool _invokeOnTapInSubtree(Element root) => _walkSubtree(root, (el) {
  final onTap = _onTapOf(el);
  if (onTap != null) {
    onTap();
    return true;
  }
  return false;
}, includeSelf: true);

/// Invoke the first `onTap` on [element] itself, then its ancestors, then its
/// subtree; returns true if one fired.
bool _invokeOnTapAncestor(Element element) {
  final self = _onTapOf(element);
  if (self != null) {
    self();
    return true;
  }
  var fired = false;
  element.visitAncestorElements((ancestor) {
    final onTap = _onTapOf(ancestor);
    if (onTap != null) {
      onTap();
      fired = true;
      return false;
    }
    return true;
  });
  if (!fired) fired = _invokeOnTapInSubtree(element);
  return fired;
}

/// Monotonically-increasing sequence to avoid gesture-arena collisions between
/// consecutive synthetic taps.
int _syntheticPointerSeq = 0;

/// Dispatch synthetic PointerAdded → Down → Up → Removed at [element]'s
/// RenderBox centre; returns the global centre offset, or null when there is no
/// usable box. The full Added/Removed envelope is required — Down/Up alone is
/// unreliable on the live gesture binding.
Offset? _dispatchSyntheticTap(Element element) {
  final ro = element.findRenderObject();
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
  final size = ro.size;
  if (size.isEmpty) return null;
  final center = ro.localToGlobal(size.center(Offset.zero));

  _syntheticPointerSeq++;
  // High bit keeps synthetic pointers separate from real device pointer ids.
  final pointer = 0x70000 | (_syntheticPointerSeq & 0xFFFF);
  final t0 = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
  final t1 = t0 + const Duration(milliseconds: 16);

  GestureBinding.instance
    ..handlePointerEvent(
      PointerAddedEvent(pointer: pointer, position: center, timeStamp: t0),
    )
    ..handlePointerEvent(
      PointerDownEvent(pointer: pointer, position: center, timeStamp: t0),
    )
    ..handlePointerEvent(
      PointerUpEvent(pointer: pointer, position: center, timeStamp: t1),
    )
    ..handlePointerEvent(
      PointerRemovedEvent(pointer: pointer, position: center, timeStamp: t1),
    );

  return center;
}
