import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show pid;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show InkResponse;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../services/car_signals.dart';
import '../services/config_store.dart';
import '../services/fakes/fake_car_signals.dart';

/// Register ext.zee.* VM-service extensions for [surface] (either 'dhu' or 'hud').
///
/// Both isolates register the same set so the Feedback Loop can drive and read
/// each surface independently. [shotKey] must wrap the root RepaintBoundary.
/// [carSignals] is the CarSignals instance for this isolate — may be a
/// [FakeCarSignals] (T1/HUD) or a NativeCarSignals (T2 DHU). On T2 DHU the
/// ext.zee.inject extension is disabled (native injection uses ADB broadcasts).
/// [onSetConfig] is optional (DHU can pass null; the store.changes subscription
/// already relays to HUD).
void registerZeeExtensions({
  required String surface,
  required ConfigStore store,
  required GlobalKey shotKey,
  CarSignals? carSignals,
  Future<void> Function(AppConfig)? onSetConfig,
}) {
  developer.registerExtension('ext.zee.whoami', (method, params) async {
    return developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{
        'surface': surface,
        'isolate': identityHashCode(store),
        'pid': pid,
        'hudBoxOn': store.value.hudBoxOn,
      }),
    );
  });

  developer.registerExtension('ext.zee.dumpState', (method, params) async {
    return developer.ServiceExtensionResponse.result(
      _dumpStateJson(surface, store),
    );
  });

  // readViewModel returns the full derived view-model (ADR 0004).
  developer.registerExtension('ext.zee.readViewModel', (method, params) async {
    final snap = carSignals?.snapshot;
    return developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{
        'surface': surface,
        'hudBoxOn': store.value.hudBoxOn,
        'speedKmh': snap?.speedKmh,
        'blinker': snap?.blinker.name ?? BlinkerState.off.name,
        'charging': snap?.charging,
        'kw': snap?.chargeKw,
        'batteryPct': snap?.batteryPct,
        'batteryTempC': snap?.batteryTempC,
        'powerFlow': snap?.powerFlow.name ?? PowerFlow.unknown.name,
      }),
    );
  });

  developer.registerExtension('ext.zee.setConfig', (method, params) async {
    final raw = params['hudBoxOn'];
    final parsed = raw == 'true';
    final next = store.value.copyWith(hudBoxOn: parsed);
    await store.setConfig(next);
    if (onSetConfig != null) await onSetConfig(next);
    return developer.ServiceExtensionResponse.result(
      _dumpStateJson(surface, store),
    );
  });

  // inject — push a fake CarSignalEvent into THIS isolate's FakeCarSignals.
  // On DHU the store.changes.listen in main.dart relays the event to HUD via hub.
  // On T2 DHU (Android NativeCarSignals) injection must use ADB broadcasts instead.
  // Params: kind=speed|blinker|charge|battery  + kind-specific values.
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
  });

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
}

// ---------------------------------------------------------------------------
// Helpers — shared by whoami/dumpState/tapByKey.
// ---------------------------------------------------------------------------

String _dumpStateJson(String surface, ConfigStore store) =>
    jsonEncode(<String, Object?>{
      'surface': surface,
      'hudBoxOn': store.value.hudBoxOn,
    });

developer.ServiceExtensionResponse _extError(String message) =>
    developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      message,
    );

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

/// Invoke the first `onTap` found in [root]'s subtree; returns true if one fired.
bool _invokeOnTapInSubtree(Element root) => _walkSubtree(root, (el) {
      final onTap = _onTapOf(el);
      if (onTap != null) {
        onTap();
        return true;
      }
      return false;
    });

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
