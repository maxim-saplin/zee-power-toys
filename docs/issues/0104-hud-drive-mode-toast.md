---
status: ready-for-agent
labels: [hud, adapt, drive-mode]
created: 2026-09-25
satisfies: foundation
blocked-by: []
modules: [AdaptApiCarSignals, CarSignals, HudHost, battery/blinker HUD chrome]
tier: T2
owner:
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
- [ ] Drive-mode Adapt (or Simulated) value reaches Dart as a first-class signal
- [ ] HUD toast appears **only on mode change**, shows picked mode ~5 s, fades
- [ ] ECO / Comfort / Sport mapping documented in issue Reconciliation + unit/fixture covering at least one change
- [ ] Settings/Sim: way to fire a change on T2 without car
- [ ] T2 evidence on Tablet dens 320 (preview/HUD shot mute-on + fade timing note) — `tmp/qa/0104-cut-<sha>/`
- [ ] Beta four-point; PDM ACCEPT after own check

## Notes
- Sequence with **0105** (own range): either tip after 0105 or parallel early review; **one Tablet** — no parallel emu cuts.
- Soft: do not block on full theme/animation polish; readable 5 s toast is enough.
