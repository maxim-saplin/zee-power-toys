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
3. When artist/title changes, show `artist — song` above the bar for exactly 3.5 seconds, then return to progress-only. Progress ticks for the same track must not restart the timer.
4. Flow upward from the bottom anchor. Reserve a fixed label row above the progress bar; showing, hiding, or changing the label must not move the bar or battery/temp rows. Keep the media row left-aligned within its fixed-width block.
5. Match the transient label's font size to the battery-temperature label. Keep the battery/temp bottom anchor stable while the label appears and disappears.
6. Preserve a stored `showMedia` preference. Read existing configs with their current toggle value; ignore legacy per-piece fields.
7. Paused or inactive media follows the existing hidden-media behavior. No YNavi or MediaSession transport commands are added.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [x] Media defaults to one visible progress bar with no icon or track text; disabling the toggle hides it.
- [x] A track change shows text-only artist/title for exactly 3.5 seconds; progress-only updates do not extend the window; a subsequent track change starts a new window.
- [x] Transient non-playing or missing-media snapshots hide chrome without canceling that deadline; a same-track resume restores only the remaining label window.
- [x] The media block grows upward from a reserved label row; label visibility and title length do not move the progress bar or battery/temp rows.
- [x] Artist/title font size equals the battery-temperature font size; the battery/temp anchor does not move.
- [x] DHU HUD Settings exposes exactly one media toggle and persists it across reload.
- [x] Widget/config tests cover defaults, old-config migration, one-toggle UI, visibility timing, progress updates, track changes, and text sizing.
- [x] T2 verification on `Tablet_Android_12L` proves the idle-to-first-track label, progress-only expiry, paused-track resume, one-toggle visibility/persistence, and stable battery/temp anchor; evidence: `tmp/qa/0127-live/`.

## Reconciliation

T2 exposed a missing label when the first track arrived after idle. `BatteryWidget` now observes media for the battery-slot lifetime. A later T2 investigation found that transient non-playing or missing-media snapshots canceled the label timer; the widget now keeps the original deadline while chrome is hidden. T2 injected DHU→HUD checks verify same-track resume and expiry at the original deadline. Evidence: `tmp/qa/0127-live/` and `tmp/qa/0127-flicker/FINDINGS.md`. The debug AVD lacks `MEDIA_CONTENT_CONTROL`, so the real MediaSession transition remains unverified there; no T3 car was attached.
