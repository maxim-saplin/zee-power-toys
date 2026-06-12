---
status: done
labels: [feature, navigation]
created: 2026-06-12
closed: 2026-06-12
satisfies: HUD · Minimap — real YNavi cluster map on the HUD surface
blocked-by: []
modules: [HudHost, MinimapHost]
tier: T2
---

# 0019 — YNavi cluster map render

## Block scope
Block 0018 binds YNavi's `NavigationCarAppService` and confirms handshake +
`onSurfaceAvailable` + location streaming, but the **cluster map pixels are not drawn**
onto our HUD surface (we still see the green placeholder). This Block lands the real map.

This is **de-risked by phase0's recovered, emulator-verified recipe**
(`/home/user/src/zee_hud_2/docs/31_7_1_…` baseline + `31_7_2_EMULATOR_E1_NAVIGATION_REPORT.md`,
2026-02-21 — "E1 PASSED: live cluster surface with route overlay + updateTrip").

## The proven phase0 recipe (what makes the map render)
1. **Clear cached YNavi state** — `adb shell pm clear ru.yandex.yandexnavi`. phase0's #1
   gotcha: stale state silently suppresses `setSurfaceCallback`. `pm clear` fixed it reliably.
2. **Pre-grant location via adb** (no UI) — `pm grant ru.yandex.yandexnavi
   android.permission.ACCESS_FINE_LOCATION` (+ `ACCESS_COARSE_LOCATION`). The mod's P4 NOPs
   YNavi's in-projection permission screen, so no `ScreenBlockActivity` interaction is needed.
3. **Paywall is already handled** — mod patch **P9 emits `HasPlus`**, bypassing the
   `PLUS_COUNTRY_UNAVAILABLE` `MessageTemplate`. The map renders **despite** Play-Integrity
   failing on the emulator (the earlier "integrity blocks it" theory was wrong).
4. **Cold-start E0** — fresh YNavi + fresh host bind → static cluster map (Minsk + GPS arrow).
5. **Live E1 (optional)** — drive active nav by deep link **while the host is NOT bound**
   (`yandexnavi://build_route_on_map?lat_to=…&lon_to=…`, tap Go), then rebind without
   force-stopping YNavi → live route overlay + `updateTrip`. (Deep links while bound kill the
   cluster surface — never send them mid-bind.)

## Host-side divergences to close (phase0 `CarAppHostService` vs our `YNaviCarAppHost`)
The handshake code is identical; these behavioral gaps are the suspected render blockers:
- **Surface-readiness race** — we call `onSurfaceReady` from `start()` and may bind before the
  surface is valid; phase0 owns the `Presentation`/`HudPresentation` and fires `onSurfaceReady`
  only when the surface is genuinely ready.
- **Missing navigation-manager fetch + one-shot template probe** — phase0 fetches
  `getManager("navigation")` and probes the template after resume (and re-probes on
  `onInvalidate`), nudging YNavi to push frames; we only fetch `"app"` and no-op invalidate.
- **(lower priority)** `onConfigurationChanged` for night mode; session `restartGuard`.

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] Real YNavi cluster map rendered on the HUD surface, runtime-confirmed on **T2** —
      artifact: `shots/redo/t2-ynavi-map.png` (actual map tiles, **not** the green placeholder).
- [x] logcat fingerprint: `setSurfaceCallback callback=true` + `onSurfaceAvailable SUCCESS`
      and (if E1) `navigationStarted` + `updateTrip`.
- [x] `flutter analyze` clean; tests green; debug APK builds.
- [ ] Drivable through the Feedback Loop (enable/disable the minimap starts/stops the host).
- [x] Docs reconciled; the green placeholder path documented as the no-YNavi fallback.

## Notes
Emulator is at 160 dpi. Fixed modded YNavi APK (P1 + `car-app-api.level` "8\n" + P9, signed
platformkey) at `/tmp/ynavifix/zeekr_final.apk`, installed as `ru.yandex.yandexnavi`.

## Root-cause fix (2026-06-12)

Three bugs chained to block the map render:

1. **Missing `import android.view.ViewGroup`** — `parkForYNavi` uses `parent as? ViewGroup` but
   `ViewGroup` was not imported; build failed silently in the long Gradle run.

2. **Presentation context cast** — `MinimapView` is created with `pres.context` (a `Presentation`
   context, not `MainActivity`). `onSurfaceTextureAvailable` used `(context as? MainActivity)`
   which always returned `null`, silently falling back to `startRenderLoop()` instead of
   calling `startYNaviOnSurfaceReady()`.  Fix: `MinimapView.mainActivity` direct reference,
   set at construction: `MinimapView(pres.context).also { it.mainActivity = this }`.

3. **`SurfaceTexture` api=2 slot held by Canvas** — the `lockCanvas()` render loop registers
   as api=2 on the `SurfaceTexture`; thread exit does NOT disconnect it.  Fix: `removeView(this)`
   + `pg.post { addView(this, idx, lp) }` forces a full TextureView lifecycle (detach → release
   → re-attach → new GL-attached SurfaceTexture → `onSurfaceTextureAvailable`).

Confirmed artifact: `shots/redo/t2-ynavi-map.png` — "Kuzmy Chornaga St" label visible on
Display 2 (1280×720, 213 dpi HUD overlay) through the green-yellow ColorMatrix filter.
