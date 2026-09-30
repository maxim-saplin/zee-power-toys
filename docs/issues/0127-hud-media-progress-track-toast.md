---
status: done
labels: [hud, media, settings]
created: 2026-09-29
satisfies: HUD media playback indicator with progress and brief track-change label
tier: T2
owner: zee-dev
blocked-by: []
modules: [MediaConfig, BatteryWidget, HUD Settings, MediaNowPlaying]
priority: now
filed-by: zee-pdm
related: [0123, 0125]
---

# 0127 — HUD media progress with brief track label

## Block scope

Show playback progress on the HUD and briefly identify a newly playing track. The control surface is one toggle in DHU HUD Settings. This is a playback indicator, not play/pause/skip transport controls.

## Product rules

1. One persisted **Show media on HUD** toggle in DHU HUD Settings; default ON. Remove the icon, artist/title, progress, and bar-only options.
2. While an active track is playing, show its progress bar by default. Do not show an icon or elapsed/remaining time.
3. When artist/title changes, briefly show `artist — song` above the bar, then return to progress-only. Use a 5-second display window; progress ticks for the same track must not restart it.
4. Match the transient label's font size to the battery-temperature label. Keep the battery/temp bottom anchor stable while the label appears and disappears.
5. Preserve a stored `showMedia` preference. Read existing configs with their current toggle value; ignore legacy per-piece fields.
6. Paused or inactive media follows the existing hidden-media behavior. No YNavi or MediaSession transport commands are added.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [x] Media defaults to one visible progress bar with no icon or track text; disabling the toggle hides it.
- [x] A track change shows text-only artist/title for 5 seconds; progress-only updates do not extend the window; a subsequent track change starts a new window.
- [x] Artist/title font size equals the battery-temperature font size; the battery/temp anchor does not move.
- [x] DHU HUD Settings exposes exactly one media toggle and persists it across reload.
- [x] Widget/config tests cover defaults, old-config migration, one-toggle UI, visibility timing, progress updates, track changes, and text sizing.
- [x] T2 verification on `Tablet_Android_12L` proves the idle-to-first-track label, progress-only expiry, paused-track resume, one-toggle visibility/persistence, and stable battery/temp anchor; evidence: `tmp/qa/0127-live/`.

## Reconciliation

T2 exposed a missing label when the first track arrived after idle. `BatteryWidget` now observes media for the battery-slot lifetime and owns the five-second label timer, even while the media child is absent. Final T2 reconformance proves the first-track label, changed-while-paused label on resume, progress-only expiry, later track changes, and toggle persistence. The real MediaSession source from 0125 is unchanged. Final findings and captures are in `tmp/qa/0127-live/FINDINGS.md`.
