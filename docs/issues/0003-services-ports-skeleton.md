---
status: done
labels: [foundation, services]
created: 2026-06-11
satisfies: foundation          # implements ADR 0003 / 0006
blocked-by: [0001]
modules: [CarSignals, ConfigStore, MinimapHost, HudHost, Installer, SystemConfig]
tier: T1
---

# 0003 — Services/ports skeleton + Riverpod injection

## Block scope
Define **all** service ports the MVP hangs off (ADR 0003) as abstract Dart classes with **Dart fakes** for T1, wired through **Riverpod** `ProviderScope.overrides` (ADR 0006), and made drivable/readable through the Feedback Loop. The new hard path proven here: a **CarSignals event injected on the DHU isolate relays across the boundary and is re-derived on the HUD isolate** — the same event-relay model the walking skeleton proved for config, now generalized to live signals.

## Touches
- **Satisfies:** Foundation — implements ADR 0003 (event-driven services, ports, cross-isolate relay) + ADR 0006 (Riverpod per-tier injection).
- **Modules:** CarSignals, ConfigStore (extend), MinimapHost, HudHost, Installer, SystemConfig.
- **ADRs:** 0003 (primary), 0006, 0002 (per-tier hosts), 0004 (inject op).

## Grounding
- Signal semantics + IDs to model the events on: [`docs/knowledge/car-signals-adaptapi.md`](../knowledge/car-signals-adaptapi.md) (speed, blinker L/R/hazard, charge V/A/kW, battery %/temp, power-flow).
- Sealed-event + fake/mock patterns: [`docs/knowledge/flutter-conventions-riverpod-testing.md`](../knowledge/flutter-conventions-riverpod-testing.md).
- The relay to generalize: `lib/relay/hub.dart` (today carries only `setConfig`).

## What to build
- **CarSignals** port: `Stream<CarSignalEvent> get events` + latest-snapshot accessor. `sealed class CarSignalEvent` → `SpeedEvent(kmh)`, `BlinkerEvent(BlinkerState{off,left,right,hazard})`, `ChargeEvent(charging, volts?, amps?, kw?)`, `BatteryEvent(levelPct, tempC)`, `PowerFlowEvent(PowerFlow)`. `FakeCarSignals` with `emitSpeed/emitBlinker/emitCharge/emitBattery` driven by `ext.zee.inject`.
- **ConfigStore**: keep; the schema grows per feature later.
- **MinimapHost** port: commands `enable(bool)`, `setBounds(rect)`, `setParams(...)`; events = trip data (`GuidanceEvent{turnArrow, distanceM, roadName, etaMin}`). `FakeMinimapHost` records commands + can emit canned trip data.
- **HudHost** port: `show()/hide()`, `applySafeArea(Rect)`. `DesktopHudHost` (T1) wraps the desktop_multi_window HUD window.
- **Installer** port: `Stream<InstallProgress> install(GithubAsset)`. `FakeInstaller` simulates progress.
- **SystemConfig** port: `Locale get systemLocale`, `setSystemLanguage`, `setClusterLanguage`. `FakeSystemConfig` in-memory.
- **Relay generalization**: hub carries a typed envelope `{kind: config|carSignal, payload}`. CarSignals events injected on DHU relay to the HUD isolate; HUD re-derives.
- **Riverpod**: a provider per port; `ProviderScope.overrides` inject the fakes on T1 (both isolates).
- **Feedback Loop**: add `ext.zee.inject` (VM-service) → `FakeCarSignals`; route T1 `inject` in `dev/feedback_loop.py` over the VM channel (reconciles 0002). Expand `ext.zee.readViewModel` to the derived view-model `{hudBoxOn, speedKmh, blinker, charging, batteryPct, batteryTempC, guidance?}`.

## Definition of Done (runtime-confirmed on T1)
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] All six ports exist with Dart fakes, injected via Riverpod; both isolates resolve them. — `flutter analyze` clean; providers in `lib/providers/services.dart`.
- [x] `inject` a `speed`, a `blinker`, and a `charge` event on the **DHU** → `readViewModel` on **both** dhu and hud reflects them (cross-isolate signal relay). — artifact: confirmed live — speed=80, blinker=left, charge{charging:true,kw:50} all appeared on both surfaces with a consistent accumulated snapshot.
- [x] Unit tests at the behaviour boundary for CarSignals→derived providers (mock the port). — `flutter test`: **10 passed**.
- [x] Principles: no shared mutable Dart object across isolates (relay carries serialized events); fakes emit on-demand (no always-on timers); minimal options.

## Reconciliation
Confirmed by the orchestrator (Opus) on T1, 2026-06-11.
1. **Block 0002 `inject` reconciled** — the CLI `inject` now routes over the **VM-service** channel (`ext.zee.inject` → `FakeCarSignals`) on T1; the native stub is a T2/T3 fallback only (matches ADR 0004's "injection point descends the stack").
2. **Riverpod 3.x `.value` not `valueOrNull`** — the conventions knowledge doc used the 2.x `valueOrNull`; corrected in [`docs/knowledge/flutter-conventions-riverpod-testing.md`](../knowledge/flutter-conventions-riverpod-testing.md) §4.
3. **Relay generalized** — `zee/hub` now carries a typed envelope `{kind, payload}` (config + carSignal); `pushCarSignalToHud` + `listenForRelay`; `listenForConfig` kept as a thin alias. Each isolate owns its own `FakeCarSignals`; the DHU one is the injectable source, the HUD one is fed by `relay()` after JSON deserialization — no Dart object crosses (ADR 0003).
4. **MinimapHost/HudHost/Installer/SystemConfig fakes are minimal** — the contracts are fixed; their deep behaviour lands in the feature Blocks that consume them.
