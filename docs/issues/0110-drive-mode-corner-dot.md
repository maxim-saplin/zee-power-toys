---
status: ready-for-agent
labels: [hud, adapt, drive-mode, settings]
created: 2026-09-26
satisfies: foundation
blocked-by: [0109]
modules: [DriveModeToastLayer, HudRoot, BatteryConfig/ConfigStore, Settings HUD]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
gate: armed-2026-09-26
related: [0104, 0109]
parent: [0104]
---

# 0110 — Settings toggle: persistent bottom-right drive-mode dot

## Block scope

Maxim 2026-09-26 ~09:33 Minsk: add a **settings toggle** that shows the **current** drive mode as a small **colored dot in the bottom-right** corner of the HUD — **persistent** indicator (not a toast).

## Product rules

1. **Toggle in Settings** (HUD battery / drive-mode area — pick a clear EN/RU label + one-line help). Default **OFF** (toast-only world from 0104/0109 unchanged when OFF).
2. When ON: show a small filled **dot** at **bottom-right** of HUD Safe Area (pad from edges; clear of battery/temp if they share that corner — nudge if needed).
3. Dot color follows current known mode:
   | Mode | Dot |
   |------|-----|
   | Comfort | **blue** |
   | ECO | **green** |
   | Sport | **yellow** |
   | other / unknown | hide soft (or dim grey — prefer hide until known) |
4. Updates live when mode changes (Adapt or Simulated). No 5 s fade — stays while ON and mode known.
5. HUD Off tears down chrome → no dot. Preview / Simulated must show the toggle working on T2.

**Note:** Toast accents stay **blue/green/red** (0109). Persistent Sport dot is **yellow** per Maxim (softer continuous chrome). Document both tables in Reconciliation.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [ ] Settings toggle OFF → no corner dot (toast still works if 0109 tip present).
- [ ] Settings toggle ON + known mode → BR colored dot (Comfort blue / ECO green / Sport yellow).
- [ ] Mode change updates the dot without requiring restart.
- [ ] EN + RU strings for toggle + short help.
- [ ] Persist in ConfigStore; survives process restart.
- [ ] T2 Tablet dens320 evidence (OFF / ON×3 modes) + units if added.
- [ ] QA FINDINGS + beta four-point + PDM ACCEPT. Soft: car T3.

## Notes

- Blocked by **0109** only for color/position polish of toast; if 0109 tip is late, 0110 may land on tip that already has 0109 or stack after. Prefer sequential on one Tablet: **0109 then 0110**.
- Tip OK; no Live bump until Maxim GO.
- Soft: exact pad vs battery BR conflict — measure; move battery or shrink dot rather than overlap.
