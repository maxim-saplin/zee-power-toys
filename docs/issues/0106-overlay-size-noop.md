---
status: ready-for-agent
labels: [speedcam, overlay, hud, dhu]
created: 2026-09-25
satisfies: Overlay size slider actually changes system overlay size when Overlay ON
tier: T2
owner: zee-dev
blocked-by: []
modules: [SpeedcamSystemOverlay, Speedcam settings, SpeedcamConfig.overlaySizeScale]
priority: now
filed-by: zee-pdm
---

# 0106 — Overlay size slider has no visible effect

## Block scope

Maxim 2026-09-25 ~21:51 Minsk: “The overlay size option doesnt seem to make any difference”. Observed on the Live path after 1.1.0+21 (0104/0105 ship). Investigate and fix the Overlay size setting for the real system overlay; do not implement a cosmetic preview-only change.

## Context for agents

- Settings: **Speedcam → Overlay ON → Overlay size** slider, key `speedcam-overlay-size` (`0.6–1.6×`), writes `SpeedcamConfig.overlaySizeScale` via `_patchSpeedcam`.
- 0079 claimed size + placement change the overlay; placement may still work — verify size specifically.
- Existing wiring: `_applySpeedcamConfig` → `ov.setLayout(sizeScale: sc.overlaySizeScale, …)` → Kotlin `SpeedcamSystemOverlayController.setLayout` → `OVERLAY_WIDTH_DP * sizeScale * density` + `applyLayoutToWindow`.
- Hypotheses are non-binding: the window layout scales but Flutter Alien/CRT content paint does not; `setLayout` is not re-applied on every slider change or races with enable; the range is too subtle on DHU dens; or the slider affects prefs/preview but not the live float. Investigate and fix the actual cause.

## Touches

- **Satisfies:** Overlay size slider actually changes system overlay size when Overlay ON
- **Modules:** SpeedcamSystemOverlay, Speedcam settings, SpeedcamConfig.overlaySizeScale
- **ADRs:** None

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [ ] On Tablet dens 320 T2 (and car T3 soft), with Overlay ON, dragging Overlay size from ~0.6× to ~1.6× visibly changes both the system overlay window and the radar/content scale — not just a blank or letterbox frame.
- [ ] The change is live; no Overlay toggle off/on is required, and it persists across relaunch.
- [ ] Placement still works; Overlay OFF still hides size chrome.
- [ ] Unit/widget coverage verifies scale application to layout and content if that is the bug.
- [ ] QA FINDINGS on tip + PDM ACCEPT.

## Reconciliation

Filled while building. Record the observed root cause, fix, verification evidence, and any divergence from this scope here.

## Notes

- Change-only preferred; no Live bump until Maxim GO after ACCEPT.
- Soft: car T3 confirmation.
