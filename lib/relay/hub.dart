import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../services/car_signals.dart';
import '../services/config_store.dart';

/// The desktop "Hub": a native-mediated cross-engine channel.
/// Routing is done inside the native ChannelRegistry — not via shared Dart heap.
/// Unidirectional: DHU invokes, HUD handles.
///
/// Envelope format: `{"kind": "config" | "carSignal", "payload": <json-string>}`
/// ADR 0003: only serialized events cross — never a shared Dart object.
const String kHubChannel = 'zee/hub';
const WindowMethodChannel _hub =
    WindowMethodChannel(kHubChannel, mode: ChannelMode.unidirectional);

// ---------------------------------------------------------------------------
// DHU → HUD push helpers
// ---------------------------------------------------------------------------

/// Push a changed [AppConfig] to the HUD isolate.
Future<void> pushConfigToHud(AppConfig c) async {
  await _push('config', jsonEncode(c.toJson()));
}

/// Push a [CarSignalEvent] to the HUD isolate.
Future<void> pushCarSignalToHud(CarSignalEvent event) async {
  await _push('carSignal', jsonEncode(_carSignalToJson(event)));
}

Future<void> _push(String kind, String payload) async {
  try {
    await _hub.invokeMethod('relay', jsonEncode(<String, Object?>{
      'kind': kind,
      'payload': payload,
    }));
  } catch (e) {
    // HUD window may not be ready yet; log but don't crash.
    debugPrint('zee/hub push($kind) failed: $e');
  }
}

// ---------------------------------------------------------------------------
// HUD side: dispatch incoming relay envelopes
// ---------------------------------------------------------------------------

/// Register a handler for all relay envelopes arriving on the HUD isolate.
/// [onConfig] and [onCarSignal] are called for their respective kinds.
void listenForRelay({
  void Function(AppConfig)? onConfig,
  void Function(CarSignalEvent)? onCarSignal,
}) {
  _hub.setMethodCallHandler((call) async {
    if (call.method == 'relay') {
      try {
        final envelope =
            jsonDecode(call.arguments as String) as Map<String, Object?>;
        final kind = envelope['kind'] as String?;
        final payload = envelope['payload'] as String?;
        if (kind == null || payload == null) return null;

        switch (kind) {
          case 'config':
            if (onConfig != null) {
              onConfig(AppConfig.fromJson(
                jsonDecode(payload) as Map<String, Object?>,
              ));
            }
          case 'carSignal':
            if (onCarSignal != null) {
              final event = _carSignalFromJson(
                jsonDecode(payload) as Map<String, Object?>,
              );
              if (event != null) onCarSignal(event);
            }
        }
      } catch (_) {
        // Ignore malformed relay messages.
      }
    }
    return null;
  });
}

/// Backward-compat alias — config-only relay (used by hudMain before this block).
void listenForConfig(void Function(AppConfig) onConfig) {
  listenForRelay(onConfig: onConfig);
}

// ---------------------------------------------------------------------------
// CarSignalEvent ↔ JSON (discriminated by "type" field)
// ---------------------------------------------------------------------------

Map<String, Object?> _carSignalToJson(CarSignalEvent event) {
  return switch (event) {
    SpeedEvent(:final kmh) => {'type': 'speed', 'kmh': kmh},
    BlinkerEvent(:final state) => {'type': 'blinker', 'state': state.name},
    ChargeEvent(:final charging, :final volts, :final amps, :final kw) =>
      <String, Object?>{
        'type': 'charge',
        'charging': charging,
        'volts': volts,
        'amps': amps,
        'kw': kw,
      },
    BatteryEvent(:final levelPct, :final tempC) => {
        'type': 'battery',
        'levelPct': levelPct,
        'tempC': tempC,
      },
    PowerFlowEvent(:final flow) => {'type': 'powerFlow', 'flow': flow.name},
  };
}

CarSignalEvent? _carSignalFromJson(Map<String, Object?> j) {
  final type = j['type'] as String?;
  return switch (type) {
    'speed' => SpeedEvent(j['kmh'] as int),
    'blinker' => BlinkerEvent(
        BlinkerState.values.byName(j['state'] as String),
      ),
    'charge' => ChargeEvent(
        charging: j['charging'] as bool,
        volts: (j['volts'] as num?)?.toDouble(),
        amps: (j['amps'] as num?)?.toDouble(),
        kw: (j['kw'] as num?)?.toDouble(),
      ),
    'battery' => BatteryEvent(
        levelPct: j['levelPct'] as int,
        tempC: (j['tempC'] as num).toDouble(),
      ),
    'powerFlow' => PowerFlowEvent(
        PowerFlow.values.byName(j['flow'] as String),
      ),
    _ => null,
  };
}
