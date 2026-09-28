---
status: tip-ready
labels: [ynavi, deepal, v30, parity, letterbox, minimap]
created: 2026-09-28
satisfies: YNavi Deepal v30 full complete parity with v27 — T2 enough; letterbox/minimap first fails only
tier: T2
owner: zee-dev
blocked-by: []
modules: [YNavi Deepal stretch, letterbox, minimap, overlay]
priority: now
filed-by: zee-pdm
related: [0082, 0097]
---

# 0122 — YNavi Deepal v30 **full parity** with v27 (HARD)

## Product (Maxim 2026-09-28 — HARD)

**Full, total, complete parity** of Deepal **v30** with **v27**. Not a two-bug list.

First fails Maxim stumbled on (symptoms, not the DoD ceiling):

1. Letterbox appeared **at the bottom** (Deepal-style), **not** to the left — wrong vs v27.
2. **Minimap not working** on v30.

Stumbling on many more after those is **not acceptable**. Expect v30 to behave like v27 across the YNavi mods surface. **T2 dens320 Tablet is more than enough** to fully test and fix v30 for parity with 27 — no “emu unavailable” / car-only excuses for this Block.

## DoD

- [ ] v30 letterbox / chrome placement matches v27 (not bottom-only Deepal strip when v27 puts it left).
- [ ] Minimap works on v30 as on v27.
- [ ] **Parity sweep**: T2 matrix covering the same YNavi/Deepal behaviors proven on v27 (mods matrix / 0097-era bar) — v30 must not regress any of them.
- [ ] Evidence bank under `tmp/qa/` with v27 vs v30 side-by-side where layout differs.
- [ ] Tip to `origin/main`.

## Soft / out of scope

- Toys Live bump unless install-screen (0121) ships in the same grind and Maxim GOs.
- New features beyond restoring v27 parity.
