---
status: in-progress
tip: 2161990
labels: [hud, media, mediasession]
created: 2026-09-28
satisfies: HUD utility info — now-playing from native MediaSession
tier: T2
owner: zee-dev
blocked-by: []
modules: [MediaSessionController, NativeMediaNowPlaying, FakeMediaNowPlaying, hub, BatteryWidget]
priority: soon
filed-by: zee-pdm
related: [0123, 0124]
---

# 0125 — Bind HUD media chrome to native MediaSession

## Product (Maxim GO 2026-09-28)

Close Soft FakeMediaOnly (0123 FAIL-open):

1. Windshield B·compact chrome reads **artist / title / progress** from real Android **MediaSession** now-playing.
2. DHU→HUD **zee/hub** relay (same pattern as CarSignals) — HUD isolate is a Fake sink.
3. `ext.zee.inject kind=media` / `FakeMediaNowPlaying` stay as **debug fallback** only.
4. Live hold **1.1.0+29** on this tip — **no bump**. After dens320 PASS + PDM ACCEPT, separate GO publishes **1.1.0+30**.

## DoD (dens320 cut)

- [x] Native `MediaSessionController` (`zee/media` + events) on DHU engine; `MEDIA_CONTENT_CONTROL` declared.
- [x] Dart `NativeMediaNowPlaying` on Android DHU; HUD Fake + `pushMediaToHud` / `onMedia`.
- [x] Unit tests green (`native_media_now_playing_test`, `media_relay_test`, media chrome).
- [x] dens320 prove path documented (real session preferred; inject alternate).
- [ ] Tip to `origin/main` (`2161990`). Live still **1.1.0+29**. Soft FakeMediaOnly closed.

## dens320 prove (QA)

**HOST_SOT unchanged:** Tablet **2560×1600@hw320**; System UI Override dens **160**; ZeeUiScale **175/130**; overlay **1024×576/213**; never `wm density`.

### Preferred — real MediaSession

1. Install/run Live tip APK (platform-signed; `MEDIA_CONTENT_CONTROL` via system uid).
2. On Tablet DHU: start a media app that publishes a session (e.g. **YouTube Music**, **Spotify**, **AIMP**, or `adb shell am start` a player) and play a track with metadata.
3. HUD windshield: B·compact shows ♪ **Artist — Song** + progress bar advancing (~500 ms ticks).
4. FL: HUD `ext.zee.readViewModel` → `media.artist` / `media.title` / `media.progress`; DHU RVM → `mediaSource: mediasession`.
5. Pause / stop session → chrome hides (or pauses progress); resume restores.

### Alternate — no real player on emu

If the AVD has no media app that owns an active session:

1. HUD isolate: `ext.zee.inject kind=media artist=… title=… progress=0.42` (debug fallback — layout only).
2. Clear: `ext.zee.inject kind=media clear=true`.
3. Still verify DHU native path is armed: DHU RVM `mediaSource` is `mediasession` (or inactive null media) — not stuck on Soft Fake-only.
4. Optional lab: `adb install` a session-publishing player APK, then re-run Preferred.

### Car path

Same native bind on DHU + hub relay to HUD Presentation. No ynavi-zee change required (in-process `zee/hub`).

## Soft leftovers

- Unprivileged (non-platform) installs: `getActiveSessions` SecurityException → inactive; inject remains debug fallback.
- Which session wins when several are active: prefer PLAYING with metadata (first match).
- Live **+29** ship-gate continues in parallel — this tip does not re-release.

## Notes

- Keep B·compact layout / Just-text battery default / larger media type from 0123/0124.
- ynavi-zee: **not touched** (relay is Toys hub only).

## DEV tip (2026-09-28 Europe/Minsk)

**Tip SHA:** `2161990`

- Native `MediaSessionController` (`zee/media` + events) on DHU; `MEDIA_CONTENT_CONTROL`.
- Dart `NativeMediaNowPlaying` on Android DHU; `pushMediaToHud` / HUD Fake sink.
- Soft FakeMediaOnly **closed**; `ext.zee.inject kind=media` = debug fallback only.
- Live hold **1.1.0+29** (no bump). After dens320 PASS + PDM ACCEPT → publish **1.1.0+30**.
- Who-next: **@zee-qa** dens320 cut (real MediaSession preferred; inject alternate in issue).
