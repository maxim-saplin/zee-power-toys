import 'dart:async';

import '../car_signals.dart';

/// T1 in-process fake for [CarSignals].
/// Emit helpers are called by ext.zee.inject and by tests.
/// No always-on timers — emits only on demand (ADR 0003).
class FakeCarSignals implements CarSignals {
  FakeCarSignals() : _ctrl = StreamController<CarSignalEvent>.broadcast();

  final StreamController<CarSignalEvent> _ctrl;
  CarSnapshot _snapshot = const CarSnapshot();

  @override
  Stream<CarSignalEvent> get events => _ctrl.stream;

  @override
  CarSnapshot get snapshot => _snapshot;

  /// Always 'fake' — this is the T1/off-car pure-Dart fake; there is no
  /// native source to auto-select behind it.
  @override
  Future<String> get sourceKind async => 'fake';

  /// Block 0026 Developer Simulate screen: identical mechanics to [relay] —
  /// update the snapshot and push the event — since on T1 "simulate" and
  /// "the live signal chain" are the same fake stream.
  @override
  Future<void> simulate(CarSignalEvent event) async => relay(event);

  // ---------------------------------------------------------------------------
  // Emit helpers — one per signal kind.
  // ---------------------------------------------------------------------------

  void emitSpeed(int kmh) {
    _snapshot = _snapshot.copyWith(speedKmh: kmh);
    _ctrl.add(SpeedEvent(kmh));
  }

  void emitBlinker(BlinkerState state) {
    _snapshot = _snapshot.copyWith(blinker: state);
    _ctrl.add(BlinkerEvent(state));
  }

  void emitCharge({
    required bool charging,
    double? volts,
    double? amps,
    double? kw,
  }) {
    _snapshot = _snapshot.copyWith(charging: charging, chargeKw: kw);
    _ctrl.add(
      ChargeEvent(charging: charging, volts: volts, amps: amps, kw: kw),
    );
  }

  void emitBattery({required int levelPct, required double tempC}) {
    _snapshot = _snapshot.copyWith(batteryPct: levelPct, batteryTempC: tempC);
    _ctrl.add(BatteryEvent(levelPct: levelPct, tempC: tempC));
  }

  void emitPowerFlow(PowerFlow flow) {
    _snapshot = _snapshot.copyWith(powerFlow: flow);
    _ctrl.add(PowerFlowEvent(flow));
  }

  /// Re-emit a [CarSignalEvent] that arrived from the relay (HUD-side use).
  void relay(CarSignalEvent event) {
    switch (event) {
      case SpeedEvent(:final kmh):
        _snapshot = _snapshot.copyWith(speedKmh: kmh);
      case BlinkerEvent(:final state):
        _snapshot = _snapshot.copyWith(blinker: state);
      case ChargeEvent(:final charging, :final kw):
        _snapshot = _snapshot.copyWith(charging: charging, chargeKw: kw);
      case BatteryEvent(:final levelPct, :final tempC):
        _snapshot = _snapshot.copyWith(
          batteryPct: levelPct,
          batteryTempC: tempC,
        );
      case PowerFlowEvent(:final flow):
        _snapshot = _snapshot.copyWith(powerFlow: flow);
    }
    _ctrl.add(event);
  }

  void dispose() => _ctrl.close();
}
