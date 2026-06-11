---
status: done
labels: [hud, preview, safe-area]
created: 2026-06-11
satisfies: HUD · preview + Safe-Area simulation
blocked-by: [0003]
modules: [HudHost, ConfigStore, hud]
tier: T1
---

# 0006 — HUD layout + Safe Area + on-DHU preview

## Block scope
Replace the walking-skeleton placeholder box with the **real HUD scaffolding**: a `HudRoot` widget that composes HUD content emissive-on-black inside a **hand-calibrated Safe Area** (ADR 0001), and a **DHU preview** that renders the *same* `HudRoot` widget subtree in the settings UI over a **grey background** (so the preview cannot drift from the real HUD), with the Safe Area outline shown. Establishes the slots that Blinker / Battery / Charging / Guidance plug into in later Blocks. Safe Area rect + HUD feature flags live in ConfigStore (defaults excellent; advanced tweak available).

## Touches
- **Satisfies:** REQUIREMENTS — "UI preview for HUD… target accurate presentation"; "Simulate accurate scaling and bounds given safe area". Folds in the Foundation "Safe Area" item.
- **Modules:** the `hud/` widget subtree, HudHost (applySafeArea), ConfigStore (HUD schema), a DHU HUD-settings screen.
- **ADRs:** 0001 (preview == real HUD widget), 0003/0006.

## Grounding
- Safe Area rect + emissive rendering + Presentation sizing: [`docs/knowledge/hud-presentation-host.md`](../knowledge/hud-presentation-host.md) (phase0 hand-calibrated bounds + the grey-on-glass preview note in PREVIEW.md).
- Current HUD: `lib/app/hud_app.dart` (the placeholder box + `hudShotKey`), `lib/main.dart`, `lib/services/config_store.dart` (AppConfig).

## What to build
- `lib/hud/hud_root.dart` — `HudRoot` widget: black background; positions content inside the Safe Area rect; named slots (minimap/guidance/blinker/battery placeholders for now — show a small labelled stub in each so the layout is visible). Emissive palette (bright marks on black; never light-on-dark chrome).
- **Safe Area**: extend `AppConfig` with a `SafeArea` (Rect-like: left/top/right/bottom or x/y/w/h, in the HUD backing-display coordinate space) + sensible default from phase0. `HudHost.applySafeArea` stores/applies it. `HudRoot` honors it.
- **HUD render**: `hud_app.dart` renders `HudRoot` (wrapped in the existing `hudShotKey` RepaintBoundary).
- **DHU preview** (`lib/widgets/hud_preview.dart`): renders the SAME `HudRoot` scaled into a preview box over a **grey** background, with the Safe Area rectangle outlined. A DHU `HudSettingsScreen` (`lib/screens/hud_settings_screen.dart`) hosts the preview + a basic Safe-Area adjust (and the existing hudBox debug toggle can move here or be retired).
- Keep `ext.zee.*` working; `readViewModel`/`dumpState` expose the HUD layout state (safeArea + which slots are active).

## Definition of Done (runtime-confirmed on T1)
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] HUD surface renders `HudRoot` inside the Safe Area (emissive-on-black); `ext.zee.shot` on hud shows the structured layout (BLINKER/BATTERY/GUIDANCE/MINIMAP slots within the calibrated rect). — artifact: [`shots/hud-layout.png`](../../shots/hud-layout.png).
- [x] DHU preview renders the SAME `HudRoot` over **grey glass** with the Safe-Area outline; black HUD regions read as grey-through-transparent (the projection simulation). Driving a Safe-Area change updates BOTH preview and HUD surface (relay). — artifact: [`shots/dhu-preview.png`](../../shots/dhu-preview.png).
- [x] Safe Area persists in ConfigStore; defaults are the **phase0 hand-calibrated** values. — artifact: `readViewModel hud` safeArea JSON.
- [x] analyze clean; 39 tests green; no regression. Principles: excellent defaults, advanced-only tweaks, no bloat.

## Reconciliation
Built by Sonnet, integrated + corrected + runtime-verified by the orchestrator (Opus) on T1, 2026-06-11.
1. **Safe Area defaults = real phase0 calibration** (not estimates): backing display 1024×576 @ 213dpi; `SAFE_AREA 616×175dp` @ offset +5/+6 → fractions `left=0.1064, top=0.3125, right=0.9072, bottom=0.7170`. Stored as 0..1 fractions (display-size-agnostic; `LayoutBuilder` → px at render). **T3 calibration item:** confirm optics on the physical unit.
2. **Backdrop-agnostic `HudRoot` (orchestrator fix).** As first built, `HudRoot` painted opaque black, so the DHU preview showed black instead of grey — defeating the "project on transparent glass" requirement. Fixed: `HudRoot` paints **no background**; the *surface* supplies it — black on the real HUD (where black = no projector light = transparent), grey in the preview. This is the correct emissive model and makes the preview faithful. Two unit tests that asserted the old opaque-black implementation were rewritten to assert the behavior (backdrop-agnostic; preview draws its own outline).
3. **`hudBoxOn`** retained in config (available to gate the HUD later); the placeholder yellow box is gone, replaced by the real slot layout.
