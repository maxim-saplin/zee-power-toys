---
status: accepted
tip: b5d7074
accepted: 2026-09-26
evidence: tmp/qa/0113-cut-b5d7074/
labels: [hud, adapt, drive-mode]
created: 2026-09-26
satisfies: Sport red corner-dot pulsates; ECO/Comfort stay calm
tier: T2
owner: zee-dev
blocked-by: [0112]
modules: [DriveModeCornerDot, HudRoot]
priority: now
filed-by: zee-pdm
related: [0110, 0112]
parent: [0110]
gate: armed-2026-09-26
---

# 0113 — Sport corner-dot pulsates; ECO/Comfort calm

## Block scope

Maxim 2026-09-26 ~13:18 Minsk: when the persistent drive-mode corner-dot is ON, the **Sport** (spirit) **red** dot must **pulsate**; ECO and Comfort dots stay **calm** (steady).

## Product rules

1. Requires **0112** Sport = red on the corner-dot (no yellow).
2. Pulse is gentle, readable at a glance, not seizure-fast; ECO/Comfort opacity/size stay fixed.
3. Toggle OFF → no dot. Unknown/other → hide (existing 0110).
4. Preview / Simulated must show Sport pulse on T2.

## DoD (T2 dens320)

- [x] ON + Sport → red pulsating BR dot
- [x] ON + ECO / Comfort → calm blue / green (no pulse)
- [x] OFF / unknown → no pulse chrome
- [x] Units / analyzer clean
- [x] Soft: car T3; pulse timing taste OK — soft stand (period 1600 ms via units/`kSportPulsePeriod`; not a blocker).
- [x] QA dens320 + four-point + PDM ACCEPT — PASS / ACCEPT `b5d7074` (2026-09-26). Soft: car T3; pulse period soft.

## Soft / residuals

- Exact pulse period left to zee-dev taste unless Maxim names Hz; document chosen period in tip.
- Soft car T3 dens clearance.
- Did **not** implement 0115 / 0116.

## Reconciliation

**2026-09-26 tip:** Sport red corner-dot gentle pulse; ECO/Comfort calm.

### Pulse chosen (document)

| Param | Value | Notes |
|-------|-------|-------|
| Period | **1600 ms** (~0.625 Hz) | Full sine breath cycle |
| Wave | `(1 − cos(2πt)) / 2` | Smooth 0→1→0; pure `sportPulseIntensity` |
| Opacity | 0.42 → 1.0 | Floor `kSportPulseOpacityMin` |
| Scale | 0.82 → 1.08 | Glanceable size breath; calm modes stay 1.0 |
| Seizure floor | ≫ 3 Hz | Period ≥ 1 s required in units |

### Changes

1. **`DriveModeCornerDotLayer` → HookConsumerWidget:** Sport-only `AnimationController.repeat()` over `kSportPulsePeriod` (1600 ms); ECO/Comfort stop controller and render opacity=1 / scale=1.
2. **Pure pulse math:** `sportPulseIntensity` / `sportPulseOpacity` / `sportPulseScale` — unit-tested (same pattern as blinker `blinkOnAt`).
3. **Preview demo:** `_demoSignalOverrides` pins `driveModeProvider` to **Sport** so Config Preview shows the pulsating red BR dot when the settings toggle is ON (Simulated already has Sport segment).
4. **0110 hide rules unchanged:** OFF / unknown / other → no chrome.
5. **Units:** accent colors + pulse period + Sport opacity/scale change over half-period; ECO/Comfort fixed across pumps.
6. **No Live bump** — stays **1.1.0+23**. Soft car T3. Did **not** implement 0115 / 0116.

### Verification

`flutter test` — `test/hud/drive_mode_corner_dot_test.dart` (+ toast accent + hud_root preview). `dart analyze` clean on touched Dart.

**Divergence:** None from scope. Soft: car T3; Maxim may retune period.



## ACCEPT (PDM 2026-09-26)

Tip `b5d7074` (1.1.0+23; Live not bumped). QA T2 dens320 PASS (`tmp/qa/0113-cut-b5d7074/`); four-point PASS (soft); units 20/20. Sport red BR sine breath **1600 ms** opacity 0.42→1.0 scale 0.82→1.08 (bri span ~67k); ECO/Comfort calm span=0; 0112 palette retained. Soft: car T3; tablet period soft (units/`kSportPulsePeriod`). Live still **1.1.0+23**.

## Notes

- Tip OK; **no Live bump** until Maxim GO.
- Do **not** implement 0115 / 0116 here.
