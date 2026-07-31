/// Car-facing signal port. The Dart brain subscribes to [events] and reads
/// [snapshot] for the current latest-of-each value. On T1 a [FakeCarSignals]
/// is injected; on the car a native AdaptAPI adapter replaces it.
/// Pure-Dart port — no AdaptAPI references here (ADR 0003).
abstract class CarSignals {
  Stream<CarSignalEvent> get events;
  CarSnapshot get snapshot;

  /// Emit a synthetic [CarSignalEvent] through the real, unforced signal
  /// chain (Block 0026 — Developer Simulate screen). This is distinct from
  /// the Config Preview's demo override (`hud_preview.dart`): that scopes a
  /// fixed value to one widget subtree, while this actually drives
  /// [events]/[snapshot] end-to-end, the same as an injected car signal
  /// would. On a real car with AdaptAPI selected as the live source, this is
  /// a safe no-op (mirrors the existing ADB-broadcast simulate path).
  Future<void> simulate(CarSignalEvent event);
}

// ---------------------------------------------------------------------------
// Sealed event hierarchy (Dart 3 exhaustive switch-friendly).
// ---------------------------------------------------------------------------

sealed class CarSignalEvent {
  const CarSignalEvent();
}

class SpeedEvent extends CarSignalEvent {
  const SpeedEvent(this.kmh);
  final int kmh;
}

class BlinkerEvent extends CarSignalEvent {
  const BlinkerEvent(this.state);
  final BlinkerState state;
}

class ChargeEvent extends CarSignalEvent {
  const ChargeEvent({
    required this.charging,
    this.volts,
    this.amps,
    this.kw,
  });
  final bool charging;
  final double? volts;
  final double? amps;
  final double? kw;
}

class BatteryEvent extends CarSignalEvent {
  const BatteryEvent({required this.levelPct, required this.tempC});
  final int levelPct;
  final double tempC;
}

class PowerFlowEvent extends CarSignalEvent {
  const PowerFlowEvent(this.flow);
  final PowerFlow flow;
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum BlinkerState { off, left, right, hazard }

/// Drive/regen/standstill power-flow state.
/// Hazard = left && right (the dedicated hazard ID is dead on firmware).
enum PowerFlow { unknown, drive, regen, standstill }

// ---------------------------------------------------------------------------
// Snapshot — immutable latest-of-each across signal kinds.
// ---------------------------------------------------------------------------

class CarSnapshot {
  const CarSnapshot({
    this.speedKmh,
    this.blinker = BlinkerState.off,
    this.charging,
    this.chargeKw,
    this.batteryPct,
    this.batteryTempC,
    this.powerFlow = PowerFlow.unknown,
  });

  final int? speedKmh;
  final BlinkerState blinker;
  final bool? charging;
  final double? chargeKw;
  final int? batteryPct;
  final double? batteryTempC;
  final PowerFlow powerFlow;

  CarSnapshot copyWith({
    int? speedKmh,
    BlinkerState? blinker,
    bool? charging,
    double? chargeKw,
    int? batteryPct,
    double? batteryTempC,
    PowerFlow? powerFlow,
  }) =>
      CarSnapshot(
        speedKmh: speedKmh ?? this.speedKmh,
        blinker: blinker ?? this.blinker,
        charging: charging ?? this.charging,
        chargeKw: chargeKw ?? this.chargeKw,
        batteryPct: batteryPct ?? this.batteryPct,
        batteryTempC: batteryTempC ?? this.batteryTempC,
        powerFlow: powerFlow ?? this.powerFlow,
      );

  /// Serialise to JSON for the relay and the Feedback Loop readViewModel.
  Map<String, Object?> toJson() => <String, Object?>{
        'speedKmh': speedKmh,
        'blinker': blinker.name,
        'charging': charging,
        'chargeKw': chargeKw,
        'batteryPct': batteryPct,
        'batteryTempC': batteryTempC,
        'powerFlow': powerFlow.name,
      };
}
