---
status: done
labels: [hud, battery, charging]
created: 2026-06-11
satisfies: HUD · utility info — battery & temp (Steam-Deck-style), charging stats
blocked-by: [0006]
modules: [CarSignals, ConfigStore, hud]
tier: T1
---

# 0008 — Battery & temp widget + charging stats

## Block scope
Real content in the HUD `BATTERY` slot: a **Steam-Deck-style** battery indicator (segmented level + %), battery **temperature**, and **charging stats** (V/A/kW) that appear **only while charging** and hide otherwise. Driven by CarSignals `BatteryEvent(levelPct,tempC)` + `ChargeEvent(charging, volts, amps, kw)`. Emissive on black. Each element toggleable (defaults: battery+temp on, charging stats auto show-while-charging).

## Touches
- **Satisfies:** REQUIREMENTS — "When charging allow to show stats in HUD (and hide when not charging)"; "battery level and temp"; "battery looks in a similar fashion as Steam Deck battery".
- **Modules:** CarSignals (battery/charge), ConfigStore (battery widget schema), `hud/` battery widgets.
- **ADRs:** 0001 (emissive), 0003/0006.

## Grounding
- Signal model + ranges: [`docs/knowledge/car-signals-adaptapi.md`](../knowledge/car-signals-adaptapi.md) (battery % 0–100, temp °C ~15–40, charge V/A/kW live only while charging; charging state).
- Providers: `lib/providers/car_signals.dart` (`batteryPctProvider`/`batteryTempCProvider`/`chargingProvider`/`chargeKwProvider` — confirm exact names; add derived ones if missing). Inject: `ext.zee.inject kind=battery levelPct.. tempC..` / `kind=charge charging.. kw..`.
- Slot + preview + settings: `lib/hud/hud_root.dart` (BATTERY slot), `lib/widgets/hud_preview.dart`, `lib/screens/hud_settings_screen.dart`.

## What to build
- `lib/hud/battery_widget.dart` — `BatteryWidget`: Steam-Deck-style battery (rounded body + nub, N segments filled by `levelPct`, % text), low-battery emphasis; battery **temp** shown beside/below; emissive amber/green-ish on black (use a HUD palette; bright marks only). Driven by `batteryPctProvider`/`batteryTempCProvider`.
- `lib/hud/charging_widget.dart` (or fold into battery) — charging stats (kW prominent, V/A secondary) shown **iff** `chargingProvider` is true; hidden otherwise (the "hide when not charging" rule — app policy, ADR 0003).
- Config: `BatteryConfig { bool showBattery; bool showTemp; bool showChargingStats; double sizeScale; }` in AppConfig (plain JSON; sensible defaults — all on, charging auto).
- Plug into HudRoot BATTERY slot (replace stub).
- DHU settings: a "Battery" section (toggles + size) with live preview.
- `ext.zee.readViewModel` includes battery view state (pct, tempC, charging, kw, which elements visible).

## Definition of Done (runtime-confirmed on T1)
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] `inject kind=battery levelPct=72 tempC=24` → Steam-Deck-style battery ~72% + 24°C. — artifact: `shots/battery.png`; low-battery red at 8% (`shots/battery-low.png`).
- [x] `inject kind=charge charging=true kw=42` → `42 kW` (cyan) + lightning bolt appear; `charging=false` → they disappear. — artifact: [`shots/charging-on.png`](../../shots/charging-on.png) / `shots/charging-off.png`.
- [x] Battery config persists; toggles relay to both surfaces. — artifact: readViewModel battery JSON; `shots/dhu-no-temp.png`.
- [x] analyze clean; **77 tests** green (fill ∝ pct; charging stats iff charging; temp toggle; JSON round-trip); no regression. Principles: show-while-charging automatic; minimal toggles.

## Reconciliation
Built by Sonnet, runtime-verified by the orchestrator (Opus) on T1, 2026-06-11.
1. **Steam-Deck design:** rounded-rect body + terminal nub, smooth proportional fill (no segments — reads better at the small BATTERY-slot size), internal ⚡ while charging. `FittedBox(scaleDown)` for graceful degradation in the narrow slot.
2. **Emissive palette:** fill green `#4ADE80` → amber `#FFC107` (15–29%) → red `#FF4444` (<15%); kW in cyan `#67E8F9`; all on black, no panels.
3. **Show-while-charging is app policy in Dart** (`showStats = isCharging && cfg.showChargingStats`) — `_ChargingStats` is never built unless charging (ADR 0003; no idle work). All four CarSignals providers already existed.
