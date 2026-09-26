---
status: accepted
tip: 36f2384
accepted: 2026-09-26
evidence: tmp/qa/0110-cut-36f2384/
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

- [x] Settings toggle OFF → no corner dot (toast still works if 0109 tip present).
- [x] Settings toggle ON + known mode → BR colored dot (Comfort blue / ECO green / Sport yellow).
- [x] Mode change updates the dot without requiring restart.
- [x] EN + RU strings for toggle + short help.
- [x] Persist in ConfigStore; survives process restart.
- [x] T2 Tablet dens320 evidence (OFF / ON×3 modes) + units — PASS (`tmp/qa/0110-cut-36f2384/`).
- [x] QA FINDINGS + beta four-point + PDM ACCEPT — PASS / ACCEPT `36f2384` (2026-09-26). Soft: car T3.


## Reconciliation

**2026-09-26 tip:** Settings toggle for persistent BR drive-mode corner dot.
**Tip SHA:** `36f2384`

### Changes
1. **Config:** `BatteryConfig.showDriveModeCornerDot` (default **OFF**); JSON round-trip via ConfigStore / SharedPrefs — survives restart.
2. **Settings:** HUD battery section toggle + one-line help — EN `showDriveModeCornerDot` / `showDriveModeCornerDotHint`, RU `Точка режима езды в углу` + help. Agent key `battery-show-drive-mode-dot`.
3. **HUD:** `DriveModeCornerDotLayer` — bottom-right Safe Area, pad **14** logical from edges, filled circle **10** dp. Default battery placement is **rightTop** (top-right) → BR clear of battery/temp; shrink/pad rather than overlap.
4. **Colors (persistent 0110):** Comfort **blue** `#3B82F6`, ECO **green** `#3DDC84`, Sport **yellow** `#FFCC00`. Other/unknown → hide.
5. **Colors (toast 0109, unchanged):** Comfort blue / ECO green / Sport **red** `#FF3B30`. Documented both tables here.
6. Live updates via `driveModeProvider` (Adapt or Simulated). No 5 s fade — persistent while ON+known. HUD Off tears down engine → no chrome. Preview/Simulated show toggle on T2.
7. **No Live bump** (`1.1.0+22`). Soft: car T3.

### Color tables

| Mode | Toast accent (0109) | Persistent corner dot (0110) |
|------|---------------------|------------------------------|
| Comfort | blue `#3B82F6` | blue `#3B82F6` |
| ECO | green `#3DDC84` | green `#3DDC84` |
| Sport | **red** `#FF3B30` | **yellow** `#FFCC00` |
| other / unknown | soft grey (toast) | **hide** |

### Verification
`flutter test` — `test/hud/drive_mode_corner_dot_test.dart` (+ toast accent / toast provider / BatteryConfig defaults) PASS. `dart analyze` clean on touched Dart.

**Divergence:** None from scope. Soft: car T3 / dens320 pad confirm vs mid-right battery placement.


## ACCEPT (PDM 2026-09-26)

Tip `36f2384` (1.1.0+22; Live not bumped). QA T2 dens320 PASS (`tmp/qa/0110-cut-36f2384/`); four-point PASS (soft); units 5/5. Default OFF → no BR corner dot; ON → Comfort blue `#3B82F6` / ECO green `#3DDC84` / Sport **yellow** `#FFCC00` (≠ toast Sport red `#FF3B30`); live update; unknown/other hide; prefs survive re-up; settings EN/RU key `battery-show-drive-mode-dot`. Color split intentional (toast red Sport vs persistent yellow Sport). Soft: car T3 dens clearance; pad soft ~20 px SA-edge→blob (code pad 14 + radius/glow). Neither soft is a blocker.

## Notes

- Blocked by **0109** only for color/position polish of toast; if 0109 tip is late, 0110 may land on tip that already has 0109 or stack after. Prefer sequential on one Tablet: **0109 then 0110**.
- Tip OK; no Live bump until Maxim GO.
- Soft: exact pad vs battery BR conflict — measure; move battery or shrink dot rather than overlap.
