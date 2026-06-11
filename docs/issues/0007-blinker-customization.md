---
status: done
labels: [hud, blinker]
created: 2026-06-11
satisfies: HUD · Blinker — shape (dots/arrows/smiley), size, position
blocked-by: [0006]
modules: [CarSignals, ConfigStore, hud]
tier: T1
---

# 0007 — Blinker customization

## Block scope
Real Blinker content in the HUD `BLINKER` slot, driven by live CarSignals (`BlinkerState` off/left/right/hazard): selectable **shape** (yellow dots [phase0 default], real turn **arrows**, yellow **smiley**), **size**, and **position**, all configured from the DHU with the live HUD preview. Emissive yellow on black. Defaults excellent (dots, sensible size/position); advanced controls minimal.

## Touches
- **Satisfies:** REQUIREMENTS — "For blinkers allow to chose shape (yellow dots as now, actual arrows as in normal car, yellow smileys) and size, adjust position."
- **Modules:** CarSignals (blinker), ConfigStore (blinker schema), the `hud/` Blinker widget.
- **ADRs:** 0001 (emissive HUD), 0003/0006.

## Grounding
- phase0 blinker visuals/positions/colors: [`docs/knowledge/hud-overlays-blinker-guidance.md`](../knowledge/hud-overlays-blinker-guidance.md) (BlinkerOverlayView / HudBeautifulBlinkerActivity — dot geometry, yellow value, side x-offsets, blink cadence).
- Slot + preview: `lib/hud/hud_root.dart` (the BLINKER slot), `lib/widgets/hud_preview.dart`, `lib/screens/hud_settings_screen.dart`.
- Signal: `lib/providers/car_signals.dart` (`blinkerProvider`), inject via `ext.zee.inject kind=blinker value=left|right|hazard|off`.

## What to build
- `lib/hud/blinker_widget.dart` — `BlinkerWidget` (HookConsumerWidget): watches `blinkerProvider`; renders the active side (left/right; hazard = both) with the configured shape/size/position; blink animation (cadence from phase0); nothing when off. Emissive yellow (`0xFFFFEB3B`-ish), bright-on-black. Shapes: `dots` (default), `arrows`, `smiley` — an enum + a painter/widget per shape.
- Config: extend `AppConfig` with `BlinkerConfig { BlinkerShape shape; double size; Alignment/offset position; }` (plain JSON, defaults = dots + phase0 size/position).
- Plug `BlinkerWidget` into the HudRoot BLINKER slot (replace the stub) — and hazard shows both sides.
- DHU settings: a Blinker section in `hud_settings_screen.dart` — shape selector (segmented), size slider, position control — with the live preview reflecting changes. `ValueKey`s for driving.
- `ext.zee.readViewModel` includes the blinker view state (shape/size/active side).

## Definition of Done (runtime-confirmed on T1)
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] `inject kind=blinker value=left/right/hazard/off` → HUD shows the configured blinker on the matching side(s); hazard = both; off = none. — artifact: [`shots/blinker-dots.png`](../../shots/blinker-dots.png), [`blinker-arrows.png`](../../shots/blinker-arrows.png), [`blinker-hazard.png`](../../shots/blinker-hazard.png) (smiley both sides).
- [x] Changing shape/size/position from the DHU updates BOTH preview and HUD (relay). — artifact: `shots/blinker-dhu-arrows-preview.png`, size 1.0 vs 1.8 shots.
- [x] Blinker config persists; default = dots. — artifact: readViewModel blinker JSON.
- [x] analyze clean; **57 tests** green (each shape × side; off clears; config round-trips); no regression. Principles: dots default excellent; animation only while active (no idle timer).

## Reconciliation
Built by Sonnet, runtime-verified by the orchestrator (Opus) on T1, 2026-06-11.
1. **Color = phase0 `hud_amber #FFC107`** (not Material `#FFEB3B`) — phase0 fidelity wins. Smiley features rendered in dark amber (`#7A5C00`) as cutouts so nothing emits bright-white (emissive rule).
2. **Blink cadence 450 ms** — the embedded `BlinkerOverlayView` production value (not the 500 ms standalone-activity value).
3. **Arrow chevrons** use the exact `ic_blinker_left/right.xml` path coords (120×60 viewport) scaled to the slot.
4. **Hazard layout:** the BLINKER slot was widened to a full-Safe-Area layer (`Positioned.fill`) so `BlinkerWidget` can place left + right marks at the edges simultaneously — faithful to phase0's full-overlay blinker. Battery/Guidance/Minimap stubs unchanged.
