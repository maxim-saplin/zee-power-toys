---
status: ready-for-qa
tip: 6ba9c36
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
- [x] Tip to `origin/main` (`6ba9c36` follow-up; was `c0947d3`). No release.yml / no version bump.
- [x] HUD-surface `ext.zee.inject kind=media` live (brace fix — not nested under `surface == dhu`).
- [x] Battery pack fill↔outline pad tighter (`batteryPackInnerPad` extra `bodyH*0.04`).

## Soft / FAIL-open

- **MediaSession binding** — unclear on Zeekr DHU (which session token / host). Soft: T1 `FakeMediaNowPlaying` + `ext.zee.inject kind=media` on **HUD** isolate (windshield). Hard bind + DHU→HUD relay deferred.
- Live hold **1.1.0+28**.

## dens320 FAIL fix (2026-09-28)

`c0947d3` nested HUD `kind=media` inject under `if (surface == 'dhu')` with `surface != 'dhu'` guard → dead on HUD isolate. Tip `6ba9c36` registers media-only inject outside the DHU brace. Maxim add-on: tighter bat fill↔outline pad.

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

## DEV tip follow-up (2026-09-28 Europe/Minsk)

**Tip SHA:** `6ba9c36` (follow-up to `c0947d3`)

- **Brace fix (hard):** `ext.zee.inject kind=media` registered on HUD isolate (outside `surface == 'dhu'`). Windshield dens320 can inject artist/title/progress.
- **Battery pad:** `batteryPackInnerPad` extra gap `bodyH*0.08` → `bodyH*0.04` (fill↔outline tighter).
- Live hold **1.1.0+28** (no bump).
- Who-next: **@zee-qa** dens320 re-cut (HUD-surface inject prove + bat pad).

