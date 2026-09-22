---
id: 0082
title: DHU/Tablet UI letterboxes + clipped status-bar icons
status: cooking
priority: now
labels: [dhu, layout, tablet, status-bar, polish]
blocked-by: []
---

# 0082 — DHU/Tablet UI letterboxes + clipped status-bar icons

## Problem (Maxim 2026-09-22)

On Tablet AVD **2560×1600 dens 320** (DHU-matched T2), Zee Power Toys DHU UI does **not** look fine:

- Odd **letterboxing** (black side bars / content not filling the screen as expected)
- **Clipped / cramped status-bar icons** at the top edges
- Visible on home and Speedcam (and older T2 QA frames show the same chrome)

Maxim: this is a **product bug**, not a README screenshot quirk. App must look fine on Tablet/DHU.

## Evidence

- `docs/assets/en-home.png`, `en-speedcam.png` (rejected README cut)
- Same geometry on `tmp/qa/0080-t2-tablet-9051421/shots/00-home.png` / `02-settings-alien-FULL.png`

## DoD

1. On Tablet_Android_12L 2560×1600 dens 320 (no `wm density`), home + Speedcam + at least one other settings screen fill the usable DHU area **without** odd side letterboxing.
2. Status bar icons not clipped against the top/side edges.
3. No Overlay #1 / HUD preview required for this fix (leave HUD Presentation path alone unless it causes the letterbox).
4. QA: adb screencap FULL frames proving (1)+(2); PDM ACCEPT after own pixel DC.

## Notes / non-binding hunches

- Speedcam CRT plate uses a narrow max width for above-the-fold CRT (historical 0039/0080) — verify whether that (or other constraints) drives the side bars vs a window/insets/system-UI issue.
- Android 12L taskbar is host chrome; product layout still must not look broken inside the app surface.

## Who-next

@zee-dev tip fix → @zee-qa T2 FULL frames → @zee-pdm ACCEPT.

## Sequencing

Maxim 2026-09-22: **after 0081** (one Tablet). Do not start T2 cut until 0081 tips.
