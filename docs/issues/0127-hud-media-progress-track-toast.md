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
7. Keep the last playing snapshot, progress, label, and slot geometry through a one-second false/null grace. Hide after media stays inactive for the full grace. A playing update cancels the hide immediately. No YNavi or MediaSession transport commands are added.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [x] Media defaults to one visible progress bar with no icon or track text; disabling the toggle hides it.
- [x] A track change shows text-only artist/title for exactly 3.5 seconds; progress-only updates do not extend the window; a subsequent track change starts a new window.
- [x] Transient false/null snapshots preserve the last media snapshot and slot geometry for one second; stable inactivity hides, and same-track resume restores only the remaining 3.5-second label window.
- [x] The media block grows upward from a reserved label row; label visibility and title length do not move the progress bar or battery/temp rows.
- [x] Artist/title font size equals the battery-temperature font size; the battery/temp anchor does not move.
- [x] DHU HUD Settings exposes exactly one media toggle and persists it across reload.
- [x] Widget/config tests cover defaults, old-config migration, one-toggle UI, visibility timing, progress updates, track changes, and text sizing.
- [x] T2 verification on `Tablet_Android_12L` proves the idle-to-first-track label, progress-only expiry, paused-track resume, one-toggle visibility/persistence, stable battery/temp anchor, and the one-second hold through rapid false/null updates; evidence: `tmp/qa/0127-live/` and `tmp/qa/0127-flicker-hold/`.

## Reconciliation

T2 exposed a missing first-track label and then flicker from transient false/null snapshots. A shared Dart presentation state now holds the last playing snapshot for one second; the label, progress, widget visibility, and slot geometry use it. T2 injected DHU→HUD proof repeated six false/true changes in 0.618 s without hiding the widget, then hid it after a stable 1.05-second inactive gap. Evidence: `tmp/qa/0127-flicker-hold/`; earlier label/timer evidence: `tmp/qa/0127-live/` and `tmp/qa/0127-flicker/`. The 631-test suite and `flutter analyze lib test` pass. Released as `1.2.3+35`; workflow `36854096536`; APK SHA-256 `e1de09a860038e2f4b623f4236b201f0336a3e86d39f01a6fb1b44a1c0ebc976`. Real MediaSession events remain unverified because T2 lacks `MEDIA_CONTENT_CONTROL`; release APK installation on the AVD remains blocked by its shared-user certificate mismatch.
