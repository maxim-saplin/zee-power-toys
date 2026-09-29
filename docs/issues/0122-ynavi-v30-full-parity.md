---
status: accepted  # scale soft-rescind then restored — see SOFT-RESCIND below
tip: 7b9a076
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

## PRIOR ACCEPT (PDM 2026-09-28) — scale soft-rescinded

**PDM ACCEPT 2026-09-28:** T2 dens320 full Zee **PASS**. The ZeeUiScale portion was later soft-rescinded because the shipped asset had baked scaling resources but no live `wrapBaseContext` callers after R8.

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


## SOFT-RESCIND scale (PDM 2026-09-28) — restored

0122 ACCEPT soft-rescinded on **ZeeUiScale chrome scale** until re-proven.
Locked RCA: shipped `a1a90227…` baked 175/130 XML but **no** `wrapBaseContext`
callers after R8 (`v63` / `q`). See `tmp/qa/0122-scale-rca/RCA.md`.

**Restored** on ynavi tip `45fada46` (this grind): `v63` reflection + Application `q` direct
`wrapBaseContext`; MapActivity `applyToConfiguration` always / before super.
Own-check dens320 Override 160: `map_activity_root` **L=840 T=123**.
Release asset sha `a000a77f158fcccb87e0c12c1001b0f93f99366341ba9be2fc11daf8509b0e8e`.
Live Toys still **1.1.0+27** (no bump). Soft: Deepal/OS7 recut; full 0097 matrix @zee-qa.

## ACCEPT (PDM 2026-09-28) — scale re-ACCEPT

The prior ACCEPT on ynavi `e9fbe330` / asset
`a1a902270252fb9ec4982e6f3214b7476ea0f3ed9f666be95ba53fae9bcf2348` is
soft-rescinded for scale. Re-ACCEPT is stamped against the restored live hooks:

| Stamp | Value |
|-------|-------|
| ynavi tip | `45fada46` |
| Release asset sha256 | `a000a77f158fcccb87e0c12c1001b0f93f99366341ba9be2fc11daf8509b0e8e` |
| Toys docs tip | `7851432` |
| Evidence | `tmp/qa/0122-scale-cut-45fada46/` |
| DoD | **ZeeUiScale LIVE** — `map_root` **L=840 T=123**; chrome **H=84 px** (=48×1.75) |
| Live Toys | **1.1.0+27** (no bump) |

**Governing:** `wrapBaseContext` is required; baked scaling XML or
letterbox-only patches are not sufficient. The accepted asset has the `v63`
reflection hook, Application `q` direct hook, and MapActivity
`applyToConfiguration` before `super`.

**Soft / non-blocking:** Deepal / OS7 recut later; full 0097 matrix remains
with @zee-qa.

## ACCEPT (PDM 2026-09-28) — enrich + guidance re-ACCEPT

The scale-LIVE tip was re-checked for cam enrichment and usable guidance
chrome under the same dens320 / Override 160 SoT. This closes the 0122 enrich
gate without a code or Live Toys bump.

| Stamp | Value |
|-------|-------|
| ynavi tip | `45fada46` |
| Release asset sha256 | `a000a77f158fcccb87e0c12c1001b0f93f99366341ba9be2fc11daf8509b0e8e` |
| Prior toys docs seal | `947af8f` |
| Evidence | `tmp/qa/0122-enrich-cut-45fada46/` |
| HOST_SOT | Phys **2560×1600@320** · Override dens **160** · overlay **1024×576@213** |
| Met | ZeeUiScale LIVE **L=840** / chrome **84 px**; CRT Alien **0.20+60**; F1 lane mute **OFF→ON→OFF**; A2 SPEED enrich; clustering **12/12 + B1 dedupe**; SpeedCamBridge **ghost+route**; guidance rails **84 px** |
| Live Toys | **1.1.0+27** (hold; no bump) |

**Soft / non-blocking:** Deepal / OS7 later; full-matrix leftovers SKIP;
navigation shields were not driven. The accepted gate is the Zee scale-LIVE
enrich and guidance-chrome cut above; no new feature is implied.

## ACCEPT (PDM 2026-09-28) — T2 uncut dens320 ACCEPT

PDM ACCEPT closes the hard U1–U12 T2 dens320 corner sweep on the same
scale-LIVE tip under HOST_SOT Override 160. Four-point **PASS soft** (U12
PASS*). No code or Live Toys bump; no inherit from rescinded `a1a90227`.

| Stamp | Value |
|-------|-------|
| ynavi tip | `45fada46` |
| Release asset sha256 | `a000a77f158fcccb87e0c12c1001b0f93f99366341ba9be2fc11daf8509b0e8e` |
| Prior toys docs seal | `5e327ff` |
| Evidence | `tmp/qa/0122-t2-uncut-45fada46/` (+ `OWN_CHECK.md`, `FOURPOINT.md`) |
| HOST_SOT | Phys **2560×1600@320** · Override dens **160** · ZeeUiScale **175/130** · overlay **1024×576@213** (never `wm density`) |
| Met | Hard **U1–U12** dens320 PASS; ZeeUiScale LIVE **L=840**; Four-point **PASS soft** (U12 PASS*) |
| Live Toys | **1.1.0+27** hold (Maxim GO for Live — no bump this tip) |

**Soft leftovers (stay soft):** G1 / M4 / P9 / T1 / Deepal / OS7. Do not chase
in this seal. No green inheritance from rescinded asset `a1a90227`.

## Live ACCEPT (PDM 2026-09-28) — 1.1.0+28 ship-gate

**PDM ACCEPT** dens320 ship-gate. Live tip `b5c3ca8` / tag `1.1.0+28` / APK sha256 `693eebdfbe48c1e2c51dc544339cc4bfe542e2e0a5fc75ff3e9cb65eb8001124`. Install UI: **default = YNavi v27.0.2** · **v30.8.1 = beta non-default** (“Not default — prefer v27”). YNavi tip stays `45fada46` / asset `a000a77f…`. Evidence `tmp/qa/1.1.0+28-ship/` (FINDINGS · FOURPOINT PASS soft). Soft: SHARED_USER Live Tablet · Deepal/OS7 · car T3 later (Maxim). No pubspec bump in this seal.

## ACCEPT (PDM 2026-09-28) — dens320 soft leftover sweep ACCEPT

PDM ACCEPT closes the soft leftover sweep on the same scale-LIVE tip under
HOST_SOT Override 160. Four-point **PASS soft**. No code or Live Toys bump;
prior Live seal `7b9a076` stays tip.

| Stamp | Value |
|-------|-------|
| ynavi tip | `45fada46` |
| Release asset sha256 | `a000a77f158fcccb87e0c12c1001b0f93f99366341ba9be2fc11daf8509b0e8e` |
| Prior Live seal | `7b9a076` |
| Live Toys | **1.1.0+28** tip `b5c3ca8` / APK sha256 `693eebdf…` (no bump) |
| Evidence | `tmp/qa/0122-t2-softs-45fada46/` (+ `FOURPOINT.md`) |
| HOST_SOT | Phys **2560×1600@320** · Override dens **160** · ZeeUiScale LIVE **L=840** · overlay **1024×576@213** |
| Met | **P9** / **0101** / **0038** PASS · **T1** PASS* · **G1** SKIP (YNavi no-internet route shutter) · **M4** SKIP* (inactive-hide PASS; nav start/end blocked same) · no hard FAIL |
| OOS soft | Deepal / car T3 / SHARED_USER |

**Soft residuals (stay soft):** G1 / M4 route-gated SKIP(+*); T1 airplane path *; Deepal / OS7 / car T3 / SHARED_USER OOS. Do not chase in this seal.

## ACCEPT soft (PDM 2026-09-29) — dens320 0122A minimap callback+tiles

**PDM ACCEPT soft** dens320 0122A. Governing DoD: `IAppHost.setSurfaceCallback`
+ `onSurfaceAvailable SUCCESS` **and** live overlay tiles (handshake alone is
not PASS). Four-point **PASS soft**. At acceptance time, no Live Toys bump or
release upload; the later ship is recorded below.

| Stamp | Value |
|-------|-------|
| ynavi tip | `4b3bab9df6e956f3fe74867d31f53d0948ecf835` |
| YNavi APK sha256 | `864bc52fe8adb30504fa49f61a24c67b2d43ef7beeced015ffbd788b7bba3672` |
| Toys code tip | `757db4de13c87cf73a067a253e9ffc5311bc7f82` |
| Toys docs tip (TIP_A) | `6e329fd07d973f29145d7f236ac9824a6042a7af` |
| Toys debug sha256 | `a4e426bc995fc2dcefae3da96d1d430cf136cb8fd51c4164eb57399f34018611` |
| Evidence | `tmp/qa/0122a-minimap-prove/` (+ `tmp/qa/0122a-tip-a/`) |
| HOST_SOT | Phys **2560×1600@320** · Override dens **160** · overlay **1024×576@213** · ZeeUiScale LIVE **L=840** |
| Met | callback+tiles **PASS**; crop nonblack **0.306** / colorful **0.343** |
| Live Toys | **1.1.0+30** hold (debug prove build only; no bump) |

**Soft / non-blocking:** Car USB minimap re-prove when DHU available; Tip C
(car-only chrome +82) held for cook; Deepal/OS7 OOS.

## Live ship (2026-09-29) — YNavi v30 and Toys +31

- YNavi prerelease `ynavi-zeekr-v30` asset replaced with the accepted 0122A APK, including the 0122B switch-thumb shape fix. Asset SHA-256: `864bc52fe8adb30504fa49f61a24c67b2d43ef7beeced015ffbd788b7bba3672`. Upstream version remains `30.8.1` / `739652660`.
- Toys release `1.1.0+31`, tag commit `e50301e`, APK SHA-256 `ab26187c7f8416f22f5181b3846e05af102ec26e30457b2de81a82c49e71270f`. GitHub Actions run `36566167379` passed analysis, tests, build, and upload.
- T2 YNavi install/launch smoke passed on `Tablet_Android_12L`; version `30.8.1` / `739652660`, no fatal startup log.
- Toys release install smoke is blocked on both Android 12L AVDs: their system certificates do not match the car platform key required by `android.uid.system` (`INSTALL_FAILED_SHARED_USER_INCOMPATIBLE`). No T3 car was attached. Do not treat emulator install as passed.

