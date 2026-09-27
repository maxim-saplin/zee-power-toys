/// Car-facing signal port. The Dart brain subscribes to [events] and reads
/// [snapshot] for the current latest-of-each value. On T1 a [FakeCarSignals]
/// is injected; on the car a native AdaptAPI adapter replaces it.
/// Pure-Dart port — no AdaptAPI references here (ADR 0003).
abstract class CarSignals {
  Stream<CarSignalEvent> get events;
  CarSnapshot get snapshot;

  /// Which car-signal source is actually live behind this port: 'adaptapi' |
  /// 'simulated' (T2/T3 native — mirrors the native CarSignalsController's own
  /// selectSource() decision, never re-derived here) or 'fake' (T1 desktop /
  /// HUD isolate's local pure-Dart fake). Resolves once, shortly after
  /// construction; the native decision does not change at runtime.
  ///
  /// This exists so the UI can tell the user whether they are looking at
  /// demo data, an injected simulation, or a real car — the specific
  /// "emulator vs. car" confusion this port used to leave unanswered.
  Future<String> get sourceKind;

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
  const ChargeEvent({required this.charging, this.volts, this.amps, this.kw});
  final bool charging;
  final double? volts;
  final double? amps;
  final double? kw;
}

class BatteryEvent extends CarSignalEvent {
  const BatteryEvent({required this.levelPct, required this.tempC});
  /// Float SoC % (0.1% resolution from Adapt) — 0118.
  final double levelPct;
  final double tempC;
}

class EfficiencyEvent extends CarSignalEvent {
  const EfficiencyEvent(this.kwhPer100km);
  /// Adapt Energy Cons 1 (`0x00103100`) kWh/100km — 0118.
  final double kwhPer100km;
}

class PowerFlowEvent extends CarSignalEvent {
  const PowerFlowEvent(this.flow);
  final PowerFlow flow;
}

class DriveModeEvent extends CarSignalEvent {
  const DriveModeEvent(this.mode);
  final DriveMode mode;
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum BlinkerState { off, left, right, hazard }

/// Drive/regen/standstill power-flow state.
/// Hazard = left && right (the dedicated hazard ID is dead on firmware).
enum PowerFlow { unknown, drive, regen, standstill }

/// Adapt drive mode `0x22010100` — HUD toast: eco/comfort/sport;
/// other known → [other] ("Mode"); sentinels → [unknown].
enum DriveMode { unknown, eco, comfort, sport, other }

// ---------------------------------------------------------------------------
// Snapshot — immutable latest-of-each across signal kinds.
// ---------------------------------------------------------------------------

class CarSnapshot {
  const CarSnapshot({
    this.speedKmh,
    this.blinker = BlinkerState.off,
    this.charging = false,
    this.chargeKw,
    this.batteryPct,
    this.batteryTempC,
    this.powerFlow = PowerFlow.unknown,
    this.driveMode = DriveMode.unknown,
    this.efficiencyKwhPer100km,
  });

  final int? speedKmh;
  final BlinkerState blinker;
  /// Always true/false — unknown/absent AdaptAPI state coalesces to false.
  final bool charging;
  final double? chargeKw;
  /// Float SoC % (0.1% ticks) — HUD may round for display; estimator uses float.
  final double? batteryPct;
  final double? batteryTempC;
  final PowerFlow powerFlow;

  /// Adapt drive mode (`0x22010100`) — see [DriveModeMapping].
  final DriveMode driveMode;

  /// Adapt Energy Cons 1 (`0x00103100`) when non-sentinel — 0118 Cons Est.
  /// Own Est. path stays own-window-only (no seed toward Cons).
  final double? efficiencyKwhPer100km;

  CarSnapshot copyWith({
    int? speedKmh,
    BlinkerState? blinker,
    bool? charging,
    double? chargeKw,
    double? batteryPct,
    double? batteryTempC,
    PowerFlow? powerFlow,
    DriveMode? driveMode,
    double? efficiencyKwhPer100km,
  }) => CarSnapshot(
    speedKmh: speedKmh ?? this.speedKmh,
    blinker: blinker ?? this.blinker,
    charging: charging ?? this.charging,
    chargeKw: chargeKw ?? this.chargeKw,
    batteryPct: batteryPct ?? this.batteryPct,
    batteryTempC: batteryTempC ?? this.batteryTempC,
    powerFlow: powerFlow ?? this.powerFlow,
    driveMode: driveMode ?? this.driveMode,
    efficiencyKwhPer100km:
        efficiencyKwhPer100km ?? this.efficiencyKwhPer100km,
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
    'driveMode': driveMode.name,
    'efficiencyKwhPer100km': efficiencyKwhPer100km,
  };
}


/// Events to re-push on hudReady / HUD recreate so the HUD isolate matches
/// [CarSignals.snapshot] (live ticks can be missed while the relay arms).
///
/// 0119: includes [EfficiencyEvent] when Cons1 is present — Kotlin
/// `publishEfficiency` skips duplicate Cons1 values, so without a reseed the
/// HUD Cons Est stays null → dashes.
List<CarSignalEvent> carSignalHudSeedEvents(CarSnapshot s) {
  final out = <CarSignalEvent>[
    ChargeEvent(charging: s.charging, kw: s.chargeKw),
  ];
  final pct = s.batteryPct;
  if (pct != null) {
    out.add(BatteryEvent(levelPct: pct, tempC: s.batteryTempC ?? 25.0));
  }
  final speed = s.speedKmh;
  if (speed != null) {
    out.add(SpeedEvent(speed));
  }
  out.add(BlinkerEvent(s.blinker));
  out.add(PowerFlowEvent(s.powerFlow));
  out.add(DriveModeEvent(s.driveMode));
  final eff = s.efficiencyKwhPer100km;
  if (eff != null) {
    out.add(EfficiencyEvent(eff));
  }
  return out;
}
