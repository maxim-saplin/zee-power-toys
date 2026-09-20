---
status: in-progress
labels: [hud, minimap, ynavi]
created: 2026-09-20
satisfies: HUD · Minimap
blocked-by: [0054]
modules: [MinimapHost, HudRoot, GuidanceOverlayView, YNaviCarAppHost]
tier: T1
owner: zee-dev
---

# 0055 — YNavi minimap street/ETA (Zee HUD 2 GuidanceOverlayView)

## Block scope
Show street + ETA on the HUD minimap **like Zee HUD 2**: Android View overlay
fed by `INavigationHost.updateTrip` (~1s), not a Flutter plate and not relying
on YNavi map-pixel maneuver-street chrome alone.

## FAIL write-up (CRITICAL — Maxim on car, 2026-09-20)

### What was tried (redirect tip `06311e6` + ynavi `becbdab07`)
1. **Flutter `MinimapGuidanceOverlay`** painted from `GuidanceEvent` — Maxim/PDM
   rejected; deleted at `06311e6`.
2. **YNavi native map-pixel flag** forced on:
   - `projectedsession/b1.isManeuverStreetInfoVisible()` → always `true`
   - `bk1/s` layer create → `setManeuverStreetInfoVisible(true)`
   - Verified on car `8d95aaec`: APK md5 matches `builds/zeekr_signed.apk`,
     lastUpdateTime 2026-09-20 16:25:37.
3. Result on HUD after redirect: **no Maxim street+ETA bar**. Map may still show
   incidental road labels (M-5/E271) and lane arrows — **not** DoD.

### Root cause
**Native `setManeuverStreetInfoVisible` alone is insufficient** for Zee HUD 2
parity:

- Zee HUD 2 does **not** depend on map-pixel street chrome for the Maxim bar.
  It paints **`GuidanceOverlayView`** (Android Views on the HUD Presentation)
  from `INavigationHost.updateTrip` every ~1s. See
  `zee_hud_2/phase0-diagnostics/YNAVI.md` + `GuidanceOverlayView.kt`.
- Power Toys already decoded `updateTrip` into the `zee/minimap/guidance`
  EventChannel (FL / 0057 `navActive`) but, after deleting the Flutter plate,
  **nothing painted** that data on the Presentation.
- Belt: `minimapScale` / buffer oversample **crops** top/bottom YNavi chrome
  inside the TextureView, so even when the map-pixel flag is true, street/ETA
  pixels can sit outside the visible square. Host overlay is independent of
  that crop.

## Fix (this tip)
1. **Port `GuidanceOverlayView`** into
   `android/.../carapp/GuidanceOverlayView.kt` (package renamed; local
   `GuidanceOverlaySettings` with `guidanceOverlay` / `etaBar` / `overlayScale`).
2. **Wire on HUD Presentation** (above FlutterTextureView, sized to minimap
   viewport via `setMinimapBounds` + Zee HUD 2 `overlayScale` layout):
   - `host.onTrip` → `guidanceOverlay.updateFromTrip(trip)` (+ EventChannel)
   - `host.onNavState(false)` → `clearGuidance()`
   - Follows `setMinimapSurfaceVisible` (0057 gate)
3. **Toggles** (Zee HUD 2 `guidance_overlay` / `eta_bar`):
   - `MinimapConfig.guidanceOverlay` / `etaBar` / `overlayScale` (defaults on / 0.5)
   - Minimap settings switches + `setMinimapParam` + FL `ext.zee.setConfig`
4. **Do not** reintroduce Flutter `MinimapGuidanceOverlay`.
5. YNavi map-pixel force-on remains as optional belt; not required for DoD.

## Definition of Done
- [x] Flutter ETA/street plate stays deleted
- [x] Native `GuidanceOverlayView` on Presentation from `updateTrip`
- [x] `guidance_overlay` / `eta_bar` toggles (defaults on)
- [x] Issue + BACKLOG updated with FAIL write-up
- [ ] Runtime T2/T3: street + ETA Maxim bar visible on minimap during guidance
      (`adb install -r` power-toys; ynavi tip optional)

## How to verify
1. Power-toys tip on `0044-publish-prep` with this fix; `adb install -r` (never uninstall).
2. Enable Minimap; start YNavi guidance.
3. Logcat: `ZEE` / `YNaviCarApp` show `INavigationHost.updateTrip` +
   `layoutGuidanceOverlay(...)`.
4. `screencap -d 2`: top bar (arrow + distance + street) and bottom ETA bar
   over the minimap square — **not** Flutter dim/green-border plate; native
   M-5 labels alone do **not** PASS.
5. Toggle “Turn-by-turn overlay” / “ETA bar” in Minimap settings → bars hide/show live.

## Install note for parent
- Power-toys: rebuild + `adb install -r` from tip on `0044-publish-prep`
- YNavi: `becbdab07` already on car (optional belt); no uninstall
- Keep 0058/0059 tips intact
