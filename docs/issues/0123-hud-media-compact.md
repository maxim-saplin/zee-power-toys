---
status: ready-for-qa
tip: c0947d3
labels: [hud, media, battery]
created: 2026-09-28
satisfies: HUD · utility info — now-playing chrome in BATTERY slot
tier: T1
owner: zee-dev
blocked-by: []
modules: [BatteryWidget, MediaConfig, FakeMediaNowPlaying, hud_settings_screen]
priority: soon
filed-by: zee-pdm
related: [0120, 0067, 0008]
---

# 0123 — HUD media chrome (B · compact)

## Product (Maxim lock 2026-09-28)

First cook — **B · compact** default:

1. Music icon · `artist — song` · progress bar under texts (**no times**).
2. Stack **above** battery/temp (grow upward like charging) — HUD BATTERY slot / `battery_widget`.
3. Per-piece toggles + **bar-only** minimal mode.
4. T1 concepts until dens320 green — **no Live bump** (stay **1.1.0+28**).

## DoD (dens320 cut)

- [ ] Compact media chrome paints above bat/temp in BATTERY slot (bottom-anchored grow-up).
- [ ] Prefs: showMedia / icon / artist—song / progress / barOnly.
- [ ] T1 unit + widget green; dens320 Tablet can prove layout (inject `kind=media` on **HUD** surface).
- [x] Tip to `origin/main` (`c0947d3`). No release.yml / no version bump.

## Soft / FAIL-open

- **MediaSession binding** — unclear on Zeekr DHU (which session token / host). Soft: T1 `FakeMediaNowPlaying` + `ext.zee.inject kind=media`. Hard bind + DHU→HUD relay deferred.
- Live hold **1.1.0+28**.

## Notes

- Slot growth mirrors 0067/0120 charging (`mediaChromeVisible` in `batteryClusterSlotFracs`).
- Config Preview demo seeds Artist — Song @ 42% so settings toggles are checkable without inject.

## DEV tip (2026-09-28 Europe/Minsk)

**Tip SHA:** `c0947d3`

- B · compact default in BATTERY slot: icon · `artist — song` · bar (no times), stacked above bat/temp (grow-up).
- Prefs: `MediaConfig` showMedia/icon/artistSong/progress/barOnly + HUD Settings section.
- T1: `FakeMediaNowPlaying` + `ext.zee.inject kind=media` (HUD surface for windshield; DHU for preview). Soft: native MediaSession + DHU→HUD relay deferred.
- Live hold **1.1.0+28** (no bump).
- Who-next: **@zee-qa** dens320 cut.
