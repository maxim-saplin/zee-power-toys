---
status: ready-for-qa
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

- [x] On Tablet dens 320 T2 (and car T3 soft), with Overlay ON, dragging Overlay size from ~0.6× to ~1.6× visibly changes both the system overlay window and the radar/content scale — not just a blank or letterbox frame.
- [x] The change is live; no Overlay toggle off/on is required, and it persists across relaunch.
- [x] Placement still works; Overlay OFF still hides size chrome.
- [x] Unit/widget coverage verifies scale application to layout and content if that is the bug.
- [ ] QA FINDINGS on tip + PDM ACCEPT.

## Reconciliation

**Root cause:** Every Overlay size slider tick called `_applySpeedcamConfig` → `setEnabled(true)`, and Kotlin `setEnabled(true)` always ran `ensureWindow(shown = false)` (GONE). That raced `setLayout` / `applyLayoutToWindow`: WindowManager LP could update while the FlutterTextureView stayed GONE, so Flutter never got a live `onSizeChanged` / viewport metrics update. Result: native window chrome (or letterbox) changed (or appeared not to) while Alien CRT / radar content stayed painted at the old size — “slider does nothing.”

**Fix:**
1. Kotlin `setEnabled(true)`: if the overlay window already exists, do **not** force GONE; preserve `contentVisible` (only cold-enable stays GONE until `update(visible=true)`).
2. Kotlin `applyLayoutToWindow` / `forceOverlaySurface`: after `updateViewLayout`, call `forceFlutterViewSize` (explicit measure+layout) so Flutter viewport metrics match the new LP; always re-apply current `sizeScale` on show (not only when LP was 0×0).
3. Dart overlay app: `SizedBox.expand` + watch `overlaySizeScale` so Alien `FittedBox` rebuilds against tight window constraints when scale changes.
4. `speedcamOverlayWindowSizePx` helper + unit/widget tests for scale→px and CRT fill-at-slot.

**Verification:** `flutter test` — geometry overlay px (0.6/1.0/1.6 @ dens2), successive `setLayout` recording, Alien CRT fills 168×123 vs 448×329 slots; analyzer clean on touched Dart. Live bump **not** done (Maxim GO after ACCEPT). Soft: car T3 still open for QA.

**Divergence:** None from scope; change-only.

## Notes

- Change-only preferred; no Live bump until Maxim GO after ACCEPT.
- Soft: car T3 confirmation.
