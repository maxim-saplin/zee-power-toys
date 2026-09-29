# Changelog

All notable changes to Zee Power Toys are documented here.

Versioning: `MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml`.
Bump **+BUILD** on every tip; bump MAJOR.MINOR.PATCH for user-facing size (0091). Release tags fire `release.yml`.

## [Unreleased]

## [1.1.0+31] — 2026-09-29

Live ship: **0122A** YNavi v30 minimap live-session fix.

### Fixed
- **0122A** Preserve the active YNavi minimap surface session across cold rebind and superseded teardown (`757db4d`).

### Notes
- T2 soft ACCEPT: minimap surface callback + live overlay tiles; evidence `tmp/qa/0122a-minimap-prove/`.
- AOSP platform-signed via `release.yml`.


## [1.1.0+30] — 2026-09-28

Live ship: ACCEPTed **0125** MediaSession bind (Soft FakeMediaOnly closed) + prior **0123**/**0124** ancestry from +29.

### Changed
- **0125** HUD media chrome binds native Android **MediaSession** now-playing (DHU `zee/media` + hub relay); Soft FakeMediaOnly closed. `ext.zee.inject kind=media` remains debug fallback (`2161990`).

### Notes
- **Live ship** — tip `b9ddade` / APK sha256 `ef6c5e473481ea32543b5b7f60158d32fb336a2c5206b9e56d2f536a998a6722` / tag `1.1.0+30` GH Latest. Soft FakeMediaOnly closed; Preferred real-session FAIL soft on debug Tablet (`MEDIA_CONTENT_CONTROL`) — platform Live/car leftover OK. Install UI unchanged: **v27.0.2 default** · **v30.8.1 beta non-default**. dens320 ship-gate DoD for QA: Install/Live APK **+30** contains **0125** MediaSession bind (+ **0123** B·compact + **0124** Just-text default ancestry).
- AOSP platform-signed via `release.yml`.


## [1.1.0+29] — 2026-09-28

Live ship: ACCEPTed **0123** HUD media B · compact + **0124** Just-text default + larger media title.

### Changed
- **0124** HUD battery default **Just text** (`look=justText` / `%` only, no pack) + larger media artist—song (`94e3970`).
- **0123** HUD media B · compact above bat/temp; HUD-surface `kind=media` inject + tighter bat pad (`6ba9c36`).

### Notes
- **Live ship** — tip `6e8a907` (release `de9d601` + gate fix) / APK sha256 `ec5f25d55ead44349278e01e8cb3bb9688efaa998d7f62d513ae8b2242e4d7db` / tag `1.1.0+29` GH Latest. Soft FakeMediaOnly FAIL-open. Install UI unchanged: **v27.0.2 default** · **v30.8.1 beta non-default**. dens320 ship-gate DoD for QA: Install/Live APK **+29** contains **0123** B·compact + **0124** Just-text default + larger media.
- AOSP platform-signed via `release.yml`.


## [1.1.0+28] — 2026-09-28

Live ship: Install screen **v30 beta** companion (non-default) + ACCEPTed **0120** HUD battery defaults / **0121** Replace older / **0122** Zee v30 parity tip.

### Added
- **Install** YNavi **v30.8.1 beta** card → Release `ynavi-zeekr-v30` asset `ynavi_30.8.1_zeekr_arm64_signed.apk` (tip `45fada46` / sha256 `a000a77f…`). **v27.0.2 remains the default** Install path (margined + OS7).

### Notes
- **PDM ACCEPT** dens320 ship-gate — tip `b5c3ca8` / APK sha256 `693eebdfbe48c1e2c51dc544339cc4bfe542e2e0a5fc75ff3e9cb65eb8001124` / tag `1.1.0+28` GH Latest. Install UI: **default = v27.0.2** · **v30.8.1 = beta non-default** (“Not default — prefer v27”). Evidence `tmp/qa/1.1.0+28-ship/` (FINDINGS · FOURPOINT PASS soft).
- Soft: SHARED_USER Live Tablet sideload · Deepal/OS7 · car T3 later (Maxim).
- AOSP platform-signed via `release.yml`.


## [1.1.0+26] — 2026-09-27

Live ship: ACCEPTed **0118** Float SoC + Cons1 dual Est. under docs seal `d6f9a24`.

### Changed
- **0118** Float SoC (no `toInt()`) + Cons1 dual Est.; keep **0117** bands + **0114** anti-cliff; DHU picker + both near toggle (`9b0c0ba`).

### Notes
- Docs ACCEPT `d6f9a24` (tip `9b0c0ba`). Bump past Live **1.1.0+25**. AOSP platform-signed via `release.yml`.
- Soft: car T3 / Cons lag / Cons2.

## [1.1.0+25] — 2026-09-26

Live ship: **0117** Own Est. window reshape under docs seal `a84dd2d`.

### Changed
- **0117** Own-range 3-band window — 1× / 8× / mute last 1 km; keep 0114 SoC quantum; no Adapt seed (`7c9397b`).

### Notes
- Docs ACCEPT `a84dd2d` (tip-SHA stamp `101ab03`). Code tip `7c9397b` (0117). AOSP platform-signed via `release.yml` (same keystore as +24).
- Soft: car T3 ~2× vs Adapt — not chased in this ship.

## [1.1.0+24] — 2026-09-26

Live ship: afternoon queue **0112–0116** under docs seal `85b76b2`.

### Fixed
- **0114** Own-range short-trip SoC quantum — Est. no longer cliffs after short hop (`9ad6c56`).
- **0112** Drive-mode accents — ECO blue / Comfort green / Sport red on toast + corner-dot (`2bf2a30`).

### Added
- **0113** Sport BR corner-dot gentle pulse; ECO/Comfort stay calm (`b5d7074`).
- **0115** Install screen auto-check Toys version on open (`77a8b76`).

### Changed
- **0116** Overlay size slider max 1.6→8.0 (~5× prior) (`74edf87`).

### Notes
- Docs ACCEPT `85b76b2`. Code tips `2bf2a30` (0112) + `b5d7074` (0113) + `9ad6c56` (0114) + `77a8b76` (0115) + `74edf87` (0116). AOSP platform-signed via `release.yml` (same keystore as +23).
- Soft: car T3 stay soft — not chased in this ship.

## [1.1.0+23] — 2026-09-26

Live ship: **0109** drive-mode toast higher + colors + **0110** BR drive-mode corner-dot toggle.

### Fixed
- **0109** Drive-mode toast raise — Align −0.82 (above speedo); accents ECO green / Comfort blue / Sport red (`67eccc5`).

### Added
- **0110** BR drive-mode corner-dot settings toggle — default OFF; Comfort blue / ECO green / Sport yellow (`36f2384`).

### Notes
- Docs ACCEPT `811f384`. Code tips `67eccc5` (0109) + `36f2384` (0110). AOSP platform-signed via `release.yml` (same keystore as +22).
- Soft: car T3 stay soft — not chased in this ship.

## [1.1.0+22] — 2026-09-25

Live ship: **0106** overlay size slider scales window + CRT + **0107** own-range HUD polish + **0108** own-range weighted 50 km window.

### Fixed
- **0106** Overlay size slider — scales system overlay window + Alien CRT content (no letterbox/noop on re-enable); keep VISIBLE + force Flutter view size after WM layout (`488d7ec`).
- **0107** Own-range ON always visible — pending `… km` or ready `N km` (no ~); km/smaller %; SoC+range below pack (`e1c3419`).

### Changed
- **0108** Own-range honesty — distance-trimmed composite Wh/km (8×/4×/1× bands over 50 km, heavier last 10/3); 1 km display cadence; EN/RU help (`11ae3cd`).

### Notes
- Docs ACCEPT `7c1fc66`. Code tips `488d7ec` (0106) + `e1c3419` (0107) + `11ae3cd` (0108). AOSP platform-signed via `release.yml` (same keystore as +21).
- Soft: hint wording / car T3 stay soft — not chased in this ship.

## [1.1.0+21] — 2026-09-25

Live ship: **0104** HUD drive-mode change toast + **0105** own estimated range beside battery %.

### Added
- **0104** HUD drive-mode change toast — ECO / Comfort / Sport (~5 s fade) on Adapt `0x22010100` change only; cold-open / first-known-after-unknown never toasts (`bc48d13`).
- **0105** Own estimated range beside battery % — EWMA Wh/km while moving; toggle default OFF; hide ~km until ≥~5 km moving history; usable pack 100 kWh constant (`97784bb`).

### Notes
- Docs ACCEPT `5efac8f`. Code tips `bc48d13` (0104) + `97784bb` (0105). AOSP platform-signed via `release.yml` (same keystore as +20).
- Soft: T3 live Adapt enum tune / Adapt efficiency seed / pack constant stay soft — not chased in this ship.

## [1.1.0+20] — 2026-09-25

Live ship: **0102** Other traffic cams mute + **0103** Install Update vs Reinstall.

### Fixed
- **0102** Other traffic cams — mute YNavi `CROSS_ROAD_CONTROL` / `ROAD_MARKING_CONTROL` / `NO_STOPPING_CONTROL` / `TRAFFIC_CONTROL` (+ LANE) by default on alert/HUD/sound; settings **"Other traffic cams"** (`62720d0`).
- Soft: `MOBILE_CONTROL` left out of taxonomy (no strong field evidence).

### Changed
- **0103** Install self-update + companion cards: **Update** when Release newer; **Reinstall** when same (or tip-ahead); package `versionCode` probe vs pins (`bb45870`).
- Soft: home companions still Install-when-missing only; Live version bump is this line.

### Notes
- Docs ACCEPT `910676c`. Code tips `62720d0` (0102) + `bb45870` (0103). AOSP platform-signed via `release.yml` (same keystore as +19).
- Soft SHARED_USER on Tablet google_apis still expected for Release install (uninstall prior debug/sharedUser pairing first).

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
