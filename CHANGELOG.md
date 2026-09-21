# Changelog

All notable changes to Zee Power Toys are documented here.

Versioning: `MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml`.
Bump **+BUILD** on every tip/release APK; bump MAJOR.MINOR.PATCH for user-facing releases.

## [Unreleased]

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
