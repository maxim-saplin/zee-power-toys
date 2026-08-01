import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../car_signals.dart';

/// Native CarSignals adapter for Android.
///
/// On Android the DHU engine hosts the native CarSignalsController (Kotlin).
/// This Dart adapter:
///   1. Opens the EventChannel "zee/car_signals/events" to receive streamed events.
///   2. Calls start() on MethodChannel "zee/car_signals" to begin emission.
///   3. Translates incoming maps → [CarSignalEvent] + updates [CarSnapshot].
///
/// The HUD isolate does NOT use this adapter; it receives relayed events from
/// the DHU via the existing hub relay (hub.dart pushCarSignalToHud).
///
/// Bridge: EventChannel + MethodChannel (not Pigeon — see RECONCILIATION in
/// the block-0005 report: Pigeon's FlutterApi streaming path fights the
/// *.g.dart gitignore rule; EventChannel delivers the identical semantic
/// contract with zero codegen).
class NativeCarSignals implements CarSignals {
  static const _methodCh = MethodChannel('zee/car_signals');
  static const _eventCh = EventChannel('zee/car_signals/events');

  final StreamController<CarSignalEvent> _ctrl =
      StreamController<CarSignalEvent>.broadcast();

  CarSnapshot _snapshot = const CarSnapshot();
  StreamSubscription<dynamic>? _sub;

  // Resolved once the native "start" round-trip returns the (source-annotated)
  // initial snapshot — see CarSignalsController.kt's selectSource()/sourceKind.
  // 'unknown' if the channel call fails; never left incomplete so callers can
  // always await [sourceKind] without hanging.
  final Completer<String> _sourceKindCompleter = Completer<String>();

  NativeCarSignals() {
    _sub = _eventCh.receiveBroadcastStream().listen(
      onNativeEvent,
      onError: (Object err) =>
          // Log but don't kill the stream — native side may emit again after
          // a transient error (e.g. during engine lifecycle transitions).
          debugPrintNativeEvent('NativeCarSignals: native event error: $err'),
    );
    // Tell the native side to start emitting.  The response is the initial
    // CarSignalSnapshot (incl. `source`) so we learn which source was
    // auto-selected from this same round-trip — no extra call needed.
    _methodCh
        .invokeMapMethod<String, Object?>('start')
        .then((raw) {
          final source = raw?['source'] as String?;
          if (!_sourceKindCompleter.isCompleted) {
            _sourceKindCompleter.complete(source ?? 'unknown');
          }
        })
        .catchError((Object e) {
          debugPrintNativeEvent('NativeCarSignals: start() failed: $e');
          if (!_sourceKindCompleter.isCompleted) {
            _sourceKindCompleter.complete('unknown');
          }
        });
  }

  @override
  Stream<CarSignalEvent> get events => _ctrl.stream;

  @override
  CarSnapshot get snapshot => _snapshot;

  @override
  Future<String> get sourceKind => _sourceKindCompleter.future;

  /// Block 0026 Developer Simulate screen: encodes [event] into the kind/value
  /// string pair `SimulatorState.apply` (Kotlin) parses — the same format the
  /// ADB `SIMULATE` broadcast extras use — and invokes the native "simulate"
  /// method (`CarSignalsController.onMethodCall`), which forwards through the
  /// real `SimulatedCarSignals`/EventChannel path. Safe no-op on a real car
  /// with AdaptAPI selected (native `simSource` stays null).
  @override
  Future<void> simulate(CarSignalEvent event) {
    final (String kind, String value) = switch (event) {
      SpeedEvent(:final kmh) => ('speed', '$kmh'),
      BlinkerEvent(:final state) => ('blinker', state.name),
      ChargeEvent(:final charging, :final volts, :final amps, :final kw) => (
        'charge',
        charging
            ? '$charging:${volts ?? ''}:${amps ?? ''}:${kw ?? ''}'
            : '$charging',
      ),
      BatteryEvent(:final levelPct, :final tempC) => (
        'battery',
        '$levelPct:$tempC',
      ),
      PowerFlowEvent(:final flow) => ('powerFlow', flow.name),
    };
    return _methodCh.invokeMethod<void>('simulate', <String, String>{
      'kind': kind,
      'value': value,
    });
  }

  // ---------------------------------------------------------------------------
  // Decode the discriminated map from Kotlin → typed CarSignalEvent.
  // Internal but @visibleForTesting so unit tests can call directly.
  // ---------------------------------------------------------------------------

  @visibleForTesting
  void onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final m = Map<String, Object?>.from(raw);
    final type = m['type'] as String?;
    try {
      switch (type) {
        case 'speed':
          final kmh = _asInt(m['kmh']) ?? 0;
          _snapshot = _snapshot.copyWith(speedKmh: kmh);
          _ctrl.add(SpeedEvent(kmh));

        case 'blinker':
          final state = BlinkerState.values.byName(
            (m['state'] as String?) ?? 'off',
          );
          _snapshot = _snapshot.copyWith(blinker: state);
          _ctrl.add(BlinkerEvent(state));

        case 'charge':
          final charging = m['charging'] as bool? ?? false;
          final volts = _asDouble(m['volts']);
          final amps = _asDouble(m['amps']);
          final kw = _asDouble(m['kw']);
          _snapshot = _snapshot.copyWith(charging: charging, chargeKw: kw);
          _ctrl.add(
            ChargeEvent(charging: charging, volts: volts, amps: amps, kw: kw),
          );

        case 'battery':
          final pct = _asInt(m['levelPct']) ?? 0;
          final tempC = _asDouble(m['tempC']) ?? 0.0;
          _snapshot = _snapshot.copyWith(batteryPct: pct, batteryTempC: tempC);
          _ctrl.add(BatteryEvent(levelPct: pct, tempC: tempC));

        case 'powerFlow':
          final flow = PowerFlow.values.byName(
            (m['flow'] as String?) ?? 'unknown',
          );
          _snapshot = _snapshot.copyWith(powerFlow: flow);
          _ctrl.add(PowerFlowEvent(flow));
      }
    } catch (e) {
      debugPrintNativeEvent('NativeCarSignals: decode error type=$type: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static int? _asInt(Object? v) =>
      v == null ? null : (v is int ? v : (v as num).toInt());

  static double? _asDouble(Object? v) =>
      v == null ? null : (v is double ? v : (v as num).toDouble());

  void dispose() {
    _sub?.cancel();
    _ctrl.close();
  }
}

// Debug log helper — uses debugPrint (overridable, throttled) per project
// convention; avoids raw print() firing in release builds.
void debugPrintNativeEvent(String msg) {
  debugPrint(msg);
}
