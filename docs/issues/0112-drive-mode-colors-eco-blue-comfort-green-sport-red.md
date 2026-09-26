---
status: tip
tip: 2bf2a30
labels: [hud, adapt, drive-mode, settings]
created: 2026-09-26
satisfies: Drive-mode accents match Maxim ECO blue → Comfort/standard green → Sport red; tip+config order matches
tier: T2
owner: zee-dev
blocked-by: []
modules: [DriveModeToastLayer, DriveModeCornerDot, BatteryConfig/ConfigStore, Settings help, tip docs]
priority: now
filed-by: zee-pdm
related: [0104, 0109, 0110]
parent: [0109]
gate: armed-2026-09-26
---

# 0112 — Drive-mode colors: ECO blue · Comfort green · Sport red (+ tip/config order)

## Block scope

Maxim 2026-09-26 ~13:09 Minsk HARD: driving-mode accents must be **ECO blue → standard/Comfort green → Sport red**, and the **same order** must appear in tip docs and config (enums, settings copy, help, reconciliation tables).

This **supersedes** the 0109/0110 color tables:

| Mode | Was (0109 toast / 0110 dot) | **Now (both toast + corner-dot)** |
|------|-----------------------------|-----------------------------------|
| ECO | green `#3DDC84` | **blue** `#3B82F6` |
| Comfort / standard | blue `#3B82F6` | **green** `#3DDC84` |
| Sport | toast red `#FF3B30` / dot yellow `#FFCC00` | **red** `#FF3B30` on **both** (no yellow) |

## Product rules

1. Toast accents and corner-dot accents use the **same** ECO blue / Comfort green / Sport red palette.
2. Tip docs, ConfigStore / BatteryConfig enums or switch order, settings EN/RU strings, and Reconciliation tables list modes in **ECO → Comfort → Sport** (or explicit “standard = Comfort”) — not Comfort-first if that contradicts Maxim’s named order.
3. Simulated / Preview / inject recipe on T2 dens320 must show the new colors pixel-exact.
4. Live **not** bumped in this tip; ship only after Maxim GO.

## DoD (T2 dens320)

- [x] Toast ECO blue / Comfort green / Sport red pixel-exact (unit Color asserts + shared `DriveModeAccents`)
- [x] Corner-dot (0110 ON) same three colors; Sport ≠ yellow
- [x] Tip + config + arb strings order/docs match ECO → Comfort → Sport
- [x] Units / analyzer clean
- [ ] Soft: car T3
- [ ] QA dens320 pixel cut (post-tip)

## Soft / residuals

- Sport **pulsate** is **0113** (depends on Sport being red here).
- Car T3 soft.
- Did **not** implement 0113 / 0115 / 0116.

## Reconciliation

**2026-09-26 tip:** Unify toast + corner-dot to ECO blue → Comfort green → Sport red; reorder tip/settings copy.

### Hex chosen (document)

| Mode | Color | Hex | Source |
|------|-------|-----|--------|
| ECO | blue | `#3B82F6` | former Comfort blue (0109/0110) |
| Comfort / standard | green | `#3DDC84` | former ECO green (0109/0110) |
| Sport | red | `#FF3B30` | former toast Sport red; drops 0110 yellow `#FFCC00` |
| other / unknown | soft grey (toast) / hide (dot) | `#C8CDD8` | unchanged |

### Changes
1. **Shared palette:** `lib/hud/drive_mode_accents.dart` — `DriveModeAccents` (ECO / Comfort / Sport / other). Toast `driveModeToastAccent` and corner-dot `driveModeCornerDotColor` both read from it → same three colors guaranteed.
2. **Toast + corner-dot:** ECO `#3B82F6` blue, Comfort `#3DDC84` green, Sport `#FF3B30` red on **both**; Sport corner yellow `#FFCC00` removed.
3. **Order ECO → Comfort → Sport:** Simulate segmented control already ECO/Comfort/Sport; `DriveMode` enum mapping 1→eco / 2→comfort / 3→sport unchanged; settings EN/RU hint reordered from Comfort-first to **ECO blue / Comfort green / Sport red** (RU: ECO — синяя, Comfort — зелёная, Sport — красная); BatteryConfig doc comment notes 0112 palette + order; Reconciliation tables here use ECO → Comfort → Sport.
4. **Units:** accent + corner-dot + toast chrome widgets assert new hex; toast≡corner for known modes; Sport ≠ `#FFCC00`.
5. **No Live bump** — stays **1.1.0+23**. Soft car T3. Did **not** implement 0113 pulsate / 0115 / 0116.

### Color table (supersedes 0109/0110)

| Mode | Toast accent | Persistent corner-dot |
|------|--------------|----------------------|
| ECO | blue `#3B82F6` | blue `#3B82F6` |
| Comfort | green `#3DDC84` | green `#3DDC84` |
| Sport | red `#FF3B30` | red `#FF3B30` |
| other / unknown | soft grey `#C8CDD8` | **hide** |

### Verification
`flutter test` — `test/hud/drive_mode_toast_accent_test.dart`, `test/hud/drive_mode_corner_dot_test.dart`, `test/providers/drive_mode_toast_test.dart`, `test/services/drive_mode_mapping_test.dart`. `dart analyze` clean on touched Dart.

**Divergence:** None from scope. Soft: car T3 dens clearance; dens320 QA pixel cut post-tip.

## Notes

- Tip OK; **no Live bump** until Maxim GO.
- Do **not** implement 0113 Sport pulsate / 0115 / 0116 here.
