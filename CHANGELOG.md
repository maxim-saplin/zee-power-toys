# Changelog

All notable changes to Zee Power Toys are documented here.

Versioning: `MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml`.
Bump **+BUILD** on every tip; bump MAJOR.MINOR.PATCH for user-facing size (0091). Release tags fire `release.yml`.

## [Unreleased]

## [1.1.0+11] — 2026-09-23

MINOR release (0091): user-facing size past 1.0.0+N tips — CRT/lane/USB/install/harness stack.

### Added
- **0083** Alien CRT parity — one DPI-agnostic plate + large type across HUD / DHU preview / Overlay (`ea3f461`).
- **0088** Lane-cam filter — `alertLaneCams` default OFF; pure-YNavi LANE only; merge does not stamp LANE onto OSM (`a1fd8d9`+`bd54d10`).
- **0089** Agent drive harness — `ext.zee.speedcam action=demo|demoStop` + `feedback_loop.py speedcam-demo on|off` (no OCR) (`081431f`).

### Fixed
- **0084** Parallel Update + YNavi install — EventChannel multiplex; companions finish before self-update commit (`a07a549`).
- **0085** USB cold-open — refresh live `persist.usb.mode` (no stale Peripheral default) (`efe1f35`).
- **0086** Install progress backstep — installing indeterminate / fraction 1.0 after download (`88c6aa6`).
- **0087** YNavi label — Deepal+Zeekr show upstream **v27.0.2** (not internal v12) (`1299105`).

### Notes
- **0090** direction enrich spike **NO-GO** — YNavi MapKit Event has no cam azimuth to copy onto undirected OSM (`2dae106`). Do not invent headings.
- Versioning (0091): MAJOR/MINOR/PATCH for user-facing size; +BUILD every tip. This line is **1.1.0+11**.

## [1.0.0+10] — 2026-09-22

### Fixed
- About / self-update version from PackageInfo only — drop hardcoded `lib/app_version.dart` (+6 lie). Tip `0f38264`.

## [1.0.0+9] — 2026-09-21

### Fixed
- Analyzer: drop unnecessary `!` on YNavi enrich start (CI)

### Added
- YNavi speedcam enrich (ghost idle-drive + route on Go) behind Speedcam **YNavi enrich** toggle — **default OFF**
- Cancel→ghost revive via `Guidance.start(null)` (wire-assisted STOP_GUIDANCE); Windshield path closed
- OSM · YNavi counters; YNavi point aging TTL (default 7d); collect/alert gates for YNavi
- Speedcam map expand/collapse + go to my location

### Notes
- Motion-backed DoD; not true free-roam. Pair with ynavi-zee tip on main (`4d93cf2eb` lineage).

## [1.0.0+7] — 2026-09-21

### Added
- DHU appearance: Auto (follow system) / Dark / Light Material 3 theme; HUD stays emissive black
- Dangerous speedcam: ±45° front cone + facing when host heading known (unknown heading → cone-only)

### Fixed
- Charge Dig/HUD: EventChannel seed after AdaptAPI start; always emit live kW; HUD seed on hudReady/config
- Leave/return HUD: Presentation reattach (DisplayListener + ensureHudPresentation); boot/FGS bring Activity
- Charge bool never null in diagnostics; CI Cluster language tests scroll past Appearance

### Added
- 0070 DHU system overlay shows full Speedcam UI (Alien|Default radar) via Flutter surface in TYPE_APPLICATION_OVERLAY
- `README_RU.md` — Russian product landing; EN/RU switch at top of both READMEs

## [1.0.0+6] — 2026-09-21

### Added
- 0070 DHU system overlay shows full Speedcam UI (Alien|Default radar) via Flutter surface in TYPE_APPLICATION_OVERLAY

## [1.0.0+5] — 2026-09-20

### Changed
- README rewritten as product landing (front face, quick start, companions; arch last)

## [1.0.0+4] — 2026-09-20

### Added
- 0065 Speedcam DHU system overlay (draw-over-apps) + settings toggle

## [1.0.0+3] — 2026-09-20

### Added
- Self-update from public GitHub Releases (0069) — Install screen Check / Update

## [1.0.0+2] — 2026-09-20

### Fixed
- CI release build: commit AOSP `androiddebugkey.jks` (was gitignored → GH fail)
- Diagnostics/HUD charge fields: read snapshot (not latest stream event); show signed kW whenever present

## [1.0.0] — 2026-09-20

First numbered product line on `0044-publish-prep`.

### Added
- Speedcam HUD/sound modes (Any / Dangerous / Off), map harvest preview, alert loudness on NAV volume
- Battery look picker (pack / pack+% / bars / text) with dual-color % inside pack
- Minimap only-while-guidance, GuidanceOverlayView scale slider
- Boot FGS auto-start + remediations (locale, YNavi whitelist)

### Fixed
- Charging indicator: real `SENSOR_TYPE_EV_BATTERY_STATE` enums + kW fallback (0066)
- HUD battery cluster: room for 3 charging lines; sizeScale no longer reverse-shrinks (0067 / 0067b)
- Speedcam radar blip colors (dangerous white / others greenish)
- Platform signing so `adb install -r` keeps data

### Changed
- Product label **Zee Power Toys**; launcher asset from public `zeekr_apk_mod`
