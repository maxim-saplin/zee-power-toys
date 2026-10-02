---
status: done
labels: [speedcam, overlay, sizing]
created: 2026-10-02
satisfies: The Default speedcam readout scales with the system overlay size
blocked-by: []
modules: [SpeedcamRadarWidget, SpeedcamOverlayApp, SpeedcamConfig.overlaySizeScale]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-qa
related: [0106, 0116]
---

# 0129 — Default speedcam view stays small in a large system overlay

## Block scope

Scale the Default arrow, distance, and speed readout with the DHU system-overlay window. Large overlay sizes must not leave the readout as a small fixed-size stack in a mostly empty panel.

## Investigation

Reproduced on T2 with Default selected. Tapping the keyed overlay-size slider at its midpoint set 4.4×; the native controller logged a 1231×902 px window, while the Default text remained small in its corner. [T2 native capture at 4.4×](../../tmp/qa/0129-investigation/default-4_4x.png).

`_DefaultSpeedcamReadout` in [SpeedcamRadarWidget](../../lib/hud/speedcam_radar_widget.dart) uses fixed 22/28/20 dp text and `FittedBox(BoxFit.scaleDown)`, which can shrink the stack but cannot enlarge it for a larger slot. The existing [overlay scale test](../../test/hud/speedcam_overlay_size_scale_test.dart) covers Alien CRT fill only; focused look and Alien-scale tests pass but do not cover Default scaling.

## Definition of Done

- [x] Default readout grows with the overlay window at 1× and 4.4×; text, arrow, spacing, and shadow remain readable and fit.
- [x] Widget coverage compares the Default distance text at distinct slot sizes, including 4.4×.
- [x] T2 native capture confirms scaled Default content in the actual system-overlay window.

## Reconciliation

Fix: pass `overlaySizeScale` from `SpeedcamOverlayApp` to the Default readout. Scale its typography, letter spacing, right inset, and shadow together. Compact HUD and DHU preview remain at 1×; the existing scale-down guard still handles smaller slots.

Verification: the new `0129` widget test failed before the fix (font ratio 1.0 at 4.4×) and passes after it. T2 native capture at 4.4× shows the Default arrow, distance, and speed in the 1231×902 px window: `tmp/qa/0129-live/default-4_4x-scaled.png`.