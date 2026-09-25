---
status: tipped
labels: [hud, adapt, drive-mode]
created: 2026-09-25
satisfies: foundation
blocked-by: []
modules: [AdaptApiCarSignals, CarSignals, HudHost, battery/blinker HUD chrome]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
gate: armed-2026-09-25
parent: []
---

# 0104 — HUD drive-mode change toast (5 s fade)

## Block scope
Maxim 2026-09-25: when the driver picks a drive mode, show a short **HUD animation / toast for the three modes** (ECO / Comfort / Sport — map Adapt enum honestly), with the **currently picked mode** stating for **~5 seconds** then **fading away**.

**Triggers:** only when Adapt drive mode **changes** (`0x22010100`), not on every HUD cold-open / every snapshot tick.

## Product rules
1. Three modes only on HUD chrome for this slice (map observed Adapt values → ECO / Comfort / Sport; unknown → soft skip or “Mode” label, do not invent a fourth permanent chip).
2. **On change only** — no permanent drive-mode badge in this Block (diagnostics may still dump raw ID).
3. **~5 s hold, then fade** — keep off blinker / Alien radar danger zone; one shared look (glyph + short label + optional color accent).
4. Respect HUD Off / preview surfaces; Simulated source must be able to fire a mode change for T2.
5. Live version **not** required to bump in this Block (tip OK); ship with later GO.

## Adapt
- Function ID **`0x22010100`** (live on car T3; see `docs/knowledge/car-signals-adaptapi.md`, `zee_hud_2` on-car sensor validation).
- Wire into `AdaptApiCarSignals` / `CarSignals` snapshot+events if not already; filter sentinels.
- Emulator: Simulated path required for T2 (no Adapt on Tablet).

## Definition of Done
- [x] Drive-mode Adapt (or Simulated) value reaches Dart as a first-class signal
- [x] HUD toast appears **only on mode change**, shows picked mode ~5 s, fades
- [x] ECO / Comfort / Sport mapping documented in issue Reconciliation + unit/fixture covering at least one change
- [x] Settings/Sim: way to fire a change on T2 without car
- [ ] T2 evidence on Tablet dens 320 (preview/HUD shot mute-on + fade timing note) — `tmp/qa/0104-cut-<sha>/`
- [ ] Beta four-point; PDM ACCEPT after own check

## Reconciliation
**2026-09-25 tip:** HUD drive-mode change toast.
**Tip SHA:** 30a390b

### Mapping (`0x22010100`)
ECarX Adapt emits raw ints in the function-id family `0x22010100 + n` (field notes / LynkCoTrack AdaptAPI):

| n | Mode | HUD |
|---|------|-----|
| 1 | ECO | **ECO** (green) |
| 2 | COMFORT | **Comfort** (cyan) |
| 3 | SPORT | **Sport** (orange) |
| 4–14 | EV / HYBRID / POWER / SNOW / MUD / ROCK / SAND / OFF-ROAD / TRACK / ADAPTIVE / CUSTOM | generic **Mode** (soft; no 4th permanent chip) |
| 255 / −1 / other | sentinel / unknown | **soft skip** (no toast) |

Small ordinals `1..14` accepted as soft fallback. Adapt start **seeds snapshot without emitting** (change-only). Kotlin `publishDriveMode` suppresses same-mode re-emits.

### Toast
- Hold ~5 s then fade (~450 ms); top-centre Safe Area (clear of blinker edges, battery, Alien radar).
- HUD Off tears down engine → no toast. Simulate / live HudRoot preview shows toast.

### Simulated / T2 fire
- **Settings → Simulate → Drive mode** segmented ECO / Comfort / Sport (debug).
- Agent keys: `simulate-drive-mode-eco` / `-comfort` / `-sport`.
- ADB: `adb shell am broadcast -a com.zeepowertoys.SIMULATE --es kind driveMode --es value sport`
- `ext.zee.inject kind=driveMode value=sport` (T1 Fake).

### Defaults
- No permanent badge; toast only on change after cold-open baseline.

## Notes
- Soft: full theme/animation polish deferred; readable 5 s toast is enough.
- Soft: car T3 confirm exact n→label if firmware diverges from +1/+2/+3.
- Live bump only on Maxim GO after ACCEPT.
