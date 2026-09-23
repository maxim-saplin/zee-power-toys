---
status: ready-for-agent
labels: [ynavi, qa, matrix, hardening]
created: 2026-09-23
satisfies: Exhaustive T2 matrix for YNavi Zee mods on v27 + v30 stretch, same bar as toys 0096
tier: T2
owner: zee-qa
blocked-by: []
modules: [ynavi-zee, letterbox, ZeeUiScale, keepalive, banners, speedcam-bridge, traffic-recovery]
priority: next
filed-by: zee-pdm
---

# 0097 — YNavi mod hardening matrix (v27 + v30 on T2)

## Why
Toys 0096 locked an exhaustive harness matrix for speedcam. Publish-trio YNavi mods (`ynavi-zee`) need the same bar: prove letterbox / scale / keepalive / banners / speedcam bridge / traffic recovery / passport gate on **T2**, for **v27 Live** (all three car variants) and **v30 stretch** (Releases-only arm64).

## Assets
| Line | Tag | APKs |
|------|-----|------|
| v27 Live | `ynavi-zeekr-v27.0.2` | `deepal_v27.0.2.apk`, `zeekr_v27.0.2_margined.apk`, `zeekr_v27.0.2_os7_nomargin.apk` |
| v30 stretch | `ynavi-zeekr-v30` (pre-release) | `ynavi_30.8.1_zeekr_arm64_signed.apk` |

Companion for bridge cases: toys Live **1.1.0+18**.

Feature docs (source of truth): `ynavi-zee/features/{1.mapactivity_letterbox_padding,2.app_ui_scale,3.fgs_keepalive,4.disable_banners,4.speedcam_bridge,5.traffic_recovery}.md` (+ open guidance-offset issue).

## Scope
- Run matrix in `docs/qa/0097-ynavi-mod-hardening-matrix.md` on T2 (Tablet/DHU-size emu).
- Evidence under `tmp/qa/0097-cut-<tag-or-sha>/` per case id.
- Tip FINDINGS when a row fails product behavior; soft SKIP+reason when emu cannot prove (never ghost PASS).
- Out of scope: N1, car T3, rebuilding full v30 Deepal/OS7 matrix unless a V4 FAIL forces a rebuild cut.

## DoD
- [ ] V1–V4 install/cold-open green (or honest FAIL)
- [ ] L / S / B rows for each installed variant that applies
- [ ] C1 bridge→toys with 1.1.0+18 OR honest SKIP+reason
- [ ] K / T / P / G / R documented (PARTIAL/SKIP allowed where noted)
- [ ] Evidence tree + tip; beta early review on V4+C1
- [ ] PDM ACCEPT after own evidence check

## Soft (not HOLD unless Maxim says)
- K2 keepalive survival on emu (often PARTIAL)
- T1 traffic recovery if network flip unavailable
- G1 guidance letterbox offset (known debt — document, compare v27 vs v30)
- No field coords required

## Owners
- **zee-pdm:** DoD / ACCEPT
- **zee-qa:** T2 matrix FINDINGS
- **zee-dev:** fix only on FAIL
- **zee-dev-beta:** parallel early review V4 + C1

## Matrix
See `docs/qa/0097-ynavi-mod-hardening-matrix.md`.
