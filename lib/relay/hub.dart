import 'dart:convert';
import 'dart:io' show Platform;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/car_signals.dart';
import '../services/config_store.dart';
import '../services/minimap_host.dart';
import '../services/speedcam.dart';

/// The cross-engine relay abstraction.
///
/// ADR 0003: only serialized events cross the isolate boundary.
/// Each tier supplies a concrete transport:
///   - DesktopRelay: desktop_multi_window WindowMethodChannel (T1)
///   - AndroidRelay: plain MethodChannel over the native bridge (T2)
/// Selection is automatic at construction time.

// ---------------------------------------------------------------------------
// Relay abstraction
// ---------------------------------------------------------------------------

/// Abstract relay: one-directional DHU→HUD transport.
/// [push] is called on the DHU side; [listen] is called on the HUD side.
abstract class Relay {
  /// Send a typed envelope to the HUD isolate.
  Future<void> push(String kind, String payload);

  /// Register a handler for incoming envelopes (HUD side only).
  void listen(void Function(String kind, String payload) onMessage);
}

// ---------------------------------------------------------------------------
// DesktopRelay — wraps desktop_multi_window WindowMethodChannel (T1)
// ---------------------------------------------------------------------------

class DesktopRelay implements Relay {
  // ChannelMode.unidirectional routes DHU→HUD through the native ChannelRegistry.
  static const WindowMethodChannel _ch =
      WindowMethodChannel(kHubChannel, mode: ChannelMode.unidirectional);

  @override
  Future<void> push(String kind, String payload) async {
    await _ch.invokeMethod('relay', jsonEncode(<String, Object?>{
      'kind': kind,
      'payload': payload,
    }));
  }

  @override
  void listen(void Function(String kind, String payload) onMessage) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'relay') {
        _dispatch(call.arguments as String, onMessage);
      }
      return null;
    });
  }
}

// ---------------------------------------------------------------------------
// AndroidRelay — wraps a plain MethodChannel over the Kotlin native bridge (T2)
// ---------------------------------------------------------------------------

class AndroidRelay implements Relay {
  static const MethodChannel _ch = MethodChannel(kHubChannel);

  @override
  Future<void> push(String kind, String payload) async {
    await _ch.invokeMethod<void>(
      'relay',
      jsonEncode(<String, Object?>{'kind': kind, 'payload': payload}),
    );
  }

  @override
  void listen(void Function(String kind, String payload) onMessage) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'relay') {
        _dispatch(call.arguments as String, onMessage);
      }
      return null;
    });
  }
}

// ---------------------------------------------------------------------------
// Singleton relay — chosen once at startup based on the current platform.
// DesktopRelay is selected for all non-Android platforms; AndroidRelay for
// Android. Using !kIsWeb guard keeps this tree-shaking-safe.
// ---------------------------------------------------------------------------

final Relay _relay = (!kIsWeb && Platform.isAndroid) ? AndroidRelay() : DesktopRelay();

// ---------------------------------------------------------------------------
// Public API (stable across tiers)
// ---------------------------------------------------------------------------

const String kHubChannel = 'zee/hub';

/// Push a changed [AppConfig] to the HUD isolate.
Future<void> pushConfigToHud(AppConfig c) async {
  await _push('config', jsonEncode(c.toJson()));
}

/// Push a [CarSignalEvent] to the HUD isolate.
Future<void> pushCarSignalToHud(CarSignalEvent event) async {
  await _push('carSignal', jsonEncode(_carSignalToJson(event)));
}

/// Push a [SpeedcamSnapshot] to the HUD isolate (0033 live CRT).
Future<void> pushSpeedcamToHud(SpeedcamSnapshot snapshot) async {
  await _push('speedcam', jsonEncode(snapshot.toRelayJson()));
}

/// Push a [GuidanceEvent] to the HUD isolate (0055 FAIL: overlay lives on HUD).
Future<void> pushGuidanceToHud(GuidanceEvent event) async {
  await _push('guidance', jsonEncode(event.toJson()));
}

Future<void> _push(String kind, String payload) async {
  try {
    await _relay.push(kind, payload);
  } catch (e) {
    // HUD surface may not be ready yet; log but don't crash.
    debugPrint('zee/hub push($kind) failed: $e');
  }
}

/// Register a handler for all relay envelopes arriving on the HUD isolate.
/// [onConfig] and [onCarSignal] are called for their respective kinds.
void listenForRelay({
  void Function(AppConfig)? onConfig,
  void Function(CarSignalEvent)? onCarSignal,
  void Function(SpeedcamSnapshot)? onSpeedcam,
  void Function(GuidanceEvent)? onGuidance,
}) {
  _relay.listen((kind, payload) {
    try {
      switch (kind) {
        case 'config':
          if (onConfig != null) {
            onConfig(AppConfig.fromJson(
              Map<String, Object?>.from(jsonDecode(payload) as Map),
            ));
          }
        case 'carSignal':
          if (onCarSignal != null) {
            final event = _carSignalFromJson(
              jsonDecode(payload) as Map<String, Object?>,
            );
            if (event != null) onCarSignal(event);
          }
        case 'speedcam':
          if (onSpeedcam != null) {
            onSpeedcam(SpeedcamSnapshot.fromJson(
              Map<String, Object?>.from(jsonDecode(payload) as Map),
            ));
          }
        case 'guidance':
          if (onGuidance != null) {
            onGuidance(GuidanceEvent.fromJson(
              Map<String, Object?>.from(jsonDecode(payload) as Map),
            ));
          }
      }
    } catch (_) {
      // Ignore malformed relay messages.
    }
  });
}

/// Backward-compat alias — config-only relay.
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

// ---------------------------------------------------------------------------
// Internal helper: decode and dispatch a relay envelope string.
// ---------------------------------------------------------------------------

void _dispatch(
  String raw,
  void Function(String kind, String payload) onMessage,
) {
  try {
    final envelope = jsonDecode(raw) as Map<String, Object?>;
    final kind = envelope['kind'] as String?;
    final payload = envelope['payload'] as String?;
    if (kind != null && payload != null) onMessage(kind, payload);
  } catch (_) {
    // Ignore malformed envelopes.
  }
}
