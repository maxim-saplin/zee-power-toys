---
status: done
labels: [hud, speedcam, audio]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0035, 0053]
modules: [AudioSpeedcamAlert]
tier: T1
owner: zee-dev
---

# 0059 — Speedcam alert loudness (HARD)

## Symptom (Maxim/PDM)
Bleep too quiet at app max. Ignores Media / NAV / Ringtone knobs **and** the
in-app Alert volume slider.

## Volume stream finding
| AudioAttributes usage | Typical AAOS / Zeekr volume group | Notes |
|---|---|---|
| `USAGE_ASSISTANCE_SONIFICATION` (was) | System / FX (often fixed quiet) | Ignored Media/NAV/Ring — **root cause** |
| `USAGE_ASSISTANCE_NAVIGATION_GUIDANCE` (**now**) | **Navigation** | Crankable; mixes with media when focus=NONE |
| `USAGE_MEDIA` | Media | Would pause risk if focus≠NONE; not used |
| `USAGE_NOTIFICATION_RINGTONE` | Ringtone | Wrong UX for HUD cues |

**Owner after fix: car Navigation volume** (+ in-app slider as digital gain).

`audioplayers` legacy `getStreamType()` maps most usages → `STREAM_MUSIC`, but
modern volume groups key off **AudioAttributes.usage** — NAV usage is what
makes the car NAV knob own the alert.

## Fix
- Context: `assistanceNavigationGuidance` + `contentType: sonification` +
  **`audioFocus: none`** (must not pause YNavi/media).
- Real gain: `speedcamAlertPlayerGain(slider)` (0=mute, 1=full); pass
  `volume:` into every `play()`; re-apply after `setAudioContext`.
- Normalize sting/ping WAVs to ~92–95% peak (sting was only ~35%).
- HUD seeds volume from prefs on `store.load()`.

## Definition of Done
- [x] Stream/usage documented (NAV owns alert)
- [x] Slider 0 mute / max full digital gain + louder assets
- [x] No exclusive focus
- [x] Unit tests for gain curve
- [ ] On-car ear QA: NAV knob + slider both move loudness
