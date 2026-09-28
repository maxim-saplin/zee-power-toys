---
status: accepted
tip: 65ffdd5
accepted: 2026-09-28
labels: [ynavi, zee, v30, parity, letterbox, minimap]
created: 2026-09-28
satisfies: YNavi Zee v30 full complete parity with Zee v27 — T2 enough; Deepal is a different flavor
tier: T2
owner: zee-dev
blocked-by: []
modules: [YNavi Zee stretch, letterbox, minimap, overlay]
priority: now
filed-by: zee-pdm
related: [0082, 0097]
---

# 0122 — YNavi **Zee** v30 full parity with **Zee** v27 (HARD)

## Product (Maxim 2026-09-28 — HARD)

**Focus: Zee flavor only.** Deepal and Zee are different flavors (minor diffs). Do **not** treat Deepal as the DoD target.

**Full, total, complete parity** of YNavi **Zee v30** with **Zee v27**. Not a two-bug list.

First fails Maxim stumbled on (symptoms, not the DoD ceiling):

1. Letterbox appeared **at the bottom**, **not** to the left — wrong vs Zee v27.
2. **Minimap not working** on Zee v30.

Stumbling on many more after those is **not acceptable**. Expect Zee v30 to behave like Zee v27 across the YNavi mods surface. **T2 dens320 Tablet is more than enough** to fully test and fix Zee v30 for parity with Zee v27 — no “emu unavailable” / car-only excuses for this Block.

## DoD

- [x] Zee v30 letterbox / chrome placement matches Zee v27 (not bottom-only strip when v27 puts it left).
- [x] Minimap works on Zee v30 as on Zee v27.
- [x] **Parity sweep**: T2 matrix covering the same YNavi/Zee behaviors proven on Zee v27 (mods matrix / 0097-era bar) — Zee v30 must not regress any of them.
- [x] Evidence bank under `tmp/qa/` with Zee v27 vs Zee v30 side-by-side where layout differs.
- [x] Tip to `origin/main`.

## Soft / out of scope

- Deepal flavor parity (separate unless Maxim expands scope).
- Toys Live bump unless install-screen (0121) ships in the same grind and Maxim GOs.
- New features beyond restoring Zee v27 parity.

## ACCEPT (PDM 2026-09-28)

**PDM ACCEPT 2026-09-28:** T2 dens320 full Zee **PASS**.

| Stamp | Value |
|-------|--------|
| ynavi tip | `e9fbe330` |
| Release asset sha | `a1a902270252fb9ec4982e6f3214b7476ea0f3ed9f666be95ba53fae9bcf2348` |
| toys tip (docs ready-for-qa) | `65ffdd5e` |
| Evidence | `tmp/qa/0122-cut-e9fbe330/FINDINGS.md` |
| HOST_SOT | Phys **2560×1600@320** · Override dens **160** · overlay **1024×576@213** · ZeeUiScale **175/130** |
| Live Toys | still **1.1.0+27** (no Live bump) |

Hard Zee matrix green (letterbox left SoT 70/10/480, minimap CarApp handshake SUCCESS, L4/K1, 0 FATAL). Soft SKIP **P9/G1/T1/M4** OK. Soft note: v27 letterbox L=**840** vs v30 L=**480** under same SoT (ZeeUiScale×letterbox on v27) — **not FAIL**.

## DEV tip (2026-09-28 Europe/Minsk) — superseded by ACCEPT

- **ynavi-zee** `e9fbe3308` — `config.env.example` → Zee 70/10/480; `docs/0122-v30-zee-parity.md`
- **Release** `ynavi-zeekr-v30` asset recut sha `a1a90227…` (letterbox + MINIMAP P1–P4)
- **Evidence:** `tmp/qa/0122-zee-letterbox-minimap/FINDINGS.md` — left letterbox v27↔v30 side-by-side; CarApp `onHandshakeCompleted SUCCESS`
- Soft: Live toys sharedUser on non-rooted Tablet; full 0097 matrix → @zee-qa
